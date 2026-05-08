# Entries list & fire-and-forget capture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a List tab with paginated entries, a view-only detail page with audio playback, and a fire-and-forget voice capture flow with toast notifications.

**Architecture:** Background `captureQueue` singleton runs transcribe+structure+save off the modal, an in-app `ToastProvider` shows status, the existing `entries` service gains `subscribeFirstPage` / `loadMore` / `getEntry`, and a new `entry/view/[id]` route renders a read-only detail with `expo-audio` playback. Pure utility modules handle duration and locale-aware date formatting and are unit-tested with `jest-expo`. UI is verified with the manual-QA matrix from the spec.

**Tech Stack:** React Native + Expo Router, TypeScript, Firebase Firestore, `expo-audio`, `lucide-react-native`, `jest-expo` (added in this plan).

**Spec:** `docs/superpowers/specs/2026-05-08-entries-list-and-fire-and-forget-capture-design.md`

---

## File Structure

**Create:**
- `client/utils/duration.ts` — `formatDurationHuman(ms)`
- `client/utils/duration.test.ts`
- `client/utils/listDate.ts` — `formatRowDateTime(iso)`
- `client/utils/listDate.test.ts`
- `client/services/toast.tsx` — `ToastProvider`, `useToast()`
- `client/services/captureQueue.ts` — singleton with `enqueue` / `retry` / `subscribe`
- `client/components/Toast.tsx` — presentational toast view
- `client/components/EntryRow.tsx` — list row
- `client/app/(tabs)/list.tsx` — list tab screen
- `client/app/entry/view/[id].tsx` — view-only detail screen
- `client/jest.setup.ts` — minimal jest setup file

**Modify:**
- `client/package.json` — add `jest-expo`, `jest`, `@types/jest`, `test` script, `jest` config
- `client/app/_layout.tsx` — mount `<ToastProvider/>`, add `<Stack.Screen name="entry/view/[id]" presentation="modal" />`, wire bridge from `captureQueue` to toast
- `client/app/(tabs)/_layout.tsx` — add `list` tab between `today` and `profile` with `List` icon
- `client/app/capture.tsx` — voice path enqueues to `captureQueue` and calls `router.back()` immediately; typed path unchanged
- `client/services/entries.ts` — add `subscribeFirstPage`, `loadMore`, `getEntry`

---

### Task 1: Add jest-expo so we can unit-test pure utilities

**Files:**
- Modify: `client/package.json`
- Create: `client/jest.setup.ts`

- [ ] **Step 1: Install dev deps**

Run from `client/`:

```bash
npm install --save-dev jest jest-expo @types/jest
```

Expected: deps installed, `package-lock.json` updated.

- [ ] **Step 2: Add the test script and jest config to `client/package.json`**

Edit `client/package.json`. After the existing `"web": "expo start --web"` line in `"scripts"`, add:

```json
    "test": "jest"
```

Then, as a sibling of `"private": true` (top-level), add:

```json
  "jest": {
    "preset": "jest-expo",
    "setupFiles": ["<rootDir>/jest.setup.ts"],
    "testPathIgnorePatterns": ["/node_modules/", "/android/", "/ios/"]
  }
```

- [ ] **Step 3: Create `client/jest.setup.ts`**

```ts
// Global jest setup. Pin TZ + locale so date/time tests are deterministic
// regardless of the developer's machine.
process.env.TZ = 'America/New_York';
```

- [ ] **Step 4: Smoke-check the test runner**

Create a throwaway test at `client/utils/__smoke__.test.ts`:

```ts
test('jest is wired up', () => {
  expect(1 + 1).toBe(2);
});
```

Run: `npm test --prefix client -- --runTestsByPath utils/__smoke__.test.ts`

Expected: 1 test passes.

- [ ] **Step 5: Delete the smoke test**

```bash
rm client/utils/__smoke__.test.ts
```

- [ ] **Step 6: Commit**

```bash
git add client/package.json client/package-lock.json client/jest.setup.ts
git commit -m "test: add jest-expo for unit testing pure modules"
```

---

### Task 2: `formatDurationHuman` (pure util, TDD)

**Files:**
- Create: `client/utils/duration.test.ts`
- Create: `client/utils/duration.ts`

- [ ] **Step 1: Write the failing test**

`client/utils/duration.test.ts`:

