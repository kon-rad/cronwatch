# Confirm-before-replace on overlapping captures

Status: Spec
Date: 2026-05-15

## Goal

Make "no two entries overlap in time" an invariant the user controls. When a new capture's parsed time range conflicts with one or more existing entries, hold the entire batch and require user confirmation of an atomic resolution (insert the new entries + trim / split / delete the conflicting ones) — or discard the whole batch. No more silent destructive mutations.

## Background

The current pipeline (`EntriesService.createCaptureEntries`) already enforces the no-overlap invariant: it fetches conflicting entries in the draft window, computes a per-entry resolution (`delete` or `update startTime/endTime`), and applies the batch silently. The user has no chance to intervene. This spec inserts a confirmation gate in front of that step and changes the resolution semantics for one case (existing fully contains new → split instead of one-sided trim).

## Non-goals

- No per-conflict prompting — confirmation is per-recording, all-or-nothing.
- No manual editing of times inside the confirmation sheet. Confirm or discard. The user can edit the saved entries afterward via the existing edit screen.
- No retroactive scan or repair of pre-existing overlaps (only enforced at save time).
- No new server-side enforcement. Detection stays on the client where the queue + UI already live.
- No local notifications. The pending-confirmation surface is the existing in-app toast.

## Conflict semantics

Intervals are half-open `[start, end)`. Two intervals touching at a single instant (e.g. `[9:00, 10:00)` and `[10:00, 11:00)`) do not overlap.

For each draft `N = [Ns, Ne)` and each existing entry `E = [Es, Ee)` such that `Es < Ne AND Ee > Ns`, the resolution is:

| Case | Condition | Resolution |
|---|---|---|
| `N` fully contains `E` | `Ns <= Es AND Ne >= Ee` | **Delete `E`**. |
| `E` fully contains `N` (strict) | `Es < Ns AND Ee > Ne` | **Split `E`** into two entries `[Es, Ns)` and `[Ne, Ee)`, preserving `E`'s `category`, `note`, `transcript`, `audioUrl`, and `captureId` on both halves. |
| `N` overlaps `E`'s left side | `Ns <= Es AND Es < Ne < Ee` | **Trim** `E.startTime` to `Ne` (keep `E`'s right side). |
| `N` overlaps `E`'s right side | `Es < Ns < Ee AND Ne >= Ee` | **Trim** `E.endTime` to `Ns` (keep `E`'s left side). |

Equivalently and more general: subtract every draft's interval from `E`'s interval; the remaining pieces are what survives. Zero pieces → delete. One piece equal to original → no-op. One piece smaller → trim. Two pieces → split. Pseudocode:

```swift
// pseudocode — see "Resolution algorithm" below for the real implementation
func resolve(E, drafts: [N]) -> Resolution {
    var keep: [Interval] = [[E.start, E.end)]
    for N in drafts where N overlaps any piece of keep {
        keep = keep.flatMap { piece in piece.subtract(N) }
    }
    switch keep.count {
        case 0: return .delete
        case 1: return keep[0] == [E.start, E.end) ? .noop : .trim(keep[0])
        case 2: return .split(keep[0], keep[1])
        default: precondition(false, "more than 2 pieces impossible from at most 2 drafts overlapping one entry once each")
    }
}
```

In other words: subtract every draft's interval from `E`'s interval; the remaining pieces are what survives. Zero pieces → delete. One piece equal to original → no-op. One piece smaller → trim. Two pieces → split.

The "at most two pieces" claim assumes drafts within a single recording are already non-overlapping with each other (the existing `snapAndDeoverlap` enforces this). Three+ pieces would require two non-adjacent overlap regions, which can't happen if drafts are merged into a single contiguous range per overlap.

If a single recording produces multiple drafts that overlap each other (LLM error after `snapAndDeoverlap`), reject the entire batch pre-confirmation with an error toast: "Couldn't save — entries from this recording overlap each other."

## User flow

### Capture (no conflicts)

