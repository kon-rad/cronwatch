import Foundation

enum CaptureJobStatus: String, Equatable, Codable {
    case queued, running, awaitingConfirmation, error
}

struct CaptureJob: Identifiable, Equatable, Codable {
    let id: String
    let uid: String
    let audioURL: URL?
    var transcript: String?
    var entryDrafts: [CapturedEntryDraft]?
    var plan: ResolutionPlan?
    var status: CaptureJobStatus
    var error: String?
    let createdAt: Date
    /// Transcription provider chosen when this job was enqueued. Optional so that
    /// jobs persisted before this field existed still decode (they default to the
    /// prior server-Deepgram behavior). Unused for text-only jobs.
    var transcriptionProvider: TranscriptionProvider?
}

@MainActor
final class CaptureQueue: ObservableObject {
    static let shared = CaptureQueue()

    @Published private(set) var jobs: [CaptureJob] = []

    private var working = false

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    @discardableResult
    func enqueue(uid: String,
                 audioURL: URL,
                 transcript: String? = nil,
                 entryDrafts: [CapturedEntryDraft]? = nil,
                 provider: TranscriptionProvider = .default,
                 initialStatus: CaptureJobStatus = .queued,
                 error: String? = nil) -> String {
        let id = Self.newJobId()
        let storedURL = (try? Self.persistAudio(jobId: id, sourceURL: audioURL)) ?? audioURL
        let job = CaptureJob(
            id: id,
            uid: uid,
            audioURL: storedURL,
            transcript: transcript,
            entryDrafts: entryDrafts,
            plan: nil,
            status: initialStatus,
            error: error,
            createdAt: Date(),
            transcriptionProvider: provider
        )
        jobs.append(job)
        saveToDisk()
        if initialStatus == .queued {
            Task { await tick() }
        }
        return id
    }

    @discardableResult
    func enqueueText(uid: String, transcript: String) -> String {
        let id = Self.newJobId()
        let job = CaptureJob(
            id: id,
            uid: uid,
            audioURL: nil,
            transcript: transcript,
            entryDrafts: nil,
            plan: nil,
            status: .queued,
            error: nil,
            createdAt: Date(),
            transcriptionProvider: nil
        )
        jobs.append(job)
        saveToDisk()
        Task { await tick() }
        return id
    }

    func retry(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .error else { return }
        if jobs[index].plan != nil {
            // Commit-time failure: re-surface the sheet so the user re-confirms
            // against the current state, rather than silently retrying.
            jobs[index].status = .awaitingConfirmation
            jobs[index].error = nil
            saveToDisk()
            return
        }
        jobs[index].status = .queued
        jobs[index].error = nil
        saveToDisk()
        Task { await tick() }
    }

    func confirmPlan(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .awaitingConfirmation else { return }
        guard let plan = jobs[index].plan else { return }
        jobs[index].status = .running
        jobs[index].error = nil
        saveToDisk()
        let job = jobs[index]
        Task { [weak self] in
            do {
                _ = try await EntriesService.shared.commitResolutionPlan(uid: job.uid, plan: plan)
                await self?.finalizeCommit(jobId: job.id)
            } catch {
                await self?.failCommit(jobId: job.id, message: error.localizedDescription)
            }
        }
    }

    func discardPlan(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .awaitingConfirmation else { return }
        if let audioURL = jobs[index].audioURL {
            Self.deleteAudio(audioURL)
        }
        jobs.remove(at: index)
        saveToDisk()
    }

    @MainActor private func finalizeCommit(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        if let audioURL = jobs[index].audioURL {
            Self.deleteAudio(audioURL)
        }
        jobs.remove(at: index)
        saveToDisk()
    }

    @MainActor private func failCommit(jobId: String, message: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        jobs[index].status = .error
        jobs[index].error = message
        saveToDisk()
    }

    func retryAll() {
        var changed = false
        for index in jobs.indices where jobs[index].status == .error {
            jobs[index].status = .queued
            jobs[index].error = nil
            changed = true
        }
        if changed {
            saveToDisk()
            Task { await tick() }
        }
    }