```ts
import { formatDurationHuman } from './duration';

describe('formatDurationHuman', () => {
  test('zero ms returns em-dash', () => {
    expect(formatDurationHuman(0)).toBe('—');
  });
  test('negative ms returns em-dash', () => {
    expect(formatDurationHuman(-5_000)).toBe('—');
  });
  test('under one hour reports minutes', () => {
    expect(formatDurationHuman(45 * 60_000)).toBe('45 min');
  });
  test('one minute is "1 min"', () => {
    expect(formatDurationHuman(60_000)).toBe('1 min');
  });
  test('exactly one hour says "1 hour"', () => {
    expect(formatDurationHuman(60 * 60_000)).toBe('1 hour');
  });
  test('exactly two hours says "2 hours"', () => {
    expect(formatDurationHuman(2 * 60 * 60_000)).toBe('2 hours');
  });
  test('1h30m says "1 hour 30 min"', () => {
    expect(formatDurationHuman(90 * 60_000)).toBe('1 hour 30 min');
  });
  test('2h15m says "2 hours 15 min"', () => {
    expect(formatDurationHuman(135 * 60_000)).toBe('2 hours 15 min');
  });
  test('rounds to nearest minute', () => {
    expect(formatDurationHuman(89 * 60_000 + 30_000)).toBe('1 hour 30 min');
  });
});
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `npm test --prefix client -- --runTestsByPath utils/duration.test.ts`

Expected: FAIL — module `./duration` not found.

- [ ] **Step 3: Implement `formatDurationHuman`**

`client/utils/duration.ts`:

```ts
export function formatDurationHuman(ms: number): string {
  if (!Number.isFinite(ms) || ms <= 0) return '—';
  const totalMin = Math.round(ms / 60_000);
  const hours = Math.floor(totalMin / 60);
  const mins = totalMin % 60;
  if (hours === 0) return `${mins} min`;
  const hourPart = hours === 1 ? '1 hour' : `${hours} hours`;
  if (mins === 0) return hourPart;
  return `${hourPart} ${mins} min`;
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `npm test --prefix client -- --runTestsByPath utils/duration.test.ts`

Expected: 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/utils/duration.ts client/utils/duration.test.ts
git commit -m "feat(util): formatDurationHuman for view-only entry detail"
```

---

### Task 3: `formatRowDateTime` (pure util, TDD)

**Files:**
- Create: `client/utils/listDate.test.ts`
- Create: `client/utils/listDate.ts`

- [ ] **Step 1: Write the failing test**

`client/utils/listDate.test.ts`:

```ts
import { formatRowDateTime } from './listDate';

// jest.setup.ts pins TZ to America/New_York. Locale defaults to 'en-US' on Node.
describe('formatRowDateTime', () => {
  test('returns localized date and time lines', () => {
    const out = formatRowDateTime('2026-05-08T18:30:00Z'); // 2:30 PM Eastern
    expect(out.dateLine).toBe('May 8');
    expect(out.timeLine.toLowerCase()).toContain('2:30');
    expect(out.timeLine.toUpperCase()).toContain('PM');
  });
  test('rolls over to previous day when UTC date differs from local date', () => {
    // 2026-05-09 02:00 UTC == 2026-05-08 22:00 Eastern
    const out = formatRowDateTime('2026-05-09T02:00:00Z');
    expect(out.dateLine).toBe('May 8');
  });
  test('handles January single-digit days', () => {
    const out = formatRowDateTime('2026-01-03T15:00:00Z');
    expect(out.dateLine).toBe('Jan 3');
  });
});
```

- [ ] **Step 2: Run, verify fail**

Run: `npm test --prefix client -- --runTestsByPath utils/listDate.test.ts`

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `formatRowDateTime`**

`client/utils/listDate.ts`:

```ts
export function formatRowDateTime(iso: string): { dateLine: string; timeLine: string } {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return { dateLine: '', timeLine: '' };
  const dateLine = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  const timeLine = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  return { dateLine, timeLine };
}
```

- [ ] **Step 4: Run, verify pass**

Run: `npm test --prefix client -- --runTestsByPath utils/listDate.test.ts`

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add client/utils/listDate.ts client/utils/listDate.test.ts
git commit -m "feat(util): formatRowDateTime for entries list rows"
```

---

### Task 4: `Toast` presentational component

**Files:**
- Create: `client/components/Toast.tsx`

- [ ] **Step 1: Implement the component**

`client/components/Toast.tsx`:

```tsx
import { useEffect, useRef } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, radii, shadow, spacing } from '@/theme/tokens';
import { type as t } from '@/theme/typography';

export type ToastKind = 'info' | 'success' | 'error';

export type ToastViewProps = {
  message: string;
  kind: ToastKind;
  action?: { label: string; onPress: () => void };
  onDismiss: () => void;
};

const BG: Record<ToastKind, string> = {
  info: colors.ink,
  success: colors.amber,
  error: colors.danger,
};

export function ToastView({ message, kind, action, onDismiss }: ToastViewProps) {
  const insets = useSafeAreaInsets();
  const translate = useRef(new Animated.Value(-80)).current;

  useEffect(() => {
    Animated.timing(translate, {
      toValue: 0,
      duration: 220,
      easing: Easing.out(Easing.ease),
      useNativeDriver: true,
    }).start();
  }, [translate]);

  return (
    <Animated.View
      pointerEvents="box-none"
      style={[
        styles.wrap,
        {
          top: insets.top + spacing.sm,
          transform: [{ translateY: translate }],
        },
      ]}
    >
      <Pressable
        onPress={onDismiss}
        accessibilityRole="alert"
        style={[styles.toast, shadow.fab, { backgroundColor: BG[kind] }]}
      >
        <Text style={[t.body, styles.message]} numberOfLines={2}>
          {message}
        </Text>
        {action ? (
          <Pressable onPress={action.onPress} hitSlop={8} style={styles.actionWrap}>
            <Text style={[t.body, styles.action]}>{action.label}</Text>
          </Pressable>
        ) : null}
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    left: spacing.md,
    right: spacing.md,
  },
  toast: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    borderRadius: radii.md,
  },
  message: {
    flex: 1,
    color: colors.white,
    fontWeight: '600',
  },
  actionWrap: { paddingLeft: spacing.sm },
  action: {
    color: colors.white,
    fontWeight: '600',
    textDecorationLine: 'underline',
  },
});
```

- [ ] **Step 2: Manual smoke**

No test runner for RN components in this project. Confirm the file compiles by running:

```bash
cd client && npx tsc --noEmit
```

Expected: no TypeScript errors.

- [ ] **Step 3: Commit**

```bash
git add client/components/Toast.tsx
git commit -m "feat(ui): Toast presentational component with slide-in animation"
```

---

### Task 5: `toast` service — provider + hook

**Files:**
- Create: `client/services/toast.tsx`

- [ ] **Step 1: Implement the provider**

`client/services/toast.tsx`:

```tsx
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { ToastView, type ToastKind } from '@/components/Toast';

export type ToastInput = {
  message: string;
  kind?: ToastKind;
  duration?: number; // ms; omit/0 = sticky (no auto-hide)
  action?: { label: string; onPress: () => void };
};

type ActiveToast = ToastInput & { id: string; kind: ToastKind };

type Ctx = {
  show: (input: ToastInput) => string;
  dismiss: (id?: string) => void;
};

const ToastCtx = createContext<Ctx | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [active, setActive] = useState<ActiveToast | null>(null);
  const queueRef = useRef<ActiveToast[]>([]);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showNext = useCallback(() => {
    const next = queueRef.current.shift() ?? null;
    setActive(next);
    if (next && next.duration && next.duration > 0) {
      timerRef.current = setTimeout(() => {
        setActive(null);
        showNext();
      }, next.duration);
    }
  }, []);

  const show = useCallback(
    (input: ToastInput): string => {
      const id = `t_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
      const t: ActiveToast = { id, kind: input.kind ?? 'info', ...input };
      if (active) {
        queueRef.current.push(t);
      } else {
        setActive(t);
        if (t.duration && t.duration > 0) {
          timerRef.current = setTimeout(() => {
            setActive(null);
            showNext();
          }, t.duration);
        }
      }
      return id;
    },
    [active, showNext],
  );

  const dismiss = useCallback(
    (id?: string) => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      setActive((cur) => {
        if (!cur) return null;
        if (id && cur.id !== id) {
          // dismissing a queued or already-gone toast: drop from queue if present
          queueRef.current = queueRef.current.filter((q) => q.id !== id);
          return cur;
        }
        return null;
      });
      // schedule next on a microtask so setActive(null) lands first
      setTimeout(() => showNext(), 0);
    },
    [showNext],
  );

  useEffect(
    () => () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    },
    [],
  );

  const ctx = useMemo<Ctx>(() => ({ show, dismiss }), [show, dismiss]);

  return (
    <ToastCtx.Provider value={ctx}>
      {children}
      {active ? (
        <ToastView
          message={active.message}
          kind={active.kind}
          action={active.action}
          onDismiss={() => dismiss(active.id)}
        />
      ) : null}
    </ToastCtx.Provider>
  );
}

