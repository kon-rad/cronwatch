import SwiftUI

struct EntryViewOnlyView: View {
    let captureId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var toasts: ToastCenter

    @StateObject private var audio = AudioPlayerService()

    @State private var capture: Capture?
    @State private var notFound = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.border)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.sm)

            header

            if notFound {
                Spacer()
                Text("Entry not found.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                Spacer()
            } else if let capture {
                detailScroll(capture: capture)
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(Palette.bg)
        .task { await loadCapture() }
        .onDisappear {
            audio.stop()
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
            }
            .contentShape(Rectangle())

            Spacer()

            Text(headerTitle)
                .font(.cwBody.weight(.semibold))
                .foregroundColor(Palette.ink)

            Spacer()

            if showPlayButton {
                Button(action: togglePlay) {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Palette.amber)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    private func detailScroll(capture: Capture) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let start = capture.blocks.first?.startTime {
                    Text(formatLongDate(start))
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(capture.blocks) { block in
                        BlockDetail(block: block)
                    }
                }
                .padding(.top, Spacing.sm)

                if let transcript = capture.transcript, !transcript.isEmpty {
                    Text(transcript)
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .lineSpacing(22 - 15)
                        .padding(.top, Spacing.md)
                        .textSelection(.enabled)
                } else if capture.blocks.count == 1, let note = capture.blocks.first?.note, !note.isEmpty {
                    Text(note)
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .lineSpacing(22 - 15)
                        .padding(.top, Spacing.md)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl * 2)
        }
    }

    private var headerTitle: String {
        guard let capture else { return "Entry" }
        return capture.blocks.count > 1 ? "Capture" : "Entry"
    }

    private var showPlayButton: Bool {
        guard let url = capture?.audioUrl, !url.isEmpty else { return false }
        return true
    }

    private func loadCapture() async {
        let uid = auth.currentUser?.uid ?? "stub-user"
        do {
            if let result = try await EntriesService.shared.getCapture(uid: uid, captureId: captureId) {
                capture = result
                if let url = result.audioUrl, !url.isEmpty {
                    _ = audio.load(urlString: url)
                }
            } else {
                notFound = true
            }
        } catch {
            notFound = true
        }
    }

    private func togglePlay() {
        guard let url = capture?.audioUrl, !url.isEmpty else { return }
        if audio.isPlaying {
            audio.pause()
            return
        }
        if !audio.load(urlString: url) {
            toasts.show(message: "Couldn't play audio", kind: .error, duration: 3)
            return
        }
        audio.play()
    }

    private func formatLongDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

private struct BlockDetail: View {
    let block: Entry

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(Categories.color(for: block.category))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(Categories.label(for: block.category))
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(Palette.ink)
                if !block.note.isEmpty {
                    Text(block.note)
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                        .lineLimit(2)
                }
                Text(metaText)
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundColor(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metaText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: block.startTime)
        let end = formatter.string(from: block.endTime)
        let dur = TimeUtils.entryDurationMin(block)
        return "\(start) — \(end) · \(TimeUtils.formatDuration(dur))"
    }
}
