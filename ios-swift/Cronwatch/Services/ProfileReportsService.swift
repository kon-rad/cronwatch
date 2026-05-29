import Foundation
import FirebaseFirestore

enum ProfileReportsServiceError: Error, LocalizedError {
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: return "Firebase is not configured."
        }
    }
}

@MainActor
final class ProfileReportsService {
    static let shared = ProfileReportsService()

    private init() {}

    func subscribe(uid: String, onChange: @escaping ([ProfileReport]) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onChange([])
            return {}
        }
        let query = reportsCollection(uid: uid)
            .order(by: "createdAt", descending: true)
        let registration = query.addSnapshotListener { snapshot, _ in
            let reports = (snapshot?.documents ?? []).compactMap {
                Self.fromDocument(id: $0.documentID, data: $0.data())
            }
            onChange(reports)
        }
        return { registration.remove() }
    }

    func save(uid: String, report: ProfileReport) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw ProfileReportsServiceError.firebaseNotConfigured
        }
        let data: [String: Any] = [
            "title": report.title,
            "html": report.html,
            "rangeStart": Timestamp(date: report.rangeStart),
            "rangeEnd": Timestamp(date: report.rangeEnd),
            "customPrompt": report.customPrompt ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        try await reportsCollection(uid: uid).document(report.id).setData(data)
    }

    func delete(uid: String, id: String) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw ProfileReportsServiceError.firebaseNotConfigured
        }
        try await reportsCollection(uid: uid).document(id).delete()
    }

    static func newReportId() -> String {
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased())
        return "r_\(ms)_\(suffix)"
    }

    private func reportsCollection(uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("reports")
    }

    private static func fromDocument(id: String, data: [String: Any]) -> ProfileReport? {
        let title = data["title"] as? String ?? ""
        let html = data["html"] as? String ?? ""
        guard let rangeStartTs = data["rangeStart"] as? Timestamp,
              let rangeEndTs = data["rangeEnd"] as? Timestamp else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let customPrompt = data["customPrompt"] as? String
        return ProfileReport(
            id: id,
            title: title,
            html: html,
            rangeStart: rangeStartTs.dateValue(),
            rangeEnd: rangeEndTs.dateValue(),
            customPrompt: (customPrompt?.isEmpty ?? true) ? nil : customPrompt,
            createdAt: createdAt
        )
    }
}
