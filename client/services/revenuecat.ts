import { Platform } from 'react-native';
import Purchases, { type CustomerInfo } from 'react-native-purchases';
import type { Entitlement } from '@/types/subscription';

const ENTITLEMENT_ID = 'pro';

const apiKey =
  Platform.OS === 'ios'
    ? process.env.EXPO_PUBLIC_REVENUECAT_API_KEY_IOS
    : process.env.EXPO_PUBLIC_REVENUECAT_API_KEY_ANDROID;

let configured = false;

function ensureConfigured(): boolean {
  if (configured) return true;
  if (!apiKey) {
    if (__DEV__) console.warn('[revenuecat] No API key set; running in stub mode.');
    return false;
  }
  Purchases.configure({ apiKey });
  configured = true;
  return true;
}

function entitlementFrom(info: CustomerInfo): Entitlement {
  const ent = info.entitlements.active[ENTITLEMENT_ID];
  if (!ent) return 'free';
  // Identify weekly vs yearly by product id heuristics; tune to your store config.
  const id = ent.productIdentifier.toLowerCase();
  if (id.includes('year')) return 'yearly';
  if (id.includes('week')) return 'weekly';
  return 'yearly';
}

export async function getEntitlement(): Promise<Entitlement> {
  if (!ensureConfigured()) return 'free';
  const info = await Purchases.getCustomerInfo();
  return entitlementFrom(info);
}

export async function presentPaywall(): Promise<void> {
  // The paywall is rendered by the app at /paywall. RevenueCat's hosted
  // paywall UI requires `react-native-purchases-ui`, which is not bundled here.
  // Purchase happens via Purchases.purchaseStoreProduct from the paywall screen.
}

export async function restorePurchases(): Promise<Entitlement> {
  if (!ensureConfigured()) return 'free';
  const info = await Purchases.restorePurchases();
  return entitlementFrom(info);
}

export async function identifyUser(uid: string): Promise<void> {
  if (!ensureConfigured()) return;
  await Purchases.logIn(uid);
}
