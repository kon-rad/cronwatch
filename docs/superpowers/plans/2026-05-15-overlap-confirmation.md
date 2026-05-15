# Confirm-before-replace on overlapping captures — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a user-controlled confirmation gate in front of the silent overlap resolution that `EntriesService.createCaptureEntries` already performs, and change the existing-contains-new case from one-sided trim to two-piece split.

**Architecture:** Pure conflict planning (`buildResolutionPlan`) is split from atomic Firestore commit (`commitResolutionPlan`). The capture queue gains an `awaitingConfirmation` job state with the plan attached; a SwiftUI sheet presents Replace / Discard. The existing toast bridge surfaces a sticky "needs review" prompt and a `ConflictPresenter` drives sheet presentation from the app root.

**Tech Stack:** SwiftUI, FirebaseFirestore, XcodeGen, XCTest.

**Spec:** `docs/superpowers/specs/2026-05-15-overlap-confirmation-design.md`

---

### Task 1: Add an XCTest target via XcodeGen

The Cronwatch xcodeproj currently has no test target. We need one before TDD on the pure conflict logic.

**Files:**
- Modify: `ios-swift/project.yml`
- Create: `ios-swift/CronwatchTests/PlaceholderTests.swift` (sanity test to verify the target builds)

- [ ] **Step 1: Add the test target to project.yml**

Append to `ios-swift/project.yml` under `targets:` (after the `Cronwatch:` target block, same indentation):

```yaml
  CronwatchTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: CronwatchTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.konradgnat.cronwatch.tests
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Cronwatch.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Cronwatch"
    dependencies:
      - target: Cronwatch
```

- [ ] **Step 2: Create the placeholder test file**

Create `ios-swift/CronwatchTests/PlaceholderTests.swift`:

```swift
import XCTest

final class PlaceholderTests: XCTestCase {
    func testTargetBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 3: Regenerate the Xcode project and verify the test target builds**

Run from `ios-swift/`:

```sh
xcodegen generate
xcodebuild test \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CronwatchTests/PlaceholderTests \
  | tail -30
```

Expected: `TEST SUCCEEDED` with `PlaceholderTests.testTargetBuilds` passing.

If the scheme `Cronwatch` doesn't include the test target, open `Cronwatch.xcodeproj`, edit the scheme, add `CronwatchTests` under Test, and re-run.

- [ ] **Step 4: Commit**

```sh
git add ios-swift/project.yml ios-swift/CronwatchTests/PlaceholderTests.swift
git commit -m "test: add CronwatchTests target via XcodeGen"
```

---

### Task 2: Introduce conflict-resolution domain types

These are the value types the plan, the sheet, the queue, and the commit step all share.

**Files:**
- Create: `ios-swift/Cronwatch/Services/ConflictResolution.swift`

- [ ] **Step 1: Write the types file**

Create `ios-swift/Cronwatch/Services/ConflictResolution.swift`:

```swift
import Foundation

struct DateRange: Equatable, Codable {
    let start: Date
    let end: Date
}

enum ConflictAction: Equatable, Codable {
    case delete
    case trim(startTime: Date, endTime: Date)
    case split(left: DateRange, right: DateRange)
}

struct Resolution: Equatable, Codable {
    let entryId: String
    let originalStart: Date
    let originalEnd: Date
    let originalSource: EntrySource
    let category: String
    let note: String
    let transcript: String?
    let audioUrl: String?
    let captureId: String
    let action: ConflictAction
}

struct ResolutionPlan: Equatable, Codable {
    let captureId: String
    let source: EntrySource
    let transcript: String?
    let audioUrl: String?
    let drafts: [CapturedEntryDraft]
    let resolutions: [Resolution]

    var hasConflicts: Bool { !resolutions.isEmpty }
}
```

- [ ] **Step 2: Build the app to confirm the new file compiles**

```sh
cd ios-swift && xcodegen generate && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```sh
git add ios-swift/Cronwatch/Services/ConflictResolution.swift ios-swift/project.yml ios-swift/Cronwatch.xcodeproj
git commit -m "feat: add ConflictResolution domain types"
```

---

### Task 3: Write the failing tests for `buildResolutionPlan`

Pure unit tests covering every conflict case before we implement the function.

**Files:**
- Create: `ios-swift/CronwatchTests/ResolutionPlanTests.swift`

- [ ] **Step 1: Write the test file**

Create `ios-swift/CronwatchTests/ResolutionPlanTests.swift`:

