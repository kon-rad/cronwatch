import SwiftUI

struct OnboardingStepLayout<Content: View>: View {
    let headline: String
    let subtext: String
    let continueLabel: String
    let canContinue: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        headline: String,
        subtext: String,
        continueLabel: String = "Continue",
        canContinue: Bool = true,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headline = headline
        self.subtext = subtext
        self.continueLabel = continueLabel
        self.canContinue = canContinue
        self.onBack = onBack
        self.onContinue = onContinue
        self.content = content
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Palette.ink)
                    }
                    .accessibilityLabel("Back")
                    .padding(.bottom, Spacing.lg)
                } else {
                    Spacer().frame(height: Spacing.lg + 28)
                }

                Text(headline)
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, Spacing.sm)

                Text(subtext)
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.xl)

                content()

                Spacer()

                Button(action: onContinue) {
                    Text(continueLabel)
                        .font(.cwBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(canContinue ? Palette.amber : Palette.border)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(!canContinue)
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
        }
    }
}
