# Swift iOS feature parity with the React Native app

Status: Spec
Date: 2026-05-12
Approach: incremental refactor of `ios-swift/` to match the React Native client at `client/`. RN remains in-tree for now; Swift becomes the canonical client going forward.

## Goal

Bring the SwiftUI app to feature parity with the current RN app: 4-tab navigation with a List tab, multi-block captures from a single recording, fire-and-forget voice capture with toasts + a draft banner, paginated entries list with grouping, view-only entry detail with audio playback, and a real overview dashboard (streak + weekly average computed from Firestore data, not mocks).

## Non-goals

- Persisting the capture queue to disk (v1 keeps it in-memory; cold start drops it).
- Actually triggering RevenueCat purchases. Entitlement read + restore stay wired, the Subscribe button stays a TODO that just dismisses — matches RN.
- Audio caching: the detail screen streams `entry.audioUrl` via AVPlayer each open.
- Editing on the view-only detail page (existing `EntryEditView` covers edits from Today).
- Search, filters, or date jumps on the list view.

## User flows (mirror RN)

### Voice capture (fire-and-forget)
1. FAB → CaptureView modal.
2. Hold mic button → records.
3. Release → `AudioRecorder.stop()` returns a URL; `CaptureQueue.enqueue(uid, url)` accepts; modal dismisses.
4. Sticky toast "Processing entry…" appears.
5. Background: `CaptureService.capture` → `EntriesService.createCaptureEntries`. On success, dismiss sticky, show "Entry saved." for 2s; on error, dismiss sticky, show "Saved as draft — tap Retry" for 4s with a Retry action.
6. The Today grid and List tab update via live Firestore subscriptions.

### Typed capture
- Save inside the modal (current behavior), then dismiss. No toast.

### List tab
- 4th tab between Today and Profile.
- Live first page of 50 entries ordered `createdAt desc`, grouped into Captures by `captureId`.
- Pull-to-refresh resets the appended tail.
- Scroll near end triggers `loadMore` page-by-page; tail is appended in memory.
- Tap row → modal `EntryViewOnlyView`.

### Entry view-only detail
- Modal sheet. Header: Done · "Entry" or "Capture" (multi-block) · play/pause (hidden when no audioUrl).
- Body: long date, list of blocks (colored dot + category label + note + range/duration line), transcript at bottom (selectable).
- AVPlayer plays from `entry.audioUrl` streaming. Failure → toast "Couldn't play audio" (3s).

## Architecture

Existing SwiftUI + ObservableObject services on `@MainActor`, deployment target iOS 17, no new SPM deps (AVFoundation/AVKit are system).

### Files to add

```
ios-swift/Cronwatch/
├── Services/
│   ├── CaptureQueue.swift
│   ├── ToastCenter.swift
│   └── AudioPlayerService.swift
├── Views/
│   ├── Common/
│   │   ├── ToastHost.swift
│   │   └── DraftBanner.swift
│   ├── Tabs/
│   │   └── EntriesListView.swift
│   └── Entry/
│       ├── CaptureRowView.swift
│       └── EntryViewOnlyView.swift
```

### Files to modify

- `Models/Entry.swift`: add `captureId: String`, `audioUrl: String?`; add `Capture` struct.
- `Services/CaptureService.swift`: collapse to `capture(audioURL:) -> CaptureResult` posting to `/capture`; add `structureText(_:)` posting to `/structure`; expanded `CaptureError`.
- `Services/EntriesService.swift`: add `createCaptureEntries`, `subscribeFirstPage`, `loadMore`, `getCapture`, `subscribeToRange`, `groupByCapture`. Keep `subscribeToToday`, `updateEntry`, `deleteEntry`.
- `Views/Capture/CaptureView.swift`: voice path enqueues + dismisses; typed path keeps in-modal Save.
- `Views/Tabs/MainTabView.swift`: 4-tab enum with `.list`, list icon between today and profile.
- `Views/Tabs/OverviewView.swift`: replace mocks with `subscribeToRange(last 21 days)`; compute streak + last-7-day average.
- `CronwatchApp.swift`: inject `ToastCenter` + `CaptureQueue` env objects; mount `ToastHost`; call `CaptureQueue.cleanupOrphans()` once.