```swift
import XCTest
@testable import Cronwatch

final class ResolutionPlanTests: XCTestCase {

    // MARK: - Helpers

    private func d(_ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 15
        comps.hour = hour
        comps.minute = minute
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func entry(id: String, _ startHour: Int, _ startMin: Int, _ endHour: Int, _ endMin: Int, category: String = "deep") -> Entry {
        Entry(
            id: id,
            captureId: "c_existing_\(id)",
            category: category,
            note: "existing",
            startTime: d(startHour, startMin),
            endTime: d(endHour, endMin),
            source: .voice,
            transcript: nil,
            audioUrl: nil,
            createdAt: d(0)
        )
    }

    private func draft(_ startHour: Int, _ startMin: Int, _ endHour: Int, _ endMin: Int, category: String = "work") -> CapturedEntryDraft {
        CapturedEntryDraft(
            category: category,
            note: "new",
            startTime: d(startHour, startMin),
            endTime: d(endHour, endMin)
        )
    }

    private func plan(existing: [Entry], drafts: [CapturedEntryDraft]) -> ResolutionPlan {
        EntriesService.buildResolutionPlan(
            existing: existing,
            drafts: drafts,
            captureId: "c_new",
            source: .voice,
            transcript: "t",
            audioUrl: nil
        )
    }

    // MARK: - Cases

    func test_noOverlap_returnsEmptyResolutions() {
        let p = plan(existing: [entry(id: "e1", 11, 0, 12, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertTrue(p.resolutions.isEmpty)
    }

    func test_touchingBoundary_isNotOverlap() {
        // Half-open intervals: existing [10, 11), draft [9, 10) -> no overlap.
        let p = plan(existing: [entry(id: "e1", 10, 0, 11, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertTrue(p.resolutions.isEmpty)
    }

    func test_newFullyContainsExisting_deletesExisting() {
        let p = plan(existing: [entry(id: "e1", 10, 0, 11, 0)], drafts: [draft(9, 0, 12, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].entryId, "e1")
        XCTAssertEqual(p.resolutions[0].action, .delete)
    }

    func test_equalRanges_deletesExisting() {
        let p = plan(existing: [entry(id: "e1", 9, 0, 10, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .delete)
    }

    func test_newOverlapsLeftSideOfExisting_trimsLeftAway() {
        // existing 9:30-11, draft 9-10 -> existing becomes 10-11
        let p = plan(existing: [entry(id: "e1", 9, 30, 11, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .trim(startTime: d(10, 0), endTime: d(11, 0)))
    }

    func test_newOverlapsRightSideOfExisting_trimsRightAway() {
        // existing 8-9:30, draft 9-10 -> existing becomes 8-9
        let p = plan(existing: [entry(id: "e1", 8, 0, 9, 30)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .trim(startTime: d(8, 0), endTime: d(9, 0)))
    }

    func test_existingFullyContainsNew_splitsExisting() {
        // existing 9-11, draft 10-10:30 -> existing becomes 9-10 and 10:30-11
        let p = plan(existing: [entry(id: "e1", 9, 0, 11, 0)], drafts: [draft(10, 0, 10, 30)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(
            p.resolutions[0].action,
            .split(
                left: DateRange(start: d(9, 0), end: d(10, 0)),
                right: DateRange(start: d(10, 30), end: d(11, 0))
            )
        )
    }

    func test_resolutionCarriesSourceAndCategoryFromExisting() {
        let e = Entry(
            id: "e1",
            captureId: "c1",
            category: "study",
            note: "n",
            startTime: d(9, 0),
            endTime: d(10, 0),
            source: .text,
            transcript: "old",
            audioUrl: "https://x/y.m4a",
            createdAt: d(0)
        )
        let p = plan(existing: [e], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions[0].originalSource, .text)
        XCTAssertEqual(p.resolutions[0].category, "study")
        XCTAssertEqual(p.resolutions[0].transcript, "old")
        XCTAssertEqual(p.resolutions[0].audioUrl, "https://x/y.m4a")
        XCTAssertEqual(p.resolutions[0].captureId, "c1")
    }

    func test_multipleDrafts_resolveAgainstSingleExisting() {
        // existing 9-12, drafts 9:30-10 and 11-11:30 -> existing splits into
        // 9-9:30, 10-11, 11:30-12 — but we only support 0/1/2 pieces, so the
        // algorithm must produce a defensive single resolution. Verify behavior
        // matches the documented "≤2 pieces" claim: defensive delete.
        // Spec note: drafts within one recording are de-overlapped, but they
        // can both overlap one existing entry in separate spots.
        let p = plan(
            existing: [entry(id: "e1", 9, 0, 12, 0)],
            drafts: [draft(9, 30, 10, 0), draft(11, 0, 11, 30)]
        )
        // Three surviving pieces is impossible from a single recording in
        // practice. Document and assert the defensive .delete fallback.
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .delete)
    }

    func test_multipleExistingEntries_allReceiveResolutions() {
        let p = plan(
            existing: [
                entry(id: "e1", 8, 0, 9, 30),   // partial right overlap
                entry(id: "e2", 10, 0, 11, 0),  // fully contained
            ],
            drafts: [draft(9, 0, 12, 0)]
        )
        XCTAssertEqual(p.resolutions.count, 2)
        let byId = Dictionary(uniqueKeysWithValues: p.resolutions.map { ($0.entryId, $0.action) })
        XCTAssertEqual(byId["e1"], .trim(startTime: d(8, 0), endTime: d(9, 0)))
        XCTAssertEqual(byId["e2"], .delete)
    }

    func test_emptyExisting_returnsEmptyResolutions() {
        let p = plan(existing: [], drafts: [draft(9, 0, 10, 0)])
        XCTAssertTrue(p.resolutions.isEmpty)
        XCTAssertEqual(p.drafts.count, 1)
    }
}
```

- [ ] **Step 2: Run the tests — confirm they fail because `buildResolutionPlan` doesn't exist yet**

```sh
cd ios-swift && xcodebuild test \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CronwatchTests/ResolutionPlanTests \
  | tail -40
```

Expected: build failure with messages like `value of type 'EntriesService.Type' has no member 'buildResolutionPlan'`.

---

### Task 4: Implement `buildResolutionPlan`

Replace the existing private `resolveConflicts` helper with the new pure plan builder. Keep `snapAndDeoverlap` and `fetchConflicts` as-is.

**Files:**
- Modify: `ios-swift/Cronwatch/Services/EntriesService.swift`

- [ ] **Step 1: Add `buildResolutionPlan` to `EntriesService` and delete the old `resolveConflicts` + `Resolution` + `ConflictAction` private types**

In `EntriesService.swift`, delete this block:

```swift
    // MARK: - Conflict resolution

    private enum ConflictAction {
        case delete
        case update(startTime: Date, endTime: Date)
    }

    private struct Resolution {
        let entry: Entry
        let action: ConflictAction
    }
```

…and replace the entire `private nonisolated static func resolveConflicts(...)` function with this `buildResolutionPlan` static (place it in the same "Conflict resolution" section):

