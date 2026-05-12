import SwiftUI

struct FloatingMicButton: View {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Palette.amber)
                    .frame(width: 56, height: 56)
                Image(systemName: "mic")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Palette.white)
            }
            .cwShadow(Shadows.fab)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture entry")
    }
}
