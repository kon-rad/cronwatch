import SwiftUI

struct ToastHost: View {
    @EnvironmentObject var toasts: ToastCenter

    var body: some View {
        VStack {
            if let toast = toasts.current {
                ToastBubble(toast: toast) { toasts.dismiss(toast.id) }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(toasts.current != nil)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: toasts.current?.id)
    }
}

private struct ToastBubble: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Text(toast.message)
                .font(.cwBody.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = toast.action {
                Button {
                    action.handler()
                    onDismiss()
                } label: {
                    Text(action.label)
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(.white)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }

    private var background: Color {
        switch toast.kind {
        case .info:    return Palette.ink
        case .success: return Palette.amber
        case .error:   return Palette.danger
        }
    }
}
