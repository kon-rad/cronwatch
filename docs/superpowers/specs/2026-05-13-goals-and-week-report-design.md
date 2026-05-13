# Goals & Personalized Week Report — Design

**Status:** Approved for planning
**Scope:** iOS Swift app (`ios-swift/`) + capture-proxy server (`server/`)
**Date:** 2026-05-13

## Summary

Add a Goals section to the home screen (Overview tab), let users save 3 free-text goals to Firestore, and unlock a "Generate personalized week report" button when their current tracking streak reaches 7 days. The report compares the past 7 days of tracked time against each goal and produces 10 concrete ideas for better time allocation. Report generation flows through the existing Express capture-proxy server, which calls Together AI; iOS does the per-category daily aggregation client-side using the same math the home screen already runs.

## Goals (of this feature)

- Surface user-defined goals on the home screen as the first thing they see.
- Reward 7-day streaks with a tangible payoff (the report).
- Keep stats deterministic (no LLM-computed numbers) while letting an LLM do prose + ideation.
- Reuse the existing server and Together AI integration; no new infra.

## Non-goals

- Per-goal target hours or category mapping (goals are free text).
- Saving / browsing past reports (regenerable, no history).
- Goal editing on individual rows (always edit all 3 at once via modal).
- Android parity (this spec is iOS-only).
- LLM-computed daily/category breakdowns.

## Data model

### Firestore: `users/{uid}` (new collection)

```
users/{uid}
  goals: [string, string, string]   // exactly 3 elements; empty strings allowed
  goalsUpdatedAt: Timestamp         // server timestamp on each save
```

A missing/empty doc means "no goals yet."

### Firestore rules (`firestore.rules`)

Add a self-only rule:

```
match /users/{uid} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

### Swift model (`ios-swift/Cronwatch/Models/UserSettings.swift`)

```swift
struct UserSettings: Codable {
    var goals: [String]   // always normalized to size 3
}
```

### Swift models (`ios-swift/Cronwatch/Models/WeekReport.swift`)

```swift
struct DayAggregate: Codable {
    let date: String                    // YYYY-MM-DD
    let categories: [CategoryMinutes]
}

struct CategoryMinutes: Codable {
    let name: String
    let minutes: Int
}

struct WeekReport: Codable {
    let goalAnalyses: [GoalAnalysis]    // 1-3 entries, one per non-empty goal
    let ideas: [String]                 // exactly 10
}

struct GoalAnalysis: Codable {
    let goal: String
    let summary: String
}
```

## Services

### `UserSettingsService` (new, `ios-swift/Cronwatch/Services/UserSettingsService.swift`)

Singleton, `@MainActor`, mirroring `EntriesService` patterns:

- `func subscribe(uid: String, onChange: @escaping (UserSettings) -> Void) -> () -> Void`
  - `addSnapshotListener` on `users/{uid}`.
  - Normalizes `goals` to length 3 (pads empties, truncates extras).
  - Returns a cancel closure.
- `func saveGoals(uid: String, goals: [String]) async throws`
  - Single `setData(["goals": goals, "goalsUpdatedAt": FieldValue.serverTimestamp()], merge: true)`.

### `WeekReportService` (new, `ios-swift/Cronwatch/Services/WeekReportService.swift`)

- `func generate(uid: String, goals: [String], days: [DayAggregate]) async throws -> WeekReport`
- POSTs to `{SERVER_BASE_URL}/week-report` (read base URL from the same `AppEnvironment` source the existing capture flow uses).
- Sets `Authorization: Bearer <firebaseIdToken>` from `AuthService.shared.idToken()`.

### `WeekReportAggregator` (new, `ios-swift/Cronwatch/Utils/WeekReportAggregator.swift`)

Pure function:

```swift
static func aggregate(entries: [Entry], weekEnd: Date, now: Date = Date())
    -> [DayAggregate]    // length 7, most recent day last
