import Foundation

struct CategoryMinutes: Codable, Equatable {
    let name: String
    let minutes: Int
}

struct DayAggregate: Codable, Equatable {
    let date: String
    let categories: [CategoryMinutes]
}

struct GoalAnalysis: Codable, Equatable, Identifiable {
    let goal: String
    let summary: String

    var id: String { goal }
}

struct WeekReport: Codable, Equatable {
    let goalAnalyses: [GoalAnalysis]
    let ideas: [String]
}
