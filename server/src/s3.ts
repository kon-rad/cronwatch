import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { randomUUID } from 'node:crypto';
import { env } from './env';

const s3 = new S3Client({
  region: env.aws.region,
  credentials: {
    accessKeyId: env.aws.accessKeyId,
    secretAccessKey: env.aws.secretAccessKey,
  },
});

export interface UploadedAudio {
  key: string;
  url: string;
}

export async function uploadAudio(
  uid: string,
  buffer: Buffer,
  contentType: string,
  ext: string,
): Promise<UploadedAudio> {
  const safeExt = ext.replace(/[^a-z0-9]/gi, '').toLowerCase() || 'm4a';
  const prefix = env.aws.keyPrefix.replace(/^\/+|\/+$/g, '');
  const datePath = new Date().toISOString().slice(0, 10);
  const key = `${prefix}/${uid}/${datePath}/${randomUUID()}.${safeExt}`;

  await s3.send(
    new PutObjectCommand({
      Bucket: env.aws.bucket,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    }),
  );

  const url = `https://${env.aws.bucket}.s3.${env.aws.region}.amazonaws.com/${key}`;
  return { key, url };
}
