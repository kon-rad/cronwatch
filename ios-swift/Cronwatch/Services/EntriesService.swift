import Foundation
import FirebaseFirestore

@MainActor
final class EntriesService {
    static let shared = EntriesService()

    private var stubStore: [Entry] = []
    private var stubListeners: [UUID: ([Entry]) -> Void] = [:]
    private var stubPagedListeners: [UUID: ([Entry], DocumentSnapshot?) -> Void] = [:]
    private var stubRangeListeners: [UUID: (from: Date, to: Date, cb: ([Entry]) -> Void)] = [:]

    private init() {}

    // MARK: - Today

    func subscribeToToday(uid: String, onChange: @escaping ([Entry]) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            let token = UUID()
            stubListeners[token] = onChange
            onChange(sortedStubSnapshot())
            return { [weak self] in
                Task { @MainActor in
                    self?.stubListeners.removeValue(forKey: token)
                }
            }
        }

        let collection = entriesCollection(uid: uid)
        let start = Timestamp(date: TimeUtils.startOfToday())
        let end = Timestamp(date: TimeUtils.endOfToday())
        let query = collection
            .whereField("startTime", isGreaterThanOrEqualTo: start)
            .whereField("startTime", isLessThanOrEqualTo: end)
            .order(by: "startTime", descending: false)

