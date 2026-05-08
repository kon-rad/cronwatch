import { DeepgramClient } from '@deepgram/sdk';
import { env } from './env';

const deepgram = new DeepgramClient({ apiKey: env.deepgram.apiKey });

export async function transcribe(audio: Buffer): Promise<string> {
  const response = await deepgram.listen.v1.media.transcribeFile(audio, {
    model: env.deepgram.model,
    language: 'en',
    punctuate: true,
    smart_format: true,
  });
  if (!('results' in response)) {
    throw new Error('Deepgram returned an async/accepted response with no transcript');
  }
  const transcript = response.results?.channels?.[0]?.alternatives?.[0]?.transcript;
  if (typeof transcript !== 'string' || transcript.trim() === '') {
    throw new Error('Deepgram returned no transcript');
  }
  return transcript;
}
