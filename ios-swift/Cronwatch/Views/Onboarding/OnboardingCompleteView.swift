import SwiftUI

struct OnboardingCompleteView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("You're ready.")
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, Spacing.md)

                Text("Start tracking your time — your goals and vision are saved.")
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(action: onDone) {
                    Text("Start tracking")
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