1. User taps FAB → capture modal opens.
2. Records or types → press release / send.
3. Modal dismisses; sticky "Processing entry…" toast.
4. Queue worker calls `/capture`, gets drafts, queries Firestore for overlaps in the draft window, **finds none**, commits via `EntriesService.createCaptureEntries`.
5. Sticky toast dismisses; "Entry saved." for 2s.

(Identical to today.)

### Capture (one or more conflicts)

1. Steps 1–3 identical.
2. Queue worker gets drafts and queries Firestore for overlaps in the draft window. **Finds at least one conflict.**
3. Worker computes a `ResolutionPlan` (drafts + per-conflict resolutions) and parks the job: `status = awaitingConfirmation`, `plan = <plan>`.
4. Toast bridge sees the new state and **replaces** the sticky "Processing entry…" toast with a sticky "1 entry needs your review — tap to resolve." toast.
5. User taps the toast → `ConflictConfirmationSheet` opens as an iOS sheet (above whatever screen they're on), populated from `plan`.
6. User taps **Replace and save**:
   - Worker transitions job to `running`, calls `EntriesService.commitResolutionPlan(plan)`, which executes a Firestore `writeBatch` with: new entries (set), trim resolutions (update startTime/endTime), split resolutions (delete original + set two new docs), delete resolutions (delete).
   - On success: job removed from queue, sticky dismisses, "Entry saved." toast.
   - On failure: job moves to `error` with the plan preserved, error toast "Couldn't save — tap Retry" (Retry replays the same plan without re-running detection).
7. User taps **Discard**: job removed from queue (audio file deleted), sticky dismisses, "Discarded." toast for 2s.
8. User dismisses the sheet without choosing (swipe down, background tap if non-modal): treat as cancel of this presentation only — the job stays in `awaitingConfirmation`, the sticky toast remains, user can tap again later. The sheet is **interactiveDismissDisabled** while either button's action is in flight.

### Backgrounded / multi-screen

The toast persists in `ToastCenter`; on next foreground/screen change, it's still visible because there's no time-based duration on it. Tapping it opens the sheet regardless of which tab is showing. No local notifications.

## Architecture

### Diff summary

```
Modified:
  ios-swift/Cronwatch/Services/CaptureQueue.swift
    + new status .awaitingConfirmation
    + CaptureJob.plan: ResolutionPlan?
    + processJob: split into detect (computes plan) and commit (applies plan)
    + new public API: confirmPlan(jobId:), discardPlan(jobId:)

  ios-swift/Cronwatch/Services/EntriesService.swift
    + extract Resolution / ConflictAction types to file scope
    + new struct ResolutionPlan { drafts, resolutions, captureId, source, transcript, audioUrl }
    + new pure helper buildResolutionPlan(existing:drafts:...) -> ResolutionPlan
      replaces resolveConflicts; supports split (two-piece) outputs
    + new commitResolutionPlan(uid:plan:) -> applies plan in writeBatch
    + createCaptureEntries refactored to: snap → fetch conflicts → buildPlan →
      if no conflicts, commitResolutionPlan (no UI involvement); if conflicts,
      throw ConflictsRequireConfirmation(plan) — caller decides

  ios-swift/Cronwatch/Services/CaptureQueueToastBridge.swift
    + watch for .awaitingConfirmation, show sticky "needs review" toast with
      tap action that opens the sheet

  ios-swift/Cronwatch/CronwatchApp.swift
    + present ConflictConfirmationSheet via .sheet(item:) bound to a published
      "active confirmation" job id on a new ConflictPresenter object

New:
  ios-swift/Cronwatch/Services/ConflictPresenter.swift
    @MainActor singleton; published var activeJobId: String? drives the sheet.
    Methods request(jobId:), dismiss().

  ios-swift/Cronwatch/Views/Capture/ConflictConfirmationSheet.swift
    SwiftUI view; takes a ResolutionPlan; renders header + new entries list +
    "This will" list + Replace/Discard buttons.

  ios-swift/CronwatchTests/ResolutionPlanTests.swift
    Pure unit tests for buildResolutionPlan covering all four cases + multi-
    draft + multi-conflict + mutually-overlapping-drafts rejection.
```

### Module boundaries

- **`EntriesService`** stays the single owner of Firestore reads/writes. It exposes pure plan computation (`buildResolutionPlan` — testable without Firestore) and atomic plan commit (`commitResolutionPlan`).
- **`CaptureQueue`** owns job lifecycle. It calls `EntriesService` for plan building and commit, but never renders UI. It transitions jobs to `awaitingConfirmation` and exposes `confirmPlan` / `discardPlan` for the UI to call.
- **`ConflictPresenter`** is the bridge between queue state and SwiftUI sheet presentation. It subscribes to `CaptureQueue.$jobs` and publishes the id of the first job in `awaitingConfirmation` state, so the app root can bind a single `.sheet(item:)` to it.
- **`CaptureQueueToastBridge`** gains awareness of `awaitingConfirmation` and shows a tappable sticky toast that calls `ConflictPresenter.request(jobId:)`.
- **`ConflictConfirmationSheet`** is presentation-only. Buttons call `CaptureQueue.confirmPlan` / `CaptureQueue.discardPlan` and let the queue handle everything else.

### CaptureJob state machine

```
                         tick()
                       (no conflicts)
                ┌─────────────────────────┐
                ▼                         │
queued ──tick()──> running ──────────────►(remove from queue, success toast)
                │           (conflicts)
                │              │
                │              ▼
                │     awaitingConfirmation
                │       │      │       │
                │       │      │       │
                │ confirmPlan  │  discardPlan
                │       │      │       │
                │       ▼      │       ▼
                │   running    │   (remove, audio deleted, "Discarded" toast)
                │       │      │
                │  (commit ok) │  (commit fails)
                │       │      │
                │       ▼      ▼
                │   (remove)  error (plan retained on job; Retry re-commits)
                ▼
              error (transcription/network failure, as today)
```

`awaitingConfirmation` is persisted to disk like other statuses. The plan is JSON-encoded with the job (it's a `Codable` struct of value types). On cold start, jobs in `awaitingConfirmation` rehydrate; their sticky toast re-appears.

### Data flow (conflict path)

```
[CaptureView] enqueue → [CaptureQueue.tick] running
                          │
                          ▼
              CaptureService.capture(audio) → drafts
                          │
                          ▼
              EntriesService.fetchConflicts(window) → existing
                          │
                          ▼
              EntriesService.buildResolutionPlan(existing, drafts)
                          │
                ┌─────────┴─────────┐
            no conflicts        has conflicts
                │                   │
                ▼                   ▼
      commitResolutionPlan    job.status = .awaitingConfirmation
                │             job.plan = <plan>
        success toast              │
                                   ▼
                          [ToastBridge] shows sticky
                          "1 entry needs your review — tap to resolve."
                                   │ tap
                                   ▼
                          [ConflictPresenter] activeJobId = jobId
                                   │
                                   ▼
                          [App root .sheet] presents
                          ConflictConfirmationSheet(plan)
                                   │
                          ┌────────┴────────┐
                       Replace             Discard
                          │                   │
                          ▼                   ▼
                CaptureQueue.confirmPlan   CaptureQueue.discardPlan
                          │                   │
                          ▼                   ▼
              commitResolutionPlan    remove job, delete audio
                          │
                  success toast / error toast
```

## Public API additions

```swift
// EntriesService.swift
enum ConflictAction: Equatable, Codable {
    case delete                                  // remove the existing entry
    case trim(startTime: Date, endTime: Date)    // shrink existing to new range
    case split(left: DateRange, right: DateRange) // replace existing with two halves
}

struct Resolution: Equatable, Codable {
    let entryId: String           // existing entry id
    let originalStart: Date       // for transactional safety check + UI display
    let originalEnd: Date
    let category: String          // for UI display
    let note: String              // for UI display + carried into split halves
    let transcript: String?       // for split halves
    let audioUrl: String?         // for split halves
    let captureId: String         // for split halves
    let action: ConflictAction
}

struct DateRange: Equatable, Codable { let start: Date; let end: Date }

struct ResolutionPlan: Equatable, Codable {
    let captureId: String                 // for the new entries about to be inserted
    let source: EntrySource
    let transcript: String?
    let audioUrl: String?
    let drafts: [CapturedEntryDraft]      // snapped, de-overlapped
    let resolutions: [Resolution]         // one per conflicting existing entry
}

extension EntriesService {
    static func buildResolutionPlan(
        existing: [Entry],
        drafts: [CapturedEntryDraft],
        captureId: String,
        source: EntrySource,
        transcript: String?,
        audioUrl: String?
    ) -> ResolutionPlan

    func commitResolutionPlan(uid: String, plan: ResolutionPlan) async throws -> [Entry]
}

// CaptureQueue.swift
enum CaptureJobStatus: String, Codable {
    case queued, running, awaitingConfirmation, error
}

struct CaptureJob: Codable {
    // ...existing fields...
    var plan: ResolutionPlan?   // set when status == .awaitingConfirmation or
                                 // when status == .error and the error was a
                                 // commit-time failure with a known plan
}

extension CaptureQueue {
    func confirmPlan(jobId: String)   // moves to running, commits, on failure → error
    func discardPlan(jobId: String)   // removes job + audio
}

// ConflictPresenter.swift
@MainActor final class ConflictPresenter: ObservableObject {
    static let shared: ConflictPresenter
    @Published private(set) var activeJobId: String?
    func request(jobId: String)
    func dismiss()
    func observe(queue: CaptureQueue)   // mirrors first awaitingConfirmation job
}
```

## Resolution algorithm (authoritative)

```swift
// Returns one resolution per existing entry that intersects at least one draft.
// Pure; no Firestore, no MainActor. Suitable for unit testing.
static func buildResolutionPlan(
    existing: [Entry],
    drafts: [CapturedEntryDraft],
    captureId: String,
    source: EntrySource,
    transcript: String?,
    audioUrl: String?
) -> ResolutionPlan {
    var resolutions: [Resolution] = []
    for entry in existing {
        // Pieces of `entry` that survive after subtracting all overlapping drafts.
        var pieces: [DateRange] = [DateRange(start: entry.startTime, end: entry.endTime)]
        for draft in drafts {
            pieces = pieces.flatMap { p -> [DateRange] in
                // Subtract draft from this piece.
                if draft.endTime <= p.start || draft.startTime >= p.end { return [p] }
                var result: [DateRange] = []
                if p.start < draft.startTime {
                    result.append(DateRange(start: p.start, end: draft.startTime))
                }
                if draft.endTime < p.end {
                    result.append(DateRange(start: draft.endTime, end: p.end))
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
                continue  // no overlap actually touched this entry; skip
            }
            action = .trim(startTime: only.start, endTime: only.end)
        case 2:
            action = .split(left: pieces[0], right: pieces[1])
        default:
            // Impossible given non-overlapping drafts; treat as full delete defensively.
            action = .delete
        }
        resolutions.append(Resolution(
            entryId: entry.id,
            originalStart: entry.startTime,
            originalEnd: entry.endTime,
            category: entry.category,
            note: entry.note,
            transcript: entry.transcript,
            audioUrl: entry.audioUrl,
            captureId: entry.captureId,
            action: action
        ))
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

## Commit (`commitResolutionPlan`)

Executes in a single Firestore `writeBatch`:

- For each `Resolution`:
  - `.delete` → `batch.deleteDocument(entries/<entryId>)`
  - `.trim(s, e)` → `batch.updateData([startTime, endTime], forDocument: <entryId>)`
  - `.split(left, right)` → `batch.deleteDocument(<entryId>)`, then `batch.setData(...)` for two new docs with new ids, preserving `category`, `note`, `transcript`, `audioUrl`, `captureId` from the resolution, `source` from the original entry (re-read from the resolution; we encode the original entry's source via `captureId` lookup at plan-build time — see TODO note below), `createdAt: FieldValue.serverTimestamp()`.
- For each draft: `batch.setData(...)` on a deterministic doc id `<captureId>__<index>` (matches existing convention).
- `batch.commit()`.

**Source on split halves.** The split halves should inherit the original entry's `source`. The current `Entry` model carries `source`, so `buildResolutionPlan` can capture it on `Resolution` (add `originalSource: EntrySource` field; small addition).

**Concurrency.** A second device could mutate one of the conflicting entries between detection and commit. `writeBatch` is atomic for writes but does not validate that existing docs haven't changed. For v1 (single-user, single-device in practice), accept this risk; the worst case is the user's "Replace" replaces a slightly different existing range than what they saw. We mitigate via a fast detect-commit window (no network in between — `confirmPlan` runs immediately on tap). A future `runTransaction`-based commit can re-read each `Resolution.entryId` and abort if `startTime`/`endTime` no longer matches `originalStart`/`originalEnd`.

## UI: ConflictConfirmationSheet

Presented as a `.sheet(item:)` from the app root, so it floats above any tab or modal. Cannot be interactively dismissed while a button action is in flight.

```
┌────────────────────────────────────────────────┐
│  Replace existing entries?                     │   t.title
│                                                │
│  This recording adds:                          │   t.caption muted
│  ● Deep    9:00 AM – 10:30 AM                  │   row: dot + label + range
│  ● Meeting 2:00 PM – 3:00 PM                   │
│                                                │
│  And will:                                     │   t.caption muted
│  • Delete "Deep work" 10:00 – 11:00            │   one bullet per resolution
│  • Trim "Lunch" to 11:30 – 12:00               │
│  • Split "Reading" into 8:00 – 9:00 and        │
│    10:30 – 11:30                               │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │             Replace and save              │  │  amber primary
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │                 Discard                   │  │  danger tertiary
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

- **Header**: `Replace existing entries?` — `t.title`, `colors.ink`.
- **"This recording adds" list**: one row per draft. Row uses `CategoryDotView` (matches `EntryRow`) + category display label + range `9:00 AM – 10:30 AM`. Range formatter reuses existing `TimeUtils.formatTimeRange(start:end:)` or equivalent (if not present, add to `TimeUtils`).
- **"And will" list**: one bullet per resolution, in original-startTime order.
  - `.delete` → `Delete "<category>" <range>`
  - `.trim(s, e)` → `Trim "<category>" to <range(s, e)>`
  - `.split(l, r)` → `Split "<category>" into <range(l)> and <range(r)>`
  Category text uses the same display-label resolution as `EntryRow` (`CATEGORIES` lookup, falling back to raw string).
- **Buttons**: `Replace and save` (full-width, `Palette.amber` background, white text, `t.body` semibold), `Discard` (full-width, `Palette.danger` text on transparent background, `t.body`). 12pt vertical gap between them. 16pt outer horizontal padding.
- **Loading state**: while a button action is in flight, both buttons become disabled and the active button shows a `ProgressView` instead of its label.

## Error handling

- **Detect step fails (Firestore read error)**: job → `error`, error toast "Couldn't check for conflicts — tap Retry". Retry replays from the same point (transcript + drafts already on the job).
- **Commit step fails (Firestore write error)**: job → `error` with `plan` still attached, error toast "Couldn't save — tap Retry". Retry calls `confirmPlan(jobId)` again (which calls `commitResolutionPlan` again with the same plan, no re-detection).
- **Discard during commit**: not possible; sheet is `interactiveDismissDisabled` once a button is tapped.
- **App killed during commit**: on cold start, `loadFromDisk` resets `.running` → `.error` (existing logic). The plan is still on the job; Retry re-commits.
- **App killed during awaiting confirmation**: status persists; sticky toast and sheet rehydrate on next launch.
- **LLM produces self-overlapping drafts**: after `snapAndDeoverlap` (which already enforces non-overlap among drafts), this shouldn't happen. If somehow `pieces.count > 2` for a single existing entry, defensively `delete` it and log.

## Firestore rules backstop

Add a lightweight defense-in-depth check in `firestore.rules` for the entries collection:

```
allow create: if request.auth != null
  && request.auth.uid == userId
  && request.resource.data.startTime is timestamp
  && request.resource.data.endTime is timestamp
  && request.resource.data.endTime > request.resource.data.startTime;
allow update: if request.auth != null
  && request.auth.uid == userId
  && request.resource.data.endTime > request.resource.data.startTime;
```

This rejects zero-length and inverted entries server-side. It cannot enforce no-overlap (rules can't query other docs), so the client remains responsible for that invariant.

## Testing strategy

### Unit (new `ResolutionPlanTests.swift`, pure, no Firestore)

Table-driven tests for `buildResolutionPlan`:

| name | drafts | existing | expected resolutions |
|---|---|---|---|
| no overlap | one at 9–10 | one at 11–12 | empty |
| partial left | one at 9–10 | one at 9:30–11 | trim 10–11 |
| partial right | one at 9–10 | one at 8–9:30 | trim 8–9 |
| full contain (new ⊃ existing) | one at 9–12 | one at 10–11 | delete |
| full contain (existing ⊃ new) | one at 10–10:30 | one at 9–11 | split 9–10 + 10:30–11 |
| equal | one at 9–10 | one at 9–10 | delete |
| touch boundary | one at 9–10 | one at 10–11 | empty (half-open) |
| multi-draft | two at 9–10 and 11–12 | one at 9:30–11:30 | trim or split per the algorithm |
| multi-conflict | one at 9–12 | two at 9:30–10 and 11–11:30 | both delete |

### Manual QA matrix

- Record an entry that doesn't conflict → saves silently (no sheet).
- Record an entry that conflicts with one existing (partial left) → sticky toast → tap → sheet shows "Trim" → Replace → original is trimmed, new saved, "Entry saved." toast.
- Same scenario → Discard → audio file removed, "Discarded." toast, nothing in Firestore changed.
- Record an entry whose range fully contains an existing → sheet shows "Delete" → Replace → existing gone, new saved.
- Record an entry whose range is fully inside an existing → sheet shows "Split into … and …" → Replace → existing replaced by two halves, new saved in the middle.
- Record a multi-slot recording where one slot conflicts and one doesn't → sheet shows both new entries; "And will" lists only the conflict → Replace → both new entries saved, conflict resolved.
- Backgrounded between record and proxy return → return to app → sticky "needs review" toast is visible → tap → sheet appears.
- Force-quit the app while sheet is open → relaunch → toast still there → tap → sheet still there.
- Toggle airplane mode after tapping Replace → error toast "Couldn't save — tap Retry" → re-enable → tap Retry → success.

## Risks and open questions

- **Cross-device race**: another device edits a conflicting entry between detection and commit. Mitigated by short window between detect and commit; not eliminated. Acceptable for v1.
- **Capture-id collisions on split halves**: split entries inherit the original entry's `captureId`. Two halves with the same `captureId` will both be returned by `getCapture(uid:captureId:)` — `groupByCapture` already handles multiple blocks per capture id, so this should be fine, but worth a manual QA pass on the entry-view detail screen for split entries.
- **Source on split halves**: the existing entry's `source` propagates to both halves. `buildResolutionPlan` must capture and forward it on `Resolution` (added to the API above).
- **Audio on split halves**: both halves point at the same `audioUrl` (same recording). Playing audio from either half plays the full original recording — minor UX wart, not blocking. Mention in followups.
- **Resolution plan size**: very large plans (e.g. an entry that fully contains 50 small existing entries) would render a long sheet. Cap or truncate the "And will" list with a "+N more" indicator if length exceeds ~10? Defer to followup unless QA finds it.

## Out of scope (followups)

- Server-enforced no-overlap via Cloud Function trigger.
- `runTransaction`-based commit with `originalStart`/`originalEnd` validation against current Firestore state.
- Inline editing of times within the confirmation sheet.
- Multi-device awareness (e.g. clear the sticky toast if another device resolved the same job).
- Audio-on-split: regenerate trimmed/sliced audio per half so playback matches range.
- Surface old (pre-existing) overlaps on a one-time data-repair flow.
