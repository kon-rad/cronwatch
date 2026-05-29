# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 6-screen onboarding flow that collects user context (what they want to improve, work type, 3/5/10-year vision, and 3 weekly time goals), saves it to Firestore, and is always shown in dev via a feature flag.

**Architecture:** `RootView` gains a settings subscription that loads `UserSettings.onboardingCompleted` before routing; authenticated users are sent to `OnboardingFlow` (6 step views managed by a step counter) until onboarding is complete. All data writes use `UserSettingsService.saveFields(uid:_:)` with `merge: true` so partial progress is preserved on early exit.

**Tech Stack:** SwiftUI, Firebase Firestore, existing `UserSettingsService` / `AuthService` / theme tokens (`Palette`, `Spacing`, `Radius`, `Font.cwBody` etc.)

---

## Build Command (use after each task)

```bash
xcodebuild -scheme Cronwatch \
  -project /Users/konradgnat/dev/startups/cronwatch/ios-swift/Cronwatch.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -20
```

Expected: `BUILD SUCCEEDED` with no `error:` lines.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Cronwatch/Models/UserSettings.swift` | Modify | Add 6 new fields + update `empty` |
| `Cronwatch/Services/UserSettingsService.swift` | Modify | Decode new fields; add `saveFields` + `setOnboardingCompleted` |
| `Cronwatch/FeatureFlags.swift` | Create | `showOnboardingInDev` constant |
| `Cronwatch/Views/Onboarding/OnboardingFlow.swift` | Create | Step coordinator, state holder, save logic |
| `Cronwatch/Views/Onboarding/OnboardingStepLayout.swift` | Create | Shared scaffold (headline / subtext / content / continue button) |
| `Cronwatch/Views/Onboarding/OnboardingWelcomeView.swift` | Create | Screen 1 — welcome |
| `Cronwatch/Views/Onboarding/OnboardingBetterAtView.swift` | Create | Screen 2 — "what do you want to get better at?" |
| `Cronwatch/Views/Onboarding/OnboardingWorkTypeView.swift` | Create | Screen 3 — "what kind of work do you do?" |
| `Cronwatch/Views/Onboarding/OnboardingVisionView.swift` | Create | Screen 4 — 3/5/10-year vision |
| `Cronwatch/Views/Onboarding/OnboardingGoalsView.swift` | Create | Screen 5 — weekly goals (replicates goal editor UI) |
| `Cronwatch/Views/Onboarding/OnboardingCompleteView.swift` | Create | Screen 6 — "You're ready" |
| `Cronwatch/Views/RootView.swift` | Modify | Subscribe to settings; route to onboarding |
| `CronwatchTests/UserSettingsTests.swift` | Create | Unit tests for model defaults |

---

## Task 1: Extend UserSettings model

**Files:**
- Modify: `ios-swift/Cronwatch/Models/UserSettings.swift`
- Create: `ios-swift/CronwatchTests/UserSettingsTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ios-swift/CronwatchTests/UserSettingsTests.swift`:

```swift
import XCTest
@testable import Cronwatch

final class UserSettingsTests: XCTestCase {

    func test_empty_hasDefaultProfileFields() {
        let s = UserSettings.empty
        XCTAssertEqual(s.wantsToBeBetterAt, "")
        XCTAssertEqual(s.workType, "")
        XCTAssertEqual(s.vision3Years, "")
        XCTAssertEqual(s.vision5Years, "")
        XCTAssertEqual(s.vision10Years, "")
        XCTAssertFalse(s.onboardingCompleted)
    }

    func test_hasAnyGoal_falseWhenAllEmpty() {
        XCTAssertFalse(UserSettings.empty.hasAnyGoal)
    }