export function useToast(): Ctx {
  const ctx = useContext(ToastCtx);
  if (!ctx) throw new Error('useToast must be used inside <ToastProvider>');
  return ctx;
}
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/services/toast.tsx
git commit -m "feat(ui): ToastProvider + useToast hook (single-toast queue)"
```

---

### Task 6: `captureQueue` service singleton

**Files:**
- Create: `client/services/captureQueue.ts`

- [ ] **Step 1: Implement the queue**

`client/services/captureQueue.ts`:

```ts
import { captureFromAudio } from '@/services/capture';
import { createEntry } from '@/services/entries';

export type JobStatus = 'queued' | 'running' | 'done' | 'error';

export type Job = {
  id: string;
  uid: string;
  uri: string;
  status: JobStatus;
  error?: string;
};

type Listener = (jobs: Job[]) => void;

let jobs: Job[] = [];
const listeners = new Set<Listener>();
let working = false;

function emit() {
  const snap = [...jobs];
  for (const l of listeners) l(snap);
}

function nextJobId(): string {
  return `j_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
}

async function tick(): Promise<void> {
  if (working) return;
  const job = jobs.find((j) => j.status === 'queued');
  if (!job) return;
  working = true;
  job.status = 'running';
  job.error = undefined;
  emit();
  try {
    const result = await captureFromAudio(job.uri);
    await createEntry(job.uid, {
      ...result.draft,
      source: 'voice',
      transcript: result.transcript,
      audioUrl: result.audioUrl,
    });
    job.status = 'done';
    emit();
    // remove the job a beat later so subscribers see the 'done' transition
    setTimeout(() => {
      jobs = jobs.filter((j) => j.id !== job.id);
      emit();
    }, 0);
  } catch (err) {
    job.status = 'error';
    job.error = err instanceof Error ? err.message : 'Unknown error';
    emit();
  } finally {
    working = false;
    if (jobs.some((j) => j.status === 'queued')) {
      void tick();
    }
  }
}

export function enqueue(uid: string, uri: string): string {
  const job: Job = { id: nextJobId(), uid, uri, status: 'queued' };
  jobs.push(job);
  emit();
  void tick();
  return job.id;
}

export function retry(jobId: string): void {
  const job = jobs.find((j) => j.id === jobId);
  if (!job || job.status !== 'error') return;
  job.status = 'queued';
  job.error = undefined;
  emit();
  void tick();
}

export function subscribe(cb: Listener): () => void {
  listeners.add(cb);
  cb([...jobs]);
  return () => {
    listeners.delete(cb);
  };
}

// Test/dev only — clear all in-memory state.
export function __reset(): void {
  jobs = [];
  listeners.clear();
  working = false;
}
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/services/captureQueue.ts
git commit -m "feat(capture): in-memory background queue for voice captures"
```

---

### Task 7: Add pagination + getEntry to `entries.ts`

**Files:**
- Modify: `client/services/entries.ts`

- [ ] **Step 1: Add the new public functions**

Open `client/services/entries.ts`. Replace the imports block at the top with:

```ts
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  DocumentSnapshot,
  getDoc,
  getDocs,
  limit as fbLimit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  startAfter,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
```

Then, just below `subscribeToToday(...)` and before `parseIso(...)`, add:

```ts
export function subscribeFirstPage(
  uid: string,
  pageSize: number,
  cb: (entries: Entry[], lastCursor: DocumentSnapshot | null) => void,
): () => void {
  const col = entriesCol(uid);
  if (!col) {
    const fire = () => {
      const snap = stubSnapshot().slice().reverse().slice(0, pageSize);
      cb(snap, null);
    };
    stubListeners.add(fire as Listener);
    fire();
    return () => stubListeners.delete(fire as Listener);
  }
  const q = query(col, orderBy('createdAt', 'desc'), fbLimit(pageSize));
  return onSnapshot(q, (snap) => {
    const entries = snap.docs.map((d) =>
      fromFirestore(d.id, d.data() as Record<string, unknown>),
    );
    const lastCursor = snap.docs.length ? snap.docs[snap.docs.length - 1] : null;
    cb(entries, lastCursor);
  });
}

export async function loadMore(
  uid: string,
  cursor: DocumentSnapshot | null,
  pageSize: number,
): Promise<{ entries: Entry[]; lastCursor: DocumentSnapshot | null; hasMore: boolean }> {
  const col = entriesCol(uid);
  if (!col || !cursor) {
    return { entries: [], lastCursor: null, hasMore: false };
  }
  const q = query(
    col,
    orderBy('createdAt', 'desc'),
    startAfter(cursor),
    fbLimit(pageSize),
  );
  const snap = await getDocs(q);
  const entries = snap.docs.map((d) =>
    fromFirestore(d.id, d.data() as Record<string, unknown>),
  );
  const lastCursor = snap.docs.length ? snap.docs[snap.docs.length - 1] : null;
  return { entries, lastCursor, hasMore: entries.length === pageSize };
}

export async function getEntry(uid: string, id: string): Promise<Entry | null> {
  const col = entriesCol(uid);
  if (!col) {
    return stubStore.find((e) => e.id === id) ?? null;
  }
  const ref = doc(col, id);
  const snap = await getDoc(ref);
  if (!snap.exists()) return null;
  return fromFirestore(snap.id, snap.data() as Record<string, unknown>);
}
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/services/entries.ts
git commit -m "feat(entries): subscribeFirstPage, loadMore, getEntry for List tab"
```

---

### Task 8: `EntryRow` list item component

**Files:**
- Create: `client/components/EntryRow.tsx`

- [ ] **Step 1: Implement the row**

`client/components/EntryRow.tsx`:

```tsx
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { CATEGORIES, colorForCategory } from '@/theme/categories';
import { formatRowDateTime } from '@/utils/listDate';
import type { Entry } from '@/types/entry';

type Props = {
  entry: Entry;
  onPress: () => void;
};

function categoryLabel(key: string): string {
  const found = CATEGORIES.find((c) => c.key === key);
  if (found) return found.label;
  const lower = key.toLowerCase();
  const byLabel = CATEGORIES.find((c) => c.label.toLowerCase() === lower);
  return byLabel ? byLabel.label : key || 'Entry';
}

function snippet(entry: Entry): string {
  const text = (entry.transcript ?? entry.note ?? '').trim();
  if (text.length <= 150) return text;
  return text.slice(0, 150).trimEnd() + '…';
}

export function EntryRow({ entry, onPress }: Props) {
  const { dateLine, timeLine } = formatRowDateTime(entry.startTime);
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, { opacity: pressed ? 0.7 : 1 }]}
      accessibilityRole="button"
      accessibilityLabel={`${categoryLabel(entry.category)} entry`}
    >
      <View style={[styles.dot, { backgroundColor: colorForCategory(entry.category) }]} />
      <View style={styles.body}>
        <Text style={[t.body, styles.title]} numberOfLines={1}>
          {categoryLabel(entry.category)}
        </Text>
        <Text style={[t.caption, styles.snippet]} numberOfLines={2}>
          {snippet(entry) || '—'}
        </Text>
      </View>
      <View style={styles.right}>
        <Text style={[t.caption, styles.dateLine]}>{dateLine}</Text>
        <Text style={[t.caption, styles.timeLine, tabular]}>{timeLine}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: 14,
    gap: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.border,
    backgroundColor: colors.bg,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: radii.pill,
    marginTop: 6,
  },
  body: { flex: 1, gap: 2 },
  title: { color: colors.ink, fontWeight: '600' },
  snippet: { color: colors.muted },
  right: { alignItems: 'flex-end', minWidth: 64 },
  dateLine: { color: colors.muted },
  timeLine: { color: colors.muted },
});
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/components/EntryRow.tsx
git commit -m "feat(ui): EntryRow component for the List tab"
```

---

### Task 9: List tab screen

**Files:**
- Create: `client/app/(tabs)/list.tsx`

- [ ] **Step 1: Implement the screen**

`client/app/(tabs)/list.tsx`:

```tsx
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import type { DocumentSnapshot } from 'firebase/firestore';
import { colors, spacing } from '@/theme/tokens';
import { type as t } from '@/theme/typography';
import { EntryRow } from '@/components/EntryRow';
import { getCurrentUser } from '@/services/auth';
import { loadMore, subscribeFirstPage } from '@/services/entries';
import type { Entry } from '@/types/entry';

const PAGE_SIZE = 50;

export default function List() {
  const router = useRouter();
  const [head, setHead] = useState<Entry[]>([]);
  const [tail, setTail] = useState<Entry[]>([]);
  const [headCursor, setHeadCursor] = useState<DocumentSnapshot | null>(null);
  const [tailCursor, setTailCursor] = useState<DocumentSnapshot | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  useEffect(() => {
    const uid = getCurrentUser()?.uid ?? 'stub-user';
    return subscribeFirstPage(uid, PAGE_SIZE, (entries, lastCursor) => {
      setHead(entries);
      setHeadCursor(lastCursor);
    });
  }, []);

  const onEndReached = useCallback(async () => {
    if (loadingMore || !hasMore) return;
    const cursor = tailCursor ?? headCursor;
    if (!cursor) return;
    const uid = getCurrentUser()?.uid ?? 'stub-user';
    setLoadingMore(true);
    try {
      const next = await loadMore(uid, cursor, PAGE_SIZE);
      setTail((prev) => [...prev, ...next.entries]);
      setTailCursor(next.lastCursor);
      setHasMore(next.hasMore);
    } finally {
      setLoadingMore(false);
    }
  }, [loadingMore, hasMore, headCursor, tailCursor]);

  const onRefresh = useCallback(() => {
    setTail([]);
    setTailCursor(null);
    setHasMore(true);
  }, []);

  const data = [...head, ...tail];

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <View style={styles.header}>
        <Text style={[t.title, { color: colors.ink }]}>Entries</Text>
      </View>
      <FlatList
        data={data}
        keyExtractor={(e) => e.id}
        renderItem={({ item }) => (
          <EntryRow entry={item} onPress={() => router.push(`/entry/view/${item.id}`)} />
        )}
        onEndReached={onEndReached}
        onEndReachedThreshold={0.4}
        refreshControl={<RefreshControl refreshing={false} onRefresh={onRefresh} />}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={[t.body, { color: colors.muted }]}>No entries yet.</Text>
          </View>
        }
        ListFooterComponent={
          loadingMore ? (
            <View style={styles.footer}>
              <ActivityIndicator color={colors.muted} />
            </View>
          ) : null
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  header: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    paddingBottom: spacing.sm,
  },
  empty: { alignItems: 'center', justifyContent: 'center', padding: spacing.xl },
  footer: { padding: spacing.md, alignItems: 'center' },
});
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/app/\(tabs\)/list.tsx
git commit -m "feat(list): paginated List tab screen"
```

---

### Task 10: Add the List tab to the tabs layout

**Files:**
- Modify: `client/app/(tabs)/_layout.tsx`

- [ ] **Step 1: Import the List icon**

In `client/app/(tabs)/_layout.tsx`, change the import line:

```tsx
import { Calendar, Home, User, Mic } from 'lucide-react-native';
```

to:

```tsx
import { Calendar, Home, List as ListIcon, User, Mic } from 'lucide-react-native';
```

- [ ] **Step 2: Insert the new tab between `today` and `profile`**

Inside the `<Tabs ...>` block, insert this `<Tabs.Screen ... name="list" />` directly after the `today` tab and before `profile`:

```tsx
        <Tabs.Screen
          name="list"
          options={{
            tabBarIcon: ({ color, size }) => (
              <ListIcon color={color} size={size} strokeWidth={1.75} />
            ),
          }}
        />
```

- [ ] **Step 3: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add client/app/\(tabs\)/_layout.tsx
git commit -m "feat(nav): add List tab between Today and Profile"
```

---

### Task 11: View-only entry detail screen

**Files:**
- Create: `client/app/entry/view/[id].tsx`

- [ ] **Step 1: Implement the screen**

`client/app/entry/view/[id].tsx`:

```tsx
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Pause, Play } from 'lucide-react-native';
import {
  setAudioModeAsync,
  useAudioPlayer,
  useAudioPlayerStatus,
} from 'expo-audio';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { CATEGORIES, colorForCategory } from '@/theme/categories';
import { getEntry } from '@/services/entries';
import { getCurrentUser } from '@/services/auth';
import { useToast } from '@/services/toast';
import { formatDurationHuman } from '@/utils/duration';
import type { Entry } from '@/types/entry';

