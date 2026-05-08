import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { env } from './env';
import { requireFirebaseUser, type AuthedRequest } from './auth';
import { uploadAudio } from './s3';
import { transcribe } from './deepgram';
import { structure } from './together';

const app = express();

const allowed = env.allowedOrigins.split(',').map((s) => s.trim()).filter(Boolean);
app.use(
  cors({
    origin: allowed.length === 1 && allowed[0] === '*' ? true : allowed,
  }),
);
app.use(express.json({ limit: '64kb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
});

app.post(
  '/capture',
  requireFirebaseUser,
  upload.single('audio'),
  async (req: AuthedRequest, res) => {
    const file = req.file;
    if (!file) {
      res.status(400).json({ error: 'Missing audio file (field "audio")' });
      return;
    }
    const uid = req.uid;
    if (!uid) {
      res.status(401).json({ error: 'Unauthenticated' });
      return;
    }

    const now = req.body?.now ? new Date(String(req.body.now)) : new Date();
    if (Number.isNaN(now.getTime())) {
      res.status(400).json({ error: 'Invalid "now" timestamp' });
      return;
    }
    const tz = typeof req.body?.tz === 'string' && req.body.tz.trim() !== ''
      ? String(req.body.tz)
      : undefined;

    const ext =
      (file.originalname?.split('.').pop() ?? '').toLowerCase() ||
      mimeToExt(file.mimetype) ||
      'm4a';
    const contentType = file.mimetype || 'audio/m4a';

    try {
      const [{ key, url }, transcript] = await Promise.all([
        uploadAudio(uid, file.buffer, contentType, ext),
        transcribe(file.buffer),
      ]);

      const draft = await structure(transcript, now, tz);

      res.json({
        transcript,
        audioKey: key,
        audioUrl: url,
        draft,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Capture failed';
      console.error('[capture] error:', err);
      res.status(500).json({ error: message });
    }
  },
);

app.post(
  '/structure',
  requireFirebaseUser,
  async (req: AuthedRequest, res) => {
    const uid = req.uid;
    if (!uid) {
      res.status(401).json({ error: 'Unauthenticated' });
      return;
    }

    const transcript = typeof req.body?.transcript === 'string'
      ? req.body.transcript.trim()
      : '';
    if (!transcript) {
      res.status(400).json({ error: 'Missing "transcript"' });
      return;
    }
    if (transcript.length > 2000) {
      res.status(400).json({ error: '"transcript" too long (max 2000 chars)' });
      return;
    }

    const now = req.body?.now ? new Date(String(req.body.now)) : new Date();
    if (Number.isNaN(now.getTime())) {
      res.status(400).json({ error: 'Invalid "now" timestamp' });
      return;
    }
    const tz = typeof req.body?.tz === 'string' && req.body.tz.trim() !== ''
      ? String(req.body.tz)
      : undefined;

    try {
      const draft = await structure(transcript, now, tz);
      res.json({ draft });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Structure failed';
      console.error('[structure] error:', err);
      res.status(500).json({ error: message });
    }
  },
);

function mimeToExt(mime: string | undefined): string | null {
  if (!mime) return null;
  if (mime.includes('m4a') || mime.includes('mp4')) return 'm4a';
  if (mime.includes('wav')) return 'wav';
  if (mime.includes('webm')) return 'webm';
  if (mime.includes('ogg')) return 'ogg';
  if (mime.includes('mpeg') || mime.includes('mp3')) return 'mp3';
  return null;
}

app.listen(env.port, () => {
  console.log(`[cronwatch-server] listening on :${env.port}`);
});