```swift
    // MARK: - Conflict resolution

    // Pure: subtract each draft's interval from each existing entry's interval.
    // Surviving pieces decide the resolution per entry:
    //   0 pieces  -> .delete
    //   1 piece   -> .trim (or no-op if unchanged)
    //   2 pieces  -> .split
    //   3+ pieces -> defensive .delete (shouldn't happen with de-overlapped drafts)
    nonisolated static func buildResolutionPlan(
        existing: [Entry],
        drafts: [CapturedEntryDraft],
        captureId: String,
        source: EntrySource,
        transcript: String?,
        audioUrl: String?
    ) -> ResolutionPlan {
        var resolutions: [Resolution] = []
        for entry in existing {
            var pieces: [DateRange] = [DateRange(start: entry.startTime, end: entry.endTime)]
            for draft in drafts {
                pieces = pieces.flatMap { piece -> [DateRange] in
                    if draft.endTime <= piece.start || draft.startTime >= piece.end {
                        return [piece]
                    }
                    var result: [DateRange] = []
                    if piece.start < draft.startTime {
                        result.append(DateRange(start: piece.start, end: draft.startTime))
                    }
                    if draft.endTime < piece.end {
                        result.append(DateRange(start: draft.endTime, end: piece.end))
                    }
                    return result
                }
            }
            let action: ConflictAction
            switch pieces.count {
            case 0:
                action = .delete
            case 1:
                let only = pieces[0]
                if only.start == entry.startTime && only.end == entry.endTime {
                    continue
                }
                action = .trim(startTime: only.start, endTime: only.end)
            case 2:
                action = .split(left: pieces[0], right: pieces[1])
            default:
                action = .delete
            }
            resolutions.append(
                Resolution(
                    entryId: entry.id,
                    originalStart: entry.startTime,
                    originalEnd: entry.endTime,
                    originalSource: entry.source,
                    category: entry.category,
                    note: entry.note,
                    transcript: entry.transcript,
                    audioUrl: entry.audioUrl,
                    captureId: entry.captureId,
                    action: action
                )
            )
        }
        return ResolutionPlan(
            captureId: captureId,
            source: source,
            transcript: transcript,
            audioUrl: audioUrl,
            drafts: drafts,
            resolutions: resolutions
        )
    }
```

- [ ] **Step 2: Update `createCaptureEntries` to consume the new types**

`createCaptureEntries` currently uses the old private `Resolution`/`ConflictAction`. Update its inner loop. Replace:

```swift
        let resolutions = Self.resolveConflicts(existing: filteredConflicts, drafts: snappedDrafts)

        let batch = db.batch()

        for ref in existingDocsForCapture {
            batch.deleteDocument(ref)
        }

        for resolution in resolutions {
            let docRef = collection.document(resolution.entry.id)
            switch resolution.action {
            case .delete:
                batch.deleteDocument(docRef)
            case .update(let newStart, let newEnd):
                batch.updateData(
                    [
                        "startTime": Timestamp(date: newStart),
                        "endTime": Timestamp(date: newEnd),
                    ],
                    forDocument: docRef
                )
            }
        }
```

…with:

```swift
        let plan = Self.buildResolutionPlan(
            existing: filteredConflicts,
            drafts: snappedDrafts,
            captureId: captureId,
            source: source,
            transcript: transcript,
            audioUrl: audioUrl
        )

        let batch = db.batch()

        for ref in existingDocsForCapture {
            batch.deleteDocument(ref)
        }

        Self.applyResolutions(plan.resolutions, in: collection, batch: batch)
```

…and add this new helper near the end of the file (above `// MARK: - Grouping`):

```swift
    nonisolated static func applyResolutions(
        _ resolutions: [Resolution],
        in collection: CollectionReference,
        batch: WriteBatch
    ) {
        for resolution in resolutions {
            let docRef = collection.document(resolution.entryId)
            switch resolution.action {
            case .delete:
                batch.deleteDocument(docRef)
            case .trim(let newStart, let newEnd):
                batch.updateData(
                    [
                        "startTime": Timestamp(date: newStart),
                        "endTime": Timestamp(date: newEnd),
                    ],
                    forDocument: docRef
                )
            case .split(let left, let right):
                batch.deleteDocument(docRef)
                let leftDoc = collection.document()
                let rightDoc = collection.document()
                let baseData: [String: Any] = [
                    "captureId": resolution.captureId,
                    "category": resolution.category,
                    "note": resolution.note,
                    "source": resolution.originalSource.rawValue,
                    "createdAt": FieldValue.serverTimestamp(),
                    "transcript": resolution.transcript ?? NSNull(),
                    "audioUrl": resolution.audioUrl ?? NSNull(),
                ]
                var leftData = baseData
                leftData["startTime"] = Timestamp(date: left.start)
                leftData["endTime"] = Timestamp(date: left.end)
                batch.setData(leftData, forDocument: leftDoc)
                var rightData = baseData
                rightData["startTime"] = Timestamp(date: right.start)
                rightData["endTime"] = Timestamp(date: right.end)
                batch.setData(rightData, forDocument: rightDoc)
            }
        }
    }
```

- [ ] **Step 3: Run the unit tests — they should pass now**

```sh
cd ios-swift && xcodebuild test \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CronwatchTests/ResolutionPlanTests \
  | tail -40
```

Expected: all 12 tests pass.

- [ ] **Step 4: Build the app to confirm the refactored `createCaptureEntries` still compiles**

```sh
cd ios-swift && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```sh
git add ios-swift/CronwatchTests/ResolutionPlanTests.swift ios-swift/Cronwatch/Services/EntriesService.swift ios-swift/Cronwatch.xcodeproj
git commit -m "feat(entries): buildResolutionPlan with split support + unit tests"
```

---

### Task 5: Implement `commitResolutionPlan`

A self-contained Firestore writer that consumes a plan and applies it atomically. Used by both the no-conflict fast path (called by `createCaptureEntries`) and the confirmed-conflict path (called by `CaptureQueue.confirmPlan`).

**Files:**
- Modify: `ios-swift/Cronwatch/Services/EntriesService.swift`

- [ ] **Step 1: Add `commitResolutionPlan` to `EntriesService`**

Add this method in the `// MARK: - Writes` section of `EntriesService`, immediately after `createCaptureEntries`:

