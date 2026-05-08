export type Entitlement = 'free' | 'weekly' | 'yearly';

export interface SubscriptionStatus {
  entitlement: Entitlement;
  renewsAt: string | null;
}
