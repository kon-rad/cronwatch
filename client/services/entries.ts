import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import { getFirebaseDb } from '@/services/firebase';
import type { Entry, CapturedEntryDraft, EntrySource } from '@/types/entry';

type Listener = (entries: Entry[]) => void;

let stubStore: Entry[] = [];
const stubListeners = new Set<Listener>();

function stubSnapshot(): Entry[] {
  return [...stubStore].sort((a, b) => a.startTime.localeCompare(b.startTime));
}

function emitStub() {
  const s = stubSnapshot();
  for (const l of stubListeners) l(s);
}

function entriesCol(uid: string) {
  const db = getFirebaseDb();
  if (!db) return null;
  return collection(db, 'users', uid, 'entries');
}

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function endOfToday(): Date {
  const d = new Date();
  d.setHours(23, 59, 59, 999);
  return d;
}

function fromFirestore(id: string, data: Record<string, unknown>): Entry {
  const start = data.startTime instanceof Timestamp ? data.startTime.toDate() : new Date(String(data.startTime));
  const end = data.endTime instanceof Timestamp ? data.endTime.toDate() : new Date(String(data.endTime));
  const created = data.createdAt instanceof Timestamp ? data.createdAt.toDate() : new Date();
  return {
    id,
    category: String(data.category ?? ''),
    note: String(data.note ?? ''),
    startTime: start.toISOString(),
    endTime: end.toISOString(),
    source: (data.source === 'text' ? 'text' : 'voice') as EntrySource,
    transcript: typeof data.transcript === 'string' ? data.transcript : undefined,
    audioUrl: typeof data.audioUrl === 'string' ? data.audioUrl : undefined,
    createdAt: created.toISOString(),
  };
}

export function subscribeToToday(uid: string, cb: Listener): () => void {
  const col = entriesCol(uid);
  if (!col) {
    stubListeners.add(cb);
    cb(stubSnapshot());
    return () => stubListeners.delete(cb);
  }
  const q = query(
    col,
    where('startTime', '>=', Timestamp.fromDate(startOfToday())),
    where('startTime', '<=', Timestamp.fromDate(endOfToday())),
    orderBy('startTime', 'asc'),
  );
  return onSnapshot(q, (snap) => {
    const entries = snap.docs.map((d) => fromFirestore(d.id, d.data() as Record<string, unknown>));
    cb(entries);
  });
}

function parseIso(label: string, value: string): Date {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`Entry has invalid ${label} (${value})`);
  }
  return d;
}

export async function createEntry(
  uid: string,
  draft: CapturedEntryDraft & { source: EntrySource; transcript?: string; audioUrl?: string },
): Promise<Entry> {
  const start = parseIso('startTime', draft.startTime);
  const end = parseIso('endTime', draft.endTime);
  if (end < start) {
    throw new Error('Entry endTime is before startTime');
  }

  const col = entriesCol(uid);
  if (!col) {
    const next: Entry = {
      id: `e${Date.now()}`,
      category: draft.category,
      note: draft.note,
      startTime: start.toISOString(),
      endTime: end.toISOString(),
      source: draft.source,
      transcript: draft.transcript,
      audioUrl: draft.audioUrl,
      createdAt: new Date().toISOString(),
    };
    stubStore.push(next);
    emitStub();
    return next;
  }
  const ref = await addDoc(col, {
    category: draft.category,
    note: draft.note,
    startTime: Timestamp.fromDate(start),
    endTime: Timestamp.fromDate(end),
    source: draft.source,
    transcript: draft.transcript ?? null,
    audioUrl: draft.audioUrl ?? null,
    createdAt: serverTimestamp(),
  });
  return {
    id: ref.id,
    ...draft,
    startTime: start.toISOString(),
    endTime: end.toISOString(),
    createdAt: new Date().toISOString(),
  };
}

export async function updateEntry(uid: string, id: string, patch: Partial<Entry>): Promise<void> {
  const col = entriesCol(uid);
  if (!col) {
    stubStore = stubStore.map((e) => (e.id === id ? { ...e, ...patch } : e));
    emitStub();
    return;
  }
  const update: Record<string, unknown> = { ...patch };
  if (patch.startTime) update.startTime = Timestamp.fromDate(new Date(patch.startTime));
  if (patch.endTime) update.endTime = Timestamp.fromDate(new Date(patch.endTime));
  await updateDoc(doc(col, id), update);
}

export async function deleteEntry(uid: string, id: string): Promise<void> {
  const col = entriesCol(uid);
  if (!col) {
    stubStore = stubStore.filter((e) => e.id !== id);
    emitStub();
    return;
  }
  await deleteDoc(doc(col, id));
}
