import { capturedEntryDraftSchema, type CapturedEntryDraft } from '@/types/capture';
import { getIdToken } from '@/services/auth';

const PROXY_URL = process.env.EXPO_PUBLIC_CAPTURE_PROXY_URL;

export interface CaptureResult {
  transcript: string;
  audioUrl: string;
  audioKey: string;
  draft: CapturedEntryDraft;
}

function proxyBase(): string {
  if (!PROXY_URL) {
    throw new Error('EXPO_PUBLIC_CAPTURE_PROXY_URL is not set.');
  }
  return PROXY_URL.replace(/\/$/, '');
}

function deviceTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    return 'UTC';
  }
}

function extFromUri(uri: string): string {
  const m = /\.([a-zA-Z0-9]+)(?:\?|#|$)/.exec(uri);
  return (m?.[1] ?? 'm4a').toLowerCase();
}

function mimeFromExt(ext: string): string {
  switch (ext) {
    case 'wav':
      return 'audio/wav';
    case 'mp3':
      return 'audio/mpeg';
    case 'webm':
      return 'audio/webm';
    case 'ogg':
      return 'audio/ogg';
    case 'caf':
      return 'audio/x-caf';
    default:
      return 'audio/m4a';
  }
}

async function readError(res: Response): Promise<string> {
  try {
    const j = (await res.json()) as { error?: string };
    return j.error ?? '';
  } catch {
    return await res.text().catch(() => '');
  }
}

export async function captureFromAudio(audioUri: string, now: Date = new Date()): Promise<CaptureResult> {
  const token = await getIdToken();
  if (!token) throw new Error('Not signed in.');

  const ext = extFromUri(audioUri);
  const mime = mimeFromExt(ext);
  const filename = `recording.${ext}`;

  const form = new FormData();
  // React Native's FormData accepts { uri, name, type } file objects.
  form.append('audio', {
    uri: audioUri,
    name: filename,
    type: mime,
  } as unknown as Blob);
  form.append('now', now.toISOString());
  form.append('tz', deviceTimezone());

  const res = await fetch(`${proxyBase()}/capture`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form as unknown as BodyInit,
  });

  if (!res.ok) {
    const detail = await readError(res);
    throw new Error(`Capture failed (${res.status})${detail ? `: ${detail}` : ''}`);
  }

  const json = (await res.json()) as {
    transcript?: unknown;
    audioUrl?: unknown;
    audioKey?: unknown;
    draft?: unknown;
  };

  if (typeof json.transcript !== 'string') throw new Error('Capture response missing transcript');
  if (typeof json.audioUrl !== 'string') throw new Error('Capture response missing audioUrl');
  if (typeof json.audioKey !== 'string') throw new Error('Capture response missing audioKey');

  const draft = capturedEntryDraftSchema.parse(json.draft);

  return {
    transcript: json.transcript,
    audioUrl: json.audioUrl,
    audioKey: json.audioKey,
    draft,
  };
}

export async function captureFromText(text: string, now: Date = new Date()): Promise<CapturedEntryDraft> {
  const token = await getIdToken();
  if (!token) throw new Error('Not signed in.');

  const trimmed = text.trim();
  if (!trimmed) throw new Error('Empty entry text.');

  const res = await fetch(`${proxyBase()}/structure`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      transcript: trimmed,
      now: now.toISOString(),
      tz: deviceTimezone(),
    }),
  });

  if (!res.ok) {
    const detail = await readError(res);
    throw new Error(`Structure failed (${res.status})${detail ? `: ${detail}` : ''}`);
  }

  const json = (await res.json()) as { draft?: unknown };
  return capturedEntryDraftSchema.parse(json.draft);
}
