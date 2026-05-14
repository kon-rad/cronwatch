# Background Capture Processing — Design Spec

**Date:** 2026-05-14
**Scope:** iOS Swift app (`ios-swift/`). React Native client is out of scope.

## Goal

Remove the foreground transcribe → edit → save step from voice and text capture. When the user releases the record button (or sends typed text), the capture sheet dismisses immediately and processing happens in the background. Drafts surface inline in the entries list — yellow while processing, red on error.

## Why

Two reasons:

1. **Speed.** Today the user is held in the capture sheet for the duration of network round-trips (transcribe + structure + write). On a slow connection this is 5–10s of dead time staring at a spinner. Background processing returns the user to their previous screen instantly.
2. **Trust.** A failed save today silently turns into a `DraftBanner` entry above the list — easy to miss. Inline yellow/red rows make in-flight and failed work impossible to lose.

## Out of scope

- Cross-device sync of pending state (drafts are device-local).
- Today/Week/Month grid views (drafts appear in Entries list only).
- Changes to backend `/capture` and `/structure` endpoints.

## Architecture

`CaptureQueue` becomes the primary path for both voice and text capture. It already exists today as a fallback for cancel/error cases; this design promotes it to the only path.

```
User holds mic → release
        ↓
CaptureView: enqueue job → 300ms "Queued" flash → dismiss sheet
        ↓
CaptureQueue (background, @MainActor, single worker)
  ├── voice path:  audioURL → CaptureService.capture() → drafts + transcript + remoteAudioUrl
  ├── text path:   transcript pre-filled → CaptureService.structureText() → drafts
  └── on success:  EntriesService.createCaptureEntries(captureId: job.id, ...)
                   → queue.discard(job) → Firestore subscription replaces the draft row
  └── on failure:  job.status = .error → renders as red row in entries list

EntriesListView
  = merge( Firestore entries grouped by captureId, queue.jobs )
  → sort by createdAt desc → render Row.capture | Row.draft
```

### Key invariant: deterministic, idempotent capture IDs

`CaptureJob.id` (today `j_<ms>_<rand>`) becomes the `captureId` for the Firestore entries created from that job. `EntriesService.createCaptureEntries` gains an optional `captureId:` parameter.

When passed:
- Doc IDs become `<captureId>__<index>` (instead of `collection.document()` auto-generated).
- The `captureId` field on each entry is set to `captureId`.
- Inside the same batch, **first delete any existing docs matching this captureId** (query → add `batch.deleteDocument` for each). This guards against the case where the first writer produced N docs and the second writer produces M < N (e.g. user edited the transcript, snap-and-deoverlap collapsed two blocks into one) — leftover docs would otherwise be orphaned with the same captureId.

This means: if the user opens `DraftEditView` while the background job is also running, both writes are idempotent on `captureId`. Last write wins, no duplicates, no orphans. No locking required.

### Single source of truth per state

- **In-flight + errored drafts:** `CaptureQueue` (in-memory + disk-persisted, device-local)
- **Saved entries:** Firestore
- **The list view merges both. Never duplicated** — when the queue creates entries it discards the job, and the Firestore subscription delivers the real entries.

## Components

### 1. `AudioRecorder` — minimum-duration guard

Add a `recordingStartedAt: Date?` and surface elapsed duration from `stop()`. If duration < 0.5s, `CaptureView` discards the audio file and dismisses silently. Prevents accidental taps from creating processing rows that error on empty audio.

### 2. `CaptureView` — simplified state machine

```swift
enum CapturePhase {
    case idle
    case recording
    case queued        // 300ms confirmation flash, then dismiss
    case savingText    // 300ms flash for typed path
}
```

Removed phases (work now lives in `CaptureQueue`): `transcribing`, `editing`, `saving`, `saved`, `transcribeError`.

**`onPressOut` (voice):**
1. `recorder.stop()` → `(url, duration)`
2. If `duration < 0.5s` → delete audio file, dismiss silently
3. `phase = .queued`
4. `queue.enqueue(uid:, audioURL: url, initialStatus: .queued)` — queue takes ownership of the audio file (existing `persistAudio` already moves it)
5. Haptic success
6. `Task.sleep(300ms)` → `dismiss()`

**`onSaveTyped` (text):**
1. Trim, guard non-empty
2. `phase = .savingText`
3. `queue.enqueueText(uid:, transcript: trimmed)` — new helper, no audioURL
4. Haptic success
5. `Task.sleep(300ms)` → `dismiss()`

