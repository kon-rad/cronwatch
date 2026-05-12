import SwiftUI
import CoreGraphics

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let fab: CGFloat = 28
    static let pill: CGFloat = 999
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: Double
}

enum Shadows {
    static let card = ShadowStyle(color: .black, radius: 2, x: 0, y: 1, opacity: 0.04)
    static let fab  = ShadowStyle(color: .black, radius: 12, x: 0, y: 4, opacity: 0.12)
}

extension View {
    func cwShadow(_ s: ShadowStyle) -> some View {
        self.shadow(color: s.color.opacity(s.opacity), radius: s.radius, x: s.x, y: s.y)
    }
}
