import Foundation

enum CaptureJobStatus: Equatable { case queued, running, error }

struct CaptureJob: Identifiable, Equatable {
    let id: String
    let uid: String
    let audioURL: URL
    var status: CaptureJobStatus
    var error: String?
    let createdAt: Date
}

@MainActor
final class CaptureQueue: ObservableObject {
    static let shared = CaptureQueue()

    @Published private(set) var jobs: [CaptureJob] = []

    private var working = false

    private init() {}

    // MARK: - Public API

    @discardableResult
    func enqueue(uid: String, audioURL: URL) -> String {
        let id = Self.newJobId()
        let storedURL = (try? Self.persistAudio(jobId: id, sourceURL: audioURL)) ?? audioURL
        let job = CaptureJob(
            id: id,
            uid: uid,
            audioURL: storedURL,
            status: .queued,
            error: nil,
            createdAt: Date()
        )
        jobs.append(job)
        Task { await tick() }
        return id
    }

    func retry(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .error else { return }
        jobs[index].status = .queued
        jobs[index].error = nil
        Task { await tick() }
    }

    func retryAll() {
        var changed = false
        for index in jobs.indices where jobs[index].status == .error {
            jobs[index].status = .queued
            jobs[index].error = nil
            changed = true
        }
        if changed { Task { await tick() } }
    }

    func discard(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        Self.deleteAudio(jobs[index].audioURL)
        jobs.remove(at: index)
    }

    static func cleanupOrphans() {
        let fm = FileManager.default
        guard let dir = capturesDirectory() else { return }
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in contents {
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Worker loop

    private func tick() async {
        if working { return }
        guard let index = jobs.firstIndex(where: { $0.status == .queued }) else { return }
        working = true
        jobs[index].status = .running
        jobs[index].error = nil

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
        case failure(String)
    }

    private func processJob(_ job: CaptureJob) async -> JobOutcome {
        do {
            let result = try await CaptureService.capture(audioURL: job.audioURL)
            guard let activeUid = AuthService.shared.currentUser?.uid, activeUid == job.uid else {
                return .failure("Signed out")
            }
            _ = try await EntriesService.shared.createCaptureEntries(
                uid: job.uid,
                drafts: result.drafts,
                source: .voice,
                transcript: result.transcript.isEmpty ? nil : result.transcript,
                audioUrl: result.audioUrl.isEmpty ? nil : result.audioUrl
            )
            return .success
        } catch let error as CaptureError {
            return .failure(error.localizedDescription)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func applyOutcome(_ outcome: JobOutcome, for jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        switch outcome {
        case .success:
            Self.deleteAudio(jobs[index].audioURL)
            jobs.remove(at: index)
        case .failure(let message):
            jobs[index].status = .error
            jobs[index].error = message
        }
    }

    // MARK: - File helpers

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

    private static func persistAudio(jobId: String, sourceURL: URL) throws -> URL {
        let fm = FileManager.default
        guard let dir = capturesDirectory() else { return sourceURL }
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destination = dir.appendingPathComponent("\(jobId).\(ext)")
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        try fm.copyItem(at: sourceURL, to: destination)
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
}
