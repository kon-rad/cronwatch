import SwiftUI

struct TodayView: View {
    enum Scope: Hashable, CaseIterable {
        case day, week, month

        var label: String {
            switch self {
            case .day:   return "Day"
            case .week:  return "Week"
            case .month: return "Month"
            }
        }
    }

    @EnvironmentObject var auth: AuthService

    @State private var entries: [Entry] = []
    @State private var cancel: (() -> Void)?
    @State private var scope: Scope = .day
    @State private var anchor: Date = Date()

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(Palette.border)
                scopedContent
                bottomNav
            }
        }
        .onAppear { resubscribe() }
        .onDisappear {
            cancel?()
            cancel = nil
        }
        .onChange(of: scope) { _, _ in resubscribe() }
        .onChange(of: anchor) { _, _ in resubscribe() }
    }

    // MARK: - Header

    private var header: some View {
        let tracked = TimeUtils.totalTrackedMin(scopedEntries)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                scopeMenu
                Spacer()
                Button(action: jumpToToday) {
                    Text("Today")
                        .font(.cwCaption.weight(.semibold))
                        .foregroundColor(jumpToTodayEnabled ? Palette.amber : Palette.muted)
                }
                .disabled(!jumpToTodayEnabled)
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(periodTitle)
                    .font(.cwTitle)
                    .foregroundColor(Palette.ink)
                Spacer()
                if scope == .day {
                    trackedBadge
                } else {
                    Text("\(TimeUtils.formatDuration(tracked)) tracked")
                        .font(.cwCaption)
                        .monospacedDigit()
                        .foregroundColor(Palette.muted)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private var trackedBadge: some View {
        let pct = TimeUtils.trackedPercentOfDay(scopedEntries, day: anchor)
        let filled = pct >= 100
        return HStack(spacing: 4) {
            Image(systemName: filled ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.amber)
            Text("Tracked · \(pct)%")
                .font(.cwCaption.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(filled ? Palette.amber : Palette.muted)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(filled ? Palette.amberSoft : Palette.white)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill)
                .stroke(filled ? Palette.amber : Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }

    private var scopeMenu: some View {
        Menu {
            ForEach(Scope.allCases, id: \.self) { s in
                Button(action: { scope = s }) {
                    HStack {
                        Text(s.label)
                        if scope == s {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(scope.label)
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(Palette.ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Palette.muted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(Palette.white)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
        }
    }

    private var periodTitle: String {
        let f = DateFormatter()
        f.locale = .current
        switch scope {
        case .day:
            f.dateFormat = "EEE, MMM d"
            return f.string(from: anchor)
        case .week:
            let start = weekStart
            let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
            let sameMonth = Calendar.current.isDate(start, equalTo: end, toGranularity: .month)
            if sameMonth {
                f.dateFormat = "MMM"
                let month = f.string(from: start)
                let sd = Calendar.current.component(.day, from: start)
                let ed = Calendar.current.component(.day, from: end)
                return "\(month) \(sd)–\(ed)"
            } else {
                f.dateFormat = "MMM d"
                return "\(f.string(from: start)) – \(f.string(from: end))"
            }
        case .month:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: anchor)
        }
    }

    private var jumpToTodayEnabled: Bool {
        !Calendar.current.isDate(anchor, inSameDayAs: Date())
    }

    // MARK: - Content

    @ViewBuilder
    private var scopedContent: some View {
        switch scope {
        case .day:
            TodayGridView(entries: entries, anchorDate: anchor)
        case .week:
            WeekGridView(entries: entries, anchorDate: anchor) { day in
                anchor = day
                scope = .day
            }
        case .month:
            MonthGridView(entries: entries, anchorDate: anchor) { day in
                anchor = day
                scope = .day
            }
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: Spacing.md) {
            Button(action: { shift(direction: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(navHintLabel)
                .font(.cwCaption)
                .foregroundColor(Palette.muted)

            Spacer()

            Button(action: { shift(direction: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Palette.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Palette.bg)
        .overlay(
            Rectangle()
                .fill(Palette.border)
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private var navHintLabel: String {
        switch scope {
        case .day:   return "Previous · Next day"
        case .week:  return "Previous · Next week"
        case .month: return "Previous · Next month"
        }
    }

    // MARK: - Range / data

    private var dayStart: Date {
        Calendar.current.startOfDay(for: anchor)
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: anchor)?.start ?? dayStart
    }

    private var monthStart: Date {
        Calendar.current.dateInterval(of: .month, for: anchor)?.start ?? dayStart
    }

    private var rangeBounds: (Date, Date) {
        let cal = Calendar.current
        switch scope {
        case .day:
            let start = dayStart
            let end = cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-0.001) ?? start
            return (start, end)
        case .week:
            let start = weekStart
            let end = cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-0.001) ?? start
            return (start, end)
        case .month:
            // Cover the whole rendered grid (6 weeks starting from the week containing the 1st).
            let gridStart = cal.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
            let gridEnd = cal.date(byAdding: .day, value: 42, to: gridStart)?.addingTimeInterval(-0.001) ?? monthStart
            return (gridStart, gridEnd)
        }
    }

    private var scopedEntries: [Entry] {
        let (start, end) = rangeBounds
        // Overlap, not just startTime-in-range, so an entry that spans the
        // window boundary (e.g. sleep from 23:00 yesterday to 09:00 today)
        // is included on both adjacent days.
        return entries.filter { $0.startTime < end && $0.endTime > start }
    }

    private func resubscribe() {
        cancel?()
        cancel = nil
        guard let uid = auth.currentUser?.uid else { return }
        let (start, end) = rangeBounds
        cancel = EntriesService.shared.subscribeToRange(uid: uid, from: start, to: end) { newEntries in
            entries = newEntries
        }
    }

    // MARK: - Navigation actions

    private func shift(direction: Int) {
        let cal = Calendar.current
        switch scope {
        case .day:
            anchor = cal.date(byAdding: .day, value: direction, to: anchor) ?? anchor
        case .week:
            anchor = cal.date(byAdding: .weekOfYear, value: direction, to: anchor) ?? anchor
        case .month:
            anchor = cal.date(byAdding: .month, value: direction, to: anchor) ?? anchor
        }
    }

    private func jumpToToday() {
        anchor = Date()
    }
}
