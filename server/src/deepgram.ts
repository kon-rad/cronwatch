import { DeepgramClient } from '@deepgram/sdk';
import { env } from './env';

const deepgram = new DeepgramClient({ apiKey: env.deepgram.apiKey });

export async function transcribe(audio: Buffer, contentType: string): Promise<string> {
  // The SDK's binary upload path can't infer Content-Type from a raw Buffer,
  // so it falls back to application/octet-stream and Deepgram fails to detect
  // the audio container (e.g. m4a/mp4). Pass mime + filename explicitly.
  const filename = `recording.${extFromContentType(contentType)}`;
  const response = await deepgram.listen.v1.media.transcribeFile(
    { data: audio, contentType, filename },
    {
      model: env.deepgram.model,
      language: 'en',
      punctuate: true,
      smart_format: true,
    },
  );
  if (!('results' in response)) {
    throw new Error('Deepgram returned an async/accepted response with no transcript');
  }
  const transcript = response.results?.channels?.[0]?.alternatives?.[0]?.transcript;
  if (typeof transcript !== 'string' || transcript.trim() === '') {
    console.warn('[deepgram] empty transcript', {
      bytes: audio.length,
      contentType,
      magic: audio.subarray(0, 16).toString('hex'),
      duration: response.metadata?.duration,
      channels: response.results?.channels?.length,
    });
    throw new Error("Couldn't hear any speech in that recording — try again.");
  }
  return transcript;
}

function extFromContentType(mime: string): string {
  const m = mime.toLowerCase();
  if (m.includes('wav')) return 'wav';
  if (m.includes('webm')) return 'webm';
  if (m.includes('ogg')) return 'ogg';
  if (m.includes('mpeg') || m.includes('mp3')) return 'mp3';
  if (m.includes('caf')) return 'caf';
  return 'm4a';
}