## Data contracts

### Entry

```swift
struct Entry: Identifiable, Hashable, Codable {
    let id: String
    let captureId: String     // falls back to id for legacy single-block docs
    var category: String
    var note: String
    var startTime: Date
    var endTime: Date
    var source: EntrySource
    var transcript: String?
    var audioUrl: String?
    let createdAt: Date
}

struct Capture: Identifiable, Equatable {
    let captureId: String
    let source: EntrySource
    var transcript: String?
    var audioUrl: String?
    let createdAt: Date
    var blocks: [Entry]       // sorted asc by startTime
    var id: String { captureId }
}
```

### Capture pipeline

Single `POST <PROXY>/capture` returns:

```json
{
  "transcript": "string",
  "audioUrl":   "https://...",
  "audioKey":   "string",
  "drafts": [
    { "category": "deep", "note": "...", "startTime": "ISO", "endTime": "ISO" }
  ]
}
```

`POST <PROXY>/structure` (typed path) returns `{ "drafts": [...] }` only.

Swift:

```swift
struct CaptureResult: Equatable {
    let transcript: String
    let audioUrl: String     // "" in stub mode
    let audioKey: String     // "" in stub mode
    let drafts: [CapturedEntryDraft] // always >= 1
}

enum CaptureError: Error {
    case proxyURLMissing
    case captureFailed(Int, String?)
    case structureFailed(Int, String?)
    case notSignedIn
    case decoding(String)
    case emptyDrafts
    case network(Error)
}

enum CaptureService {
    static func capture(audioURL: URL, now: Date = Date()) async throws -> CaptureResult
    static func structureText(_ text: String, now: Date = Date()) async throws -> [CapturedEntryDraft]
}
```

Multipart upload uses field name `audio`, filename `recording.m4a`, content-type `audio/m4a`. Adds form fields `now` (ISO-8601 with fractional seconds) and `tz` (`TimeZone.current.identifier`). `Authorization: Bearer <idToken>` from `AuthService.shared.idToken()`. Decodes drafts; throws `.emptyDrafts` when array is empty.

Stub mode (no `CAPTURE_PROXY_URL`): both methods sleep ~600ms and return canned single-draft data; `audioUrl` and `audioKey` are empty strings so the play button stays hidden.

### EntriesService extensions

```swift
@MainActor
final class EntriesService {
    static let shared: EntriesService

    func subscribeToToday(uid: String, onChange: @escaping ([Entry]) -> Void) -> () -> Void
    func subscribeToRange(uid: String, from: Date, to: Date,
                          onChange: @escaping ([Entry]) -> Void) -> () -> Void
    func subscribeFirstPage(uid: String, pageSize: Int,
                            onChange: @escaping ([Entry], _ lastCursor: DocumentSnapshot?) -> Void) -> () -> Void
    func loadMore(uid: String, cursor: DocumentSnapshot?, pageSize: Int) async throws
        -> (entries: [Entry], lastCursor: DocumentSnapshot?, hasMore: Bool)

    func getEntry(uid: String, id: String) async throws -> Entry?
    func getCapture(uid: String, captureId: String) async throws -> Capture?

    func createCaptureEntries(uid: String, drafts: [CapturedEntryDraft],
                              source: EntrySource, transcript: String?,
                              audioUrl: String?) async throws -> [Entry]
    func updateEntry(uid: String, id: String, category: String?, note: String?,
                     startTime: Date?, endTime: Date?) async throws
    func deleteEntry(uid: String, id: String) async throws

    nonisolated static func groupByCapture(_ entries: [Entry]) -> [Capture]
}
```

Firestore writes: `createCaptureEntries` does a `writeBatch` under one generated `captureId` so a partial failure can't half-save a capture. `transcript`/`audioUrl` write as `NSNull()` when absent.