```swift
    func commitResolutionPlan(uid: String, plan: ResolutionPlan) async throws -> [Entry] {
        guard !plan.drafts.isEmpty else {
            throw CaptureError.emptyDrafts
        }
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }

        let collection = entriesCollection(uid: uid)
        let db = collection.firestore
        let batch = db.batch()

        Self.applyResolutions(plan.resolutions, in: collection, batch: batch)

        var pending: [Entry] = []
        let createdAt = Date()
        for (index, draft) in plan.drafts.enumerated() {
            let ref = collection.document("\(plan.captureId)__\(index)")
            let data: [String: Any] = [
                "captureId": plan.captureId,
                "category": draft.category,
                "note": draft.note,
                "startTime": Timestamp(date: draft.startTime),
                "endTime": Timestamp(date: draft.endTime),
                "source": plan.source.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "transcript": plan.transcript ?? NSNull(),
                "audioUrl": plan.audioUrl ?? NSNull(),
            ]
            batch.setData(data, forDocument: ref)
            pending.append(
                Entry(
                    id: ref.documentID,
                    captureId: plan.captureId,
                    category: draft.category,
                    note: draft.note,
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    source: plan.source,
                    transcript: plan.transcript,
                    audioUrl: plan.audioUrl,
                    createdAt: createdAt
                )
            )
        }

        try await batch.commit()
        return pending
    }
```

- [ ] **Step 2: Build to confirm it compiles**

```sh
cd ios-swift && xcodegen generate && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```sh
git add ios-swift/Cronwatch/Services/EntriesService.swift
git commit -m "feat(entries): commitResolutionPlan for atomic plan commit"
```

---

### Task 6: Add `.awaitingConfirmation` status and `plan` field on `CaptureJob`

**Files:**
- Modify: `ios-swift/Cronwatch/Services/CaptureQueue.swift`

- [ ] **Step 1: Extend the status enum and job struct**

In `CaptureQueue.swift`, replace:

```swift
enum CaptureJobStatus: String, Equatable, Codable { case queued, running, error }

struct CaptureJob: Identifiable, Equatable, Codable {
    let id: String
    let uid: String
    let audioURL: URL?
    var transcript: String?
    var remoteAudioUrl: String?
    var entryDrafts: [CapturedEntryDraft]?
    var status: CaptureJobStatus
    var error: String?
    let createdAt: Date
}
```

…with:

```swift
enum CaptureJobStatus: String, Equatable, Codable {
    case queued, running, awaitingConfirmation, error
}

struct CaptureJob: Identifiable, Equatable, Codable {
    let id: String
    let uid: String
    let audioURL: URL?
    var transcript: String?
    var remoteAudioUrl: String?
    var entryDrafts: [CapturedEntryDraft]?
    var plan: ResolutionPlan?
    var status: CaptureJobStatus
    var error: String?
    let createdAt: Date
}
```

- [ ] **Step 2: Update both `enqueue` and `enqueueText` constructors to pass `plan: nil`**

Inside `enqueue(uid:audioURL:...)`, in the `let job = CaptureJob(...)` initializer block, add `plan: nil,` immediately after `entryDrafts: entryDrafts,`:

```swift
        let job = CaptureJob(
            id: id,
            uid: uid,
            audioURL: storedURL,
            transcript: transcript,
            remoteAudioUrl: remoteAudioUrl,
            entryDrafts: entryDrafts,
            plan: nil,
            status: initialStatus,
            error: error,
            createdAt: Date()
        )
```

Inside `enqueueText(uid:transcript:)`, same change after `entryDrafts: nil,`:

```swift
        let job = CaptureJob(
            id: id,
            uid: uid,
            audioURL: nil,
            transcript: transcript,
            remoteAudioUrl: nil,
            entryDrafts: nil,
            plan: nil,
            status: .queued,
            error: nil,
            createdAt: Date()
        )
```

- [ ] **Step 3: Build to confirm**

```sh
cd ios-swift && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Expected: `BUILD SUCCEEDED`. (Note: existing persisted job JSON without `plan` will still decode since `plan: ResolutionPlan?` is optional.)

- [ ] **Step 4: Commit**

```sh
git add ios-swift/Cronwatch/Services/CaptureQueue.swift
git commit -m "feat(queue): awaitingConfirmation status + plan on CaptureJob"
```

---

### Task 7: Split `CaptureQueue.processJob` into detect-then-park-or-commit

After the proxy returns drafts, fetch conflicts, build a plan, and either commit immediately (no conflicts) or transition to `awaitingConfirmation` (conflicts present).

**Files:**
- Modify: `ios-swift/Cronwatch/Services/CaptureQueue.swift`
- Modify: `ios-swift/Cronwatch/Services/EntriesService.swift` (expose `fetchConflicts` and `snapAndDeoverlap` at file scope so the queue can call them)

- [ ] **Step 1: Make `snapAndDeoverlap` and `fetchConflicts` callable from outside `EntriesService`**

In `EntriesService.swift`, change the access on these two functions from `private` to `internal` (default — drop the `private` keyword) and keep them `nonisolated static`. Also expose `fetchConflicts` as `async throws` — it already is — and remove `private`:

Find:

```swift
    private nonisolated static func snapAndDeoverlap(_ drafts: [CapturedEntryDraft]) -> [CapturedEntryDraft] {
```

Change to:

```swift
    nonisolated static func snapAndDeoverlap(_ drafts: [CapturedEntryDraft]) -> [CapturedEntryDraft] {
```

Find:

