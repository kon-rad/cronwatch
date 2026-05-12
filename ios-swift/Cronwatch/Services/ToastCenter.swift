import Foundation

enum ToastKind: Equatable { case info, success, error }

struct Toast: Identifiable, Equatable {
    let id: String
    let message: String
    let kind: ToastKind
    let duration: TimeInterval?
    let action: ToastAction?

    struct ToastAction: Equatable {
        let label: String
        let handler: () -> Void

        static func == (lhs: ToastAction, rhs: ToastAction) -> Bool {
            lhs.label == rhs.label
        }
    }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published private(set) var current: Toast?

    private init() {}

    @discardableResult
    func show(message: String,
              kind: ToastKind = .info,
              duration: TimeInterval? = nil,
              action: Toast.ToastAction? = nil) -> String {
        let toast = Toast(
            id: Self.newId(),
            message: message,
            kind: kind,
            duration: duration,
            action: action
        )
        return show(toast)
    }

    @discardableResult
    func show(_ toast: Toast) -> String {
        current = toast
        if let duration = toast.duration, duration > 0 {
            let id = toast.id
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard let self else { return }
                if self.current?.id == id { self.current = nil }
            }
        }
        return toast.id
    }

    func dismiss(_ id: String? = nil) {
        guard let current else { return }
        if let id, current.id != id { return }
        self.current = nil
    }

    private static func newId() -> String {
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(5).lowercased())
        return "t_\(ms)_\(suffix)"
    }
}
