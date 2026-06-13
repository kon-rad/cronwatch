import { transcribe as transcribeWithDeepgram } from './deepgram';
import { transcribeWithWhisper } from './together';

/**
 * Server-side transcription providers the client can request via the /capture
 * "provider" field. The on-device "speechAnalyzer" option never reaches the
 * server (the client posts text straight to /structure), so it is not listed here.
 */
export type TranscriptionProvider = 'deepgram' | 'together';

const PROVIDERS: ReadonlySet<string> = new Set<TranscriptionProvider>(['deepgram', 'together']);

/** Coerce an untrusted request value into a known provider, defaulting to Deepgram. */
export function parseProvider(raw: unknown): TranscriptionProvider {
  return typeof raw === 'string' && PROVIDERS.has(raw)
    ? (raw as TranscriptionProvider)
    : 'deepgram';
}

export async function transcribeAudio(
  audio: Buffer,
  contentType: string,
  provider: TranscriptionProvider,
): Promise<string> {
  if (provider === 'together') {
    return transcribeWithWhisper(audio, contentType);
  }
  return transcribeWithDeepgram(audio, contentType);
}