```swift
    private static func fetchConflicts(in collection: CollectionReference,
                                       windowStart: Date,
                                       windowEnd: Date) async throws -> [Entry] {
```

Change to:

```swift
    static func fetchConflicts(in collection: CollectionReference,
                                windowStart: Date,
                                windowEnd: Date) async throws -> [Entry] {
```

Add a small convenience that takes a `uid` (so the queue doesn't need to know about `entriesCollection`):

```swift
    func fetchConflicts(uid: String, windowStart: Date, windowEnd: Date) async throws -> [Entry] {
        guard FirebaseBootstrap.isConfigured else {
            throw EntriesServiceError.firebaseNotConfigured
        }
        let collection = entriesCollection(uid: uid)
        return try await Self.fetchConflicts(in: collection, windowStart: windowStart, windowEnd: windowEnd)
    }
```

- [ ] **Step 2: Add `newCaptureId` as `internal static` so the queue can produce stable capture ids**

In `EntriesService.swift`, find:

```swift
    private static func newCaptureId() -> String {
```

Change to:

```swift
    static func newCaptureId() -> String {
```

- [ ] **Step 3: Replace `processJob`'s commit step with detect-then-decide**

In `CaptureQueue.swift`, replace the final `do { ... } catch { ... }` block of `processJob` (the part that calls `EntriesService.shared.createCaptureEntries(...)`) with detect-build-decide logic. The new tail of `processJob` becomes:

```swift
        let source: EntrySource = job.audioURL != nil ? .voice : .text
        let snapped = EntriesService.snapAndDeoverlap(drafts)
        guard !snapped.isEmpty else {
            return .partial(
                transcript: transcript,
                remoteAudioUrl: remoteAudioUrl,
                entryDrafts: entryDrafts,
                error: "Empty draft."
            )
        }
        let windowStart = snapped.map(\.startTime).min() ?? Date()
        let windowEnd = snapped.map(\.endTime).max() ?? windowStart

        let existing: [Entry]
        do {
            existing = try await EntriesService.shared.fetchConflicts(
                uid: job.uid,
                windowStart: windowStart,
                windowEnd: windowEnd
            )
        } catch {
            return .partial(
                transcript: transcript,
                remoteAudioUrl: remoteAudioUrl,
                entryDrafts: entryDrafts,
                error: "Couldn't check for conflicts."
            )
        }

        let plan = EntriesService.buildResolutionPlan(
            existing: existing,
            drafts: snapped,
            captureId: job.id,
            source: source,
            transcript: (transcript?.isEmpty == false) ? transcript : nil,
            audioUrl: (remoteAudioUrl?.isEmpty == false) ? remoteAudioUrl : nil
        )

        if plan.hasConflicts {
            return .awaiting(plan: plan, transcript: transcript, remoteAudioUrl: remoteAudioUrl, entryDrafts: entryDrafts)
        }

        do {
            _ = try await EntriesService.shared.commitResolutionPlan(uid: job.uid, plan: plan)
            return .success
        } catch {
            return .partial(
                transcript: transcript,
                remoteAudioUrl: remoteAudioUrl,
                entryDrafts: entryDrafts,
                error: error.localizedDescription
            )
        }
    }
```

- [ ] **Step 4: Extend the `JobOutcome` enum**

In `CaptureQueue.swift`, find:

```swift
    private enum JobOutcome {
        case success
        case partial(transcript: String?, remoteAudioUrl: String?, entryDrafts: [CapturedEntryDraft]?, error: String)
        case failure(String)
    }
```

Replace with:

```swift
    private enum JobOutcome {
        case success
        case awaiting(plan: ResolutionPlan,
                      transcript: String?,
                      remoteAudioUrl: String?,
                      entryDrafts: [CapturedEntryDraft]?)
        case partial(transcript: String?, remoteAudioUrl: String?, entryDrafts: [CapturedEntryDraft]?, error: String)
        case failure(String)
    }
```

And in `applyOutcome`, add a new case before `.partial`:

```swift
        case .awaiting(let plan, let transcript, let remoteAudioUrl, let entryDrafts):
            if let transcript { jobs[index].transcript = transcript }
            if let remoteAudioUrl { jobs[index].remoteAudioUrl = remoteAudioUrl }
            if let entryDrafts { jobs[index].entryDrafts = entryDrafts }
            jobs[index].plan = plan
            jobs[index].status = .awaitingConfirmation
            jobs[index].error = nil
```

- [ ] **Step 5: Build to confirm**

```sh
cd ios-swift && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```sh
git add ios-swift/Cronwatch/Services/CaptureQueue.swift ios-swift/Cronwatch/Services/EntriesService.swift
git commit -m "feat(queue): park overlapping captures in awaitingConfirmation"
```

---

### Task 8: Add `confirmPlan` and `discardPlan` to `CaptureQueue`

The UI calls these to resolve a parked job.

**Files:**
- Modify: `ios-swift/Cronwatch/Services/CaptureQueue.swift`

- [ ] **Step 1: Add public API**

In `CaptureQueue.swift`, add the following methods inside the public-API section (after `retry`/`retryAll`/`discard`):

```swift
    func confirmPlan(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .awaitingConfirmation else { return }
        guard let plan = jobs[index].plan else { return }
        jobs[index].status = .running
        jobs[index].error = nil
        saveToDisk()
        let job = jobs[index]
        Task { [weak self] in
            do {
                _ = try await EntriesService.shared.commitResolutionPlan(uid: job.uid, plan: plan)
                await self?.finalizeCommit(jobId: job.id)
            } catch {
                await self?.failCommit(jobId: job.id, message: error.localizedDescription)
            }
        }
    }

    func discardPlan(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .awaitingConfirmation else { return }
        if let audioURL = jobs[index].audioURL {
            Self.deleteAudio(audioURL)
        }
        jobs.remove(at: index)
        saveToDisk()
    }

    @MainActor private func finalizeCommit(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        if let audioURL = jobs[index].audioURL {
            Self.deleteAudio(audioURL)
        }
        jobs.remove(at: index)
        saveToDisk()
    }

    @MainActor private func failCommit(jobId: String, message: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        jobs[index].status = .error
        jobs[index].error = message
        saveToDisk()
    }
```

- [ ] **Step 2: Make `retry` re-commit when a saved plan exists**

In `CaptureQueue.retry(jobId:)`, immediately after the existing guard:

```swift
    func retry(jobId: String) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        guard jobs[index].status == .error else { return }
        if jobs[index].plan != nil {
            jobs[index].status = .awaitingConfirmation
            jobs[index].error = nil
            saveToDisk()
            return
        }
        jobs[index].status = .queued
        jobs[index].error = nil
        saveToDisk()
        Task { await tick() }
    }
