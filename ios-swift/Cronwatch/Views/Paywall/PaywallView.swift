import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var rc: RevenueCatService

    private enum Plan { case yearly, weekly }
    @State private var plan: Plan = .yearly

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Track your time without thinking about it.")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineSpacing(32 - 26)
                    .padding(.trailing, 28)

                Text("Voice in. Structured time out.")
                    .font(.cwBody)
                    .foregroundColor(Palette.muted)
                    .padding(.top, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    FeatureRow(
                        icon: "mic",
                        title: "Voice capture",
                        sub: "Hold the button, speak naturally. Cronwatch turns it into a structured entry."
                    )
                    FeatureRow(
                        icon: "square.grid.3x3",
                        title: "15-minute grid",
                        sub: "Your day at a glance — every block accounted for, nothing fudged."
                    )
                    FeatureRow(
                        icon: "lock",
                        title: "Private by default",
                        sub: "Your entries stay on-device. No analytics, no ads, no resold data."
                    )
                }
                .padding(.top, Spacing.xl)

                HStack(alignment: .top, spacing: Spacing.sm) {
                    PlanCard(
                        selected: plan == .yearly,
                        badge: "Best value · 20% off",
                        title: "Yearly",
                        price: "$40",
                        unit: "/yr",
                        sub: "$3.33/month",
                        onTap: { plan = .yearly }
                    )
                    PlanCard(
                        selected: plan == .weekly,
                        badge: nil,
                        title: "Weekly",
                        price: "$4",
                        unit: "/wk",
                        sub: "Try a week",
                        onTap: { plan = .weekly }
                    )
                }
                .padding(.top, Spacing.xl)

                Button(action: { Task { await onSubscribe() } }) {
                    Text("Start subscription")
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.amber)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xl)

                fineprint
                    .padding(.top, Spacing.md)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xl + Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Palette.muted)
                    .padding(Spacing.xs)
            }
            .contentShape(Rectangle())
            .padding(.top, Spacing.md + 4)
            .padding(.trailing, Spacing.md)
        }
    }

    private var fineprint: some View {
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                Text("Cancel anytime · ")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                Text("Restore purchases")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .underline()
                    .onTapGesture { Task { _ = await rc.restore() } }
                Text(" · ")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                Text("Terms")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .underline()
            }
            .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func onSubscribe() async {
        // TODO: trigger RevenueCat purchase for the selected plan
        dismiss()
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let sub: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Palette.borderSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Palette.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(Palette.ink)
                Text(sub)
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .lineSpacing(18 - 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PlanCard: View {
    let selected: Bool
    let badge: String?
    let title: String
    let price: String
    let unit: String
    let sub: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if let badge {
                    Text(badge)
                        .font(.cwCaption.weight(.semibold))
                        .foregroundColor(Palette.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.amber.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .padding(.bottom, 6)
                }
                Text(title)
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                HStack(alignment: .bottom, spacing: 4) {
                    Text(price)
                        .font(.cwTitle)
                        .foregroundColor(Palette.ink)
                        .monospacedDigit()
                    Text(unit)
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                        .monospacedDigit()
                        .padding(.bottom, 2)
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
                Text(sub)
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .padding(Spacing.md)
            .background(selected ? Palette.amber.opacity(0.08) : Palette.white)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(selected ? Palette.amber : Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }
}
