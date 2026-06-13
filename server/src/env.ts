import 'dotenv/config';

function required(name: string): string {
  const v = process.env[name];
  if (!v || v.trim() === '') {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v;
}

function optional(name: string, fallback = ''): string {
  const v = process.env[name];
  return v && v.trim() !== '' ? v : fallback;
}

export const env = {
  port: Number(process.env.PORT ?? 8080),
  allowedOrigins: optional('ALLOWED_ORIGINS', '*'),

  firebase: {
    serviceAccountJson: optional('FIREBASE_SERVICE_ACCOUNT_JSON'),
    projectId: optional('FIREBASE_PROJECT_ID'),
    clientEmail: optional('FIREBASE_CLIENT_EMAIL'),
    privateKey: optional('FIREBASE_PRIVATE_KEY').replace(/\\n/g, '\n'),
  },

  deepgram: {
    // Optional: only required when the client selects the "deepgram" transcription
    // provider. On-device (SpeechAnalyzer) and Together Whisper never touch it.
    apiKey: optional('DEEPGRAM_API_KEY'),
    model: optional('DEEPGRAM_MODEL', 'nova-3'),
  },

  together: {
    apiKey: required('TOGETHER_API_KEY'),
    model: optional('TOGETHER_MODEL', 'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo'),
    // Larger, better-value model used for long-form HTML reports.
    reportModel: optional('TOGETHER_REPORT_MODEL', 'meta-llama/Llama-3.3-70B-Instruct-Turbo'),
    // Whisper model used for cheap cloud transcription (the "together" provider).
    whisperModel: optional('TOGETHER_WHISPER_MODEL', 'openai/whisper-large-v3'),
  },
};
