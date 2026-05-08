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

  aws: {
    region: required('AWS_REGION'),
    accessKeyId: required('AWS_ACCESS_KEY_ID'),
    secretAccessKey: required('AWS_SECRET_ACCESS_KEY'),
    bucket: required('S3_BUCKET'),
    keyPrefix: optional('S3_KEY_PREFIX', 'captures'),
  },

  deepgram: {
    apiKey: required('DEEPGRAM_API_KEY'),
    model: optional('DEEPGRAM_MODEL', 'nova-3'),
  },

  together: {
    apiKey: required('TOGETHER_API_KEY'),
    model: optional('TOGETHER_MODEL', 'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo'),
  },
};