    func discard(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        if let audioURL = jobs[index].audioURL {
            Self.deleteAudio(audioURL)
        }
        jobs.remove(at: index)
        saveToDisk()
    }

    func update(jobId: String,
                transcript: String?? = nil,
                entryDrafts: [CapturedEntryDraft]?? = nil,
                status: CaptureJobStatus? = nil,
                error: String?? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        if let transcript { jobs[index].transcript = transcript }
        if let entryDrafts { jobs[index].entryDrafts = entryDrafts }
        if let status { jobs[index].status = status }
        if let error { jobs[index].error = error }
        saveToDisk()
    }

    func job(id: String) -> CaptureJob? {
        jobs.first(where: { $0.id == id })
    }

    static func cleanupOrphans() {
        let fm = FileManager.default
        guard let dir = capturesDirectory() else { return }
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let referenced = Set(loadJobsFromDisk().compactMap { $0.audioURL?.lastPathComponent })
        for url in contents where url.lastPathComponent != metadataFilename {
            if !referenced.contains(url.lastPathComponent) {
                try? fm.removeItem(at: url)
            }
        }
    }

    // MARK: - Worker loop

    private func tick() async {
        if working { return }
        guard let index = jobs.firstIndex(where: { $0.status == .queued }) else { return }
        working = true
        jobs[index].status = .running
        jobs[index].error = nil
        saveToDisk()

        let job = jobs[index]
        let outcome = await processJob(job)
        applyOutcome(outcome, for: job.id)

        working = false
        if jobs.contains(where: { $0.status == .queued }) {
            Task { await tick() }
        }
    }

    private enum JobOutcome {
        case success
        case awaiting(plan: ResolutionPlan,
                      transcript: String?,
                      entryDrafts: [CapturedEntryDraft]?)
        case partial(transcript: String?, entryDrafts: [CapturedEntryDraft]?, error: String)
        case failure(String)
    }

    private func processJob(_ job: CaptureJob) async -> JobOutcome {
        guard let activeUid = AuthService.shared.currentUser?.uid, activeUid == job.uid else {
            return .failure("Signed out")
        }

        // Resume from the latest unfinished step.
        var transcript = job.transcript
        var entryDrafts = job.entryDrafts

        // Provider chosen at enqueue time. Legacy jobs (persisted before the field
        // existed) default to server-side Deepgram, matching prior behavior.
        let provider = job.transcriptionProvider ?? .deepgram

        if entryDrafts == nil {
            // Step 1 — obtain a transcript if we don't have one yet.
            if transcript == nil {
                guard let audioURL = job.audioURL else {
                    return .failure("Missing audio for transcription.")
                }
                do {
                    switch provider {
                    case .speechAnalyzer:
                        // Transcribe on-device; fall back to cheap cloud Whisper if
                        // on-device recognition is unavailable or fails.
                        do {
                            transcript = try await OnDeviceTranscriber.transcribe(audioURL: audioURL)
                        } catch {
                            let result = try await CaptureService.capture(
                                audioURL: audioURL, provider: .togetherWhisper
                            )
                            transcript = result.transcript
                            entryDrafts = result.drafts
                        }
                    case .togetherWhisper, .deepgram:
                        // Cloud transcription via /capture (also returns structured drafts).
                        let result = try await CaptureService.capture(
                            audioURL: audioURL, provider: provider
                        )
                        transcript = result.transcript
                        entryDrafts = result.drafts
                    }
                } catch {
                    return .partial(
                        transcript: transcript,
                        entryDrafts: entryDrafts,
                        error: error.localizedDescription
                    )
                }
            }

            // Step 2 — structure the transcript into drafts (covers on-device voice
            // captures and text-only jobs; cloud /capture already filled drafts above).
            if entryDrafts == nil, let text = transcript {
                do {
                    entryDrafts = try await CaptureService.structureText(text)
                } catch {
                    return .partial(
                        transcript: transcript,
                        entryDrafts: entryDrafts,
                        error: error.localizedDescription
                    )
                }
            }
        }

        guard let drafts = entryDrafts, !drafts.isEmpty else {
            return .partial(
                transcript: transcript,
                entryDrafts: entryDrafts,
                error: "Empty draft."
            )
        }

        let source: EntrySource = job.audioURL != nil ? .voice : .text
        let snapped = EntriesService.snapAndDeoverlap(drafts)
        guard !snapped.isEmpty else {
            return .partial(
                transcript: transcript,
                entryDrafts: entryDrafts,
                error: "Empty draft."
            )
        }
        let windowStart = snapped.map(\.startTime).min() ?? Date()
        let windowEnd = snapped.map(\.endTime).max() ?? windowStart

        let existing: [Entry]
        do {
            existing = try await EntriesService.shared.fetchConflicts(
                uid: job.uid,
                windowStart: windowStart,
                windowEnd: windowEnd
            )
        } catch {
            return .partial(
                transcript: transcript,
                entryDrafts: entryDrafts,
                error: "Couldn't check for conflicts."
            )
        }

        let plan = EntriesService.buildResolutionPlan(
            existing: existing,
            drafts: snapped,
            captureId: job.id,
            source: source,
            transcript: (transcript?.isEmpty == false) ? transcript : nil
        )

        if plan.hasConflicts {
            return .awaiting(
                plan: plan,
                transcript: transcript,
                entryDrafts: entryDrafts
            )
        }

        do {
            _ = try await EntriesService.shared.commitResolutionPlan(uid: job.uid, plan: plan)
            return .success
        } catch {
            return .partial(
                transcript: transcript,
                entryDrafts: entryDrafts,
                error: error.localizedDescription
            )
        }
    }

