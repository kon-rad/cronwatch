# Entries list, view-only detail, and fire-and-forget voice capture

Status: Spec
Date: 2026-05-08

## Goal

Make Cronwatch feel like the user can talk and walk away. Recording stops, the modal closes, a toast says "Processing entry…", the entry shows up by itself. Add a List tab that shows every entry ever, newest first. Add a read-only detail page with audio playback for the saved recording.

## Non-goals

- No editing on the new view page (existing `entry/[id]` edit form stays).
- No category filter, search, or date jumping in the list view (yet).
- No scrubber on audio playback — just play/pause toggle.
- No multi-toast stacking — one at a time, queued internally if needed.

## User flows

### Voice capture (fire-and-forget)

1. User taps the FAB on any tab → `capture` modal opens.
2. User holds the big mic button → `onPressIn` starts recording.
3. User releases → `onPressOut`:
   - `audioRecorder.stop()` resolves; the file URI is captured.
   - The capture is enqueued in `captureQueue`.
   - `router.back()` closes the modal.
   - A sticky toast appears: "Processing entry…".
4. In the background:
   - `captureFromAudio(uri)` (transcribe + structure on the proxy)
   - `createEntry(uid, …)` writes to Firestore
   - On success: dismiss the sticky toast, show success toast "Entry saved." for 2s.
   - On failure: dismiss sticky, show error toast "Couldn't save entry" for 4s with a "Retry" action that re-runs the same job from the original URI.
5. Because the first page of the List tab and the Today grid both subscribe live, the new entry appears in both as soon as Firestore returns.

### Typed capture (unchanged confirmation)

User types in the modal's text input → taps Send / Save → existing flow runs to completion in the modal, then `router.back()`. No toast involved.

### List tab

1. User taps the List icon (third position, between Today and Profile) → `(tabs)/list.tsx`.
2. First 50 entries load via a live subscription, ordered by `createdAt desc` (most-recently-captured on top, regardless of when the activity itself happened).
3. Each row: colored dot + category title; 150-char transcript snippet under the title; right side shows two stacked lines — date ("May 8") on top, time ("2:30 PM") below — derived from the entry's `startTime` (the time the user said the activity occurred), via device locale.
4. `onEndReached` loads the next page of 50 (one-shot read with cursor on `createdAt`). Loaded older pages are appended in memory; they don't auto-update if older entries change (acceptable trade-off — captures are write-once in practice).
5. Pull-to-refresh resets to the live first page.
6. Tap row → `entry/view/[id]`.

### Entry detail (view-only)

1. Modal-presented route at `entry/view/[id]`.
2. Header: `Done` (left) · "Entry" (center title) · play/pause icon (right, hidden if `audioUrl` is missing).
3. Body sections:
   - Category (large title, `t.title`) with the category's colored dot beside it.
   - Date and time it was recorded, in `colors.muted` (e.g. "May 8, 2026 · 9:00 AM").
   - Duration line ("1 hour 30 min", "45 min", "2 hours", "1 hour").
   - Range line ("9:00 AM — 10:30 AM").
   - Transcript as body text, selectable.
4. Audio: when the play button is tapped, an `expo-audio` player loads the `audioUrl` and plays. Tapping again pauses. The player is disposed on unmount or screen blur.

## Architecture

### New files

```
client/
  app/
    (tabs)/list.tsx                # paginated entries list
    entry/view/[id].tsx            # view-only detail with playback
  components/
    Toast.tsx                      # presentational toast view
    EntryRow.tsx                   # a single row in the list
  services/
    captureQueue.ts                # in-memory background processor
    toast.ts                       # context provider + useToast() hook
  utils/
    duration.ts                    # formatDurationHuman(ms)
    listDate.ts                    # formatRowDateTime(iso)
```

### Modified files

```
client/app/_layout.tsx             # mount <ToastProvider/>; wire bridge to captureQueue
client/app/(tabs)/_layout.tsx      # add 4th tab "list" with List icon
client/app/capture.tsx             # voice path enqueues job, calls router.back(), shows toast
client/services/entries.ts         # add subscribeFirstPage, loadMore, getEntry
```

### Module boundaries