```

(If the failure was a commit-time failure, the saved plan needs user re-confirmation rather than a silent retry. Sending the job back to `.awaitingConfirmation` re-surfaces the sheet via the same flow.)

- [ ] **Step 3: Build to confirm**

```sh
cd ios-swift && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```sh
git add ios-swift/Cronwatch/Services/CaptureQueue.swift
git commit -m "feat(queue): confirmPlan and discardPlan for parked jobs"
```

---

### Task 9: Create `ConflictPresenter`

A small `@MainActor` `ObservableObject` that mirrors the first `awaitingConfirmation` job id so the app root can bind a `.sheet(item:)`.

**Files:**
- Create: `ios-swift/Cronwatch/Services/ConflictPresenter.swift`

- [ ] **Step 1: Write the presenter**

Create `ios-swift/Cronwatch/Services/ConflictPresenter.swift`:

```swift
import Combine
import Foundation
import SwiftUI

@MainActor
final class ConflictPresenter: ObservableObject {
    static let shared = ConflictPresenter()

    @Published var activeJob: PendingConfirmation?

    private var cancellable: AnyCancellable?

    private init() {}

    func observe(queue: CaptureQueue) {
        cancellable?.cancel()
        update(jobs: queue.jobs)
        cancellable = queue.$jobs.sink { [weak self] jobs in
            self?.update(jobs: jobs)
        }
    }

    func dismiss() {
        activeJob = nil
    }

    private func update(jobs: [CaptureJob]) {
        let candidate = jobs.first(where: { $0.status == .awaitingConfirmation })
        if let candidate, let plan = candidate.plan {
            let next = PendingConfirmation(jobId: candidate.id, plan: plan)
            if activeJob == nil || activeJob?.jobId != next.jobId || activeJob?.plan != next.plan {
                activeJob = next
            }
        } else if activeJob != nil {
            activeJob = nil
        }
    }
}

struct PendingConfirmation: Identifiable, Equatable {
    let jobId: String
    let plan: ResolutionPlan

    var id: String { jobId }
}
```

- [ ] **Step 2: Build to confirm**

```sh
cd ios-swift && xcodegen generate && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```sh
git add ios-swift/Cronwatch/Services/ConflictPresenter.swift ios-swift/Cronwatch.xcodeproj
git commit -m "feat: ConflictPresenter to surface awaitingConfirmation jobs"
```

---

### Task 10: Teach `CaptureQueueToastBridge` about `awaitingConfirmation`

Replace the "Processing entry…" sticky with a "1 entry needs your review — tap to resolve." sticky that taps through to the sheet.

**Files:**
- Modify: `ios-swift/Cronwatch/Services/CaptureQueueToastBridge.swift`

- [ ] **Step 1: Update the bridge to handle the awaiting state**

Replace `process(jobs:toasts:)` with:

```swift
    private func process(jobs: [CaptureJob], toasts: ToastCenter) {
        let active = jobs.contains(where: { $0.status == .queued || $0.status == .running })
        let awaiting = jobs.first(where: { $0.status == .awaitingConfirmation })

        if let awaiting {
            if stickyId == nil || lastStickyKind != .needsReview {
                if let id = stickyId { toasts.dismiss(id) }
                let jobId = awaiting.id
                stickyId = toasts.show(
                    message: "1 entry needs your review — tap to resolve.",
                    kind: .info,
                    duration: nil,
                    action: .init(label: "Review") {
                        Task { @MainActor in
                            ConflictPresenter.shared.activeJob = PendingConfirmation(
                                jobId: jobId,
                                plan: awaiting.plan ?? ResolutionPlan(
                                    captureId: "",
                                    source: .voice,
                                    transcript: nil,
                                    audioUrl: nil,
                                    drafts: [],
                                    resolutions: []
                                )
                            )
                        }
                    }
                )
                lastStickyKind = .needsReview
            }
        } else if active {
            if stickyId == nil || lastStickyKind != .processing {
                if let id = stickyId { toasts.dismiss(id) }
                stickyId = toasts.show(message: "Processing entry…", kind: .info, duration: nil)
                lastStickyKind = .processing
            }
        } else if let id = stickyId {
            toasts.dismiss(id)
            stickyId = nil
            lastStickyKind = nil
        }

        let currentIds = Set(jobs.map(\.id))
        for job in jobs {
            let previous = lastStatus[job.id]
            if previous != job.status {
                if job.status == .error {
                    toasts.show(
                        message: "Saved as draft — tap Retry",
                        kind: .error,
                        duration: 4,
                        action: .init(label: "Retry") {
                            Task { @MainActor in CaptureQueue.shared.retry(jobId: job.id) }
                        }
                    )
                }
                lastStatus[job.id] = job.status
            }
        }

        for previousId in lastKnownIds where !currentIds.contains(previousId) {
            if lastStatus[previousId] == .running {
                toasts.show(message: "Entry saved.", kind: .success, duration: 2)
            }
            lastStatus.removeValue(forKey: previousId)
        }
        lastKnownIds = currentIds
    }