    private func applyOutcome(_ outcome: JobOutcome, for jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        switch outcome {
        case .success:
            if let audioURL = jobs[index].audioURL {
                Self.deleteAudio(audioURL)
            }
            jobs.remove(at: index)
        case .awaiting(let plan, let transcript, let entryDrafts):
            if let transcript { jobs[index].transcript = transcript }
            if let entryDrafts { jobs[index].entryDrafts = entryDrafts }
            jobs[index].plan = plan
            jobs[index].status = .awaitingConfirmation
            jobs[index].error = nil
        case .partial(let transcript, let entryDrafts, let message):
            if let transcript { jobs[index].transcript = transcript }
            if let entryDrafts { jobs[index].entryDrafts = entryDrafts }
            jobs[index].status = .error
            jobs[index].error = message
        case .failure(let message):
            jobs[index].status = .error
            jobs[index].error = message
        }
        saveToDisk()
    }

    // MARK: - Persistence

    private static let metadataFilename = "drafts.json"

    private static func capturesDirectory() -> URL? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("captures", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func metadataURL() -> URL? {
        capturesDirectory()?.appendingPathComponent(metadataFilename)
    }

    private static func persistAudio(jobId: String, sourceURL: URL) throws -> URL {
        let fm = FileManager.default
        guard let dir = capturesDirectory() else { return sourceURL }
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destination = dir.appendingPathComponent("\(jobId).\(ext)")
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        if sourceURL == destination {
            return destination
        }
        if sourceURL.path.hasPrefix(dir.path) {
            try fm.moveItem(at: sourceURL, to: destination)
        } else {
            try fm.copyItem(at: sourceURL, to: destination)
        }
        return destination
    }

    private static func deleteAudio(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func newJobId() -> String {
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(5).lowercased())
        return "j_\(ms)_\(suffix)"
    }

    private func saveToDisk() {
        guard let url = Self.metadataURL() else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(jobs)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence failure isn't fatal; in-memory state stays correct.
        }
    }

    private func loadFromDisk() {
        let loaded = Self.loadJobsFromDisk()
        // Any job that was "running" mid-process when the app died is reset to "error" so the user can decide.
        jobs = loaded.map { job in
            var copy = job
            if copy.status == .running {
                copy.status = .error
                copy.error = copy.error ?? "Interrupted."
            }
            return copy
        }
    }

    fileprivate static func loadJobsFromDisk() -> [CaptureJob] {
        guard let url = metadataURL() else { return [] }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CaptureJob].self, from: data)) ?? []
    }
}
