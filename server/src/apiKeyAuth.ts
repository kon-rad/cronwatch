import { createHash } from 'crypto';
import type { NextFunction, Request, Response } from 'express';
import { firebaseDb } from './firebase';

export interface ApiKeyRequest extends Request {
  uid?: string;
}

export async function resolveApiKey(rawKey: string): Promise<string | null> {
  const hash = createHash('sha256').update(rawKey).digest('hex');
  const snap = await firebaseDb
    .collection('apiKeys')
    .where('keyHash', '==', hash)
    .limit(1)
    .get();
  if (snap.empty) return null;
  const doc = snap.docs[0];
  // Fire-and-forget lastUsedAt update
  doc.ref.update({ lastUsedAt: new Date() }).catch(() => {});
  return doc.data().uid as string;
}

export async function requireApiKey(
  req: ApiKeyRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const raw = req.header('x-api-key') ?? '';
  if (!raw.startsWith('cw_')) {
    res.status(401).json({ error: 'Missing or invalid X-Api-Key header' });
    return;
  }
  const uid = await resolveApiKey(raw).catch(() => null);
  if (!uid) {
    res.status(401).json({ error: 'Invalid API key' });
    return;
  }
  req.uid = uid;
  next();
}