        let registration = query.addSnapshotListener { snapshot, _ in
            let entries = (snapshot?.documents ?? []).compactMap {
                Self.entryFromDocument(id: $0.documentID, data: $0.data())
            }
            onChange(entries)
        }
        return { registration.remove() }
    }

    // MARK: - Range

    func subscribeToRange(uid: String,
                          from: Date,
                          to: Date,
                          onChange: @escaping ([Entry]) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            let token = UUID()
            stubRangeListeners[token] = (from, to, onChange)
            onChange(filteredStubRange(from: from, to: to))
            return { [weak self] in
                Task { @MainActor in
                    self?.stubRangeListeners.removeValue(forKey: token)
                }
            }
        }

        let collection = entriesCollection(uid: uid)
        let query = collection
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: from))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: to))
            .order(by: "startTime", descending: false)

        let registration = query.addSnapshotListener { snapshot, _ in
            let entries = (snapshot?.documents ?? []).compactMap {
                Self.entryFromDocument(id: $0.documentID, data: $0.data())
            }
            onChange(entries)
        }
        return { registration.remove() }
    }

    // MARK: - Pagination

    func subscribeFirstPage(uid: String,
                            pageSize: Int,
                            onChange: @escaping ([Entry], DocumentSnapshot?) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            let token = UUID()
            stubPagedListeners[token] = onChange
            onChange(stubFirstPageSnapshot(pageSize: pageSize), nil)
            return { [weak self] in
                Task { @MainActor in
                    self?.stubPagedListeners.removeValue(forKey: token)
                }
            }
        }

        let collection = entriesCollection(uid: uid)
        let query = collection
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        let registration = query.addSnapshotListener { snapshot, _ in
            let docs = snapshot?.documents ?? []
            let entries = docs.compactMap {
                Self.entryFromDocument(id: $0.documentID, data: $0.data())
            }
            onChange(entries, docs.last)
        }
        return { registration.remove() }
    }

    func loadMore(uid: String,
                  cursor: DocumentSnapshot?,
                  pageSize: Int) async throws
        -> (entries: [Entry], lastCursor: DocumentSnapshot?, hasMore: Bool)
    {
        guard FirebaseBootstrap.isConfigured else {
            return ([], nil, false)
        }
        guard let cursor else { return ([], nil, false) }
        let collection = entriesCollection(uid: uid)
        let query = collection
            .order(by: "createdAt", descending: true)
            .start(afterDocument: cursor)
            .limit(to: pageSize)

        let snapshot = try await query.getDocuments()
        let docs = snapshot.documents
        let entries = docs.compactMap {
            Self.entryFromDocument(id: $0.documentID, data: $0.data())
        }
        return (entries, docs.last, entries.count == pageSize)
    }

    // MARK: - Single fetches

    func getEntry(uid: String, id: String) async throws -> Entry? {
        guard FirebaseBootstrap.isConfigured else {
            return stubStore.first(where: { $0.id == id })
        }
        let collection = entriesCollection(uid: uid)
        let snapshot = try await collection.document(id).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return Self.entryFromDocument(id: snapshot.documentID, data: data)
    }

    func getCapture(uid: String, captureId: String) async throws -> Capture? {
        guard FirebaseBootstrap.isConfigured else {
            let blocks = stubStore.filter { $0.captureId == captureId || $0.id == captureId }
            if blocks.isEmpty { return nil }
            return Self.groupByCapture(blocks).first
        }
        let collection = entriesCollection(uid: uid)

        let snapshot = try await collection
            .whereField("captureId", isEqualTo: captureId)
            .getDocuments()
        var entries = snapshot.documents.compactMap {
            Self.entryFromDocument(id: $0.documentID, data: $0.data())
        }

        if entries.isEmpty {
            let docSnap = try await collection.document(captureId).getDocument()
            if docSnap.exists, let data = docSnap.data(),
               let entry = Self.entryFromDocument(id: docSnap.documentID, data: data) {
                entries = [entry]
            }
        }

        if entries.isEmpty { return nil }
        return Self.groupByCapture(entries).first
    }

    // MARK: - Writes

    func createCaptureEntries(uid: String,
                              drafts: [CapturedEntryDraft],
                              source: EntrySource,
                              transcript: String?,
                              audioUrl: String?) async throws -> [Entry] {
        guard !drafts.isEmpty else {
            throw CaptureError.emptyDrafts
        }

        let captureId = Self.newCaptureId()
        let createdAt = Date()

        guard FirebaseBootstrap.isConfigured else {
            let baseTs = Int(Date().timeIntervalSince1970 * 1000)
            var created: [Entry] = []
            for (index, draft) in drafts.enumerated() {
                let entry = Entry(
                    id: "e\(baseTs)_\(index)",
                    captureId: captureId,
                    category: draft.category,
                    note: draft.note,
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    source: source,
                    transcript: transcript,
                    audioUrl: audioUrl,
                    createdAt: createdAt
                )
                stubStore.append(entry)
                created.append(entry)
            }
            emitStub()
            return created
        }

        let collection = entriesCollection(uid: uid)
        let db = collection.firestore
        let batch = db.batch()
        var pending: [Entry] = []

        for draft in drafts {
            let ref = collection.document()
            var data: [String: Any] = [
                "captureId": captureId,
                "category": draft.category,
                "note": draft.note,
                "startTime": Timestamp(date: draft.startTime),
                "endTime": Timestamp(date: draft.endTime),
                "source": source.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "transcript": transcript ?? NSNull(),
                "audioUrl": audioUrl ?? NSNull(),
            ]
            _ = data
            batch.setData(data, forDocument: ref)
            pending.append(
                Entry(
                    id: ref.documentID,
                    captureId: captureId,
                    category: draft.category,
                    note: draft.note,
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    source: source,
                    transcript: transcript,
                    audioUrl: audioUrl,
                    createdAt: createdAt
                )
            )
        }

        try await batch.commit()
        return pending
    }

    func updateEntry(uid: String,
                     id: String,
                     category: String?,
                     note: String?,
                     startTime: Date?,
                     endTime: Date?) async throws {
        guard FirebaseBootstrap.isConfigured else {
            stubStore = stubStore.map { existing in
                guard existing.id == id else { return existing }
                var copy = existing
                if let category { copy.category = category }
                if let note { copy.note = note }
                if let startTime { copy.startTime = startTime }
                if let endTime { copy.endTime = endTime }
                return copy
            }
            emitStub()
            return
        }

        var update: [String: Any] = [:]
        if let category { update["category"] = category }
        if let note { update["note"] = note }
        if let startTime { update["startTime"] = Timestamp(date: startTime) }
        if let endTime { update["endTime"] = Timestamp(date: endTime) }
        guard !update.isEmpty else { return }

        try await entriesCollection(uid: uid).document(id).updateData(update)
    }

    func deleteEntry(uid: String, id: String) async throws {
        guard FirebaseBootstrap.isConfigured else {
            stubStore.removeAll { $0.id == id }
            emitStub()
            return
        }
        try await entriesCollection(uid: uid).document(id).delete()
    }

    // MARK: - Grouping

    nonisolated static func groupByCapture(_ entries: [Entry]) -> [Capture] {
        var order: [String] = []
        var byId: [String: Capture] = [:]
        for entry in entries {
            if var existing = byId[entry.captureId] {
                existing.blocks.append(entry)
                if existing.transcript == nil, let t = entry.transcript, !t.isEmpty {
                    existing.transcript = t
                }
                if existing.audioUrl == nil, let url = entry.audioUrl, !url.isEmpty {
                    existing.audioUrl = url
                }
                byId[entry.captureId] = existing
            } else {
                let capture = Capture(
                    captureId: entry.captureId,
                    source: entry.source,
                    transcript: entry.transcript,
                    audioUrl: entry.audioUrl,
                    createdAt: entry.createdAt,
                    blocks: [entry]
                )
                byId[entry.captureId] = capture
                order.append(entry.captureId)
            }
        }
        return order.compactMap { id in
            guard var capture = byId[id] else { return nil }
            capture.blocks.sort { $0.startTime < $1.startTime }
            return capture
        }
    }

    // MARK: - Helpers

    private func entriesCollection(uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("entries")
    }

    private func sortedStubSnapshot() -> [Entry] {
        stubStore.sorted { $0.startTime < $1.startTime }
    }

    private func stubFirstPageSnapshot(pageSize: Int) -> [Entry] {
        Array(stubStore.sorted { $0.createdAt > $1.createdAt }.prefix(pageSize))
    }

    private func filteredStubRange(from: Date, to: Date) -> [Entry] {
        sortedStubSnapshot().filter { $0.startTime >= from && $0.startTime <= to }
    }

    private func emitStub() {
        let todaySnapshot = sortedStubSnapshot()
        for listener in stubListeners.values { listener(todaySnapshot) }

        for (_, paged) in stubPagedListeners {
            paged(stubFirstPageSnapshot(pageSize: 50), nil)
        }
        for (_, entry) in stubRangeListeners {
            entry.cb(filteredStubRange(from: entry.from, to: entry.to))
        }
    }

    private static func newCaptureId() -> String {
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased())
        return "c_\(ms)_\(suffix)"
    }

    private static func entryFromDocument(id: String, data: [String: Any]) -> Entry? {
        let category = data["category"] as? String ?? ""
        let note = data["note"] as? String ?? ""
        guard let startTimestamp = data["startTime"] as? Timestamp,
              let endTimestamp = data["endTime"] as? Timestamp else { return nil }
        let startTime = startTimestamp.dateValue()
        let endTime = endTimestamp.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let sourceRaw = data["source"] as? String
        let source: EntrySource = (sourceRaw == "text") ? .text : .voice
        let transcript = data["transcript"] as? String
        let audioUrl = data["audioUrl"] as? String
        let storedCaptureId = data["captureId"] as? String
        let captureId = (storedCaptureId?.isEmpty == false) ? storedCaptureId! : id

        return Entry(
            id: id,
            captureId: captureId,
            category: category,
            note: note,
            startTime: startTime,
            endTime: endTime,
            source: source,
            transcript: transcript,
            audioUrl: audioUrl,
            createdAt: createdAt
        )
    }
}
