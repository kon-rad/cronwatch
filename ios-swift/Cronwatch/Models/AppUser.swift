import Foundation

struct AppUser: Hashable, Identifiable, Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    var id: String { uid }
}
