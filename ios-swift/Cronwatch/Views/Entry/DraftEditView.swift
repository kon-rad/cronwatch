import SwiftUI
import UIKit

struct DraftEditView: View {
    let jobId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var queue: CaptureQueue

    @State private var loadedJob: CaptureJob?
    @State private var transcriptDraft: String = ""
    @State private var blocks: [BlockDraft] = []

    @State private var isRetryingTranscribe: Bool = false
    @State private var isRetryingStructure: Bool = false
    @State private var isSaving: Bool = false
    @State private var actionError: String?

    @State private var showDeleteAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.border)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.sm)

            header

            if loadedJob == nil {
                Spacer()
                Text("Draft not found.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                Spacer()
            } else {
                content
            }
        }
        .background(Palette.bg)
        .clipShape(RoundedCornersDraft(radius: 20, corners: [.topLeft, .topRight]))
        .onAppear { loadJob() }
        .onDisappear { persistEdits() }
        .interactiveDismissDisabled(isWorking)
        .alert("Delete draft?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("The recording and any edits will be removed.")
        }
    }

    private var isWorking: Bool {
        isRetryingTranscribe || isRetryingStructure || isSaving
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
            }
            .disabled(isWorking)
            .contentShape(Rectangle())

            Spacer()

            Text("Edit draft")
                .font(.cwBody.weight(.semibold))
                .foregroundColor(Palette.ink)

            Spacer()

            Button(action: { Task { await onSave() } }) {
                Text("Save")
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(canSave ? Palette.amber : Palette.muted)
            }
            .disabled(!canSave)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    private var canSave: Bool {
        if isWorking { return false }
        return !blocks.isEmpty
    }

    // MARK: - Content

    private var backgroundCompleted: Bool {
        loadedJob != nil && queue.job(id: jobId) == nil
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if backgroundCompleted {
                    raceBanner
                } else if let actionError {
                    errorBanner(actionError)
                } else if let jobError = loadedJob?.error, !jobError.isEmpty {
                    errorBanner(jobError)
                }

                transcriptSection
                blocksSection
                deleteSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl * 2)
        }
    }

    private var raceBanner: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Palette.amber)
                .padding(.top, 2)
            Text("This draft was just processed in the background. Saving will overwrite the auto-processed entry; closing without saving will keep it.")
                .font(.cwCaption)
                .foregroundColor(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.sm)
        .background(Palette.amberSoft)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Palette.danger)
                .padding(.top, 2)
            Text(message)
                .font(.cwCaption)
                .foregroundColor(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.sm)
        .background(Palette.amberSoft)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Transcript section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("TRANSCRIPT")

            if transcriptDraft.isEmpty && !isRetryingTranscribe {
                Text("No transcript yet. Tap Retry transcription to convert the recording to text.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .padding(.bottom, Spacing.xs)
            } else {
                TextEditor(text: $transcriptDraft)
                    .font(.cwBody)
                    .foregroundColor(Palette.ink)
                    .scrollContentBackground(.hidden)
                    .background(Palette.white)
                    .frame(minHeight: 140)
                    .padding(Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Palette.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .disabled(isWorking)
            }

            HStack(spacing: Spacing.sm) {
                Button(action: { Task { await onRetryTranscribe() } }) {
                    HStack(spacing: Spacing.xs) {
                        if isRetryingTranscribe {
                            ProgressView().controlSize(.small).tint(Palette.amber)
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 14, weight: .regular))
                        }
                        Text(isRetryingTranscribe ? "Transcribing…" : "Retry transcription")
                            .font(.cwCaption.weight(.semibold))
                    }
                    .foregroundColor(isWorking ? Palette.muted : Palette.amber)
                    .padding(.vertical, 8)
                    .padding(.horizontal, Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(isWorking ? Palette.border : Palette.amber, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                Button(action: { Task { await onRetryStructure() } }) {
                    HStack(spacing: Spacing.xs) {
                        if isRetryingStructure {
                            ProgressView().controlSize(.small).tint(Palette.amber)
                        } else {
                            Image(systemName: "rectangle.split.3x1")
                                .font(.system(size: 14, weight: .regular))
                        }
                        Text(isRetryingStructure ? "Re-parsing…" : "Re-parse blocks")
                            .font(.cwCaption.weight(.semibold))
                    }
                    .foregroundColor(canRetryStructure ? Palette.amber : Palette.muted)
                    .padding(.vertical, 8)
                    .padding(.horizontal, Spacing.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(canRetryStructure ? Palette.amber : Palette.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                }
                .buttonStyle(.plain)
                .disabled(!canRetryStructure)
            }
        }
    }

    private var canRetryStructure: Bool {
        !isWorking && !transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Blocks section

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("TIME BLOCKS")

            if blocks.isEmpty {
                Text("No time blocks yet. Edit the transcript above and tap Re-parse blocks.")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
            } else {
                ForEach(blocks.indices, id: \.self) { index in
                    blockCard(at: index)
                }
            }
        }
    }

    private func blockCard(at index: Int) -> some View {
        let block = blocks[index]
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Menu {
                    ForEach(Categories.all, id: \.key) { c in
                        Button(action: { blocks[index].category = c.key }) {
                            HStack {
                                Text(c.label)
                                if blocks[index].category == c.key {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Categories.color(for: block.category))
                            .frame(width: 8, height: 8)
                        Text(Categories.label(for: block.category))
                            .font(.cwBody)
                            .foregroundColor(Palette.ink)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Palette.muted)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 6)
                    .background(Palette.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(Palette.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                }
                .disabled(isWorking)

                Spacer()

                Button(action: { blocks.remove(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Palette.muted)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }

            TextField(
                "What did you do?",
                text: Binding(
                    get: { blocks[index].note },
                    set: { blocks[index].note = $0 }
                ),
                axis: .vertical
            )
            .font(.cwBody)
            .foregroundColor(Palette.ink)
            .lineLimit(1...4)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 8)
            .background(Palette.white)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .disabled(isWorking)

            BlockDateStepper(
                date: blocks[index].date,
                onPrev: {
                    blocks[index].date = Calendar.current.date(byAdding: .day, value: -1, to: blocks[index].date) ?? blocks[index].date
                },
                onNext: {
                    let next = Calendar.current.date(byAdding: .day, value: 1, to: blocks[index].date) ?? blocks[index].date
                    if next <= Calendar.current.startOfDay(for: Date()) {
                        blocks[index].date = next
                    }
                }
            )
            .disabled(isWorking)

            HStack(spacing: Spacing.md) {
                BlockTimeStepper(
                    label: "START",
                    value: TimeUtils.formatTimeOfDay(blocks[index].startMin),
                    onMinus: {
                        let next = TimeUtils.snapTo15(max(0, blocks[index].startMin - 15))
                        blocks[index].startMin = next
                    },
                    onPlus: {
                        let next = TimeUtils.snapTo15(min(24 * 60 - 15, blocks[index].startMin + 15))
                        blocks[index].startMin = next
                        if next >= blocks[index].endMin {
                            blocks[index].endMin = next + 15
                        }
                    }
                )
                BlockTimeStepper(
                    label: "END",
                    value: TimeUtils.formatTimeOfDay(blocks[index].endMin),
                    onMinus: {
                        blocks[index].endMin = TimeUtils.snapTo15(max(blocks[index].startMin + 15, blocks[index].endMin - 15))
                    },
                    onPlus: {
                        blocks[index].endMin = TimeUtils.snapTo15(min(24 * 60, blocks[index].endMin + 15))
                    }
                )
            }
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Palette.danger)
                Text("Delete draft")
                    .font(.cwBody)
                    .foregroundColor(Palette.danger)
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .padding(.top, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.cwCaption)
            .foregroundColor(Palette.muted)
            .tracking(1.2)
    }

    // MARK: - Load + persist

    private func loadJob() {
        guard let job = queue.job(id: jobId) else {
            loadedJob = nil
            return
        }
        loadedJob = job
        transcriptDraft = job.transcript ?? ""
        if let drafts = job.entryDrafts {
            blocks = drafts.map { BlockDraft(from: $0) }
        } else {
            blocks = []
        }
    }

    private func persistEdits() {
        guard let job = loadedJob, queue.job(id: jobId) != nil else { return }
        let normalizedTranscript = transcriptDraft.isEmpty ? nil : transcriptDraft
        let normalizedDrafts: [CapturedEntryDraft]? = blocks.isEmpty ? nil : blocks.map { $0.toCapturedDraft(base: job.createdAt) }
        queue.update(
            jobId: jobId,
            transcript: .some(normalizedTranscript),
            entryDrafts: .some(normalizedDrafts)
        )
    }

    // MARK: - Actions

    private func onRetryTranscribe() async {
        guard let job = loadedJob else { return }
        guard let audioURL = job.audioURL else {
            actionError = "No audio available to transcribe."
            return
        }
        actionError = nil
        isRetryingTranscribe = true
        defer { isRetryingTranscribe = false }

        do {
            let result = try await CaptureService.capture(audioURL: audioURL)
            transcriptDraft = result.transcript
            blocks = result.drafts.map { BlockDraft(from: $0) }
            queue.update(
                jobId: jobId,
                transcript: .some(result.transcript),
                entryDrafts: .some(result.drafts),
                error: .some(nil)
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func onRetryStructure() async {
        let trimmed = transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        actionError = nil
        isRetryingStructure = true
        defer { isRetryingStructure = false }

        do {
            let drafts = try await CaptureService.structureText(trimmed)
            blocks = drafts.map { BlockDraft(from: $0) }
            queue.update(
                jobId: jobId,
                transcript: .some(trimmed),
                entryDrafts: .some(drafts),
                error: .some(nil)
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func onSave() async {
        guard let job = loadedJob else { return }
        guard let uid = auth.currentUser?.uid else {
            actionError = "Not signed in."
            return
        }
        guard !blocks.isEmpty else { return }

        actionError = nil
        isSaving = true
        defer { isSaving = false }

        let drafts = blocks.map { $0.toCapturedDraft(base: job.createdAt) }
        let transcript = transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: EntrySource = job.audioURL != nil ? .voice : .text
        do {
            _ = try await EntriesService.shared.createCaptureEntries(
                uid: uid,
                drafts: drafts,
                source: source,
                transcript: transcript.isEmpty ? nil : transcript,
                captureId: jobId
            )
            queue.discard(jobId: jobId)
            loadedJob = nil
            dismiss()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func onDelete() {
        queue.discard(jobId: jobId)
        loadedJob = nil
        dismiss()
    }
}

private struct BlockDraft: Identifiable, Equatable {
    let id = UUID()
    var category: String
    var note: String
    var date: Date       // start of calendar day in local timezone
    var startMin: Int
    var endMin: Int

    init(from draft: CapturedEntryDraft) {
        self.category = draft.category
        self.note = draft.note
        self.date = Calendar.current.startOfDay(for: draft.startTime)
        self.startMin = TimeUtils.minutesOfDay(of: draft.startTime)
        self.endMin = TimeUtils.minutesOfDay(of: draft.endTime)
    }

    func toCapturedDraft(base: Date) -> CapturedEntryDraft {
        let start = TimeUtils.date(date, withMinutesOfDay: startMin)
        let end = TimeUtils.date(date, withMinutesOfDay: max(endMin, startMin + 15))
        return CapturedEntryDraft(
            category: category,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: start,
            endTime: end
        )
    }
}

private struct BlockDateStepper: View {
    let date: Date
    let onPrev: () -> Void
    let onNext: () -> Void

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DATE")
                .font(.cwCaption)
                .foregroundColor(Palette.muted)
                .tracking(1.2)
                .padding(.bottom, 4)

            HStack(spacing: Spacing.xs) {
                Text(Self.formatter.string(from: date))
                    .font(.cwBody)
                    .foregroundColor(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onPrev) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isToday ? Palette.muted : Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isToday)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 8)
            .background(Palette.bg)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BlockTimeStepper: View {
    let label: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.cwCaption)
                .foregroundColor(Palette.muted)
                .tracking(1.2)
                .padding(.bottom, 4)

            HStack(spacing: Spacing.xs) {
                Text(value)
                    .font(.cwBody)
                    .foregroundColor(Palette.ink)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onMinus) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(Palette.borderSoft)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 8)
            .background(Palette.bg)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RoundedCornersDraft: Shape {
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
