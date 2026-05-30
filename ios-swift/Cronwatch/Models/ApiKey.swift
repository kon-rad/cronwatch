import Foundation

struct ApiKey: Identifiable, Codable, Equatable {
    let id: String
    let uid: String
    let name: String
    let prefix: String
    let createdAt: Date
}
