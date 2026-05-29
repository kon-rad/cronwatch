import SwiftUI

struct WeekGridView: View {
    let entries: [Entry]
    let anchorDate: Date
    var onSelectDay: (Date) -> Void = { _ in }

    static let timeColWidth: CGFloat = 36
    // 2/3 of 24 hours visible in the body; the remaining 1/3 is scrollable.
    static let hoursVisible: CGFloat = 16

    @State private var nowMin: Int = WeekGridView.currentMinuteOfDay()
    @State private var presentedEntry: EntrySheetItem?
    @State private var didInitialScroll: Bool = false

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: anchorDate)?.start
            ?? Calendar.current.startOfDay(for: anchorDate)
    }

    private var days: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func entriesFor(day: Date) -> [Entry] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return entries.filter { $0.startTime < dayEnd && $0.endTime > dayStart }
    }

    var body: some View {
        VStack(spacing: 0) {
            dayHeaderRow

            Divider().background(Palette.border)

            GeometryReader { geo in
                let hourPx = max(20, geo.size.height / Self.hoursVisible)
                let pxPerMin = hourPx / 60
                let dayHeight = 24 * hourPx

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            hourLabels(hourPx: hourPx)
                            gridArea(hourPx: hourPx, pxPerMin: pxPerMin, dayHeight: dayHeight)
                                .padding(.leading, Self.timeColWidth)

                            // Anchors used for initial auto-scroll
                            Color.clear
                                .frame(width: 1, height: 1)
                                .id("hour-6")
                                .position(x: 0, y: 6 * hourPx)
                            Color.clear
                                .frame(width: 1, height: 1)
                                .id("now")
                                .position(x: 0, y: CGFloat(nowMin) * pxPerMin)
                        }
                        .frame(height: dayHeight)
                        .padding(.bottom, 120)
                    }
                    .background(Palette.bg)
                    .onAppear {
                        guard !didInitialScroll else { return }
                        didInitialScroll = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.none) {
                                proxy.scrollTo(initialScrollAnchor, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            nowMin = WeekGridView.currentMinuteOfDay()
        }
        .sheet(item: $presentedEntry) { item in
            EntryEditView(entryID: item.id)
                .presentationDetents([.large])
        }
    }

    private var initialScrollAnchor: String {
        if days.contains(where: { Calendar.current.isDateInToday($0) }) {
            return "now"
        }
        return "hour-6"
    }

    // MARK: - Day header

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.timeColWidth, height: 0)
            ForEach(days, id: \.self) { day in
                Button(action: { onSelectDay(day) }) {
                    dayHeaderCell(day)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .background(Palette.bg)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dayHeaderCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let dayNum = cal.component(.day, from: day)
        return HStack(spacing: 4) {
            Text(dayAbbrev(day))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Palette.muted)
                .tracking(0.5)
            Text("\(dayNum)")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? Palette.amber : Palette.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    // MARK: - Hour labels

    private func hourLabels(hourPx: CGFloat) -> some View {
        ForEach(0..<24, id: \.self) { h in
            Text(String(format: "%02d", h))
                .font(.cwCaption)
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
                .frame(width: Self.timeColWidth, alignment: .trailing)
                .padding(.trailing, 4)
                .position(
                    x: Self.timeColWidth / 2,
                    y: CGFloat(h) * hourPx + 7
                )
        }
    }

    // MARK: - Grid

    private func gridArea(hourPx: CGFloat, pxPerMin: CGFloat, dayHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let colWidth = width / 7
            ZStack(alignment: .topLeading) {
                // Horizontal hour lines
                ForEach(0..<25, id: \.self) { h in
                    Rectangle()
                        .fill(Palette.borderSoft)
                        .frame(width: width, height: 0.5)
                        .position(x: width / 2, y: CGFloat(h) * hourPx)
                }

                // Vertical day separators
                ForEach(1..<7, id: \.self) { i in
                    Rectangle()
                        .fill(Palette.borderSoft)
                        .frame(width: 0.5, height: dayHeight)
                        .position(x: CGFloat(i) * colWidth, y: dayHeight / 2)
                }

                // Day backgrounds + entries
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let dayEntries = entriesFor(day: day)
                    ForEach(dayEntries) { entry in
                        if let clip = TimeUtils.clipMinutesOfDay(entry, day: day) {
                            entryBlock(
                                entry: entry,
                                clip: clip,
                                colIndex: index,
                                colWidth: colWidth,
                                pxPerMin: pxPerMin
                            )
                        }
                    }
                }

                // Now line on today column
                if let todayIndex = days.firstIndex(where: { Calendar.current.isDateInToday($0) }) {
                    let nowY = CGFloat(nowMin) * pxPerMin
                    let nowX = CGFloat(todayIndex) * colWidth
                    Rectangle()
                        .fill(Palette.amber)
                        .frame(width: colWidth, height: 1)
                        .position(x: nowX + colWidth / 2, y: nowY)
                    Circle()
                        .fill(Palette.amber)
                        .frame(width: 6, height: 6)
                        .position(x: nowX + 4, y: nowY)
                }
            }
            .frame(width: width, height: dayHeight, alignment: .topLeading)
        }
        .frame(height: dayHeight)
    }

    private func entryBlock(entry: Entry, clip: (startMin: Int, endMin: Int), colIndex: Int, colWidth: CGFloat, pxPerMin: CGFloat) -> some View {
        let startMin = clip.startMin
        let durMin = max(15, clip.endMin - clip.startMin)
        let top = CGFloat(startMin) * pxPerMin
        let height = max(10, CGFloat(durMin) * pxPerMin - 1)
        let bg = Categories.pillBackground(for: entry.category)
        let stroke = Categories.color(for: entry.category)
        let inset: CGFloat = 1
        let blockWidth = max(0, colWidth - inset * 2)
        let x = CGFloat(colIndex) * colWidth + inset + blockWidth / 2

        return Button {
            presentedEntry = EntrySheetItem(id: entry.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if height > 24 {
                    Text(entry.category.capitalized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                    if height > 36, !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.system(size: 9))
                            .foregroundColor(Palette.muted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .frame(width: blockWidth, height: height, alignment: .topLeading)
            .background(bg)
            .overlay(
                Rectangle()
                    .fill(stroke)
                    .frame(width: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .position(x: x, y: top + height / 2)
    }

    private static func currentMinuteOfDay() -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
