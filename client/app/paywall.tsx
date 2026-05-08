import { useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Grid3x3, Lock, Mic, X } from 'lucide-react-native';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { restorePurchases } from '@/services/revenuecat';

type Plan = 'yearly' | 'weekly';

export default function Paywall() {
  const router = useRouter();
  const [plan, setPlan] = useState<Plan>('yearly');

  const onSubscribe = () => {
    // TODO(task-4): trigger RevenueCat purchase for the selected plan
    router.back();
  };

  const onRestore = async () => {
    await restorePurchases();
  };

  return (
    <View style={styles.root}>
      <Pressable onPress={() => router.back()} style={styles.close} hitSlop={12}>
        <X color={colors.muted} size={20} strokeWidth={1.75} />
      </Pressable>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={[t.title, styles.headline]}>Track your time without thinking about it.</Text>
        <Text style={[t.body, { color: colors.muted, marginTop: spacing.sm }]}>
          Voice in. Structured time out.
        </Text>

        <View style={styles.features}>
          <Feature
            icon={<Mic color={colors.ink} size={20} strokeWidth={1.75} />}
            title="Voice capture"
            sub="Hold the button, speak naturally. Cronwatch turns it into a structured entry."
          />
          <Feature
            icon={<Grid3x3 color={colors.ink} size={20} strokeWidth={1.75} />}
            title="15-minute grid"
            sub="Your day at a glance — every block accounted for, nothing fudged."
          />
          <Feature
            icon={<Lock color={colors.ink} size={20} strokeWidth={1.75} />}
            title="Private by default"
            sub="Your entries stay on-device. No analytics, no ads, no resold data."
          />
        </View>

        <View style={styles.plans}>
          <PlanCard
            selected={plan === 'yearly'}
            badge="Best value · 20% off"
            title="Yearly"
            price="$40"
            unit="/yr"
            sub="$3.33/month"
            onPress={() => setPlan('yearly')}
          />
          <PlanCard
            selected={plan === 'weekly'}
            title="Weekly"
            price="$4"
            unit="/wk"
            sub="Try a week"
            onPress={() => setPlan('weekly')}
          />
        </View>

        <Pressable
          onPress={onSubscribe}
          style={({ pressed }) => [styles.cta, { opacity: pressed ? 0.9 : 1 }]}
        >
          <Text style={[t.body, { color: colors.white, fontWeight: '600' }]}>
            Start subscription
          </Text>
        </Pressable>

        <Text style={[t.caption, styles.fineprint]}>
          Cancel anytime ·{' '}
          <Text onPress={onRestore} style={{ textDecorationLine: 'underline' }}>
            Restore purchases
          </Text>{' '}
          ·{' '}
          <Text style={{ textDecorationLine: 'underline' }}>Terms</Text>
        </Text>
      </ScrollView>
    </View>
  );
}

function Feature({
  icon,
  title,
  sub,
}: {
  icon: React.ReactNode;
  title: string;
  sub: string;
}) {
  return (
    <View style={styles.feature}>
      <View style={styles.featureIcon}>{icon}</View>
      <View style={{ flex: 1 }}>
        <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>{title}</Text>
        <Text style={[t.caption, { color: colors.muted, marginTop: 2, lineHeight: 18 }]}>
          {sub}
        </Text>
      </View>
    </View>
  );
}

function PlanCard({
  selected,
  badge,
  title,
  price,
  unit,
  sub,
  onPress,
}: {
  selected: boolean;
  badge?: string;
  title: string;
  price: string;
  unit: string;
  sub: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.planCard,
        selected
          ? { borderColor: colors.amber, backgroundColor: 'rgba(232, 163, 61, 0.08)' }
          : null,
      ]}
    >
      {badge ? (
        <View style={styles.badge}>
          <Text style={[t.caption, { color: colors.amber, fontWeight: '600' }]}>{badge}</Text>
        </View>
      ) : null}
      <Text style={[t.caption, { color: colors.muted, marginTop: badge ? 6 : 0 }]}>{title}</Text>
      <View style={styles.priceRow}>
        <Text style={[t.title, { color: colors.ink }, tabular]}>{price}</Text>
        <Text style={[t.caption, { color: colors.muted, marginBottom: 2 }, tabular]}>{unit}</Text>
      </View>
      <Text style={[t.caption, { color: colors.muted }]}>{sub}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  close: {
    position: 'absolute',
    top: spacing.md + 4,
    right: spacing.md,
    zIndex: 1,
    padding: spacing.xs,
  },
  scroll: { padding: spacing.lg, paddingTop: spacing.xl + spacing.md, paddingBottom: spacing.xl },
  headline: { color: colors.ink, fontSize: 26, lineHeight: 32, marginRight: 28 },
  features: { gap: spacing.md, marginTop: spacing.xl },
  feature: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md },
  featureIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.borderSoft,
  },
  plans: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.xl,
  },
  planCard: {
    flex: 1,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radii.md,
    padding: spacing.md,
    backgroundColor: colors.white,
    minHeight: 140,
    justifyContent: 'flex-start',
  },
  badge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: radii.sm,
    backgroundColor: 'rgba(232, 163, 61, 0.18)',
    marginBottom: 6,
  },
  priceRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 4,
    marginTop: 4,
    marginBottom: 4,
  },
  cta: {
    marginTop: spacing.xl,
    backgroundColor: colors.amber,
    paddingVertical: 14,
    borderRadius: radii.md,
    alignItems: 'center',
  },
  fineprint: {
    color: colors.muted,
    textAlign: 'center',
    marginTop: spacing.md,
  },
});