```

For each of the 7 calendar days ending today (locale calendar):
- For each category, sum minutes using the same overlap-clipping math as `Streak.coveredMinutes` (clipped to the day window).
- Returns `[DayAggregate(date: Date, categories: [CategoryMinutes])]`.

## UI

### Goals card on Overview

Placement: top of `OverviewView`'s scroll content, above the existing "Overview" title block.

**Empty state:**

- Card chrome: `Palette.white` fill, `Radius.md`, `Palette.border` stroke (matches `streakCard`).
- Header eyebrow: "MY GOALS" — `.cwCaption`, tracking 1.2, `Palette.muted`.
- Body: "Set your 3 goals to unlock personalized weekly insights."
- Button: "Set your goals" — `Palette.amber` text, plain button style.

**Populated state:**

- Same chrome.
- "MY GOALS" eyebrow on the left; "Edit" amber button on the right of the header row.
- Three numbered rows (`1.`, `2.`, `3.`). Each row shows the goal text in `Palette.ink`.
- Empty slots show muted placeholder: "Goal N — tap Edit to add."

### Goals editor sheet (`GoalsEditorView`)

Presented as `.sheet`.

- Nav bar: title "My Goals", Cancel (left), Save (right).
- Three text fields, labeled "Goal 1", "Goal 2", "Goal 3", single-line, 100-char max.
- Pre-filled with current goals.
- Save button:
  - Disabled while a save is in flight.
  - On success: dismiss.
  - On error: surface via `ToastCenter`, leave sheet open.
- Cancel discards changes and dismisses.

### Streak card — add report button

Inside the existing `streakCard` in `OverviewView`, below the row of streak day-blocks:

```
┌──────────────────────────────────────┐
│  9 days                last 21 days  │
│  ████░░██████████████████████        │
│                                      │
│  [ ✨ Generate week report      › ]  │   ← only when streak ≥ 7
└──────────────────────────────────────┘
```

- Visibility: `Streak.currentStreak(from: dayFlags) >= 7`.
- Style: full-width filled button, `Palette.amber` background, white text, sparkles SF Symbol leading + chevron trailing.
- Disabled for 10s after a successful generation (prevents double-tap regen storms).

### Week report sheet (`WeekReportView`)

Presented as `.sheet` from the home screen.

- Header: "Week of {MMM d} – {MMM d}", close (X) button top-right.
- Initial state: centered spinner + "Generating your weekly report…".
- Network call kicked off in `.task { }`.
- Loaded state:
  - Up to 3 goal cards (skip ones with empty goal strings). Each: bold goal text, then summary paragraph.
  - Section eyebrow: "10 IDEAS TO BETTER USE YOUR TIME".
  - Numbered list 1–10, one idea per line.
  - Small "Regenerate" button at the bottom.
- Error state: short message + "Try again" button; tapping it re-runs `.task`.

## Server

### New endpoint (`server/src/weekReport.ts`)

POST `/week-report`:

- Auth: bearer Firebase ID token, verified via firebase-admin (existing pattern).
- Request (zod-validated):
  ```ts
  {
    goals: [string, string, string],           // strings, may be empty
    weekStart: string,                          // ISO date
    weekEnd: string,                            // ISO date
    days: Array<{
      date: string,                             // YYYY-MM-DD
      categories: Array<{ name: string, minutes: number }>
    }>                                          // length 7
  }
  ```
- Calls Together AI via the existing `together-ai` client wrapper (see `server/src/together.ts`). Reuse whichever model identifier the capture-structuring flow currently uses (looked up at implementation time) so this feature inherits the same model, billing, and limits. Request JSON-formatted response.
- Response:
  ```ts
  {
    goalAnalyses: Array<{ goal: string, summary: string }>,  // 1-3, one per non-empty goal
    ideas: string[]                                          // exactly 10
  }
  ```
- Errors → 4xx with `{ error: string }`.

### Wire-up

`server/src/index.ts` — mount the new route alongside the capture routes.

### Prompt outline (server-side system prompt)

> You are a productivity coach. The user has these 3 goals: `<goals>`. Their last 7 days of tracked time, in minutes per category per day, is: `<days>`. For each non-empty goal, write 2–3 sentences referencing SPECIFIC numbers from the data and contrasting actual time spent vs. what the goal demands. Then produce EXACTLY 10 concrete, varied, actionable ideas to better align their time with their goals. No platitudes. Respond as strict JSON: `{ "goalAnalyses": [...], "ideas": [...] }`.

## Streak / midnight rollover

`Streak.computeDayFlags(now:)` already uses `Date()` at call time, and `OverviewView` already receives Firestore updates via `addSnapshotListener` whenever entries change. Two additions:

- Subscribe to `NotificationCenter.default.publisher(for: .NSCalendarDayChanged)` in `OverviewView` and bump a `@State var dayTick: Date` so day-boundary recomputation happens for foregrounded views at midnight. Use `dayTick` as an explicit dependency in `dayFlags`, `weeklyRows`, and the donut.
- No change to streak semantics: a full day stays `coveredMinutes >= 24*60`.

## File inventory

**New files:**

- `ios-swift/Cronwatch/Models/UserSettings.swift`
- `ios-swift/Cronwatch/Models/WeekReport.swift`
- `ios-swift/Cronwatch/Services/UserSettingsService.swift`
- `ios-swift/Cronwatch/Services/WeekReportService.swift`
- `ios-swift/Cronwatch/Utils/WeekReportAggregator.swift`
- `ios-swift/Cronwatch/Views/Overview/GoalsCardView.swift`
- `ios-swift/Cronwatch/Views/Overview/GoalsEditorView.swift`
- `ios-swift/Cronwatch/Views/Overview/WeekReportView.swift`
- `server/src/weekReport.ts`

**Modified files:**

- `ios-swift/Cronwatch/Views/Tabs/OverviewView.swift` — Goals card at top, settings subscription, week-report button inside `streakCard`, midnight tick.
- `firestore.rules` — `users/{uid}` self-only rule.
- `server/src/index.ts` — mount `/week-report`.

## Testing notes

- `WeekReportAggregator` is pure — add unit tests covering: entries that span midnight (clipped to day windows), multiple categories per day, days with zero entries.
- `Streak.currentStreak` is already tested by the existing streak UI; no new tests there.
- Manual: verify the editor sheet behaviour offline (toast on save failure), the button visibility transitioning at the 7-day threshold, and that opening the report sheet shows the loading state before content lands.

## Out of scope (explicit YAGNI guards)

- Per-goal category mapping or hours/day targets.
- Saving past reports for browsing.
- Streaming the LLM response to the report sheet.
- Editing one goal at a time.
- Server-side caching of recent reports.
- Android parity.
