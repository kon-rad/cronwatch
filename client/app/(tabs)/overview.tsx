import { useEffect, useMemo, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { CATEGORIES, colorForCategory } from '@/theme/categories';
import { Donut } from '@/components/Donut';
import { CategoryDot } from '@/components/CategoryDot';
import { subscribeToToday } from '@/services/entries';
import { getCurrentUser } from '@/services/auth';
import { entryDurationMin, formatDuration } from '@/utils/time';
import type { Entry } from '@/types/entry';

export default function Overview() {
  const [entries, setEntries] = useState<Entry[]>([]);

  useEffect(() => {
    const uid = getCurrentUser()?.uid ?? 'stub-user';
    return subscribeToToday(uid, setEntries);
  }, []);

  const slices = useMemo(() => buildSlices(entries), [entries]);
  const trackedMin = slices.reduce((s, x) => s + x.minutes, 0);
  const distinct = new Set(entries.map((e) => e.category)).size;
  const top = [...slices].sort((a, b) => b.minutes - a.minutes)[0];

  const weekly = useMemo(
    () => CATEGORIES.map((c) => ({ category: c.key, minutes: 0 })),
    [],
  );
  const weeklyTotalMin = weekly.reduce((s, w) => s + w.minutes, 0);

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={[t.title, { color: colors.ink }]}>Overview</Text>
        <Text style={[t.caption, { color: colors.muted, marginTop: 2 }]}>
          How you&apos;ve been spending your time
        </Text>

        <View style={styles.card}>
          <View style={styles.donutWrap}>
            <Donut slices={slices} size={120} thickness={16} />
            <View style={styles.donutLabel}>
              <Text style={[t.title, { color: colors.ink }, tabular]}>{distinct}</Text>
              <Text style={[t.caption, { color: colors.muted }]}>CATEGORIES</Text>
            </View>
          </View>
          <View style={styles.donutMeta}>
            <Text style={[t.caption, { color: colors.muted, letterSpacing: 1 }]}>TODAY</Text>
            <Text style={[t.title, { color: colors.ink, fontSize: 28, lineHeight: 34 }, tabular]}>
              {formatDuration(trackedMin)}
            </Text>
            <Text style={[t.caption, { color: colors.muted, marginTop: 2 }]}>
              tracked of 24h
            </Text>
            {top ? (
              <View style={styles.mostPill}>
                <CategoryDot category={top.category} />
                <Text style={[t.caption, { color: colors.ink, textTransform: 'capitalize' }]}>
                  Most: {labelFor(top.category)}
                </Text>
              </View>
            ) : null}
          </View>
        </View>

        <View style={styles.weeklyHeader}>
          <Text style={[t.caption, styles.sectionLabel]}>THIS WEEK · DAILY AVERAGE</Text>
          <Text style={[t.caption, { color: colors.muted }, tabular]}>
            {formatHours(weeklyTotalMin)}/day
          </Text>
        </View>

        <View style={styles.barList}>
          {weekly.map((w) => (
            <BarRow
              key={w.category}
              category={w.category}
              hours={w.minutes / 60}
              maxHours={Math.max(1, ...weekly.map((x) => x.minutes / 60))}
            />
          ))}
        </View>

        <Text style={[t.caption, styles.sectionLabel, { marginTop: spacing.lg }]}>
          TRACKING STREAK
        </Text>
        <View style={styles.streakCard}>
          <View style={styles.streakHeader}>
            <Text style={[t.title, { color: colors.ink, fontSize: 24, lineHeight: 30 }, tabular]}>
              14 days
            </Text>
            <Text style={[t.caption, { color: colors.muted }]}>last 21 days</Text>
          </View>
          <View style={styles.streakStrip}>
            {STREAK_MOCK.map((on, i) => (
              <View
                key={i}
                style={[
                  styles.streakBar,
                  { backgroundColor: on ? colors.amber : colors.border },
                ]}
              />
            ))}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function BarRow({
  category,
  hours,
  maxHours,
}: {
  category: string;
  hours: number;
  maxHours: number;
}) {
  const widthPct = hours <= 0 ? 0 : Math.max(2, (hours / maxHours) * 100);
  return (
    <View style={styles.barRow}>
      <CategoryDot category={category} />
      <Text style={[t.body, { color: colors.ink, width: 80, textTransform: 'capitalize' }]}>
        {labelFor(category)}
      </Text>
      <View style={styles.barTrack}>
        <View
          style={[
            styles.barFill,
            { width: `${widthPct}%`, backgroundColor: colorForCategory(category) },
          ]}
        />
      </View>
      <Text style={[t.caption, { color: colors.muted, width: 36, textAlign: 'right' }, tabular]}>
        {hours.toFixed(1)}h
      </Text>
    </View>
  );
}

function labelFor(key: string): string {
  return CATEGORIES.find((c) => c.key === key)?.label ?? key;
}

function buildSlices(entries: Entry[]): { category: string; minutes: number }[] {
  const map = new Map<string, number>();
  for (const e of entries) {
    map.set(e.category, (map.get(e.category) ?? 0) + entryDurationMin(e));
  }
  return [...map.entries()].map(([category, minutes]) => ({ category, minutes }));
}

function formatHours(min: number): string {
  return `${(min / 60).toFixed(0)}h`;
}

const STREAK_MOCK = [
  true,  true,  true,  true,  true,  false, true,
  true,  true,  true,  true,  false, true,  true,
  true,  true,  true,  true,  true,  true,  true,
];

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  scroll: { padding: spacing.md, paddingBottom: 160 },
  sectionLabel: { color: colors.muted, letterSpacing: 1.2 },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.white,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    marginTop: spacing.md,
  },
  donutWrap: {
    width: 120,
    height: 120,
    alignItems: 'center',
    justifyContent: 'center',
  },
  donutLabel: { position: 'absolute', alignItems: 'center' },
  donutMeta: { flex: 1, gap: 2 },
  mostPill: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: 4,
    borderRadius: radii.pill,
    backgroundColor: colors.borderSoft,
    marginTop: spacing.sm,
  },
  weeklyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  barList: { gap: 10 },
  barRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  barTrack: {
    flex: 1,
    height: 6,
    borderRadius: 3,
    backgroundColor: colors.borderSoft,
    overflow: 'hidden',
  },
  barFill: { height: '100%', borderRadius: 3 },
  streakCard: {
    backgroundColor: colors.white,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    marginTop: spacing.sm,
  },
  streakHeader: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
  },
  streakStrip: {
    flexDirection: 'row',
    gap: 3,
    marginTop: spacing.sm,
  },
  streakBar: {
    flex: 1,
    height: 28,
    borderRadius: 4,
  },
});
