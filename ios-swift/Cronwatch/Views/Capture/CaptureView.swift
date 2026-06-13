import SwiftUI
import UIKit

enum CapturePhase: Equatable {
    case idle
    case recording
    case queued
    case savingText
}

private let minRecordingDuration: TimeInterval = 0.5
private let queuedFlashDuration: UInt64 = 300_000_000

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var queue: CaptureQueue
    @StateObject private var recorder = AudioRecorder()

    @ObservedObject private var consent = AIConsentStore.shared

    @State private var phase: CapturePhase = .idle
    @State private var typed: String = ""
    @State private var pulse: CGFloat = 1.0
    @State private var isPressing: Bool = false
    @State private var showConsent: Bool = false
    /// Action to run once the user agrees to the AI data disclosure.
    @State private var pendingAfterConsent: (() -> Void)?
    @FocusState private var textFocused: Bool

    private var hasTypedContent: Bool {
        !typed.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var typedSaveDisabled: Bool {
        !hasTypedContent || phase != .idle
    }

    private var idleStatusText: String {
        switch phase {
        case .savingText: return "Queued — processing in the background…"
        case .queued:     return "Queued — processing in the background…"
        default:          return "Hold to record, or type below."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.border)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.sm)

            header

            idleContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.bg)
        .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))
        .interactiveDismissDisabled(isInBusyPhase)
        .sheet(isPresented: $showConsent) {
            AIDataConsentView(
                onAgree: {
                    consent.recordConsent()
                    showConsent = false
                    let action = pendingAfterConsent
                    pendingAfterConsent = nil
                    action?()
                },
                onDecline: {
                    pendingAfterConsent = nil
                    showConsent = false
                }
            )
            .presentationDetents([.large])
        }
    }

    /// Runs `action` immediately if the user has already consented to AI data
    /// sharing; otherwise presents the one-time disclosure and runs it on agree.
    private func withAIConsent(_ action: @escaping () -> Void) {
        if consent.hasConsented {
            action()
        } else {
            pendingAfterConsent = action
            showConsent = true
        }
    }

    private var isInBusyPhase: Bool {
        switch phase {
        case .recording, .queued, .savingText: return true
        default: return false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
            }
            .contentShape(Rectangle())
            .disabled(isInBusyPhase)

            Spacer()

            Text(headerTitle)
                .font(.cwBody.weight(.semibold))
                .foregroundColor(Palette.ink)

            Spacer()

            // Invisible placeholder keeps the title centered.
            Text("Cancel")
                .font(.cwBody)
                .foregroundColor(.clear)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    private var headerTitle: String {
        switch phase {
        case .queued, .savingText: return "Queued"
        default:                   return "New entry"
        }
    }

    // MARK: - Idle / recording content

    private var idleContent: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── Upper: record section ────────────────────────────
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: Spacing.lg) {
                        if !textFocused {
                            if phase == .idle {
                                hintBlock
                            } else {
                                Text(idleStatusText)
                                    .font(.cwBody)
                                    .foregroundColor(Palette.muted)
                                    .multilineTextAlignment(.center)
                            }
                        } else if phase != .idle {
                            Text(idleStatusText)
                                .font(.cwBody)
                                .foregroundColor(Palette.muted)
                                .multilineTextAlignment(.center)
                        }

                        ZStack {
                            if phase == .recording {
                                WaveformView()
                            } else {
                                Text("............")
                                    .font(.cwCaption)
                                    .foregroundColor(Palette.muted)
                                    .tracking(4)
                            }
                        }
                        .frame(height: 36)

                        recordSection
                    }
                    .padding(.horizontal, Spacing.md)

                    Spacer(minLength: 0)
                }
                .frame(height: geo.size.height * (textFocused ? 1.0 / 3.0 : 2.0 / 3.0))
                .clipped()
                .animation(.spring(duration: 0.35), value: textFocused)

                // ── Lower: text input ────────────────────────────────
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Palette.border)
                        .frame(height: 1)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $typed)
                            .font(.cwBody)
                            .foregroundColor(Palette.ink)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($textFocused)
                            .disabled(phase != .idle)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)

                        if typed.isEmpty {
                            Text("Or type an entry…")
                                .font(.cwBody)
                                .foregroundColor(Palette.muted.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(Palette.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(textFocused ? Palette.amber : Palette.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)

                    if hasTypedContent {
                        HStack {
                            Spacer()
                            Button(action: { Task { await onSaveTyped() } }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(typedSaveDisabled ? Palette.muted : Palette.amber)
                            }
                            .contentShape(Rectangle())
                            .disabled(typedSaveDisabled)
                            .padding(.trailing, Spacing.md)
                            .padding(.top, Spacing.xs)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(height: geo.size.height * (textFocused ? 2.0 / 3.0 : 1.0 / 3.0))
                .animation(.spring(duration: 0.35), value: textFocused)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hintBlock: some View {
        VStack(spacing: Spacing.sm) {
            Text("Say what you did, the start time, and the end time — include AM/PM or use 24-hour time.")
                .font(.cwBody)
                .foregroundColor(Palette.muted)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("TRY SAYING")
                    .font(.cwCaption)
                    .tracking(1.2)
                    .foregroundColor(Palette.muted)
                    .padding(.bottom, 2)
                Text("\u{201C}Worked on the report from 9am to 10am\u{201D}")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("\u{201C}Meeting from 2pm to 3pm, gym from 6pm to 7pm\u{201D}")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("\u{201C}Slept from 11pm to 7am\u{201D}")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("\u{201C}Deep work from 14:00 to 16:30\u{201D}")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("One recording can capture multiple time slots.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private var recordSection: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Palette.amber)
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

                if phase == .savingText || phase == .queued {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "mic")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(pulse)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            isPressing = true
                            Task { await onPressIn() }
                        }
                    }
                    .onEnded { _ in
                        if isPressing {
                            isPressing = false
                            Task { await onPressOut() }
                        }
                    }
            )
            .allowsHitTesting(phase == .idle || phase == .recording)
            .onChange(of: phase) { _, newValue in
                if newValue == .recording {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        pulse = 1.08
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pulse = 1.0
                    }
                }
            }

            Text("HOLD TO RECORD")
                .font(.cwCaption)
                .foregroundColor(Palette.muted)
                .tracking(1)
                .padding(.top, Spacing.sm)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Press handlers

    private func onPressIn() async {
        guard phase == .idle else { return }
        // Disclose AI data sharing and get permission before any recording or
        // upload happens. The user re-presses to record after agreeing.
        guard consent.hasConsented else {
            isPressing = false
            pendingAfterConsent = nil
            showConsent = true
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let granted = await recorder.requestPermission()
        guard granted else {
            isPressing = false
            phase = .idle
            return
        }
        // User may have released during the permission round-trip.
        guard isPressing else {
            phase = .idle
            return
        }
        do {
            try recorder.start()
            phase = .recording
        } catch {
            isPressing = false
            phase = .idle
        }
    }

    private func onPressOut() async {
        guard phase == .recording else { return }
        guard let recording = recorder.stop() else {
            phase = .idle
            return
        }

        // Discard too-short recordings (accidental taps).
        guard recording.duration >= minRecordingDuration else {
            try? FileManager.default.removeItem(at: recording.url)
            phase = .idle
            return
        }

        guard let uid = auth.currentUser?.uid else {
            try? FileManager.default.removeItem(at: recording.url)
            phase = .idle
            return
        }

        _ = queue.enqueue(uid: uid, audioURL: recording.url, provider: TranscriptionSettings.shared.provider)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        phase = .queued
        try? await Task.sleep(nanoseconds: queuedFlashDuration)
        dismiss()
    }

    // MARK: - Cancel & typed save

    private func onCancel() {
        if phase == .recording {
            _ = recorder.stop()
        }
        dismiss()
    }

    private func onSaveTyped() async {
        let trimmed = typed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard phase == .idle else { return }
        guard let uid = auth.currentUser?.uid else { return }

        // Typed entries are also sent to Together AI for structuring, so gate
        // the first one on the same disclosure.
        withAIConsent {
            phase = .savingText
            _ = queue.enqueueText(uid: uid, transcript: trimmed)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                try? await Task.sleep(nanoseconds: queuedFlashDuration)
                dismiss()
            }
        }
    }
}

private struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
