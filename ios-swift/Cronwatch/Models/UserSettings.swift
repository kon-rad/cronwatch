import Foundation

struct Goal: Codable, Equatable {
    var category: String
    var weeklyTargetHours: Double

    var isSet: Bool { !category.isEmpty && weeklyTargetHours > 0 }
}

struct UserSettings: Codable, Equatable {
    var goals: [Goal]
    var wantsToBeBetterAt: String
    var workType: String
    var vision3Years: String
    var vision5Years: String
    var vision10Years: String
    var onboardingCompleted: Bool

    static let empty = UserSettings(
        goals: [
            Goal(category: "", weeklyTargetHours: 0),
            Goal(category: "", weeklyTargetHours: 0),
            Goal(category: "", weeklyTargetHours: 0),
        ],
        wantsToBeBetterAt: "",
        workType: "",
        vision3Years: "",
        vision5Years: "",
        vision10Years: "",
        onboardingCompleted: false
    )

    var hasAnyGoal: Bool {
        goals.contains { $0.isSet }
    }
}
