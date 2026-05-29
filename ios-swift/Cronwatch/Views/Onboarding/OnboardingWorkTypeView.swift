import SwiftUI

struct OnboardingWorkTypeView: View {
    @Binding var value: String
    let onBack: () -> Void
    let onNext: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            headline: "What kind of work do you do?",
            subtext: "This helps Cronwatch understand your time better.",
            canContinue: !value.trimmingCharacters(in: .whitespaces).isEmpty,
            onBack: onBack,
            onContinue: onNext
        ) {
            TextField("e.g. Software engineer, freelance designer…", text: $value)
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
