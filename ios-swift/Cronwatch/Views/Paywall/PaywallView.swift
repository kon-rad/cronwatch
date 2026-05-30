import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rc: RevenueCatService

    @State private var showCouponAlert = false
    @State private var couponCode = ""

    var body: some View {
        ZStack(alignment: .bottom) {
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

            Button("Have a coupon code?") {
                showCouponAlert = true
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Palette.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            .padding(.bottom, 36)
        }
        .alert("Redeem Code", isPresented: $showCouponAlert) {
            TextField("Enter code", text: $couponCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Redeem") {
                let redeemed = rc.redeemCoupon(couponCode)
                couponCode = ""
                if redeemed {
                    ToastCenter.shared.show(
                        message: "Code accepted. Subscription active.",
                        kind: .success,
                        duration: 3
                    )
                    dismiss()
                } else {
                    ToastCenter.shared.show(
                        message: "Invalid code.",
                        kind: .error,
                        duration: 3
                    )
                }
            }
            Button("Cancel", role: .cancel) { couponCode = "" }
        } message: {
            Text("Enter your coupon code to unlock a subscription.")
        }
    }
}