function categoryLabel(key: string): string {
  const found = CATEGORIES.find((c) => c.key === key);
  if (found) return found.label;
  const lower = key.toLowerCase();
  const byLabel = CATEGORIES.find((c) => c.label.toLowerCase() === lower);
  return byLabel ? byLabel.label : key || 'Entry';
}

function fmtDateLong(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });
}

function fmtTimeShort(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

export default function EntryView() {
  const router = useRouter();
  const toast = useToast();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [entry, setEntry] = useState<Entry | null>(null);
  const [notFound, setNotFound] = useState(false);

  const player = useAudioPlayer(entry?.audioUrl ? { uri: entry.audioUrl } : null);
  const status = useAudioPlayerStatus(player);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const uid = getCurrentUser()?.uid ?? 'stub-user';
      const e = await getEntry(uid, String(id));
      if (cancelled) return;
      if (!e) {
        setNotFound(true);
      } else {
        setEntry(e);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id]);

  useEffect(() => {
    void setAudioModeAsync({ playsInSilentMode: true, allowsRecording: false }).catch(() => {});
    return () => {
      try {
        player?.pause();
      } catch {
        // ignore
      }
    };
  }, [player]);

  const onTogglePlay = async () => {
    if (!player) return;
    try {
      if (status.playing) {
        player.pause();
      } else {
        if (status.didJustFinish || (status.currentTime ?? 0) >= (status.duration ?? 0)) {
          await player.seekTo(0);
        }
        player.play();
      }
    } catch (err) {
      toast.show({
        message: "Couldn't play audio",
        kind: 'error',
        duration: 3000,
      });
    }
  };

  if (notFound) {
    return (
      <View style={[styles.root, styles.center]}>
        <View style={styles.handle} />
        <Text style={[t.caption, { color: colors.muted }]}>Entry not found.</Text>
      </View>
    );
  }
  if (!entry) {
    return (
      <View style={[styles.root, styles.center]}>
        <View style={styles.handle} />
      </View>
    );
  }

  const start = new Date(entry.startTime);
  const end = new Date(entry.endTime);
  const duration = formatDurationHuman(end.getTime() - start.getTime());
  const playing = !!status.playing;
  const showPlay = !!entry.audioUrl;

  return (
    <View style={styles.root}>
      <View style={styles.handle} />
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Text style={[t.body, { color: colors.muted }]}>Done</Text>
        </Pressable>
        <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>Entry</Text>
        {showPlay ? (
          <Pressable onPress={onTogglePlay} hitSlop={12} accessibilityRole="button" accessibilityLabel={playing ? 'Pause' : 'Play'}>
            {playing ? (
              <Pause color={colors.amber} size={22} strokeWidth={1.75} />
            ) : (
              <Play color={colors.amber} size={22} strokeWidth={1.75} />
            )}
          </Pressable>
        ) : (
          <View style={{ width: 22 }} />
        )}
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.titleRow}>
          <View style={[styles.titleDot, { backgroundColor: colorForCategory(entry.category) }]} />
          <Text style={[t.title, { color: colors.ink }]}>{categoryLabel(entry.category)}</Text>
        </View>

        <Text style={[t.caption, styles.meta]}>
          {fmtDateLong(entry.startTime)} · {fmtTimeShort(entry.startTime)}
        </Text>

        <Text style={[t.caption, styles.meta, tabular]}>{duration}</Text>

        <Text style={[t.caption, styles.meta, tabular]}>
          {fmtTimeShort(entry.startTime)} — {fmtTimeShort(entry.endTime)}
        </Text>

        {entry.transcript ? (
          <Text style={[t.body, styles.transcript]} selectable>
            {entry.transcript}
          </Text>
        ) : entry.note ? (
          <Text style={[t.body, styles.transcript]} selectable>
            {entry.note}
          </Text>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  center: { alignItems: 'center', justifyContent: 'center' },
  handle: {
    alignSelf: 'center',
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.border,
    marginTop: spacing.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  scroll: { padding: spacing.md, gap: spacing.sm, paddingBottom: spacing.xl * 2 },
  titleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  titleDot: { width: 10, height: 10, borderRadius: radii.pill },
  meta: { color: colors.muted },
  transcript: {
    color: colors.ink,
    marginTop: spacing.md,
    lineHeight: 22,
  },
});
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors. If `expo-audio` complains about the `null` source signature, change the player call to:

```tsx
const player = useAudioPlayer(entry?.audioUrl ? entry.audioUrl : undefined);
```

and re-run `tsc --noEmit`.

- [ ] **Step 3: Commit**

```bash
git add client/app/entry/view/\[id\].tsx
git commit -m "feat(entry): view-only detail screen with audio playback"
```

---

### Task 12: Mount ToastProvider, register view route, wire capture queue → toast

**Files:**
- Modify: `client/app/_layout.tsx`

- [ ] **Step 1: Add the route entry**

Inside the `<Stack ...>` block, add a sibling line after the existing `<Stack.Screen name="entry/[id]" ... />`:

```tsx
        <Stack.Screen name="entry/view/[id]" options={{ presentation: 'modal' }} />
```

- [ ] **Step 2: Wrap the app in `ToastProvider` and add the queue bridge**

Add new imports at the top of `client/app/_layout.tsx`:

```tsx
import { ToastProvider, useToast } from '@/services/toast';
import { retry as retryCapture, subscribe as subscribeCaptureQueue, type Job } from '@/services/captureQueue';
```

Wrap the existing `Stack` in `<ToastProvider>`. The full return becomes:

```tsx
  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <ToastProvider>
        <CaptureQueueBridge />
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }}>
          <Stack.Screen name="(auth)" />
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="capture" options={{ presentation: 'modal' }} />
          <Stack.Screen name="entry/[id]" options={{ presentation: 'modal' }} />
          <Stack.Screen name="entry/view/[id]" options={{ presentation: 'modal' }} />
          <Stack.Screen name="paywall" options={{ presentation: 'modal' }} />
        </Stack>
      </ToastProvider>
    </SafeAreaProvider>
  );
```

Then add this component below `RootLayout`:

```tsx
function CaptureQueueBridge() {
  const toast = useToast();
  const stickyRef = useRef<string | null>(null);
  const lastStatusRef = useRef<Map<string, Job['status']>>(new Map());

  useEffect(() => {
    return subscribeCaptureQueue((jobs) => {
      const statuses = lastStatusRef.current;

      const active = jobs.find((j) => j.status === 'queued' || j.status === 'running');
      if (active && stickyRef.current === null) {
        stickyRef.current = toast.show({ message: 'Processing entry…', kind: 'info' });
      }
      if (!active && stickyRef.current !== null) {
        toast.dismiss(stickyRef.current);
        stickyRef.current = null;
      }

      for (const j of jobs) {
        const prev = statuses.get(j.id);
        if (prev !== j.status) {
          if (j.status === 'done') {
            toast.show({ message: 'Entry saved.', kind: 'success', duration: 2000 });
          }
          if (j.status === 'error') {
            toast.show({
              message: "Couldn't save entry",
              kind: 'error',
              duration: 4000,
              action: { label: 'Retry', onPress: () => retryCapture(j.id) },
            });
          }
          statuses.set(j.id, j.status);
        }
      }
      // prune ids no longer present
      for (const id of [...statuses.keys()]) {
        if (!jobs.find((j) => j.id === id)) statuses.delete(id);
      }
    });
  }, [toast]);

  return null;
}
```

Add `useRef`, `useEffect` to the existing `react` import if they aren't already there:

```tsx
import { useEffect, useRef, useState } from 'react';
```

- [ ] **Step 3: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add client/app/_layout.tsx
git commit -m "feat(toast): mount ToastProvider, register view route, bridge captureQueue"
```

---

### Task 13: Switch capture modal voice path to fire-and-forget

**Files:**
- Modify: `client/app/capture.tsx`

- [ ] **Step 1: Replace the voice path**

In `client/app/capture.tsx`, modify the imports — remove `captureFromAudio` (no longer used here) and add the queue:

```tsx
import { captureFromText } from '@/services/capture';
import { createEntry } from '@/services/entries';
import { enqueue as enqueueCapture } from '@/services/captureQueue';
```

Remove the `Phase` 'transcribing' usage in the voice flow and the `captureResultRef`. The simplified voice handler:

Replace the entire `onPressOut` function with:

```tsx
  const onPressOut = async () => {
    if (phase !== 'recording') return;
    try {
      await audioRecorder.stop();
      const uri = audioRecorder.uri;
      if (!uri) throw new Error('Recording produced no file.');
      const uid = getCurrentUser()?.uid;
      if (!uid) throw new Error('Not signed in.');
      enqueueCapture(uid, uri);
      router.back();
    } catch (err) {
      console.warn('[capture] recording failed', err);
      Alert.alert('Could not save recording', err instanceof Error ? err.message : 'Unknown error');
      setPhase('idle');
    }
  };
```

And update `onSave` (the typed path) to drop the now-unused voice branch:

```tsx
  const onSave = async () => {
    const trimmed = typed.trim();
    if (!trimmed) return;
    setPhase('structuring');
    try {
      const uid = getCurrentUser()?.uid;
      if (!uid) throw new Error('Not signed in.');
      const draft = await captureFromText(trimmed);
      await createEntry(uid, { ...draft, source: 'text', transcript: trimmed });
      setPhase('saved');
      setTimeout(() => router.back(), 600);
    } catch (err) {
      console.warn('[capture] save failed', err);
      Alert.alert('Save failed', err instanceof Error ? err.message : 'Unknown error');
      setPhase('idle');
    }
  };
```

Also remove the now-unused `transcript` state and `captureResultRef`. Adjust:

- Delete the `const [transcript, setTranscript] = useState('');` line.
- Delete the `const captureResultRef = ...;` line.
- Replace `const hasContent = transcript.trim().length > 0 || typed.trim().length > 0;` with:

```tsx
  const hasContent = typed.trim().length > 0;
```

- In the JSX body, replace the label/transcript chunk:

```tsx
        <Text style={[t.body, { color: colors.muted, textAlign: 'center' }]}>
          {phase === 'recording'
            ? 'Listening…'
            : phase === 'transcribing'
              ? 'Transcribing…'
              : phase === 'structuring'
                ? 'Structuring…'
                : transcript
                  ? null
                  : 'Hold to record, or type below.'}
        </Text>

        {transcript ? (
          <Text style={[t.body, styles.transcript]}>{transcript}</Text>
        ) : (
          <View style={styles.waveformPlaceholder}>
            {recorderState.isRecording ? (
              <Waveform />
            ) : (
              <Text style={[t.caption, { color: colors.muted, letterSpacing: 4 }]}>
                ............
              </Text>
            )}
          </View>
        )}
```

with:

```tsx
        <Text style={[t.body, { color: colors.muted, textAlign: 'center' }]}>
          {phase === 'recording'
            ? 'Listening…'
            : phase === 'structuring'
              ? 'Saving…'
              : 'Hold to record, or type below.'}
        </Text>

        <View style={styles.waveformPlaceholder}>
          {recorderState.isRecording ? (
            <Waveform />
          ) : (
            <Text style={[t.caption, { color: colors.muted, letterSpacing: 4 }]}>
              ............
            </Text>
          )}
        </View>
```

- Update the `Phase` type alias to drop `'transcribing'`:

```tsx
type Phase = 'idle' | 'recording' | 'structuring' | 'saved';
```

- Update `recordDisabled` to drop the `'transcribing'` check:

```tsx
  const recordDisabled = phase === 'structuring' || phase === 'saved';
```

- Update the spinner condition inside the record button:

```tsx
              {phase === 'structuring' ? (
                <ActivityIndicator color={colors.white} />
              ) : (
                <Mic color={colors.white} size={28} strokeWidth={1.75} />
              )}
```

- [ ] **Step 2: Type-check**

```bash
cd client && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add client/app/capture.tsx
git commit -m "feat(capture): voice path is fire-and-forget; modal closes on release"
```

---

### Task 14: Manual QA pass

**Files:** none (manual verification on device/simulator)

- [ ] **Step 1: Boot the app**

```bash
cd client && npx expo start --clear
```

Open on iOS or Android simulator.

- [ ] **Step 2: Run the QA matrix from the spec**

Verify each of the following. For each, note pass/fail:

1. Hold-to-record short clip → modal closes immediately on release → toast "Processing entry…" appears at the top → toast disappears and "Entry saved." flashes for ~2s → the new entry shows up on Today and on the new List tab.
2. Force airplane mode mid-capture → on stop, error toast "Couldn't save entry" appears with a "Retry" action → re-enable network → tap Retry → flow completes successfully.
3. Type an entry, tap Send → modal closes after the existing 600ms delay; no toast involved.
4. Open List tab → header reads "Entries" → first 50 entries load newest first → scroll past 50 → next page appends → footer spinner appears briefly while loading.
5. Pull-to-refresh on List → tail clears, head remains live.
6. Tap any list row → view detail modal opens → category title with colored dot, gray date and duration lines, transcript body. For an entry with audio: top-right play icon visible → tap → audio plays → tap again → pauses.
7. Tap a list row whose entry has no `audioUrl` → top-right play icon is absent.
8. Background the app during processing → return → toast still reflects the final state (success or error).
9. Tab order check: bottom tabs read Overview, Today, List, Profile, with the FAB still floating above.

- [ ] **Step 3: Run the unit tests one more time**

```bash
npm test --prefix client
```

Expected: all passing.

- [ ] **Step 4: Commit any QA fixes (if any)**

If you found and fixed a bug during QA, commit each fix with a focused message. If the QA pass was clean, no commit needed.

```bash
# example
# git add client/...
# git commit -m "fix(list): pagination cursor reset on pull-to-refresh"
```

---

## Self-review notes

- **Spec coverage:** All spec sections map to tasks. Toast (T4–T5), captureQueue (T6), entries pagination (T7), List tab (T8–T10), View detail (T11), capture flow (T13), wiring (T12), QA matrix (T14).
- **No placeholders.** Every step has either runnable code, an exact command, or an explicit edit instruction with code shown.
- **Type consistency.** `Job`, `JobStatus`, `Listener`, `ToastInput`, `ToastKind`, `formatDurationHuman`, `formatRowDateTime`, `subscribeFirstPage`, `loadMore`, `getEntry` are referenced consistently across tasks.
- **TDD coverage** is applied where it materially helps — the two pure utility modules. UI screens / queue / toast service are validated by `tsc --noEmit` plus the manual QA matrix in Task 14, mirroring the spec's testing strategy.
