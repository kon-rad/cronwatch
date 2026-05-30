import Foundation

struct CategoryMinutes: Codable, Equatable {
    let name: String
    let minutes: Int
}

struct DayAggregate: Codable, Equatable {
    let date: String
    let categories: [CategoryMinutes]
}
