# Onboarding Flow Design

**Date:** 2026-05-29
**Status:** Approved

## Overview

A 6-screen onboarding flow shown to new users immediately after sign-in. Collects personal context (goals, work type, vision) to populate their profile and seed their first weekly time goals. A developer flag allows the flow to be re-triggered in development without clearing Firestore.

## Screens

### Screen 1 — Welcome
**Headline:** "Cronwatch helps you track your time so you can own it."
**Subtext:** "Answer a few questions to get started."
**Action:** Button — "Let's go"
**Data saved:** none

---

### Screen 2 — What do you want to get better at?
**Headline:** "What do you want to get better at?"
**Subtext:** "In one sentence — what matters most to you right now?"
**Input:** Single-line free text field
**Data saved:** `UserSettings.wantsToBeBetterAt: String` → `users/{uid}/settings`

---

### Screen 3 — What kind of work do you do?
**Headline:** "What kind of work do you do?"
**Subtext:** "This helps Cronwatch understand your time better."
**Input:** Single-line free text field
**Data saved:** `UserSettings.workType: String` → `users/{uid}/settings`

---

### Screen 4 — Your vision
**Headline:** "Where are you headed?"
**Subtext:** "These are for you — a reminder of the bigger picture."
**Inputs:** Three labeled text fields:
- "In 3 years, I want to be..."
- "In 5 years, I want to be..."
- "In 10 years, I want to be..."

**Data saved:**
- `UserSettings.vision3Years: String` → `users/{uid}/settings`
- `UserSettings.vision5Years: String` → `users/{uid}/settings`
- `UserSettings.vision10Years: String` → `users/{uid}/settings`

---

### Screen 5 — Set your weekly goals
**Headline:** "Set your weekly time goals."
**Subtext:** "Choose up to 3 categories and how many hours per week you want to spend on each."
**UI:** Reuse the existing goal editor component (category dropdown + hours input × 3), same as the home screen goals editor.
**Data saved:** `UserSettings.goals: [Goal]` → `users/{uid}/settings` (existing field, no model change)

---

### Screen 6 — All set
**Headline:** "You're ready."
**Subtext:** "Start tracking your time — your goals and vision are saved."
**Action:** Button — "Start tracking"
**Data saved:** `UserSettings.onboardingCompleted = true` → `users/{uid}/settings`
**Effect:** Transitions user to `MainTabView`

---

## Data Model Changes

All new fields added to the existing `UserSettings` struct and saved to the same Firestore document at `users/{uid}/settings`.

| Field | Swift Type | Default | Source |
|---|---|---|---|
| `wantsToBeBetterAt` | `String` | `""` | Screen 2 |
| `workType` | `String` | `""` | Screen 3 |
| `vision3Years` | `String` | `""` | Screen 4 |
| `vision5Years` | `String` | `""` | Screen 4 |
| `vision10Years` | `String` | `""` | Screen 4 |
| `onboardingCompleted` | `Bool` | `false` | Screen 6 |

Goals are written to the existing `goals: [Goal]` array — no model change needed.

## Developer Flag

New file `FeatureFlags.swift`:

```swift
enum FeatureFlags {
    static let showOnboardingInDev: Bool = true  // set false before shipping
}
```

## Routing Logic

`RootView` routing (updated):

| State | View shown |
|---|---|
| Not authenticated | `SignInView` |
| Authenticated + `FeatureFlags.showOnboardingInDev == true` | `OnboardingFlow` |
| Authenticated + `onboardingCompleted == false` | `OnboardingFlow` |
| Authenticated + `onboardingCompleted == true` | `MainTabView` |

The dev flag takes precedence over `onboardingCompleted`, so the flow is always reachable during development without modifying Firestore.

## Navigation

- Each screen has a **Continue** button (disabled until the required field(s) are non-empty, except Screen 1 and Screen 6).
- Screen 5 (goals) requires at least 1 of 3 goals to be set before Continue is enabled — matching the existing `UserSettings.hasAnyGoal` property.
- No back navigation on Screen 1. Back navigation allowed on Screens 2–5.
- Data is saved to Firestore on **each screen's Continue tap** (not batched at the end), so partial progress is preserved if the user exits mid-flow.

## Files to Create / Modify

| File | Change |
|---|---|
| `FeatureFlags.swift` | New — dev flag |
| `Models/UserSettings.swift` | Add 6 new fields with defaults |
| `Services/UserSettingsService.swift` | No change needed (already writes the full UserSettings doc) |
| `Views/Onboarding/OnboardingFlow.swift` | New — top-level coordinator, manages current step |
| `Views/Onboarding/OnboardingWelcomeView.swift` | New — Screen 1 |
| `Views/Onboarding/OnboardingBetterAtView.swift` | New — Screen 2 |
| `Views/Onboarding/OnboardingWorkTypeView.swift` | New — Screen 3 |
| `Views/Onboarding/OnboardingVisionView.swift` | New — Screen 4 |
| `Views/Onboarding/OnboardingGoalsView.swift` | New — Screen 5, reuses goal editor |
| `Views/Onboarding/OnboardingCompleteView.swift` | New — Screen 6 |
| `Views/RootView.swift` | Add onboarding routing condition |
