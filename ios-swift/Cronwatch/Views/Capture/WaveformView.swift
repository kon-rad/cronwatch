import SwiftUI

struct WaveformView: View {
    @State private var phase: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(Palette.amber)
                    .frame(width: 3, height: phase ? 28 : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.06),
                        value: phase
                    )
            }
        }
        .frame(height: 32)
        .onAppear { phase = true }
    }
}