`getCapture` queries `where("captureId", "==", captureId)`. If empty (legacy single-block doc), falls back to `getDocument(captureId)` and treats the doc id as its own captureId.

`subscribeFirstPage` uses `orderBy("createdAt", descending: true).limit(pageSize)`. `loadMore` adds `start(afterDocument: cursor)`. `hasMore` is `result.count == pageSize`.

Stub mode: in-memory store grows to support all of the above; `subscribeFirstPage` emits a sorted-desc snapshot up to `pageSize` and a `nil` cursor.

## Capture queue + toast + bridge

```swift
enum CaptureJobStatus { case queued, running, error }
struct CaptureJob: Identifiable, Equatable { /* id, uid, audioURL, status, error?, createdAt */ }

@MainActor
final class CaptureQueue: ObservableObject {
    static let shared: CaptureQueue
    @Published private(set) var jobs: [CaptureJob]
    func enqueue(uid: String, audioURL: URL) -> String
    func retry(jobId: String); func retryAll(); func discard(jobId: String)
    static func cleanupOrphans()  // delete Documents/captures contents at boot
}
```

`enqueue` copies the source audio into `Documents/captures/<jobId>.<ext>` (path-stable across modal dismiss), appends a `.queued` job, ticks. The tick pump runs one job at a time: status → running → call `CaptureService.capture` → call `createCaptureEntries` → success: delete local audio + remove job; failure: set status to `.error` with the error message. After each completion, re-tick if any queued remain. Before the Firestore write, re-check `AuthService.shared.currentUser?.uid` and fail the job with "Signed out" on mismatch.

```swift
enum ToastKind { case info, success, error }
struct Toast: Identifiable, Equatable { /* id, message, kind, duration?, action? */ }

@MainActor
final class ToastCenter: ObservableObject {
    static let shared: ToastCenter
    @Published private(set) var current: Toast?
    @discardableResult func show(_ toast: Toast) -> String
    func dismiss(_ id: String? = nil)
}
```

Single-toast model; auto-dismiss via captured-id check after `Task.sleep`. Tap dismisses; action handler runs and then dismisses.

`ToastHost` is a top-anchored SwiftUI overlay with spring transition. Backgrounds: info=ink, success=amber, error=danger. Action label underlined.

`CaptureQueueToastBridge` observes `queue.jobs` and emits exactly the same transitions as RN's `CaptureQueueBridge` (sticky processing toast when any queued/running; success toast on disappearance from running; error toast with Retry on status==error).

`DraftBanner` reads `queue.jobs` filtered to `.error`, mounts inside `EntriesListView` above the list. Header: warning glyph + "N drafts waiting" + "Retry all" + chevron. Expanded rows show formatted time, error message, Retry, Discard (destructive alert before discard).

## List, view-only detail, audio playback

`EntriesListView` mounts:
- `subscribeFirstPage(uid, 50)` on appear → `head: [Entry]`, `headCursor: DocumentSnapshot?`.
- `onEndReached` (computed from `List.onAppear` of the last row): if not currently loading and `hasMore`, calls `loadMore(uid, tailCursor ?? headCursor, 50)` and appends to `tail`.
- Pull-to-refresh: clears `tail`.
- Renders `DraftBanner` + a `List` of `Capture` (via `groupByCapture(head + tail)`).
- Tap row → `selectedCaptureId` state → `.sheet(item: ...)` presenting `EntryViewOnlyView`.

`CaptureRowView` mirrors RN's design exactly:
- Top: 2-line transcript snippet (≤150 chars, ellipsized) + right-aligned dateLine over timeLine (caption, muted).
- Below: one or more block rows: colored dot, category label (semi-bold) and note (muted), right-aligned `HH:mm · 1h 30m`.
- Hairline bottom border.

