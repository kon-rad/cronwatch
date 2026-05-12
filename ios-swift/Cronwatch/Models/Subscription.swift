import Foundation

enum Entitlement: String, Codable { case free, weekly, yearly }

struct SubscriptionStatus: Codable, Equatable {
    let entitlement: Entitlement
    let renewsAt: Date?
}
