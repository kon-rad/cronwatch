import type { NextFunction, Request, Response } from 'express';
import { firebaseAuth } from './firebase';

export interface AuthedRequest extends Request {
  uid?: string;
}

export async function requireFirebaseUser(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.header('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }
  try {
    const decoded = await firebaseAuth.verifyIdToken(match[1]);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid Firebase ID token' });
  }
}
