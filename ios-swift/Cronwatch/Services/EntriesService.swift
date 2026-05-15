import Foundation
import FirebaseFirestore

enum EntriesServiceError: Error, LocalizedError {
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: return "Firebase is not configured."
        }
    }
}

@MainActor
final class EntriesService {
    static let shared = EntriesService()

    private init() {}

    // MARK: - Today

    func subscribeToToday(uid: String, onChange: @escaping ([Entry]) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onChange([])
            return {}
        }

        let collection = entriesCollection(uid: uid)
        let windowStart = TimeUtils.startOfToday()
        let windowEnd = TimeUtils.endOfToday()
        // Two-field inequalities aren't allowed in Firestore, so we widen the
        // startTime lower bound by 24h and filter endTime client-side. This
        // surfaces entries that started yesterday but extend into today
        // (e.g. sleep from 23:00 yesterday to 09:00 today).
        let queryStart = Timestamp(date: windowStart.addingTimeInterval(-24 * 60 * 60))
        let queryEnd = Timestamp(date: windowEnd)
        let query = collection
            .whereField("startTime", isGreaterThanOrEqualTo: queryStart)
            .whereField("startTime", isLessThanOrEqualTo: queryEnd)
            .order(by: "startTime", descending: false)

        let registration = query.addSnapshotListener { snapshot, _ in
            let entries = (snapshot?.documents ?? []).compactMap {
                Self.entryFromDocument(id: $0.documentID, data: $0.data())
            }
            .filter { $0.endTime > windowStart }
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
            onChange([])
            return {}
        }

        let collection = entriesCollection(uid: uid)
        // Widen lower bound 24h so entries that started before `from` but
        // extend into the window (typical for sleep crossing midnight) are
        // surfaced. Two-field inequalities aren't allowed in Firestore, so
        // the endTime overlap is filtered client-side.
        let queryStart = Timestamp(date: from.addingTimeInterval(-24 * 60 * 60))
        let queryEnd = Timestamp(date: to)
        let query = collection
            .whereField("startTime", isGreaterThanOrEqualTo: queryStart)
            .whereField("startTime", isLessThanOrEqualTo: queryEnd)
            .order(by: "startTime", descending: false)

