import {
  GoogleAuthProvider,
  OAuthProvider,
  onAuthStateChanged as fbOnAuthStateChanged,
  signInWithCredential,
  signOut as fbSignOut,
  type User as FirebaseUser,
} from 'firebase/auth';
import * as AppleAuthentication from 'expo-apple-authentication';
import { getFirebaseAuth } from '@/services/firebase';
import type { AppUser } from '@/types/user';

type Listener = (user: AppUser | null) => void;

const STUB_USER: AppUser = {
  uid: 'stub-user',
  email: 'emma@cronwatch.app',
  displayName: 'Emma Mori',
  photoURL: null,
};

let current: AppUser | null = null;
const listeners = new Set<Listener>();

function emit() {
  for (const l of listeners) l(current);
}

function toAppUser(u: FirebaseUser | null): AppUser | null {
  if (!u) return null;
  return {
    uid: u.uid,
    email: u.email,
    displayName: u.displayName,
    photoURL: u.photoURL,
  };
}

export function getCurrentUser(): AppUser | null {
  const auth = getFirebaseAuth();
  if (auth?.currentUser) return toAppUser(auth.currentUser);
  return current;
}

export function onAuthStateChanged(cb: Listener): () => void {
  const auth = getFirebaseAuth();
  if (auth) {
    return fbOnAuthStateChanged(auth, (u) => {
      current = toAppUser(u);
      cb(current);
    });
  }
  listeners.add(cb);
  cb(current);
  return () => {
    listeners.delete(cb);
  };
}

export async function signInWithApple(): Promise<AppUser> {
  const auth = getFirebaseAuth();
  if (!auth) {
    await new Promise((r) => setTimeout(r, 250));
    current = STUB_USER;
    emit();
    return STUB_USER;
  }
  const credential = await AppleAuthentication.signInAsync({
    requestedScopes: [
      AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
      AppleAuthentication.AppleAuthenticationScope.EMAIL,
    ],
  });
  if (!credential.identityToken) {
    throw new Error('Apple sign-in did not return an identity token.');
  }
  const provider = new OAuthProvider('apple.com');
  const oauthCredential = provider.credential({
    idToken: credential.identityToken,
  });
  const { user } = await signInWithCredential(auth, oauthCredential);
  return toAppUser(user)!;
}

export async function signInWithGoogle(idToken?: string): Promise<AppUser> {
  const auth = getFirebaseAuth();
  if (!auth || !idToken) {
    await new Promise((r) => setTimeout(r, 250));
    current = STUB_USER;
    emit();
    return STUB_USER;
  }
  const credential = GoogleAuthProvider.credential(idToken);
  const { user } = await signInWithCredential(auth, credential);
  return toAppUser(user)!;
}

export async function signOut(): Promise<void> {
  const auth = getFirebaseAuth();
  if (auth) {
    await fbSignOut(auth);
    return;
  }
  current = null;
  emit();
}

export async function getIdToken(): Promise<string | null> {
  const auth = getFirebaseAuth();
  return auth?.currentUser ? auth.currentUser.getIdToken() : null;
}