- **`captureQueue`** owns the lifecycle of a voice capture after the modal closes. Pure module singleton with `enqueue(uri, uid) -> jobId`, `subscribe(cb)`, internal `Job[]` state. Calls `captureFromAudio` and `createEntry`. Knows nothing about UI; emits status changes for any subscriber.
- **`toast`** owns user-visible status. Provider holds `Toast[]` (queue), exposes `show()` / `dismiss()`. `_layout.tsx` includes a bridge `useEffect` that subscribes to `captureQueue` and calls `toast.show()` based on job status transitions.
- **`entries`** owns Firestore reads/writes. Adds `subscribeFirstPage(uid, n, cb)` (live, ordered `createdAt desc`), `loadMore(uid, cursorDoc, n)` (one-shot), and `getEntry(uid, id)` for the view route. Existing `subscribeToToday` and `createEntry` are unchanged.

### Data flow diagrams

```
[Capture modal]
  onPressOut
    └─> audioRecorder.stop()
    └─> captureQueue.enqueue(uri, uid)   ── jobId ──┐
    └─> router.back()                                │
                                                     │
[ToastProvider bridge in _layout]                    │
  subscribes to captureQueue                         │
    on job.queued|running -> toast.show(sticky)      │
    on job.done           -> dismiss sticky,         │
                              show "Entry saved."    │
    on job.error          -> dismiss sticky,         │
                              show error + retry     │
                                                     │
[captureQueue (singleton)]  <──────────────────────┘
  while jobs queued:
    job.status = 'running'
    captureFromAudio(uri)       (transcribe + structure)
    createEntry(uid, draft)     (write Firestore)
    job.status = 'done' | 'error'
```

```
[List tab]
  mount:
    subscribeFirstPage(uid, 50, setHead)
  onEndReached:
    if !loadingMore && hasMore:
      loadMore(uid, lastCursor, 50) -> setTail(prev => prev.concat(...))
  pull-to-refresh:
    discard tail; subscription stays live for head
```

## Public API additions

```ts
// services/captureQueue.ts
export type Job = {
  id: string;
  uid: string;
  uri: string;
  status: 'queued' | 'running' | 'done' | 'error';
  error?: string;
};
export function enqueue(uid: string, uri: string): string; // returns jobId
export function retry(jobId: string): void;
export function subscribe(cb: (jobs: Job[]) => void): () => void;

// services/toast.ts
export type ToastKind = 'info' | 'success' | 'error';
export type ToastInput = {
  message: string;
  kind?: ToastKind;
  duration?: number;            // ms; omit/0 = sticky
  action?: { label: string; onPress: () => void };
};
export function ToastProvider(props: { children: React.ReactNode }): JSX.Element;
export function useToast(): {
  show(input: ToastInput): string; // returns id
  dismiss(id?: string): void;       // omit = dismiss current
};

// services/entries.ts
export function subscribeFirstPage(
  uid: string,
  pageSize: number,
  cb: (entries: Entry[], lastCursor: unknown) => void,
): () => void;
export function loadMore(
  uid: string,
  cursor: unknown,
  pageSize: number,
): Promise<{ entries: Entry[]; lastCursor: unknown; hasMore: boolean }>;
export function getEntry(uid: string, id: string): Promise<Entry | null>;

// utils/duration.ts
export function formatDurationHuman(ms: number): string; // "1 hour 30 min"

// utils/listDate.ts
export function formatRowDateTime(iso: string): { dateLine: string; timeLine: string };
```

## UI specifics

### Tabs layout

Tab order becomes: `overview`, `today`, `list`, `profile`. The List tab uses `lucide-react-native`'s `List` icon (already a dependency) at `strokeWidth: 1.75` to match siblings.

### Toast appearance

- Position: anchored at top of screen, below safe-area inset, full-width minus 16px horizontal margin, 12px below the inset.
- Slide-in: translateY -64 → 0, 220ms ease-out. Slide-out reversed.
- Background: `colors.ink` for info/sticky, `colors.amber` for success, `colors.danger` for error. Text in `colors.white`. Bordered with subtle shadow (`shadow.fab`).
- Tap: dismiss immediately. Action button (when present): right-aligned label in `colors.white` with underline, separate hit target.

### EntryRow

```
┌──────────────────────────────────────────────────────────────┐
│ ●  Deep                                              May 8   │
│    Working on the auth refactor and pushed the       9:00 AM │
│    new middleware to staging. Took about an…                 │
└──────────────────────────────────────────────────────────────┘
```