        let registration = query.addSnapshotListener { snapshot, _ in
            let entries = (snapshot?.documents ?? []).compactMap {
                Self.entryFromDocument(id: $0.documentID, data: $0.data())
            }
            .filter { $0.endTime > from }
            onChange(entries)
        }
        return { registration.remove() }
    }

    func fetchRange(uid: String, from: Date, to: Date) async throws -> [Entry] {
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }
        let collection = entriesCollection(uid: uid)
        // Widen lower bound 24h so entries that started before `from` but
        // extend into the window (typical for sleep crossing midnight) are
        // surfaced. Two-field inequalities aren't allowed in Firestore, so
        // the endTime overlap is filtered client-side.
        let queryStart = Timestamp(date: from.addingTimeInterval(-24 * 60 * 60))
        let queryEnd = Timestamp(date: to)
        let snapshot = try await collection
            .whereField("startTime", isGreaterThanOrEqualTo: queryStart)
            .whereField("startTime", isLessThanOrEqualTo: queryEnd)
            .order(by: "startTime", descending: false)
            .getDocuments()
        return snapshot.documents
            .compactMap { Self.entryFromDocument(id: $0.documentID, data: $0.data()) }
            .filter { $0.endTime > from }
    }

    // MARK: - Pagination

    func subscribeFirstPage(uid: String,
                            pageSize: Int,
                            onChange: @escaping ([Entry], DocumentSnapshot?) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onChange([], nil)
            return {}
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
            throw EntriesServiceError.firebaseNotConfigured
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

    func getEntriesCount(uid: String) async throws -> Int {
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }
        let collection = entriesCollection(uid: uid)
        let snapshot = try await collection.count.getAggregation(source: .server)
        return snapshot.count.intValue
    }

    // MARK: - Single fetches

    func getEntry(uid: String, id: String) async throws -> Entry? {
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }
        let collection = entriesCollection(uid: uid)
        let snapshot = try await collection.document(id).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return Self.entryFromDocument(id: snapshot.documentID, data: data)
    }

    func getCapture(uid: String, captureId: String) async throws -> Capture? {
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
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
                              audioUrl: String?,
                              captureId explicitCaptureId: String? = nil) async throws -> [Entry] {
        guard !drafts.isEmpty else {
            throw CaptureError.emptyDrafts
        }
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }

        let snappedDrafts = Self.snapAndDeoverlap(drafts)
        guard !snappedDrafts.isEmpty else {
            throw CaptureError.emptyDrafts
        }

        let captureId = explicitCaptureId ?? Self.newCaptureId()
        let createdAt = Date()
        let collection = entriesCollection(uid: uid)
        let db = collection.firestore

        // When the caller provides a stable captureId, the same logical capture
        // may have been written before (e.g. background queue raced with manual
        // save). Wipe any prior docs for that captureId so the second writer's
        // set fully replaces the first — no orphans if the new set is smaller.
        var existingDocsForCapture: [DocumentReference] = []
        if explicitCaptureId != nil {
            let existingSnap = try await collection
                .whereField("captureId", isEqualTo: captureId)
                .getDocuments()
            existingDocsForCapture = existingSnap.documents.map { $0.reference }
        }

        let windowStart = snappedDrafts.map(\.startTime).min() ?? Date()
        let windowEnd = snappedDrafts.map(\.endTime).max() ?? windowStart
        let conflicts = try await Self.fetchConflicts(
            in: collection,
            windowStart: windowStart,
            windowEnd: windowEnd
        )
        // Don't treat our own prior docs (same captureId) as conflicts — we're
        // about to delete them anyway.
        let existingIds = Set(existingDocsForCapture.map { $0.documentID })
        let filteredConflicts = conflicts.filter { !existingIds.contains($0.id) }
        let plan = Self.buildResolutionPlan(
            existing: filteredConflicts,
            drafts: snappedDrafts,
            captureId: captureId,
            source: source,
            transcript: transcript,
            audioUrl: audioUrl
        )

        let batch = db.batch()

        for ref in existingDocsForCapture {
            batch.deleteDocument(ref)
        }

        Self.applyResolutions(plan.resolutions, in: collection, batch: batch)

        var pending: [Entry] = []
        for (index, draft) in snappedDrafts.enumerated() {
            let ref: DocumentReference
            if explicitCaptureId != nil {
                ref = collection.document("\(captureId)__\(index)")
            } else {
                ref = collection.document()
            }
            let data: [String: Any] = [
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

    func commitResolutionPlan(uid: String, plan: ResolutionPlan) async throws -> [Entry] {
        guard !plan.drafts.isEmpty else {
            throw CaptureError.emptyDrafts
        }
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }

        let collection = entriesCollection(uid: uid)
        let db = collection.firestore
        let batch = db.batch()

        Self.applyResolutions(plan.resolutions, in: collection, batch: batch)

        var pending: [Entry] = []
        let createdAt = Date()
        for (index, draft) in plan.drafts.enumerated() {
            let ref = collection.document("\(plan.captureId)__\(index)")
            let data: [String: Any] = [
                "captureId": plan.captureId,
                "category": draft.category,
                "note": draft.note,
                "startTime": Timestamp(date: draft.startTime),
                "endTime": Timestamp(date: draft.endTime),
                "source": plan.source.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "transcript": plan.transcript ?? NSNull(),
                "audioUrl": plan.audioUrl ?? NSNull(),
            ]
            batch.setData(data, forDocument: ref)
            pending.append(
                Entry(
                    id: ref.documentID,
                    captureId: plan.captureId,
                    category: draft.category,
                    note: draft.note,
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    source: plan.source,
                    transcript: plan.transcript,
                    audioUrl: plan.audioUrl,
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
            throw EntriesServiceError.firebaseNotConfigured
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
            throw EntriesServiceError.firebaseNotConfigured
        }
        try await entriesCollection(uid: uid).document(id).delete()
    }

    // MARK: - Conflict resolution

    // Snap drafts to 15-min boundaries, then enforce non-overlap among the
    // drafts themselves (snapping can re-introduce overlap between adjacent
    // entries the server had already separated).
    nonisolated static func snapAndDeoverlap(_ drafts: [CapturedEntryDraft]) -> [CapturedEntryDraft] {
        let slot = TimeUtils.slotSeconds
        var sorted: [CapturedEntryDraft] = drafts.map { draft in
            var copy = draft
            copy.startTime = TimeUtils.snapTo15(draft.startTime)
            copy.endTime = TimeUtils.snapTo15(draft.endTime)
            if copy.endTime <= copy.startTime {
                copy.endTime = copy.startTime.addingTimeInterval(slot)
            }
            return copy
        }
        sorted.sort { $0.startTime < $1.startTime }
        for i in 1..<sorted.count {
            if sorted[i].startTime < sorted[i - 1].endTime {
                sorted[i].startTime = sorted[i - 1].endTime
                if sorted[i].endTime <= sorted[i].startTime {
                    sorted[i].endTime = sorted[i].startTime.addingTimeInterval(slot)
                }
            }
        }
        return sorted
    }

    func fetchConflicts(uid: String, windowStart: Date, windowEnd: Date) async throws -> [Entry] {
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }
        let collection = entriesCollection(uid: uid)
        return try await Self.fetchConflicts(in: collection, windowStart: windowStart, windowEnd: windowEnd)
    }

    static func fetchConflicts(in collection: CollectionReference,
                               windowStart: Date,
                               windowEnd: Date) async throws -> [Entry] {
        // Two-field inequalities aren't allowed in Firestore, so we bound the
        // startTime scan to a 48h window before windowStart and filter the
        // endTime overlap client-side. 48h comfortably covers overnight
        // entries (sleep, etc.) without scanning the whole collection.
        let lowerBound = windowStart.addingTimeInterval(-48 * 60 * 60)
        let snapshot = try await collection
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: lowerBound))
            .whereField("startTime", isLessThan: Timestamp(date: windowEnd))
            .getDocuments()
        let entries = snapshot.documents.compactMap {
            Self.entryFromDocument(id: $0.documentID, data: $0.data())
        }
        return entries.filter { $0.endTime > windowStart }
    }

    // Pure: subtract each draft's interval from each existing entry's interval.
    // Surviving pieces decide the resolution per entry:
    //   0 pieces  -> .delete
    //   1 piece   -> .trim (or skip if unchanged)
    //   2 pieces  -> .split
    //   3+ pieces -> defensive .delete (shouldn't happen with de-overlapped drafts)
    nonisolated static func buildResolutionPlan(
        existing: [Entry],
        drafts: [CapturedEntryDraft],
        captureId: String,
        source: EntrySource,
        transcript: String?,
        audioUrl: String?
    ) -> ResolutionPlan {
        var resolutions: [Resolution] = []
        for entry in existing {
            var pieces: [DateRange] = [DateRange(start: entry.startTime, end: entry.endTime)]
            for draft in drafts {
                pieces = pieces.flatMap { piece -> [DateRange] in
                    if draft.endTime <= piece.start || draft.startTime >= piece.end {
                        return [piece]
                    }
                    var result: [DateRange] = []
                    if piece.start < draft.startTime {
                        result.append(DateRange(start: piece.start, end: draft.startTime))
                    }
                    if draft.endTime < piece.end {
                        result.append(DateRange(start: draft.endTime, end: piece.end))
                    }
                    return result
                }
            }
            let action: ConflictAction
            switch pieces.count {
            case 0:
                action = .delete
            case 1:
                let only = pieces[0]
                if only.start == entry.startTime && only.end == entry.endTime {
                    continue
                }
                action = .trim(startTime: only.start, endTime: only.end)
            case 2:
                action = .split(left: pieces[0], right: pieces[1])
            default:
                action = .delete
            }
            resolutions.append(
                Resolution(
                    entryId: entry.id,
                    originalStart: entry.startTime,
                    originalEnd: entry.endTime,
                    originalSource: entry.source,
                    category: entry.category,
                    note: entry.note,
                    transcript: entry.transcript,
                    audioUrl: entry.audioUrl,
                    captureId: entry.captureId,
                    action: action
                )
            )
        }
        return ResolutionPlan(
            captureId: captureId,
            source: source,
            transcript: transcript,
            audioUrl: audioUrl,
            drafts: drafts,
            resolutions: resolutions
        )
    }

    nonisolated static func applyResolutions(
        _ resolutions: [Resolution],
        in collection: CollectionReference,
        batch: WriteBatch
    ) {
        for resolution in resolutions {
            let docRef = collection.document(resolution.entryId)
            switch resolution.action {
            case .delete:
                batch.deleteDocument(docRef)
            case .trim(let newStart, let newEnd):
                batch.updateData(
                    [
                        "startTime": Timestamp(date: newStart),
                        "endTime": Timestamp(date: newEnd),
                    ],
                    forDocument: docRef
                )
            case .split(let left, let right):
                batch.deleteDocument(docRef)
                let leftDoc = collection.document()
                let rightDoc = collection.document()
                let baseData: [String: Any] = [
                    "captureId": resolution.captureId,
                    "category": resolution.category,
                    "note": resolution.note,
                    "source": resolution.originalSource.rawValue,
                    "createdAt": FieldValue.serverTimestamp(),
                    "transcript": resolution.transcript ?? NSNull(),
                    "audioUrl": resolution.audioUrl ?? NSNull(),
                ]
                var leftData = baseData
                leftData["startTime"] = Timestamp(date: left.start)
                leftData["endTime"] = Timestamp(date: left.end)
                batch.setData(leftData, forDocument: leftDoc)
                var rightData = baseData
                rightData["startTime"] = Timestamp(date: right.start)
                rightData["endTime"] = Timestamp(date: right.end)
                batch.setData(rightData, forDocument: rightDoc)
            }
        }
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

    static func newCaptureId() -> String {
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