`EntryViewOnlyView` (sheet, presented with `selectedCaptureId`):
- Drag handle + header (Done · "Entry"/"Capture" · play/pause when audioUrl present).
- Long date below header.
- Block list: colored dot, category bold + optional note, range + duration meta.
- Transcript text at the bottom, selectable.
- On open: `getCapture(uid, captureId)`; if nil, show "Entry not found."
- AudioPlayerService manages a single `AVPlayer`. Play sets up the item from `URL(string: audioUrl)` and `player.play()`. Pause calls `player.pause()`. End-of-item observer flips back to play state. Errors surface to `ToastCenter`.
- On disappear: `player.pause()` + clear current item.

## Overview real data

```swift
@State private var todayEntries: [Entry]
@State private var rangeEntries: [Entry]  // last 21 days
```

- Mount two subscriptions on appear; cancel on disappear.
- Donut and "TODAY" card use `todayEntries`.
- "THIS WEEK · DAILY AVERAGE": compute per-category minutes across the last 7 days (today and 6 prior). Bar widths use the max value as denominator. Header total shows `formatHours(totalMin/7)/day` (the daily average, not the weekly total).
- "TRACKING STREAK": compute `dayFlags: [Bool]` over the last 21 days where each day is "covered" if `coveredMs(rangeEntries, dayStart, dayEnd) >= 24h`. Streak counts consecutive trailing `true`s.
- Title labels exactly match RN.

`computeStreak` and `coveredMs` are pure helpers in `Utils/Streak.swift` (new file).

## App entry

```swift
@main struct CronwatchApp: App {
    @StateObject var auth = AuthService.shared
    @StateObject var rc   = RevenueCatService.shared
    @StateObject var toasts = ToastCenter.shared
    @StateObject var queue  = CaptureQueue.shared
    @StateObject var bridge = CaptureQueueToastBridge()

    init() { CaptureQueue.cleanupOrphans() }

    var body: some Scene {
        WindowGroup {
            ZStack { RootView(); ToastHost() }
                .environmentObject(auth)
                .environmentObject(rc)
                .environmentObject(toasts)
                .environmentObject(queue)
                .onAppear { bridge.observe(queue: queue, toasts: toasts) }
        }
    }
}
```

## Error handling

- `CaptureError.captureFailed/structureFailed` → job error with HTTP status text; toast surfaces "Saved as draft — tap Retry".
- `CaptureError.emptyDrafts` → job error "Empty response".
- `CaptureError.notSignedIn` → "Signed out".
- Firestore write failure → job error with `error.localizedDescription`.
- Audio playback error → `ToastCenter.show(.error, "Couldn't play audio", 3s)`.
- Pagination error → inline retry footer in `EntriesListView`.

## Testing

The repo has no Swift tests yet; the migration adds a small XCTest target only if XcodeGen + an XCTest target is wired (out of scope for v1 if no test target exists). For now: rely on `#Preview` blocks and manual QA matrix copied from the RN spec:

- Hold-to-record → modal closes → toast → entry appears in Today and List.
- Airplane mode mid-capture → error toast + Retry; restore network → Retry → success.
- Typed save → modal closes normally, no toast.
- List scroll past 50 → next page loads.
- Pull-to-refresh on List.
- Tap row → detail → play → audio plays → pause works.
- Row with no audioUrl → no play button.
- Multi-block recording shows "Capture" title and N block lines.
- Sign out → orphans cleaned next launch.

## Risks

- Multipart upload Content-Length: URLSession sets it correctly from the in-memory body Data.
- AVPlayer streaming requires the audio URL to be publicly resolvable for the playback session — the proxy must mint signed URLs (already done for RN).
- Background termination during a job is accepted v1 — the toast is lost, the user sees no draft banner because nothing is persisted. Mitigation in v2: persist queue to UserDefaults + audio files in Documents/captures.

## Out of scope (follow-ups)

- Disk-persisted capture queue.
- Idempotent createCaptureEntries (client UUID echoed by the proxy).
- Search/filter on List, date jump.
- Audio scrubber/waveform on detail.
- Tests target (XCTest).
