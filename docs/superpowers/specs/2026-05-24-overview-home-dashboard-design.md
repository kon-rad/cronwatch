# Overview Home Dashboard — Design Spec
**Date:** 2026-05-24

---

## Summary

Redesign the Overview tab into a true dashboard: a quick-glance hero card at the top that answers "how is today going and am I hitting my weekly goals?" followed by the existing analytical depth below the fold. Goals are revised from free-text strings to structured category + weekly hour targets.

---

## 1. Data Model Changes

### Current
```swift
struct UserSettings: Codable {
    var goals: [String]  // e.g. ["Write more", "Get healthier", ""]
}
```

### New
```swift
struct Goal: Codable, Equatable {
    var category: String       // key from Categories.all, e.g. "deep"
    var weeklyTargetHours: Double  // e.g. 20.0
}

struct UserSettings: Codable {
    var goals: [Goal]  // always exactly 3 slots; empty goal = category "" and target 0
}
```

**Migration:** On first load, if existing Firestore data has string goals, treat them as unset (empty state). Do not attempt to parse strings into categories.

**Firestore shape:** Each goal is stored as a map `{ category: "deep", weeklyTargetHours: 20.0 }`. The top-level `goals` field becomes an array of maps.

---

## 2. Goals Editor Redesign (`GoalsEditorView`)

The editor gets a new 3-field structure per goal:

**Each goal row contains:**
- A section header: "GOAL 1", "GOAL 2", "GOAL 3" in muted caption
- A category picker — a horizontal scroll row of tappable pills for all 11 categories, each with its color dot and label. Tapping selects it (highlighted, filled). Currently selected = amber outline or filled with category color.
- A weekly target input — a numeric stepper or inline text field: "X hours per week". Increments of 0.5h. Range 0.5–80h. Displayed as "20h / week".

**Empty state per slot:** Both category and target are unset. The goal row shows a placeholder state ("Choose a category and a target").

**Validation:** A goal is considered "set" only if both category and target are filled. Partial goals (category only, or target only) are shown as incomplete and not counted in dashboard progress. Save is allowed at any time — partial goals are persisted as-is.

**Header copy:** Replace "Three goals you want to make progress on" with: "Choose up to 3 categories to focus on each week. Track your hours against a personal target."

---

## 3. Hero Card (`DashboardHeroCard`)

A single card, always pinned at the top of the Overview scroll, visible before any scrolling. White background, `Radius.md` corners, `Palette.border` outline — consistent with all other cards.

### 3a. Today's Coverage (top section)

```
┌─────────────────────────────────────────┐
│  TODAY                                  │
│                                         │
│      67%        ●━━━━━━━━━━━━━━━━━━━━◌  │
│   16h 3m of 24h tracked                 │
└─────────────────────────────────────────┘
```

- **Large percentage** (`font size ~36pt, semibold, monospacedDigit`) — today's coverage, computed as `coveredMinutes(todayEntries, 0:00–23:59) / 1440 * 100`, rounded to nearest integer.
- **Subtitle** in muted caption: "Xh Ym of 24h tracked"
- **Progress element:** A thin horizontal capsule bar spanning full card width below the number, fills left-to-right in `Palette.amber` as coverage increases. At 100%, bar fills solid amber and a small `checkmark.circle.fill` icon appears inline.
- No period switcher. This section is always *today*.

### 3b. Divider

A single `Palette.border` hairline divider between the coverage section and the goals section.

### 3c. Goal Progress Rows (bottom section)

Three rows, one per goal. Each row:

```
● Deep Work    ████████░░░░░░  8h 20m / 20h
● Exercise     ███░░░░░░░░░░░  1h 10m /  5h
● Sleep        ████████████░░  38h 0m / 49h
```

**Per row elements (left to right):**
1. `CategoryDotView(category:)` — the category color dot (existing component)
2. Category label (`cwBody`, `Palette.ink`, fixed width ~90pt left-aligned)
3. Progress bar — fills in the category's own color (`Categories.color(for:)`), tracks from 0 to target. Capped visually at 100% (no overflow). Bar height: 6pt, same as existing BarRow.
4. Time logged / target (`cwCaption`, `Palette.muted`, right-aligned, monospaced) — format: "8h 20m / 20h"

**When a goal is hit (≥ 100%):**
- Bar fills solid, category color
- Time label turns `Palette.ink` (not muted)
- A small `checkmark` SF Symbol appears to the right of the time label in the category color

