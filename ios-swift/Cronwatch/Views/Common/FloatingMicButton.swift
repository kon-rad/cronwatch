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
                    .frame(width: 64, height: 64)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Palette.white)
            }
            .cwShadow(Shadows.fab)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture entry")
    }
}