**`onCancel` during recording:** stop recorder, delete audio file, dismiss. No more `saveAsDraftIfNeeded` — the user explicitly cancelled before releasing, nothing to save.

**Header simplification:** remove the top-right "Save" button. Typed flow uses the paperplane icon in the footer input only.

### 3. `CaptureQueue` — Optional audioURL + text enqueue helper

Change `CaptureJob.audioURL` to `URL?`. `Codable` handles this automatically. Update:
- `persistAudio`: no-op when source is nil.
- `deleteAudio`: no-op when url is nil.
- `cleanupOrphans`: skip jobs with nil audioURL.
- `processJob`: only reads `audioURL` when `transcript == nil && entryDrafts == nil`, so the text path naturally skips audio handling.

New helper:

```swift
@discardableResult
func enqueueText(uid: String, transcript: String) -> String {
    let id = Self.newJobId()
    let job = CaptureJob(
        id: id,
        uid: uid,
        audioURL: nil,
        transcript: transcript,
        remoteAudioUrl: nil,
        entryDrafts: nil,
        status: .queued,
        error: nil,
        createdAt: Date()
    )
    jobs.append(job)
    saveToDisk()
    Task { await tick() }
    return id
}
```

`processJob` requires no logic changes other than threading `captureId: job.id` into `createCaptureEntries`.

### 4. `EntriesService` — captureId param

```swift
func createCaptureEntries(
    uid: String,
    drafts: [CapturedEntryDraft],
    source: EntrySource,
    transcript: String?,
    audioUrl: String?,
    captureId: String? = nil   // NEW
) async throws -> [Entry]
```

When `captureId` is provided:
- Doc ID: `<captureId>__<index>` (zero-padded if needed)
- `captureId` field on each entry: `captureId`

When nil, current behavior preserved.

### 5. `EntriesListView` — merged row model

```swift
enum EntryRow: Identifiable {
    case capture(Capture)
    case draft(CaptureJob)

    var id: String {
        switch self {
        case .capture(let c): return "c_" + c.id
        case .draft(let j):   return "d_" + j.id
        }
    }

    var sortDate: Date {
        switch self {
        case .capture(let c): return c.createdAt
        case .draft(let j):   return j.createdAt
        }
    }
}
```

Build the list:
```swift
let captures = EntriesService.groupByCapture(head + tail).map(EntryRow.capture)
let drafts = queue.jobs.map(EntryRow.draft)
let rows = (captures + drafts).sorted(by: { $0.sortDate > $1.sortDate })
```

Pagination still triggers on `.capture` rows only (drafts are always recent and few). The `maybeLoadMore` check finds the last `.capture` row.

`@EnvironmentObject var queue: CaptureQueue` is added so SwiftUI re-renders when jobs change.

### 6. `DraftRowView` — new inline component

Two visual states driven by `job.status`:

