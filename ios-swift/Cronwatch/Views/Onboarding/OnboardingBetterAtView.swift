import SwiftUI

struct OnboardingBetterAtView: View {
    @Binding var value: String
    let onBack: () -> Void
    let onNext: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            headline: "What do you want to get better at?",
            subtext: "In one sentence — what matters most to you right now.",
            canContinue: !value.trimmingCharacters(in: .whitespaces).isEmpty,
            onBack: onBack,
            onContinue: onNext
        ) {
            TextField("e.g. Being more intentional with my time", text: $value)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(focused ? Palette.amber : Palette.border, lineWidth: 1)
                )
                .focused($focused)
                .submitLabel(.done)
                .onSubmit {
                    if !value.trimmingCharacters(in: .whitespaces).isEmpty { onNext() }
                }
                .onAppear { focused = true }
        }
    }
}