    func test_hasAnyGoal_trueWhenOneGoalSet() {
        var s = UserSettings.empty
        s.goals[0] = Goal(category: "work", weeklyTargetHours: 10)
        XCTAssertTrue(s.hasAnyGoal)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -scheme Cronwatch \
  -project /Users/konradgnat/dev/startups/cronwatch/ios-swift/Cronwatch.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|PASSED|test_" | tail -20
```

Expected: compile error — `wantsToBeBetterAt` not found.

- [ ] **Step 3: Update UserSettings.swift**

Replace the entire file content:

```swift
import Foundation

struct Goal: Codable, Equatable {
    var category: String
    var weeklyTargetHours: Double

    var isSet: Bool { !category.isEmpty && weeklyTargetHours > 0 }
}

struct UserSettings: Codable, Equatable {
    var goals: [Goal]
    var wantsToBeBetterAt: String
    var workType: String
    var vision3Years: String
    var vision5Years: String
    var vision10Years: String
    var onboardingCompleted: Bool

    static let empty = UserSettings(
        goals: [
            Goal(category: "", weeklyTargetHours: 0),
            Goal(category: "", weeklyTargetHours: 0),
            Goal(category: "", weeklyTargetHours: 0),
        ],
        wantsToBeBetterAt: "",
        workType: "",
        vision3Years: "",
        vision5Years: "",
        vision10Years: "",
        onboardingCompleted: false
    )

    var hasAnyGoal: Bool {
        goals.contains { $0.isSet }
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
xcodebuild test -scheme Cronwatch \
  -project /Users/konradgnat/dev/startups/cronwatch/ios-swift/Cronwatch.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|PASSED|test_" | tail -20
```

Expected: `test_empty_hasDefaultProfileFields` PASSED, `test_hasAnyGoal_*` PASSED.

- [ ] **Step 5: Commit**

```bash
git add ios-swift/Cronwatch/Models/UserSettings.swift \
        ios-swift/CronwatchTests/UserSettingsTests.swift
git commit -m "feat(model): extend UserSettings with profile and onboarding fields"
```

---

## Task 2: Update UserSettingsService

**Files:**
- Modify: `ios-swift/Cronwatch/Services/UserSettingsService.swift`

- [ ] **Step 1: Replace the file with the updated service**

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
            let data = snapshot?.data() ?? [:]

            let raw = (data["goals"] as? [[String: Any]]) ?? []
            var goals: [Goal] = raw.compactMap { map in
                guard let category = map["category"] as? String,
                      let target = map["weeklyTargetHours"] as? Double else { return nil }
                return Goal(category: category, weeklyTargetHours: target)
            }
            while goals.count < 3 {
                goals.append(Goal(category: "", weeklyTargetHours: 0))
            }

            onChange(UserSettings(
                goals: Array(goals.prefix(3)),
                wantsToBeBetterAt: data["wantsToBeBetterAt"] as? String ?? "",
                workType:          data["workType"]          as? String ?? "",
                vision3Years:      data["vision3Years"]      as? String ?? "",
                vision5Years:      data["vision5Years"]      as? String ?? "",
                vision10Years:     data["vision10Years"]     as? String ?? "",
                onboardingCompleted: data["onboardingCompleted"] as? Bool ?? false
            ))
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

    func saveFields(uid: String, _ fields: [String: Any]) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw UserSettingsServiceError.firebaseNotConfigured
        }
        try await userDoc(uid: uid).setData(fields, merge: true)
    }

    func setOnboardingCompleted(uid: String) async throws {
        try await saveFields(uid: uid, ["onboardingCompleted": true])
    }

    private func userDoc(uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Services/UserSettingsService.swift
git commit -m "feat(service): decode profile fields in subscribe; add saveFields + setOnboardingCompleted"
```

---

## Task 3: Add FeatureFlags

**Files:**
- Create: `ios-swift/Cronwatch/FeatureFlags.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

enum FeatureFlags {
    // Set to false before shipping to production.
    static let showOnboardingInDev: Bool = true
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/FeatureFlags.swift
git commit -m "feat: add FeatureFlags with showOnboardingInDev dev toggle"
```

---

## Task 4: Create OnboardingStepLayout

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingStepLayout.swift`

This shared container is used by screens 2–5. It provides the back button, headline, subtext, arbitrary content, and a bottom Continue button.

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p /Users/konradgnat/dev/startups/cronwatch/ios-swift/Cronwatch/Views/Onboarding
```

Then create `ios-swift/Cronwatch/Views/Onboarding/OnboardingStepLayout.swift`:

```swift
import SwiftUI

struct OnboardingStepLayout<Content: View>: View {
    let headline: String
    let subtext: String
    let continueLabel: String
    let canContinue: Bool
    let onBack: (() -> Void)?
    let onContinue: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        headline: String,
        subtext: String,
        continueLabel: String = "Continue",
        canContinue: Bool = true,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headline = headline
        self.subtext = subtext
        self.continueLabel = continueLabel
        self.canContinue = canContinue
        self.onBack = onBack
        self.onContinue = onContinue
        self.content = content
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.bottom, Spacing.lg)
                } else {
                    Spacer().frame(height: Spacing.lg + 28)
                }

                Text(headline)
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, Spacing.sm)

                Text(subtext)
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.xl)

                content()

                Spacer()

                Button(action: onContinue) {
                    Text(continueLabel)
                        .font(.cwBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canContinue ? Palette.amber : Palette.border)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(!canContinue)
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingStepLayout.swift
git commit -m "feat(onboarding): add shared OnboardingStepLayout scaffold"
```

---

## Task 5: Create OnboardingWelcomeView (Screen 1)

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingWelcomeView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("Cronwatch helps you track your time so you can own it.")
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.md)

                Text("Answer a few questions to get started.")
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(action: onNext) {
                    Text("Let's go")
                        .font(.cwBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Palette.amber)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingWelcomeView.swift
git commit -m "feat(onboarding): add OnboardingWelcomeView (screen 1)"
```

---

## Task 6: Create OnboardingBetterAtView (Screen 2)

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingBetterAtView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct OnboardingBetterAtView: View {
    @Binding var value: String
    let onBack: () -> Void
    let onNext: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            headline: "What do you want to get better at?",
            subtext: "In one sentence — what matters most to you right now.",
            canContinue: !value.trimmingCharacters(in: .whitespaces).isEmpty,
            onBack: onBack,
            onContinue: onNext
        ) {
            TextField("e.g. Being more intentional with my time", text: $value)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(focused ? Palette.amber : Palette.border, lineWidth: 1)
                )
                .focused($focused)
                .submitLabel(.done)
                .onAppear { focused = true }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingBetterAtView.swift
git commit -m "feat(onboarding): add OnboardingBetterAtView (screen 2)"
```

---

## Task 7: Create OnboardingWorkTypeView (Screen 3)

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingWorkTypeView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct OnboardingWorkTypeView: View {
    @Binding var value: String
    let onBack: () -> Void
    let onNext: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(
            headline: "What kind of work do you do?",
            subtext: "This helps Cronwatch understand your time better.",
            canContinue: !value.trimmingCharacters(in: .whitespaces).isEmpty,
            onBack: onBack,
            onContinue: onNext
        ) {
            TextField("e.g. Software engineer, freelance designer…", text: $value)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(focused ? Palette.amber : Palette.border, lineWidth: 1)
                )
                .focused($focused)
                .submitLabel(.done)
                .onAppear { focused = true }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingWorkTypeView.swift
git commit -m "feat(onboarding): add OnboardingWorkTypeView (screen 3)"
```

---

## Task 8: Create OnboardingVisionView (Screen 4)

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingVisionView.swift`

- [ ] **Step 1: Create the file**

Screen 4 has three labeled text fields. Continue is always enabled (all three fields are optional — the user may not have answers yet).

```swift
import SwiftUI

struct OnboardingVisionView: View {
    @Binding var years3: String
    @Binding var years5: String
    @Binding var years10: String
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnboardingStepLayout(
            headline: "Where are you headed?",
            subtext: "These are for you — a reminder of the bigger picture.",
            canContinue: true,
            onBack: onBack,
            onContinue: onNext
        ) {
            VStack(spacing: Spacing.md) {
                visionField(label: "In 3 years, I want to be…", value: $years3)
                visionField(label: "In 5 years, I want to be…", value: $years5)
                visionField(label: "In 10 years, I want to be…", value: $years10)
            }
        }
    }

    private func visionField(label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
            TextField("", text: value)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.border, lineWidth: 1)
                )
                .submitLabel(.next)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingVisionView.swift
git commit -m "feat(onboarding): add OnboardingVisionView (screen 4)"
```

---

## Task 9: Create OnboardingGoalsView (Screen 5)

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingGoalsView.swift`

Replicates the goal editor UI from `GoalsEditorView` (category chips + hours input × 3), inside the onboarding `OnboardingStepLayout`. Continue is enabled when `hasAnyGoal` is true.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct OnboardingGoalsView: View {
    @Binding var goals: [Goal]
    let onBack: () -> Void
    let onNext: () -> Void

    private var hasAnyGoal: Bool { goals.contains { $0.isSet } }

    var body: some View {
        OnboardingStepLayout(
            headline: "Set your weekly time goals.",
            subtext: "Choose up to 3 categories and how many hours per week you want to spend on each.",
            canContinue: hasAnyGoal,
            onBack: onBack,
            onContinue: onNext
        ) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    goalSlot(index: index)
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
            TextField("", value: Binding(
                get: { goals[index].weeklyTargetHours },
                set: { goals[index].weeklyTargetHours = max(0.5, min(80, $0)) }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.cwBody.weight(.semibold))
            .monospacedDigit()
            .frame(width: 52)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.bg)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            Text("hours / week")
                .font(.cwBody)
                .foregroundStyle(Palette.muted)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingGoalsView.swift
git commit -m "feat(onboarding): add OnboardingGoalsView with category picker (screen 5)"
```

---

## Task 10: Create OnboardingCompleteView (Screen 6)

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingCompleteView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct OnboardingCompleteView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("You're ready.")
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, Spacing.md)

                Text("Start tracking your time — your goals and vision are saved.")
                    .font(.cwBody)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(action: onDone) {
                    Text("Start tracking")
                        .font(.cwBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Palette.amber)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingCompleteView.swift
git commit -m "feat(onboarding): add OnboardingCompleteView (screen 6)"
```

---

## Task 11: Create OnboardingFlow coordinator

**Files:**
- Create: `ios-swift/Cronwatch/Views/Onboarding/OnboardingFlow.swift`

The coordinator holds all collected state, manages the current step index, and performs Firestore saves on each Continue tap.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct OnboardingFlow: View {
    let uid: String
    let onComplete: () -> Void

    @State private var step = 0
    @State private var wantsToBeBetterAt = ""
    @State private var workType = ""
    @State private var vision3Years = ""
    @State private var vision5Years = ""
    @State private var vision10Years = ""
    @State private var goals: [Goal] = [
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
    ]

    var body: some View {
        ZStack {
            switch step {
            case 0:
                OnboardingWelcomeView(onNext: { step = 1 })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 1:
                OnboardingBetterAtView(
                    value: $wantsToBeBetterAt,
                    onBack: { step = 0 },
                    onNext: { saveAndAdvance(from: 1) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 2:
                OnboardingWorkTypeView(
                    value: $workType,
                    onBack: { step = 1 },
                    onNext: { saveAndAdvance(from: 2) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 3:
                OnboardingVisionView(
                    years3: $vision3Years,
                    years5: $vision5Years,
                    years10: $vision10Years,
                    onBack: { step = 2 },
                    onNext: { saveAndAdvance(from: 3) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 4:
                OnboardingGoalsView(
                    goals: $goals,
                    onBack: { step = 3 },
                    onNext: { saveAndAdvance(from: 4) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 5:
                OnboardingCompleteView(onDone: complete)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Save + advance

    private func saveAndAdvance(from currentStep: Int) {
        Task {
            do {
                switch currentStep {
                case 1:
                    try await UserSettingsService.shared.saveFields(
                        uid: uid,
                        ["wantsToBeBetterAt": wantsToBeBetterAt]
                    )
                case 2:
                    try await UserSettingsService.shared.saveFields(
                        uid: uid,
                        ["workType": workType]
                    )
                case 3:
                    try await UserSettingsService.shared.saveFields(uid: uid, [
                        "vision3Years":  vision3Years,
                        "vision5Years":  vision5Years,
                        "vision10Years": vision10Years,
                    ])
                case 4:
                    try await UserSettingsService.shared.saveGoals(uid: uid, goals: goals)
                default:
                    break
                }
            } catch {
                // Save failure is non-critical; continue so the user isn't blocked.
            }
            step = currentStep + 1
        }
    }

    // MARK: - Complete

    private func complete() {
        Task {
            try? await UserSettingsService.shared.setOnboardingCompleted(uid: uid)
            onComplete()
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/Onboarding/OnboardingFlow.swift
git commit -m "feat(onboarding): add OnboardingFlow coordinator with step management and Firestore saves"
```

---

## Task 12: Update RootView

**Files:**
- Modify: `ios-swift/Cronwatch/Views/RootView.swift`

`RootView` needs to subscribe to `UserSettings` and add onboarding routing. The new logic: while settings are loading show the existing loading background; once loaded, check `FeatureFlags.showOnboardingInDev || !userSettings.onboardingCompleted`. The `hasCompletedOnboarding` flag ensures that after finishing onboarding in dev mode (where the flag is always `true`), the app transitions to `MainTabView` without requiring a Firestore round-trip.

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    @State private var userSettings: UserSettings = .empty
    @State private var settingsReady = false
    @State private var settingsUnsubscribe: (() -> Void)?
    @State private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if !auth.isReady || (auth.currentUser != nil && !settingsReady) {
                Palette.bg.ignoresSafeArea()
            } else if auth.currentUser == nil {
                SignInView()
                    .transition(.opacity)
            } else if showOnboarding {
                OnboardingFlow(
                    uid: auth.currentUser!.uid,
                    onComplete: { hasCompletedOnboarding = true }
                )
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.currentUser?.uid)
        .animation(.easeInOut(duration: 0.2), value: auth.isReady)
        .animation(.easeInOut(duration: 0.2), value: settingsReady)
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
        .onAppear { subscribeToSettings() }
        .onDisappear {
            settingsUnsubscribe?()
            settingsUnsubscribe = nil
        }
        .onChange(of: auth.currentUser?.uid) { _, _ in
            hasCompletedOnboarding = false
            subscribeToSettings()
        }
    }

    private var showOnboarding: Bool {
        guard !hasCompletedOnboarding else { return false }
        return FeatureFlags.showOnboardingInDev || !userSettings.onboardingCompleted
    }

    private func subscribeToSettings() {
        settingsUnsubscribe?()
        settingsUnsubscribe = nil
        settingsReady = false

        guard let uid = auth.currentUser?.uid else {
            userSettings = .empty
            settingsReady = true
            return
        }

        var receivedFirst = false
        settingsUnsubscribe = UserSettingsService.shared.subscribe(uid: uid) { settings in
            self.userSettings = settings
            if !receivedFirst {
                receivedFirst = true
                self.settingsReady = true
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run the build command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add ios-swift/Cronwatch/Views/RootView.swift
git commit -m "feat(routing): wire OnboardingFlow into RootView with settings subscription and dev flag"
```

---

## Task 13: Smoke test on simulator

- [ ] **Step 1: Launch app in simulator**

Open Xcode, select an iPhone 16 simulator, and run the Cronwatch scheme.

- [ ] **Step 2: Verify onboarding appears after sign-in**

Sign in with a test account. Confirm `OnboardingWelcomeView` is shown instead of `MainTabView`.

- [ ] **Step 3: Walk through all 6 screens**

- Screen 1: Tap "Let's go"
- Screen 2: Type a sentence, tap Continue. Back button returns to Screen 1.
- Screen 3: Type work type, tap Continue.
- Screen 4: Fill in one or more vision fields (all optional), tap Continue.
- Screen 5: Select a category for at least one goal, set hours. Confirm Continue is disabled until a goal is set.
- Screen 6: Tap "Start tracking". Confirm `MainTabView` appears.

- [ ] **Step 4: Verify Firestore data**

In Firebase Console → Firestore → `users/{uid}` document, confirm these fields are present:
- `wantsToBeBetterAt`
- `workType`
- `vision3Years`, `vision5Years`, `vision10Years`
- `goals` (updated)
- `onboardingCompleted: true`

- [ ] **Step 5: Verify dev flag re-shows onboarding**

Kill app, relaunch. Confirm onboarding appears again (because `FeatureFlags.showOnboardingInDev = true`). Walk to Screen 6 and tap "Start tracking" — confirm `MainTabView` shows without needing to restart.

- [ ] **Step 6: Final commit**

```bash
git add .
git commit -m "feat(onboarding): complete 6-screen onboarding flow with Firestore persistence and dev flag"
```
