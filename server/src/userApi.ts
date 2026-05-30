import type { Request, Response } from 'express';
import { Timestamp } from 'firebase-admin/firestore';
import { firebaseDb } from './firebase';

interface ApiKeyRequest extends Request {
  uid?: string;
}

// GET /v1/me
export async function getMeHandler(req: ApiKeyRequest, res: Response): Promise<void> {
  const uid = req.uid!;
  try {
    const userDoc = await firebaseDb.collection('users').doc(uid).get();
    const data = userDoc.data() ?? {};
    const rawGoals = (data.goals as Array<{ category: string; weeklyTargetHours: number }>) ?? [];
    const goals = rawGoals
      .filter((g) => g.category && g.weeklyTargetHours > 0)
      .map((g) => ({ category: g.category, weeklyTargetHours: g.weeklyTargetHours }));
    res.json({ uid, goals });
  } catch {
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
}

// GET /v1/entries
// Query params:
//   from  - ISO 8601 datetime, lower bound on startTime (default: 7 days ago)
//   to    - ISO 8601 datetime, upper bound on startTime (default: now)
//   limit - max entries to return (default: 200, max: 500)
export async function getEntriesHandler(req: ApiKeyRequest, res: Response): Promise<void> {
  const uid = req.uid!;

  const now = new Date();
  const defaultFrom = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  const fromRaw = typeof req.query.from === 'string' ? req.query.from : '';
  const toRaw = typeof req.query.to === 'string' ? req.query.to : '';
  const limitRaw = typeof req.query.limit === 'string' ? req.query.limit : '';

  const from = fromRaw ? new Date(fromRaw) : defaultFrom;
  const to = toRaw ? new Date(toRaw) : now;
  const limit = Math.min(500, Math.max(1, parseInt(limitRaw || '200', 10) || 200));

  if (isNaN(from.getTime())) {
    res.status(400).json({ error: 'Invalid "from" date' });
    return;
  }
  if (isNaN(to.getTime())) {
    res.status(400).json({ error: 'Invalid "to" date' });
    return;
  }
  if (from >= to) {
    res.status(400).json({ error: '"from" must be before "to"' });
    return;
  }

  try {
    const col = firebaseDb.collection('users').doc(uid).collection('entries');
    // Widen lower bound by 24h to catch overnight entries (e.g. sleep starting
    // before `from` but ending within the window). Filter endTime client-side.
    const queryFrom = new Date(from.getTime() - 24 * 60 * 60 * 1000);
    const snap = await col
      .where('startTime', '>=', Timestamp.fromDate(queryFrom))
      .where('startTime', '<=', Timestamp.fromDate(to))
      .orderBy('startTime', 'asc')
      .limit(limit)
      .get();

    const entries = snap.docs
      .map((doc) => {
        const d = doc.data();
        const startTime: Date = (d.startTime as Timestamp).toDate();
        const endTime: Date = (d.endTime as Timestamp).toDate();
        const createdAt: Date = d.createdAt ? (d.createdAt as Timestamp).toDate() : startTime;
        return {
          id: doc.id,
          captureId: (d.captureId as string | undefined) ?? doc.id,
          category: (d.category as string | undefined) ?? '',
          note: (d.note as string | undefined) ?? '',
          startTime: startTime.toISOString(),
          endTime: endTime.toISOString(),
          source: (d.source as string | undefined) ?? 'voice',
          transcript: (d.transcript as string | undefined) ?? null,
          createdAt: createdAt.toISOString(),
          _endTime: endTime,
        };
      })
      // Client-side endTime > from filter for the midnight-spanning entries
      .filter((e) => e._endTime > from)
      .map(({ _endTime: _et, ...rest }) => rest);

    res.json({ entries, count: entries.length });
  } catch (err) {
    console.error('[userApi/entries] error:', err);
    res.status(500).json({ error: 'Failed to fetch entries' });
  }
}
