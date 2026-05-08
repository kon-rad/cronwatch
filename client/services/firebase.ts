import { initializeApp, getApps, type FirebaseApp } from 'firebase/app';
import {
  getAuth,
  initializeAuth,
  type Auth,
} from 'firebase/auth';
// `getReactNativePersistence` is provided at runtime via Metro's RN platform
// resolver but is not in the public type surface of `firebase/auth`. The
// import works at runtime; the cast below silences the TS gap.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { getReactNativePersistence } = require('firebase/auth') as {
  getReactNativePersistence: (storage: unknown) => unknown;
};
import { getFirestore, type Firestore } from 'firebase/firestore';
import AsyncStorage from '@react-native-async-storage/async-storage';

const config = {
  apiKey: process.env.EXPO_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.EXPO_PUBLIC_FIREBASE_APP_ID,
};

let _app: FirebaseApp | null = null;
let _auth: Auth | null = null;
let _db: Firestore | null = null;

function ensureApp(): FirebaseApp | null {
  if (_app) return _app;
  if (!config.apiKey || !config.projectId) {
    if (__DEV__) {
      console.warn('[firebase] EXPO_PUBLIC_FIREBASE_* env not set; running in stub mode.');
    }
    return null;
  }
  _app = getApps()[0] ?? initializeApp(config as Record<string, string>);
  return _app;
}

export function getFirebaseApp(): FirebaseApp | null {
  return ensureApp();
}

export function getFirebaseAuth(): Auth | null {
  if (_auth) return _auth;
  const app = ensureApp();
  if (!app) return null;
  try {
    _auth = initializeAuth(app, {
      persistence: getReactNativePersistence(AsyncStorage) as never,
    });
  } catch {
    _auth = getAuth(app);
  }
  return _auth;
}

export function getFirebaseDb(): Firestore | null {
  if (_db) return _db;
  const app = ensureApp();
  if (!app) return null;
  _db = getFirestore(app);
  return _db;
}