- Dot: 8×8, `radii.pill`, color from `colorForCategory(entry.category)`.
- Title: the category's display label (resolved by looking up `entry.category` in `CATEGORIES` for the friendly form like "Deep", falling back to the raw `entry.category` string when unknown). `t.body` weight 600, `colors.ink`, single-line truncate.
- Snippet: first 150 chars of `entry.transcript` (fallback to `entry.note` if no transcript), `t.caption` color `colors.muted`, max 2 lines.
- Right column: stacked text right-aligned. `dateLine` `t.caption` `colors.muted`; `timeLine` `t.caption` `colors.muted` with `tabular`.
- Row padding: `spacing.md` horizontal / 14 vertical. Hairline border bottom.

### Entry view detail

- Same modal chrome as `entry/[id]` (handle, header).
- Right header slot: a `Pressable` with `Play` or `Pause` icon (lucide). Hidden when `entry.audioUrl` is empty/null. 32×32 hit area.
- Title row: `colorForCategory` dot 10×10 + category display label (looked up the same way as on rows) in `t.title`.
- Meta lines below the title use `t.caption` color `colors.muted`.

### Duration formatting

- 0 min: `"—"`.
- < 60 min: `"45 min"`.
- Whole hours: `"1 hour"`, `"2 hours"`.
- Hours + minutes: `"1 hour 30 min"`, `"2 hours 15 min"`.

## Error handling

- **Queue job error**: keep the job in the queue with `status:'error'` and `error` message. Toast shows "Couldn't save entry" (4s) with a Retry action that calls `captureQueue.retry(jobId)` to re-run.
- **Get entry on view page**: if `getEntry` returns `null`, show "Entry not found." inside the modal (matches existing edit page).
- **Audio playback failure**: catch in the player effect; toast "Couldn't play audio" 3s; do not crash the screen.
- **Pagination error**: surface inline at list bottom: "Couldn't load more — tap to retry".
- **Auth gone mid-capture**: queue worker checks `getCurrentUser()` before save; if absent, mark job error "Signed out".

## Testing strategy

Unit tests where the project already has them (none yet — the codebase is currently devoid of tests). For this change:

- `utils/duration.ts`: deterministic table of inputs → outputs.
- `utils/listDate.ts`: snapshot under a fixed locale + tz.
- Manual QA matrix:
  - Hold-to-record short clip → modal closes → "Processing…" toast → "Entry saved." → row visible on Today and List.
  - Force airplane mode mid-capture → error toast with Retry → re-enable network → tap Retry → success.
  - Type an entry, tap Save → modal closes normally, no toast.
  - Open List, scroll past 50 entries → next page loads.
  - Pull-to-refresh on List.
  - Tap a list row → view detail → tap play → hear audio → tap again → pauses.
  - Tap a list row whose entry has no `audioUrl` → no play button visible.
  - Background the app during processing → return → toast still reflects final state (success or error).

## Risks and open questions

- **Background termination**: if iOS suspends the app between modal-close and Firestore write, the in-flight request can be killed. We accept this for v1 — the user will see an error toast on resume; the entry isn't double-charged because we only call `createEntry` once per job. A future improvement is to persist the job (URI + timestamps) to disk so we can resume across cold starts.
- **Duplicate entries on retry**: `createEntry` is non-idempotent. If the network call to `/capture` succeeded but the response was lost, a Retry would re-upload and re-charge transcription. Acceptable for v1; mitigation later is a client-generated UUID echoed by the proxy.
- **Pagination semantics on edits**: older pages are static reads. If a user edits an old entry on Today, the List tab won't reflect it until refresh. Acceptable — edits to old entries are rare from this surface.
- **Audio player lifecycle**: `expo-audio` deprecates `Audio` from `expo-av`. Using `useAudioPlayer({uri})` requires the URL to be reachable and unauthenticated, or signed long enough to play. Confirm Firebase Storage URLs we save are signed/public for the playback duration; otherwise the proxy must mint a signed URL on read.

## Out of scope (followups)

- Disk-persisted capture queue (survives cold starts).
- Idempotent `createEntry` with client UUID.
- Search and category filter on List.
- Calendar-style jump in List ("Jump to date").
- Audio scrubber and waveform on the detail page.
