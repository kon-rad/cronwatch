import SwiftUI

struct PersonalBestsView: View {
    let entries: [Entry]
    var windowDays: Int = 90

    @State private var selected: String = PersonalBests.presetCategories[0]

    private var categories: [String] { PersonalBests.presetCategories }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        selected = cat
                    } label: {
                        Text(Categories.label(for: cat))
                            .font(.cwCaption)
                            .tracking(0.5)
                            .foregroundStyle(selected == cat ? Palette.ink : Palette.muted)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(selected == cat ? Palette.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .stroke(selected == cat ? Palette.border : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            let best = PersonalBests.bestDay(for: selected, entries: entries, windowDays: windowDays)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    CategoryDotView(category: selected, size: 8)
                    Text("Best \(Categories.label(for: selected)) day".uppercased())
                        .font(.cwCaption)
                        .tracking(1)
                        .foregroundStyle(Palette.muted)
                }
                Text(best.map { TimeUtils.formatDuration($0.minutes) } ?? "—")
                    .font(.system(size: 32, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)
                Text(best.map { shortDate($0.date) } ?? "No data yet")
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
