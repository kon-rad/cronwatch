import Foundation
import RevenueCat

@MainActor
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published private(set) var entitlement: Entitlement = .free

    private let entitlementID = "subscription"
    var configured = false

    private init() {}

    func configureIfNeeded() {
        guard !configured, let key = AppEnvironment.revenueCatAPIKey else { return }
        Purchases.configure(withAPIKey: key)
        configured = true
        observeCustomerInfo()
    }

    /// Keeps `entitlement` in sync with RevenueCat for all paths — purchases,
    /// offer-code redemptions, renewals, and expirations.
    private func observeCustomerInfo() {
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.entitlement = self?.mapEntitlement(from: info) ?? .free
            }
        }
    }

    func refreshEntitlement() async -> Entitlement {
        guard configured else { return .free }
        do {
            let info = try await Purchases.shared.customerInfo()
            let resolved = mapEntitlement(from: info)
            self.entitlement = resolved
            return resolved
        } catch {
            return .free
        }
    }

    func restore() async -> Entitlement {
        guard configured else { return .free }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let resolved = mapEntitlement(from: info)
            self.entitlement = resolved
            return resolved
        } catch {
            return .free
        }
    }

    func identify(uid: String) async {
        guard configured else { return }
        _ = try? await Purchases.shared.logIn(uid)
    }

    func apply(customerInfo: CustomerInfo) {
        self.entitlement = mapEntitlement(from: customerInfo)
    }

    /// Presents Apple's native offer-code redemption sheet. Redemption is processed
    /// by the App Store; the `customerInfoStream` observer then updates `entitlement`.
    func presentOfferCodeRedemption() {
        guard configured else { return }
        Purchases.shared.presentCodeRedemptionSheet()
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
