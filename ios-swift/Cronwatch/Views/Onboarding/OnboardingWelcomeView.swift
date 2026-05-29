import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("Cronwatch helps you track your time so you can own it.")
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.md)

                Text("Answer a few questions to get started.")
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(action: onNext) {
                    Text("Let's go")
                        .font(.cwBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Palette.amber)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
        }
    }
}