**Progress computation:**
- `hoursLogged` = total minutes for this category in entries that fall within the current calendar week (Mon 00:00 – Sun 23:59), divided by 60.
- Calendar week = Monday-anchored, matching `Calendar.current` week with `.firstWeekday = 2` (or handle system locale — see note below).
- **Week boundary note:** Use `Calendar.current.dateInterval(of: .weekOfYear, for: Date())` with `firstWeekday = 2` forced, or compute Mon as `startOfDay(for: mostRecentMonday(from: Date()))`. Do not rely on system locale's week start.

**Empty state (no goals set):**
The goals section shows:
```
  No goals set
  Tap "Edit" to set your 3 weekly targets →
```
Muted body text, no bars, no rows. Same edit button in card top-right.

**Edit affordance:** A small "Edit" button (`cwCaption.weight(.semibold)`, `Palette.amber`) in the top-right corner of the entire card, same as the existing GoalsCardView.

---

## 4. Below-the-Fold Depth Sections

The sections below the hero card remain largely as-is. Order from top to bottom:

### 4a. "Overview" section header
Keep the existing `Text("Overview")` title and subtitle "How you've been spending your time."

### 4b. Donut Card (existing, unchanged)
Category breakdown with period tabs (Today / This Week / This Month / All Time). Shows total tracked time, # of categories, top category. No changes needed.

### 4c. Weekly Daily Average Bars (existing, unchanged)
"THIS WEEK · DAILY AVERAGE" with per-category bar rows. Keep as-is.

### 4d. Tracking Streak Card (existing, unchanged)
21-day window of squares. Week report button at streak ≥ 7 + goals set. Keep as-is. Note: with goals now being structured (category + target), the `weekReportEligible` check uses `settings.hasAnyGoal` — update `hasAnyGoal` to return `true` when at least one Goal has a non-empty category and target > 0.

### 4e. Monthly Heatmap (existing, unchanged)
`MonthlyHeatmapView`. Keep as-is.

### 4f. Personal Bests (existing, unchanged)
`PersonalBestsView` with 90-day window for work, exercise, sleep. Keep as-is.

---

## 5. `UserSettings` Helpers to Update

```swift
var hasAnyGoal: Bool {
    goals.contains { !$0.category.isEmpty && $0.weeklyTargetHours > 0 }
}
```

Remove `static func normalized(_ goals: [String])`. Replace with:

```swift
static let empty = UserSettings(goals: [
    Goal(category: "", weeklyTargetHours: 0),
    Goal(category: "", weeklyTargetHours: 0),
    Goal(category: "", weeklyTargetHours: 0)
])
```

---

## 6. `UserSettingsService` Changes

`saveGoals(uid:goals:)` currently accepts `[String]`. Update signature to accept `[Goal]`. The Firestore encoding/decoding uses `Codable` — confirm that the `Goal` struct encodes correctly to a Firestore-compatible map (it should via `Firestore.Encoder`).

---

## 7. View Hierarchy Summary

```
OverviewView (ScrollView)
  └── DashboardHeroCard              ← NEW (replaces GoalsCardView)
        ├── CoverageSection          ← NEW
        └── GoalProgressSection      ← NEW
  └── "Overview" title + subtitle    ← existing
  └── DonutCard                      ← existing
  └── PeriodTabs                     ← existing
  └── "THIS WEEK · DAILY AVERAGE"    ← existing
  └── BarList                        ← existing
  └── StreakCard                     ← existing
  └── MonthlyHeatmapView             ← existing
  └── PersonalBestsView              ← existing
```

---

## 8. Edge Cases

| Case | Behaviour |
|------|-----------|
| Goal category not set | Row not shown (goal treated as empty) |
| Goal target = 0 | Row not shown |
| Two goals set, one empty | Show 2 rows only |
| All goals empty | Show empty-state copy, no bars |
| Coverage = 0% (nothing tracked today) | Show "0%" with empty bar — honest |
| Coverage = 100% | Bar fills amber, checkmark icon appears |
| Week resets (Monday) | Progress bars reset to 0 automatically (week boundary computation) |
| Entry spans Sunday→Monday midnight | Count only the Monday portion toward the new week |

---

## 9. What Is Not Changing

- The `Entry` model — no changes
- Category definitions in `Categories.swift` — no changes
- The donut, heatmap, streak, personal bests views — no changes
- The AI week report flow — no changes (it still uses `settings.goals` for the prompt, now passes the goal category labels as the goal text)

---

## 10. Week Report Goal Text

The `WeekReportService` currently passes `goals: [String]` to the AI prompt. Update the call site to map structured goals to readable strings:

```swift
let goalDescriptions = settings.goals
    .filter { !$0.category.isEmpty && $0.weeklyTargetHours > 0 }
    .map { "\(Categories.label(for: $0.category)): \($0.weeklyTargetHours)h/week" }
```

Pass `goalDescriptions` as the `goals` parameter to `WeekReportService.generate(...)`.