```

And add the supporting state to the class:

```swift
private enum StickyKind { case processing, needsReview }

@MainActor
final class CaptureQueueToastBridge: ObservableObject {
    private var stickyId: String?
    private var lastStickyKind: StickyKind?
    private var lastStatus: [String: CaptureJobStatus] = [:]
    private var lastKnownIds: Set<String> = []
    private var cancellable: AnyCancellable?

    // ... rest unchanged ...
```

- [ ] **Step 2: Build to confirm**

```sh
cd ios-swift && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```sh
git add ios-swift/Cronwatch/Services/CaptureQueueToastBridge.swift
git commit -m "feat(toast): awaitingConfirmation sticky drives ConflictPresenter"
```

---

### Task 11: Build `ConflictConfirmationSheet`

A presentation-only SwiftUI view that renders the plan and exposes Replace / Discard.

**Files:**
- Create: `ios-swift/Cronwatch/Views/Capture/ConflictConfirmationSheet.swift`

- [ ] **Step 1: Write the sheet**

Create `ios-swift/Cronwatch/Views/Capture/ConflictConfirmationSheet.swift`:

```swift
import SwiftUI

struct ConflictConfirmationSheet: View {
    let pending: PendingConfirmation
    var onReplace: () -> Void
    var onDiscard: () -> Void

    @State private var inFlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Replace existing entries?")
                .font(.cwTitle)
                .foregroundColor(Palette.ink)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("This recording adds:")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                ForEach(Array(pending.plan.drafts.enumerated()), id: \.offset) { _, draft in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(Categories.color(for: draft.category))
                            .frame(width: 10, height: 10)
                        Text(Categories.label(for: draft.category))
                            .font(.cwBody.weight(.semibold))
                            .foregroundColor(Palette.ink)
                        Spacer()
                        Text(Self.formatRange(draft.startTime, draft.endTime))
                            .font(.cwCaption)
                            .monospacedDigit()
                            .foregroundColor(Palette.muted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("And will:")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                ForEach(Array(pending.plan.resolutions.enumerated()), id: \.offset) { _, resolution in
                    Text(Self.describe(resolution: resolution))
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: Spacing.sm) {
                Button(action: {
                    guard !inFlight else { return }
                    inFlight = true
                    onReplace()
                }) {
                    HStack {
                        if inFlight {
                            ProgressView().tint(.white)
                        } else {
                            Text("Replace and save")
                                .font(.cwBody.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Palette.amber)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(inFlight)

                Button(action: {
                    guard !inFlight else { return }
                    inFlight = true
                    onDiscard()
                }) {
                    Text("Discard")
                        .font(.cwBody)
                        .foregroundColor(Palette.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .disabled(inFlight)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .interactiveDismissDisabled(inFlight)
        .background(Palette.bg)
    }

    private static func formatRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private static func describe(resolution: Resolution) -> String {
        let label = Categories.label(for: resolution.category)
        switch resolution.action {
        case .delete:
            return "• Delete “\(label)” \(formatRange(resolution.originalStart, resolution.originalEnd))"
        case .trim(let s, let e):
            return "• Trim “\(label)” to \(formatRange(s, e))"
        case .split(let l, let r):
            return "• Split “\(label)” into \(formatRange(l.start, l.end)) and \(formatRange(r.start, r.end))"
        }
    }
}
```

If `.cwTitle` is not a defined font extension, replace with `.title3.weight(.semibold)` or check `Typography.swift` for the project's title style and use that.

- [ ] **Step 2: Verify font/style references against `Typography.swift`**

Check the file:

```sh
grep -n "cwTitle\|cwBody\|cwCaption" /Users/konradgnat/dev/startups/cronwatch/ios-swift/Cronwatch/Theme/Typography.swift
```

If `.cwTitle` doesn't exist, replace it in the sheet with whatever the project uses (e.g. `.title3.weight(.semibold)` or `.cwHeadline`). The sheet must use the project's existing typography tokens — don't introduce new ones.

- [ ] **Step 3: Build to confirm**

```sh
cd ios-swift && xcodegen generate && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```sh
git add ios-swift/Cronwatch/Views/Capture/ConflictConfirmationSheet.swift ios-swift/Cronwatch.xcodeproj
git commit -m "feat(ui): ConflictConfirmationSheet"
```

---

### Task 12: Mount the sheet at the app root

The sheet should float above any tab or modal, so it lives on `CronwatchApp`'s root.

**Files:**
- Modify: `ios-swift/Cronwatch/CronwatchApp.swift`

- [ ] **Step 1: Wire `ConflictPresenter` into the app root and bind `.sheet(item:)`**

In `CronwatchApp.swift`, replace the `CronwatchApp` struct body with:

```swift
@main
struct CronwatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var rc = RevenueCatService.shared
    @StateObject private var toasts = ToastCenter.shared
    @StateObject private var queue = CaptureQueue.shared
    @StateObject private var bridge = CaptureQueueToastBridge()
    @StateObject private var conflicts = ConflictPresenter.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                ToastHost()
            }
            .environmentObject(auth)
            .environmentObject(rc)
            .environmentObject(toasts)
            .environmentObject(queue)
            .preferredColorScheme(.light)
            .tint(Palette.amber)
            .onAppear {
                bridge.observe(queue: queue, toasts: toasts)
                conflicts.observe(queue: queue)
            }
            .sheet(item: $conflicts.activeJob) { pending in
                ConflictConfirmationSheet(
                    pending: pending,
                    onReplace: {
                        CaptureQueue.shared.confirmPlan(jobId: pending.jobId)
                        conflicts.dismiss()
                    },
                    onDiscard: {
                        CaptureQueue.shared.discardPlan(jobId: pending.jobId)
                        conflicts.dismiss()
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}
```

- [ ] **Step 2: Build and run a smoke launch**

```sh
cd ios-swift && xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Expected: `BUILD SUCCEEDED`. The presenter starts subscribed; with no awaiting jobs, no sheet appears.

- [ ] **Step 3: Commit**

```sh
git add ios-swift/Cronwatch/CronwatchApp.swift
git commit -m "feat(app): mount ConflictConfirmationSheet at root"
```

---

### Task 13: Firestore rules backstop for malformed time ranges

Add per-doc validation so zero-length or inverted entries can't be written.

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Add validation predicates**

Replace the `users/{uid}/entries/{entryId}` block:

```
    match /users/{uid}/entries/{entryId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
```

…with:

```
    match /users/{uid}/entries/{entryId} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow delete: if request.auth != null && request.auth.uid == uid;
      allow create: if request.auth != null
        && request.auth.uid == uid
        && request.resource.data.startTime is timestamp
        && request.resource.data.endTime is timestamp
        && request.resource.data.endTime > request.resource.data.startTime;
      allow update: if request.auth != null
        && request.auth.uid == uid
        && request.resource.data.endTime is timestamp
        && request.resource.data.startTime is timestamp
        && request.resource.data.endTime > request.resource.data.startTime;
    }
```

- [ ] **Step 2: Commit**

```sh
git add firestore.rules
git commit -m "fix(rules): reject zero-length and inverted entries"
```

Deploying the rules is out of scope for this plan — call out the change in the PR description so the rules can be pushed alongside.

---

### Task 14: Manual QA pass

Validate the full flow on a simulator with live Firebase.

**Files:** none.

- [ ] **Step 1: Regenerate, build, and launch on simulator**

```sh
cd ios-swift && xcodegen generate
xcodebuild build \
  -project Cronwatch.xcodeproj \
  -scheme Cronwatch \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  | tail -10
```

Launch from Xcode (`Cmd+R`). Sign in.

- [ ] **Step 2: Run the QA matrix**

Verify each scenario from the spec's Testing Strategy section, checking off as you go:

- **No conflict (sanity)**: Record an entry at a time slot with no existing entry → modal closes → "Processing entry…" sticky → "Entry saved." toast. No sheet appears.
- **Partial left overlap**: Existing 9:30–11. Record/type a new entry 9:00–10:00 → "needs review" sticky → tap → sheet says "Trim 'Deep' to 10:00 AM – 11:00 AM" → Replace → existing becomes 10:00–11:00, new saved at 9:00–10:00.
- **Partial right overlap**: Existing 8:00–9:30. New 9:00–10:00 → "Trim 'Deep' to 8:00 AM – 9:00 AM" → Replace.
- **New fully contains existing**: Existing 10:00–11:00. New 9:00–12:00 → "Delete 'Deep' 10:00 AM – 11:00 AM" → Replace → existing removed.
- **Existing fully contains new**: Existing 9:00–11:00. New 10:00–10:30 → "Split 'Deep' into 9:00 AM – 10:00 AM and 10:30 AM – 11:00 AM" → Replace → existing replaced by two halves, new in the middle.
- **Multi-conflict batch**: Multiple existing entries that all intersect a single new entry → sheet lists all of them under "And will:".
- **Discard path**: Same setup as partial left → tap Discard → existing unchanged in Firestore, "Discarded." toast (or no toast — verify acceptable), audio file deleted.
- **Backgrounded confirmation**: Start a conflicting capture, immediately background the app. Wait ~10s. Return to app → "needs review" sticky visible → tap → sheet appears.
- **Force-quit during await**: With a sheet pending, kill the app. Relaunch → sticky still there → tap → sheet still there.
- **Commit failure**: Toggle airplane mode, tap Replace → error toast "Saved as draft — tap Retry" → enable network → tap Retry → sheet reappears (because we route back through awaiting) → Replace again → success.

- [ ] **Step 3: Commit a QA-results note (optional)**

If any scenarios surface bugs, fix them in dedicated follow-up commits referencing this plan.

---

## Self-review against the spec

- **Goal**: ✓ Task 7 inserts confirmation gate; Tasks 2–4 add split semantics.
- **Conflict semantics (delete / trim / split, half-open)**: ✓ Tasks 3–4 (tests + implementation cover all cases including touching boundary).
- **All-or-nothing per recording**: ✓ Task 8 (`confirmPlan` commits the whole batch; `discardPlan` drops the job).
- **Confirmation as async sheet over any screen**: ✓ Tasks 9, 11, 12 (`ConflictPresenter` + sheet at app root).
- **Backgrounded surface = sticky "needs review" toast**: ✓ Task 10.
- **`buildResolutionPlan` pure**: ✓ Task 4 (nonisolated static; tests in Task 3 don't touch Firestore).
- **`commitResolutionPlan` atomic writeBatch**: ✓ Task 5.
- **Source on split halves preserved from original entry**: ✓ Resolution carries `originalSource` (Task 2); `applyResolutions` uses it (Task 4 step 2).
- **Persistence across cold start**: ✓ `plan: ResolutionPlan?` is Codable on `CaptureJob` (Task 6); existing disk persistence in `CaptureQueue` keeps working.
- **Firestore rules backstop**: ✓ Task 13.
- **Tests**: ✓ Tasks 1, 3 (target + 12 unit tests). Manual QA matrix in Task 14.

No placeholders. All types/methods referenced in later tasks are defined in earlier tasks: `DateRange`, `ConflictAction`, `Resolution`, `ResolutionPlan`, `PendingConfirmation`, `buildResolutionPlan`, `commitResolutionPlan`, `fetchConflicts` (uid overload), `snapAndDeoverlap`, `applyResolutions`, `confirmPlan`, `discardPlan`, `ConflictPresenter.observe`, `ConflictPresenter.activeJob`, `ConflictPresenter.dismiss`.
