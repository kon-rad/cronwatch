import SwiftUI

struct OnboardingVisionView: View {
    @Binding var years3: String
    @Binding var years5: String
    @Binding var years10: String
    let onBack: () -> Void
    let onNext: () -> Void

    private enum Field { case years3, years5, years10 }
    @FocusState private var focusedField: Field?

    var body: some View {
        OnboardingStepLayout(
            headline: "Where are you headed?",
            subtext: "These are for you — a reminder of the bigger picture.",
            canContinue: true,
            onBack: onBack,
            onContinue: onNext
        ) {
            VStack(spacing: Spacing.md) {
                visionField(label: "In 3 years, I want to be…", value: $years3, field: .years3, next: .years5)
                visionField(label: "In 5 years, I want to be…", value: $years5, field: .years5, next: .years10)
                visionField(label: "In 10 years, I want to be…", value: $years10, field: .years10, next: nil)
            }
        }
    }

    private func visionField(label: String, value: Binding<String>, field: Field, next: Field?) -> some View {
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
                        .stroke(focusedField == field ? Palette.amber : Palette.border, lineWidth: 1)
                )
                .focused($focusedField, equals: field)
                .submitLabel(next != nil ? .next : .done)
                .onSubmit {
                    if let next { focusedField = next } else { focusedField = nil }
                }
        }
    }
}
