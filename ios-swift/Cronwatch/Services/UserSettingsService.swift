import Foundation
import FirebaseFirestore

enum UserSettingsServiceError: Error, LocalizedError {
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: return "Firebase is not configured."
        }
    }
}

@MainActor
final class UserSettingsService {
    static let shared = UserSettingsService()

    private init() {}

    func subscribe(uid: String, onChange: @escaping (UserSettings) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onChange(.empty)
            return {}
        }

        let doc = userDoc(uid: uid)
        let registration = doc.addSnapshotListener { snapshot, _ in
            let raw = (snapshot?.data()?["goals"] as? [[String: Any]]) ?? []
            var goals: [Goal] = raw.compactMap { map in
                guard let category = map["category"] as? String,
                      let target = map["weeklyTargetHours"] as? Double else { return nil }
                return Goal(category: category, weeklyTargetHours: target)
            }
            while goals.count < 3 {
                goals.append(Goal(category: "", weeklyTargetHours: 0))
            }
            var settings = UserSettings.empty
            settings.goals = Array(goals.prefix(3))
            onChange(settings)
        }
        return { registration.remove() }
    }

    func saveGoals(uid: String, goals: [Goal]) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw UserSettingsServiceError.firebaseNotConfigured
        }
        let data = goals.map { ["category": $0.category, "weeklyTargetHours": $0.weeklyTargetHours] }
        try await userDoc(uid: uid).setData([
            "goals": data,
            "goalsUpdatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    private func userDoc(uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }
}
