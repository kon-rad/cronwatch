import SwiftUI
import UIKit

enum CapturePhase { case idle, recording, savingText, saved }

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var queue: CaptureQueue
    @StateObject private var recorder = AudioRecorder()

    @State private var phase: CapturePhase = .idle
    @State private var typed: String = ""
    @State private var pulse: CGFloat = 1.0

    private var hasContent: Bool {
        !typed.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var saveDisabled: Bool {
        !hasContent || phase == .savingText || phase == .saved
    }

    private var statusText: String {
        switch phase {
        case .recording:  return "Listening…"
        case .savingText: return "Saving…"
        case .saved:      return ""
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

            VStack(spacing: Spacing.lg) {
                if phase == .idle {
                    hintBlock
                } else {
                    Text(statusText)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.md)

            footer
        }
        .background(Palette.bg)
        .clipShape(RoundedCorners(radius: 20, corners: [.topLeft, .topRight]))
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
            }
            .contentShape(Rectangle())

            Spacer()

            Text(phase == .saved ? "Logged." : "New entry")
                .font(.cwBody.weight(.semibold))
                .foregroundColor(Palette.ink)

            Spacer()

            Button(action: { Task { await onSave() } }) {
                Text("Save")
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(saveDisabled ? Palette.muted : Palette.amber)
            }
            .disabled(saveDisabled)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    private var hintBlock: some View {
        VStack(spacing: Spacing.sm) {
            Text("Hold to record, or type below.")
                .font(.cwBody)
                .foregroundColor(Palette.muted)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("TRY SAYING")
                    .font(.cwCaption)
                    .tracking(1.2)
                    .foregroundColor(Palette.muted)
                    .padding(.bottom, 2)
                Text("\u{201C}Just worked on the report for 30 minutes\u{201D}")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("\u{201C}9 to 10 was a meeting, gym from 1 to 2\u{201D}")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("\u{201C}Last hour: 30 min email, 30 min deep work\u{201D}")
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

                if phase == .savingText {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "mic")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(pulse)
            .contentShape(Circle())
            .onLongPressGesture(
                minimumDuration: 0.0,
                maximumDistance: .infinity,
                perform: {},
                onPressingChanged: { pressing in
                    if pressing {
                        Task { await onPressIn() }
                    } else {
                        Task { await onPressOut() }
                    }
                }
            )
            .disabled(phase == .savingText || phase == .saved)
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

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)

            HStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    TextField("Or type an entry…", text: $typed)
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .submitLabel(.send)
                        .onSubmit { Task { await onSave() } }
                        .disabled(phase != .idle)
                        .padding(.vertical, 4)

                    if !typed.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: { Task { await onSave() } }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(Palette.amber)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Palette.white)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
    }

    private func onPressIn() async {
        guard phase == .idle else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let granted = await recorder.requestPermission()
        guard granted else {
            phase = .idle
            return
        }
        do {
            try recorder.start()
            phase = .recording
        } catch {
            phase = .idle
        }
    }

    private func onPressOut() async {
        guard phase == .recording else { return }
        let url = recorder.stop()
        phase = .idle

        guard let url else { return }
        guard let uid = auth.currentUser?.uid else { return }
        _ = queue.enqueue(uid: uid, audioURL: url)
        dismiss()
    }

    private func onSave() async {
        let trimmed = typed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        phase = .savingText
        guard let uid = auth.currentUser?.uid else {
            phase = .idle
            return
        }
        do {
            let drafts = try await CaptureService.structureText(trimmed)
            _ = try await EntriesService.shared.createCaptureEntries(
                uid: uid,
                drafts: drafts,
                source: .text,
                transcript: trimmed,
                audioUrl: nil
            )
            phase = .saved
            try? await Task.sleep(nanoseconds: 600_000_000)
            dismiss()
        } catch {
            phase = .idle
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
