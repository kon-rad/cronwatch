import SwiftUI

enum Palette {
    static let bg          = Color(hex: "#FAFAF7")
    static let ink         = Color(hex: "#111111")
    static let muted       = Color(hex: "#5C5C58")
    static let border      = Color(hex: "#ECECEA")
    static let borderSoft  = Color(hex: "#F2F2EF")
    static let amber       = Color(hex: "#E8A33D")
    static let amberSoft   = Color(hex: "#FBEFD8")
    static let white       = Color.white
    static let danger      = Color(hex: "#C8412C")
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
