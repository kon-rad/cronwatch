# Overview Home Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat GoalsCardView with a unified DashboardHeroCard showing today's coverage % and 3 goal progress bars, while migrating goals from free-text strings to structured category + weekly-hour-target objects.

**Architecture:** Goals become a `Goal` struct (category + weeklyTargetHours). `UserSettings` is updated in-place; Firestore reads/writes are updated to match. A new `DashboardHeroCard` view replaces `GoalsCardView` at the top of `OverviewView`. The `GoalsEditorView` is redesigned with a category pill picker and hour stepper. All other views (donut, streak, heatmap, personal bests) are untouched.

**Tech Stack:** SwiftUI, Firebase Firestore, existing Palette/Spacing/Radius/Categories theme tokens.

---

## File Map

| Action | File |
|--------|------|
| Modify | `ios-swift/Cronwatch/Models/UserSettings.swift` |
| Modify | `ios-swift/Cronwatch/Services/UserSettingsService.swift` |
| Create | `ios-swift/Cronwatch/Views/Overview/DashboardHeroCard.swift` |
| Modify | `ios-swift/Cronwatch/Views/Overview/GoalsEditorView.swift` |
| Delete | `ios-swift/Cronwatch/Views/Overview/GoalsCardView.swift` |
| Modify | `ios-swift/Cronwatch/Views/Tabs/OverviewView.swift` |
| Modify | `ios-swift/Cronwatch/Services/WeekReportService.swift` |

---

## Task 1: Add Goal model & update UserSettings

**Files:**
- Modify: `ios-swift/Cronwatch/Models/UserSettings.swift`

- [ ] **Step 1: Replace the contents of UserSettings.swift**

```swift
import Foundation

struct Goal: Codable, Equatable {
    var category: String
    var weeklyTargetHours: Double

    var isSet: Bool { !category.isEmpty && weeklyTargetHours > 0 }
}

struct UserSettings: Codable, Equatable {
    var goals: [Goal]

    static let empty = UserSettings(goals: [
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
    ])

    var hasAnyGoal: Bool {
        goals.contains { $0.isSet }
    }
}
```

- [ ] **Step 2: Verify the file compiles in isolation**

In Xcode, cmd-B (build). You will see compile errors in `UserSettingsService`, `GoalsEditorView`, `GoalsCardView`, `OverviewView`, and `WeekReportService` — all expected because they reference the old `[String]` API. Do not fix them yet; just confirm the model file itself is clean.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Models/UserSettings.swift
git commit -m "feat(model): replace string goals with Goal struct (category + weeklyTargetHours)"
```

---

## Task 2: Update UserSettingsService

**Files:**
- Modify: `ios-swift/Cronwatch/Services/UserSettingsService.swift`

- [ ] **Step 1: Replace the file contents**

```swift
import Foundation
import FirebaseFirestore

enum UserSettingsServiceError: Error, LocalizedError {
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: return "Firebase is not configured."
        }
    }
}

@MainActor
final class UserSettingsService {
    static let shared = UserSettingsService()

    private init() {}

    func subscribe(uid: String, onChange: @escaping (UserSettings) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onChange(.empty)
            return {}
        }

