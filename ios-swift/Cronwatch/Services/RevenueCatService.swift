import Foundation
import RevenueCat

@MainActor
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published private(set) var entitlement: Entitlement = RevenueCatService.couponRedeemed ? .yearly : .free

    private let entitlementID = "subscription"
    var configured = false

    private static let couponDefaultsKey = "coupon_redeemed_ns2026"
    private static var couponRedeemed: Bool {
        UserDefaults.standard.bool(forKey: couponDefaultsKey)
    }

    private init() {}

    func configureIfNeeded() {
        guard !configured, let key = AppEnvironment.revenueCatAPIKey else { return }
        Purchases.configure(withAPIKey: key)
        configured = true
    }

    func refreshEntitlement() async -> Entitlement {
        guard configured else { return couponFallback(.free) }
        do {
            let info = try await Purchases.shared.customerInfo()
            let resolved = couponFallback(mapEntitlement(from: info))
            self.entitlement = resolved
            return resolved
        } catch {
            return couponFallback(.free)
        }
    }

    func restore() async -> Entitlement {
        guard configured else { return couponFallback(.free) }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let resolved = couponFallback(mapEntitlement(from: info))
            self.entitlement = resolved
            return resolved
        } catch {
            return couponFallback(.free)
        }
    }

    func identify(uid: String) async {
        guard configured else { return }
        _ = try? await Purchases.shared.logIn(uid)
    }

    func apply(customerInfo: CustomerInfo) {
        self.entitlement = couponFallback(mapEntitlement(from: customerInfo))
    }

    @discardableResult
    func redeemCoupon(_ code: String) -> Bool {
        guard code.trimmingCharacters(in: .whitespaces).uppercased() == "NS2026" else { return false }
        UserDefaults.standard.set(true, forKey: Self.couponDefaultsKey)
        entitlement = .yearly
        return true
    }

    // If RevenueCat says free but the user redeemed the coupon, honour that.
    private func couponFallback(_ resolved: Entitlement) -> Entitlement {
        resolved == .free && Self.couponRedeemed ? .yearly : resolved
    }

    // MARK: - Helpers

    private func mapEntitlement(from info: CustomerInfo) -> Entitlement {
        guard let active = info.entitlements.active[entitlementID] else { return .free }
        let id = active.productIdentifier.lowercased()
        if id.contains("year") { return .yearly }
        if id.contains("week") { return .weekly }
        return .yearly
    }
}
