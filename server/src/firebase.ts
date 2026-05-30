import { cert, getApps, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { env } from './env';

function buildCredential(): ServiceAccount {
  if (env.firebase.serviceAccountJson) {
    const parsed = JSON.parse(env.firebase.serviceAccountJson) as ServiceAccount;
    return parsed;
  }
  if (!env.firebase.projectId || !env.firebase.clientEmail || !env.firebase.privateKey) {
    throw new Error(
      'Firebase Admin not configured. Provide FIREBASE_SERVICE_ACCOUNT_JSON, or all of FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY.',
    );
  }
  return {
    projectId: env.firebase.projectId,
    clientEmail: env.firebase.clientEmail,
    privateKey: env.firebase.privateKey,
  };
}

if (getApps().length === 0) {
  initializeApp({ credential: cert(buildCredential()) });
}

export const firebaseAuth = getAuth();
export const firebaseDb = getFirestore();
