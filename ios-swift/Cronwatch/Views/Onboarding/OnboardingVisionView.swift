import SwiftUI

struct OnboardingVisionView: View {
    @Binding var years3: String
    @Binding var years5: String
    @Binding var years10: String
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(
            headline: "Where are you headed?",
            subtext: "These are for you — a reminder of the bigger picture.",
            canContinue: true,
            onBack: onBack,
            onContinue: onNext
        ) {
            VStack(spacing: Spacing.md) {
                visionField(label: "In 3 years, I want to be…", value: $years3)
                visionField(label: "In 5 years, I want to be…", value: $years5)
                visionField(label: "In 10 years, I want to be…", value: $years10)
            }
        }
    }

    private func visionField(label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
            TextField("", text: value)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.border, lineWidth: 1)
                )
                .submitLabel(.next)
        }
    }
}
