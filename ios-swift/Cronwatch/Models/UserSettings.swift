import Foundation

struct Goal: Codable, Equatable {
    var category: String
    var weeklyTargetHours: Double

    var isSet: Bool { !category.isEmpty && weeklyTargetHours > 0 }
}

struct UserSettings: Codable, Equatable {
    var goals: [Goal]

    static let empty = UserSettings(goals: [
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
    ])

    var hasAnyGoal: Bool {
        goals.contains { $0.isSet }
    }
}
