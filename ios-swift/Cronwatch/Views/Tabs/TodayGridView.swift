import SwiftUI

struct TodayGridView: View {
    let entries: [Entry]

    static let pxPerMin: CGFloat = 1.4
    static let hourPx: CGFloat = 60 * 1.4
    static let timeColWidth: CGFloat = 56

    @State private var nowMin: Int = {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }()

    @State private var presentedEntry: EntrySheetItem?
    @State private var didInitialScroll = false

    private var dayHeight: CGFloat { 24 * Self.hourPx }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Hour labels (left column)
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d:00", h))
                            .font(.cwCaption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 2)
                            .frame(width: Self.timeColWidth, alignment: .leading)
                            .padding(.leading, Spacing.md)
                            .position(
                                x: Spacing.md + Self.timeColWidth / 2,
                                y: CGFloat(h) * Self.hourPx + 9
                            )
                    }

                    // Grid area to the right of the time column
                    gridArea
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, Spacing.md + Self.timeColWidth)
                        .padding(.trailing, Spacing.md)
                }
                .frame(height: dayHeight)
                .padding(.bottom, 160)
            }
            .background(Palette.bg)
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.none) {
                        proxy.scrollTo("now", anchor: .top)
                    }
                }
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
                nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
            .sheet(item: $presentedEntry) { item in
                EntryEditView(entryID: item.id)
                    .presentationDetents([.large])
            }
        }
    }

    private var gridArea: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                // Dotted dividers (96 hairlines)
                ForEach(0..<(24 * 4), id: \.self) { q in
                    Rectangle()
                        .fill(q % 4 == 0 ? Palette.border : Palette.borderSoft)
                        .frame(width: width, height: 0.5)
                        .position(x: width / 2, y: CGFloat(q) * 15 * Self.pxPerMin + 0.5)
                }

                // Entries
                ForEach(entries) { entry in
                    entryBlock(for: entry, width: width)
                }

                // Now line + dot
                nowLine(width: width)
                    .id("now")
            }
            .frame(width: width, height: dayHeight, alignment: .topLeading)
        }
        .frame(height: dayHeight)
    }

    private func entryBlock(for entry: Entry, width: CGFloat) -> some View {
        let startMin = TimeUtils.minutesSinceMidnight(entry.startTime)
        let durMin = TimeUtils.entryDurationMin(entry)
        let top = CGFloat(startMin) * Self.pxPerMin
        let height = max(28, CGFloat(durMin) * Self.pxPerMin - 2)
        let bg = Categories.pillBackground(for: entry.category)
        let leftInset: CGFloat = Spacing.sm
        let rightInset: CGFloat = Spacing.xs
        let blockWidth = max(0, width - leftInset - rightInset)

        let combinedLabel = (
            Text(entry.category.capitalized)
                .font(.cwBody)
                .fontWeight(.semibold)
                .foregroundColor(Palette.ink)
            + Text("  ·  \(entry.note)")
                .font(.cwBody)
                .foregroundColor(Palette.muted)
        )

        return Button {
            presentedEntry = EntrySheetItem(id: entry.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    CategoryDotView(category: entry.category)
                    combinedLabel
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: Spacing.xs)
                    Text(TimeUtils.formatDuration(durMin))
                        .font(.cwCaption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.muted)
                }
                if height > 56 {
                    Text(TimeUtils.formatHHmm(entry.startTime))
                        .font(.cwCaption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .frame(width: blockWidth, height: height, alignment: .topLeading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .position(x: leftInset + blockWidth / 2, y: top + height / 2)
    }

    private func nowLine(width: CGFloat) -> some View {
        let y = CGFloat(nowMin) * Self.pxPerMin
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Palette.amber)
                .frame(width: width + 10, height: 1)
                .offset(x: -10)
            Circle()
                .fill(Palette.amber)
                .frame(width: 8, height: 8)
                .offset(x: -14)
        }
        .frame(width: width, height: 8, alignment: .leading)
        .position(x: width / 2, y: y)
        .allowsHitTesting(false)
    }
}

struct EntrySheetItem: Identifiable, Hashable {
    let id: String
}
