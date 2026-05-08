import { useEffect, useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ChevronRight, ExternalLink } from 'lucide-react-native';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t } from '@/theme/typography';
import { getCurrentUser, signOut } from '@/services/auth';
import { getEntitlement } from '@/services/revenuecat';
import type { AppUser } from '@/types/user';
import type { Entitlement } from '@/types/subscription';

const APP_VERSION = '1.0.0';

export default function Profile() {
  const router = useRouter();
  const [user, setUser] = useState<AppUser | null>(null);
  const [entitlement, setEntitlement] = useState<Entitlement>('free');

  useEffect(() => {
    setUser(getCurrentUser());
    getEntitlement().then(setEntitlement);
  }, []);

  const onSignOut = () => {
    Alert.alert('Sign out?', undefined, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Sign out', style: 'destructive', onPress: () => signOut() },
    ]);
  };

  const onDelete = () => {
    Alert.alert(
      'Delete account?',
      'This permanently removes your entries. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete', style: 'destructive', onPress: () => signOut() },
      ],
    );
  };

  const initials = (user?.displayName ?? user?.email ?? 'C')
    .split(/\s+/)
    .map((s) => s[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();

  const planLabel =
    entitlement === 'weekly'
      ? 'Weekly plan'
      : entitlement === 'yearly'
        ? 'Yearly plan'
        : 'Free plan';
  const planSub =
    entitlement === 'free' ? 'No active subscription' : 'Renews automatically';

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.identity}>
          <View style={styles.avatar}>
            <Text style={[t.body, { color: colors.white, fontWeight: '600' }]}>
              {initials || 'C'}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[t.title, { color: colors.ink }]}>
              {user?.displayName ?? 'Cronwatch user'}
            </Text>
            {user?.email ? (
              <Text style={[t.caption, { color: colors.muted, marginTop: 2 }]}>{user.email}</Text>
            ) : null}
          </View>
        </View>

        <Section label="SUBSCRIPTION">
          <View style={styles.subCard}>
            <View style={{ flex: 1 }}>
              <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>{planLabel}</Text>
              <Text style={[t.caption, { color: colors.muted, marginTop: 2 }]}>{planSub}</Text>
            </View>
            <Pressable
              onPress={() => router.push('/paywall')}
              style={({ pressed }) => [
                styles.cta,
                { opacity: pressed ? 0.85 : 1 },
              ]}
            >
              <Text style={[t.body, { color: colors.white, fontWeight: '600' }]}>
                {entitlement === 'free' ? 'Upgrade' : 'Manage'}
              </Text>
            </Pressable>
          </View>
        </Section>

        <Section label="ACCOUNT">
          <Row label="Sign out" onPress={onSignOut} />
          <Row label="Delete account" onPress={onDelete} />
        </Section>

        <Section label="ABOUT">
          <Row label="Version" trailing={APP_VERSION} />
          <Row label="Source on GitHub" trailing={<ExternalLink color={colors.muted} size={16} strokeWidth={1.75} />} />
          <Row label="Privacy" />
          <Row label="Terms" />
        </Section>

        <Text style={[t.caption, styles.footerNote]}>MADE QUIETLY · CRONWATCH</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={[t.caption, styles.sectionLabel]}>{label}</Text>
      <View style={styles.sectionBody}>{children}</View>
    </View>
  );
}

function Row({
  label,
  onPress,
  trailing,
}: {
  label: string;
  onPress?: () => void;
  trailing?: React.ReactNode;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, { opacity: pressed && onPress ? 0.6 : 1 }]}
    >
      <Text style={[t.body, { color: colors.ink, flex: 1 }]}>{label}</Text>
      {typeof trailing === 'string' ? (
        <Text style={[t.body, { color: colors.muted }]}>{trailing}</Text>
      ) : (
        trailing ?? <ChevronRight color={colors.muted} size={16} strokeWidth={1.75} />
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  scroll: { padding: spacing.md, paddingBottom: 160 },
  identity: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.muted,
    alignItems: 'center',
    justifyContent: 'center',
  },
  section: { marginTop: spacing.lg },
  sectionLabel: { color: colors.muted, letterSpacing: 1.2, marginBottom: spacing.sm },
  sectionBody: {
    backgroundColor: colors.white,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.border,
    overflow: 'hidden',
  },
  subCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    gap: spacing.md,
  },
  cta: {
    backgroundColor: colors.amber,
    paddingHorizontal: spacing.md,
    paddingVertical: 10,
    borderRadius: radii.md,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: 14,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.border,
  },
  footerNote: {
    textAlign: 'center',
    color: colors.muted,
    letterSpacing: 1.2,
    marginTop: spacing.xl,
  },
});
