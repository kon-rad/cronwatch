import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { TodayGrid } from '@/components/TodayGrid';
import { subscribeToToday } from '@/services/entries';
import { getCurrentUser } from '@/services/auth';
import {
  MIN_PER_DAY,
  formatDuration,
  formatLongDate,
  totalTrackedMin,
} from '@/utils/time';
import type { Entry } from '@/types/entry';

export default function Today() {
  const [entries, setEntries] = useState<Entry[]>([]);

  useEffect(() => {
    const uid = getCurrentUser()?.uid ?? 'stub-user';
    return subscribeToToday(uid, setEntries);
  }, []);

  const tracked = totalTrackedMin(entries);
  const open = Math.max(0, MIN_PER_DAY - tracked);

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <View style={styles.header}>
        <Text style={[t.title, { color: colors.ink }]}>{formatLongDate()}</Text>
        <View style={styles.metaRow}>
          <Text style={[t.caption, { color: colors.muted }, tabular]}>
            {formatDuration(tracked)} tracked
          </Text>
          <View style={styles.metaSpacer} />
          <Text style={[t.caption, { color: colors.muted }, tabular]}>
            {formatDuration(open)} open
          </Text>
        </View>
      </View>
      <TodayGrid entries={entries} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  header: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.sm,
    paddingBottom: spacing.sm,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 2,
  },
  metaSpacer: { width: spacing.md },
});
