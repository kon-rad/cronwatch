import SwiftUI

struct CategoryDef: Hashable {
    let key: String
    let label: String
    let color: Color
}

enum Categories {
    static let all: [CategoryDef] = [
        .init(key: "work",      label: "Work",      color: Color(hex: "#3D6F8E")),
        .init(key: "deep",      label: "Deep",      color: Color(hex: "#4F7A6A")),
        .init(key: "meeting",   label: "Meeting",   color: Color(hex: "#B07845")),
        .init(key: "study",     label: "Study",     color: Color(hex: "#8A6FA3")),
        .init(key: "exercise",  label: "Exercise",  color: Color(hex: "#C8412C")),
        .init(key: "sleep",     label: "Sleep",     color: Color(hex: "#5C5C58")),
        .init(key: "meal",      label: "Meal",      color: Color(hex: "#E8A33D")),
        .init(key: "break",     label: "Break",     color: Color(hex: "#A8A89D")),
        .init(key: "commute",   label: "Commute",   color: Color(hex: "#7A8A95")),
        .init(key: "entertain", label: "Entertain", color: Color(hex: "#A05B7E")),
        .init(key: "personal",  label: "Personal",  color: Color(hex: "#9C8855")),
    ]

    static func color(for key: String) -> Color {
        if let exact = all.first(where: { $0.key == key }) { return exact.color }
        let lower = key.lowercased()
        if let byLabel = all.first(where: { $0.label.lowercased() == lower }) { return byLabel.color }
        if let byKey = all.first(where: { $0.key.lowercased() == lower }) { return byKey.color }
        return Color(hex: "#5C5C58")
    }

    static func pillBackground(for key: String) -> Color {
        color(for: key).opacity(0.12)
    }

    static func label(for key: String) -> String {
        if let exact = all.first(where: { $0.key == key }) { return exact.label }
        return key
    }
}