        let doc = userDoc(uid: uid)
        let registration = doc.addSnapshotListener { snapshot, _ in
            let raw = (snapshot?.data()?["goals"] as? [[String: Any]]) ?? []
            var goals: [Goal] = raw.compactMap { map in
                guard let category = map["category"] as? String,
                      let target = map["weeklyTargetHours"] as? Double else { return nil }
                return Goal(category: category, weeklyTargetHours: target)
            }
            while goals.count < 3 {
                goals.append(Goal(category: "", weeklyTargetHours: 0))
            }
            onChange(UserSettings(goals: Array(goals.prefix(3))))
        }
        return { registration.remove() }
    }

    func saveGoals(uid: String, goals: [Goal]) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw UserSettingsServiceError.firebaseNotConfigured
        }
        let data = goals.map { ["category": $0.category, "weeklyTargetHours": $0.weeklyTargetHours] }
        try await userDoc(uid: uid).setData([
            "goals": data,
            "goalsUpdatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    private func userDoc(uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }
}
```

- [ ] **Step 2: Build and verify this file compiles**

Remaining compile errors will be in `GoalsEditorView`, `GoalsCardView`, `OverviewView`, and `WeekReportService`. Those are fixed in later tasks.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Services/UserSettingsService.swift
git commit -m "feat(service): update UserSettingsService to read/write [Goal] structs"
```

---

## Task 3: Create DashboardHeroCard

**Files:**
- Create: `ios-swift/Cronwatch/Views/Overview/DashboardHeroCard.swift`

- [ ] **Step 1: Create the file with this content**

```swift
import SwiftUI

struct DashboardHeroCard: View {
    let todayEntries: [Entry]
    let rangeEntries: [Entry]
    let goals: [Goal]
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            coverageSection
                .padding(.top, Spacing.xs)

            let setGoals = goals.filter { $0.isSet }
            if setGoals.isEmpty {
                emptyGoalsSection
            } else {
                Divider()
                    .background(Palette.border)
                    .padding(.vertical, Spacing.md)
                goalsSection(setGoals)
            }
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(alignment: .center) {
            Text("TODAY")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
            Spacer()
            Button(action: onEdit) {
                Text("Edit")
                    .font(.cwCaption.weight(.semibold))
                    .foregroundColor(Palette.amber)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Coverage

    private var coverageSection: some View {
        let pct = TimeUtils.trackedPercentOfDay(todayEntries, day: Date())
        let covMin = TimeUtils.coveredMinutesOfDay(todayEntries, day: Date())
        let isComplete = pct >= 100

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(pct)%")
                    .font(.system(size: 36, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.amber)
                }
            }

            Text("\(TimeUtils.formatDuration(covMin)) of 24h tracked")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.borderSoft)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.amber)
                        .frame(
                            width: geo.size.width * CGFloat(min(1.0, Double(pct) / 100.0)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
            .padding(.top, 2)
        }
    }

    // MARK: - Goals

    private var emptyGoalsSection: some View {
        Text("Tap Edit to set up to 3 weekly goals →")
            .font(.cwCaption)
            .foregroundStyle(Palette.muted)
            .padding(.top, Spacing.sm)
    }

    private func goalsSection(_ setGoals: [Goal]) -> some View {
        VStack(spacing: 10) {
            ForEach(setGoals, id: \.category) { goal in
                goalRow(goal)
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let targetMin = Int(goal.weeklyTargetHours * 60)
        let loggedMin = weeklyMinutes(for: goal.category)
        let progress = targetMin > 0 ? min(1.0, Double(loggedMin) / Double(targetMin)) : 0.0
        let isComplete = targetMin > 0 && loggedMin >= targetMin

        return HStack(spacing: Spacing.sm) {
            CategoryDotView(category: goal.category)

            Text(Categories.label(for: goal.category))
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.borderSoft)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Categories.color(for: goal.category))
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 4) {
                Text(progressLabel(logged: loggedMin, target: targetMin))
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundStyle(isComplete ? Palette.ink : Palette.muted)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Categories.color(for: goal.category))
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private var mondayOfCurrentWeek: Date {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: todayStart)
        // weekday: 1=Sunday, 2=Monday … 7=Saturday
        let daysSinceMonday = (weekday - 2 + 7) % 7
        return cal.date(byAdding: .day, value: -daysSinceMonday, to: todayStart) ?? todayStart
    }

    private func weeklyMinutes(for category: String) -> Int {
        let cal = Calendar.current
        let weekStart = mondayOfCurrentWeek
        guard let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return 0 }
        return rangeEntries
            .filter { $0.category == category }
            .reduce(0) { total, entry in
                let s = max(entry.startTime, weekStart)
                let e = min(entry.endTime, weekEnd)
                guard e > s else { return total }
                return total + Int(e.timeIntervalSince(s) / 60)
            }
    }

    private func progressLabel(logged: Int, target: Int) -> String {
        let loggedH = logged / 60
        let loggedM = logged % 60
        let targetH = target / 60
        let loggedStr = loggedM > 0 ? "\(loggedH)h \(loggedM)m" : "\(loggedH)h"
        return "\(loggedStr) / \(targetH)h"
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode, right-click the `Views/Overview` group → Add Files → select `DashboardHeroCard.swift`. Verify it appears in the project navigator under that group.

- [ ] **Step 3: Build and confirm no new errors from this file**

- [ ] **Step 4: Commit**

```bash
git add ios-swift/Cronwatch/Views/Overview/DashboardHeroCard.swift
git commit -m "feat(ui): DashboardHeroCard with today coverage % and weekly goal progress bars"
```

---

## Task 4: Redesign GoalsEditorView

**Files:**
- Modify: `ios-swift/Cronwatch/Views/Overview/GoalsEditorView.swift`

- [ ] **Step 1: Replace the entire file contents**

```swift
import SwiftUI

struct GoalsEditorView: View {
    let uid: String
    let initial: UserSettings
    let onClose: () -> Void

    @State private var goals: [Goal]
    @State private var saving: Bool = false
    @State private var errorMessage: String?

    init(uid: String, initial: UserSettings, onClose: @escaping () -> Void) {
        self.uid = uid
        self.initial = initial
        self.onClose = onClose
        var g = initial.goals
        while g.count < 3 { g.append(Goal(category: "", weeklyTargetHours: 0)) }
        _goals = State(initialValue: Array(g.prefix(3)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("Choose up to 3 categories to focus on each week. Set a personal hour target for each.")
                            .font(.cwCaption)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(0..<3, id: \.self) { index in
                            goalSlot(index: index)
                        }

                        if let errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Couldn't save")
                                    .font(.cwCaption.weight(.semibold))
                                    .foregroundStyle(Palette.danger)
                                Text(errorMessage)
                                    .font(.cwCaption)
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("My Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await save() } }) {
                        if saving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    // MARK: - Goal slot

    @ViewBuilder
    private func goalSlot(index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("GOAL \(index + 1)")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)

            categoryPicker(index: index)

            if !goals[index].category.isEmpty {
                targetInput(index: index)
            }
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    // MARK: - Category picker

    private func categoryPicker(index: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(Categories.all, id: \.key) { cat in
                    let isSelected = goals[index].category == cat.key
                    let isUsedElsewhere = goals.indices
                        .filter { $0 != index }
                        .contains { goals[$0].category == cat.key }

                    Button {
                        if isSelected {
                            goals[index] = Goal(category: "", weeklyTargetHours: 0)
                        } else {
                            goals[index].category = cat.key
                            if goals[index].weeklyTargetHours == 0 {
                                goals[index].weeklyTargetHours = 5.0
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            CategoryDotView(category: cat.key)
                            Text(cat.label)
                                .font(.cwCaption)
                                .foregroundStyle(
                                    isSelected ? .white :
                                    (isUsedElsewhere ? Palette.muted : Palette.ink)
                                )
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? cat.color :
                            (isUsedElsewhere ? Palette.borderSoft : Color.clear)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected || isUsedElsewhere ? Color.clear : Palette.border,
                                lineWidth: 1
                            )
                        )
                        .opacity(isUsedElsewhere && !isSelected ? 0.4 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUsedElsewhere && !isSelected)
                }
            }
        }
    }

    // MARK: - Target input

    private func targetInput(index: Int) -> some View {
        HStack {
            Text("Weekly target")
                .font(.cwBody)
                .foregroundStyle(Palette.muted)
            Spacer()
            Stepper(
                value: Binding(
                    get: { goals[index].weeklyTargetHours },
                    set: { goals[index].weeklyTargetHours = max(0.5, min(80, $0)) }
                ),
                in: 0.5...80,
                step: 0.5
            ) {
                Text(formatHours(goals[index].weeklyTargetHours) + " / week")
                    .font(.cwBody.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
    }

    // MARK: - Helpers

    private func formatHours(_ h: Double) -> String {
        h.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(h))h" : String(format: "%.1fh", h)
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            try await UserSettingsService.shared.saveGoals(uid: uid, goals: goals)
            onClose()
        } catch {
            let nsError = error as NSError
            let message = nsError.localizedDescription
            errorMessage = "\(message) [code \(nsError.code), domain \(nsError.domain)]"
            ToastCenter.shared.show(message: message, kind: .error)
        }
    }
}
```

- [ ] **Step 2: Build. Remaining compile errors should now be only in GoalsCardView and OverviewView.**

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Overview/GoalsEditorView.swift
git commit -m "feat(ui): redesign GoalsEditorView with category pill picker and hour stepper"
```

---

## Task 5: Delete GoalsCardView

**Files:**
- Delete: `ios-swift/Cronwatch/Views/Overview/GoalsCardView.swift`

- [ ] **Step 1: Delete the file from Xcode**

In Xcode's project navigator, right-click `GoalsCardView.swift` → Delete → Move to Trash.

- [ ] **Step 2: Also delete from disk if still present**

```bash
rm -f ios-swift/Cronwatch/Views/Overview/GoalsCardView.swift
```

- [ ] **Step 3: Build. The only remaining compile error should be in OverviewView (references to GoalsCardView and settings.goals as [String]).**

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: delete GoalsCardView (replaced by DashboardHeroCard)"
```

---

## Task 6: Update OverviewView

**Files:**
- Modify: `ios-swift/Cronwatch/Views/Tabs/OverviewView.swift`

- [ ] **Step 1: Replace the GoalsCardView call with DashboardHeroCard**

Find this block in `OverviewView.body`:
```swift
GoalsCardView(settings: settings) {
    showGoalsEditor = true
}
.padding(.bottom, Spacing.md)
```

Replace with:
```swift
DashboardHeroCard(
    todayEntries: todayEntries,
    rangeEntries: rangeEntries,
    goals: settings.goals,
    onEdit: { showGoalsEditor = true }
)
.padding(.bottom, Spacing.md)
```

- [ ] **Step 2: Fix the WeekReportView call site**

Find this in `OverviewView.body`:
```swift
WeekReportView(
    goals: settings.goals,
    days: WeekReportAggregator.aggregate(entries: rangeEntries, now: dayTick),
    weekStart: start,
    weekEnd: end
) {
    showWeekReport = false
}
```

Replace with:
```swift
let goalDescriptions = settings.goals
    .filter { $0.isSet }
    .map { goal -> String in
        let label = Categories.label(for: goal.category)
        let hrs = goal.weeklyTargetHours.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(goal.weeklyTargetHours))h"
            : String(format: "%.1fh", goal.weeklyTargetHours)
        return "\(label): \(hrs)/week"
    }
WeekReportView(
    goals: goalDescriptions,
    days: WeekReportAggregator.aggregate(entries: rangeEntries, now: dayTick),
    weekStart: start,
    weekEnd: end
) {
    showWeekReport = false
}
```

- [ ] **Step 3: Fix the GoalsEditorView call site**

Find:
```swift
GoalsEditorView(uid: uid, initial: settings) {
    showGoalsEditor = false
}
```

This call signature is unchanged — GoalsEditorView still takes `uid: String, initial: UserSettings, onClose`. No change needed here.

- [ ] **Step 4: Build — the only remaining compile error should be in WeekReportService.**

- [ ] **Step 5: Commit**

```bash
git add ios-swift/Cronwatch/Views/Tabs/OverviewView.swift
git commit -m "feat(ui): wire DashboardHeroCard into OverviewView, map Goal to goal descriptions for WeekReport"
```

---

## Task 7: Update WeekReportService

**Files:**
- Modify: `ios-swift/Cronwatch/Services/WeekReportService.swift`

- [ ] **Step 1: Remove the UserSettings.normalized call**

Find in `WeekReportService.generate`:
```swift
let payload: [String: Any] = [
    "goals": UserSettings.normalized(goals),
```

Replace with:
```swift
let payload: [String: Any] = [
    "goals": goals,
```

`goals` is now a pre-formatted `[String]` from the call site — no normalization needed.

- [ ] **Step 2: Build — project should compile with zero errors.**

```bash
xcodebuild -scheme Cronwatch -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Services/WeekReportService.swift
git commit -m "fix(service): remove UserSettings.normalized from WeekReportService (goals are pre-formatted)"
```

---

## Task 8: Smoke test on simulator

- [ ] **Step 1: Launch the app in a simulator**

Run on iPhone 16 simulator. Sign in (or use an existing test account).

- [ ] **Step 2: Verify hero card — empty goals state**

If goals were previously text strings (old format), Firestore will return them as strings, not maps — the snapshot listener will parse zero valid goals. You should see the hero card with:
- Coverage % for today
- "Tap Edit to set up to 3 weekly goals →" empty state

- [ ] **Step 3: Open GoalsEditorView and set a goal**

Tap "Edit". Verify:
- Three goal slots appear, each with "GOAL 1", "GOAL 2", "GOAL 3"
- A horizontal scroll row of category pills (all 11 categories visible)
- Tapping a category selects it (fills with category color, white text)
- After selecting, a "Weekly target" stepper appears below the pills, starting at 5h
- Stepper increments/decrements by 0.5h
- The same category can't be selected in two different goal slots (greyed out at 40% opacity elsewhere)
- Tap Save — no error

- [ ] **Step 4: Verify hero card — goals state**

After saving, the hero card should show:
- Coverage % at top with amber bar
- Divider
- One row per set goal: colored dot, category label, progress bar, "Xh Ym / Zh" label
- If any goal is at 100%, the bar is solid and a checkmark appears

- [ ] **Step 5: Verify week boundary**

If today is not Monday, goals should show partial-week progress (hours from Monday 00:00 to now).

- [ ] **Step 6: Verify week report still works**

If streak ≥ 7 and goals are set, the "Generate week report" button should appear. Tap it. Verify the sheet loads and the AI receives goal descriptions like "Deep: 20h/week" instead of crashing.

- [ ] **Step 7: Final commit if any polish fixes were needed**

```bash
git add -p
git commit -m "fix(ui): polish from smoke test"
```

---

## Spec Coverage Check

| Spec section | Covered by task |
|---|---|
| Goal struct with category + weeklyTargetHours | Task 1 |
| UserSettings.goals: [Goal], hasAnyGoal, empty | Task 1 |
| Firestore read [Goal] from maps | Task 2 |
| Firestore write [Goal] as maps | Task 2 |
| Migration: old string goals treated as unset | Task 2 (compactMap returns nil for strings) |
| DashboardHeroCard: coverage % + amber bar | Task 3 |
| DashboardHeroCard: 3 goal rows with per-category progress | Task 3 |
| Goal complete: solid bar + checkmark | Task 3 |
| Empty goals state copy | Task 3 |
| Edit button on hero card | Task 3 |
| Monday-anchored week boundary | Task 3 (mondayOfCurrentWeek) |
| GoalsEditorView category pill picker | Task 4 |
| GoalsEditorView hour stepper, default 5h | Task 4 |
| Duplicate category prevention | Task 4 |
| GoalsCardView removed | Task 5 |
| OverviewView wired to DashboardHeroCard | Task 6 |
| WeekReportView receives [String] goal descriptions | Task 6 |
| hasAnyGoal gates week report button | Task 1 (isSet condition matches spec) |
| WeekReportService: no UserSettings.normalized call | Task 7 |
