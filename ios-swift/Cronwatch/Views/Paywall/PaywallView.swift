import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rc: RevenueCatService

    var body: some View {
        RevenueCatUI.PaywallView()
            .onRequestedDismissal {
                dismiss()
            }
            .onPurchaseCompleted { customerInfo in
                rc.apply(customerInfo: customerInfo)
                ToastCenter.shared.show(
                    message: "Subscription active. Welcome to Cronwatch.",
                    kind: .success,
                    duration: 3
                )
                dismiss()
            }
            .onPurchaseFailure { error in
                ToastCenter.shared.show(
                    message: error.localizedDescription,
                    kind: .error,
                    duration: 4
                )
            }
            .onRestoreCompleted { customerInfo in
                rc.apply(customerInfo: customerInfo)
                let hasActive = !customerInfo.entitlements.active.isEmpty
                ToastCenter.shared.show(
                    message: hasActive ? "Purchases restored." : "No active purchases found.",
                    kind: hasActive ? .success : .info,
                    duration: 3
                )
                if hasActive { dismiss() }
            }
    }
}