**Processing (`.queued` or `.running`):**
- Background: `Palette.amberSoft`
- Left: small `ProgressView` (16pt)
- Center: "Processing…" if `status == .queued` or `transcript == nil`; "Transcribing…" if `status == .running` and `transcript == nil`. Once a transcript exists, the row still shows "Processing…" (we don't reveal partial state — keeps the row compact per design choice).
- Right: timestamp (`formatTime(job.createdAt)`)
- Tap: opens `DraftEditView(jobId:)` (existing component). The job keeps running; deterministic captureId handles the race.

**Error (`.error`):**
- Background: `Palette.danger.opacity(0.10)` — soft red tint
- Left: `exclamationmark.triangle.fill` in `Palette.danger`
- Center: truncated `job.error ?? "Couldn't process entry"` (1 line)
- Right: timestamp
- Tap: opens `DraftEditView(jobId:)`
- Swipe-to-delete (iOS swipe action): calls `queue.discard(jobId: job.id)`. Confirmation alert before discard (consistent with existing `DraftBanner` discard flow).

Row height and horizontal padding match `CaptureRowView` so the merged list reads as one column.

### 7. `DraftBanner` — reduced to Retry-all summary

Strip down to a single-line summary when ≥1 error job exists:

```
⚠️  3 drafts need attention                    Retry all
```

- Only renders when `drafts.count > 0` (drafts = jobs with `status == .error`)
- No expansion, no per-draft sub-rows (those are inline now)
- Tap "Retry all" → `queue.retryAll()`
- Banner sits at top of list (same position as today)

### 8. `DraftEditView` — minimal changes for race handling

Most behavior already works. Two adjustments:

- **`onSave`** already calls `EntriesService.createCaptureEntries(...)` then `queue.discard(jobId:)`. Add `captureId: jobId` to the create call so it's idempotent against the background worker.
- **Detect race resolution while editing:** observe `queue.job(id: jobId)` via `@EnvironmentObject` reactivity. If the background job succeeds while the edit sheet is open, `queue.job(id:)` returns nil; show a non-blocking banner at the top of the sheet: "This draft was just processed — your edits will overwrite when you save." User can choose to save (overwriting) or dismiss (keeping the auto-processed version).

## Data flow examples

### Happy path (voice)
1. User holds mic, releases after 3s.
2. `CaptureView`: 0.5s guard passes → `queue.enqueue(...)` returns job `j_1747252800123_a4f9b` → phase = `.queued`.
3. After 300ms, sheet dismisses. User sees Entries list. New yellow row at top: "Processing…".
4. `CaptureQueue.tick` picks up the job → status `.running` → calls `CaptureService.capture(audioURL:)` → drafts + transcript come back.
5. Queue calls `createCaptureEntries(captureId: "j_1747252800123_a4f9b", ...)`. Firestore writes docs `j_1747252800123_a4f9b__0`, `__1`, etc.
6. Queue removes the job. Firestore subscription delivers the new entries. The yellow row is replaced by a normal `CaptureRowView`.

### Error path (network drops mid-transcribe)
1. Steps 1–4 as above.
2. `CaptureService.capture` throws. Queue marks `status = .error` with the error message.
3. Yellow row turns red, shows the error.
4. User taps the row → `DraftEditView` opens with `transcript = nil`, `blocks = []`. User taps "Retry transcription" → `CaptureService.capture` re-runs in the sheet (existing path), populates state, user can save.

### Race path (background succeeds while editing)
1. User taps a processing yellow row → `DraftEditView` opens.
2. Background job completes successfully → Firestore docs written with deterministic captureId → `queue.discard(jobId:)`.
3. `queue.job(id: jobId)` returns nil. Edit sheet shows banner: "This draft was just processed."
4. If user clicks Save, their write hits the same doc IDs → overwrites. Last write wins by design.
5. If user dismisses, the auto-processed entry remains.

## Edge cases

| Case | Behavior |
|---|---|
| Audio < 0.5s | Discard file, no job, silent dismiss |
| User signs out while job is queued | Existing `processJob` guard errors with "Signed out"; status becomes `.error`. User can retry after signing back in. |
| App backgrounded mid-`running` | Job persisted to disk. On cold launch, `running` → `error` ("Interrupted") per existing logic. User retries from inline row or banner. |
| Multiple drafts queued | Single worker processes serially (existing). Yellow rows appear in order; first becomes a real entry, then next moves to `.running`. |
| User taps the same processing draft twice quickly | SwiftUI sheet binding already de-dupes. |
| Permission denied on first record | Existing flow — phase resets to `.idle`, no change. |

## Testing

- Unit: `CaptureQueue.enqueueText` produces a job that skips straight to `structureText`.
- Unit: `EntriesService.createCaptureEntries(captureId:)` writes deterministic doc IDs.
- Unit: `EntryRow` merging sorts correctly with mixed timestamps.
- Manual: happy path voice, happy path text, network-off error, swipe-delete, retry-all, race (open edit while processing — pause network in proxy to simulate slow processing).

## Files touched

- `ios-swift/Cronwatch/Services/AudioRecorder.swift` — duration guard
- `ios-swift/Cronwatch/Services/CaptureQueue.swift` — `enqueueText`, optional `audioURL`, thread `captureId`
- `ios-swift/Cronwatch/Services/EntriesService.swift` — `captureId:` param
- `ios-swift/Cronwatch/Views/Capture/CaptureView.swift` — strip phases, enqueue + dismiss
- `ios-swift/Cronwatch/Views/Tabs/EntriesListView.swift` — merged `EntryRow`
- `ios-swift/Cronwatch/Views/Entry/DraftRowView.swift` — NEW
- `ios-swift/Cronwatch/Views/Common/DraftBanner.swift` — reduce to one-line summary
- `ios-swift/Cronwatch/Views/Entry/DraftEditView.swift` — race banner, captureId on save
