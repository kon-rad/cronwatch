import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { CATEGORIES, colorForCategory } from '@/theme/categories';
import { formatRowDateTime } from '@/utils/listDate';
import type { Entry } from '@/types/entry';

type Props = {
  entry: Entry;
  onPress: () => void;
};

function categoryLabel(key: string): string {
  const found = CATEGORIES.find((c) => c.key === key);
  if (found) return found.label;
  const lower = key.toLowerCase();
  const byLabel = CATEGORIES.find((c) => c.label.toLowerCase() === lower);
  return byLabel ? byLabel.label : key || 'Entry';
}

function snippet(entry: Entry): string {
  const text = (entry.transcript ?? entry.note ?? '').trim();
  if (text.length <= 150) return text;
  return text.slice(0, 150).trimEnd() + '…';
}

export function EntryRow({ entry, onPress }: Props) {
  const { dateLine, timeLine } = formatRowDateTime(entry.startTime);
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, { opacity: pressed ? 0.7 : 1 }]}
      accessibilityRole="button"
      accessibilityLabel={`${categoryLabel(entry.category)} entry`}
    >
      <View style={[styles.dot, { backgroundColor: colorForCategory(entry.category) }]} />
      <View style={styles.body}>
        <Text style={[t.body, styles.title]} numberOfLines={1}>
          {categoryLabel(entry.category)}
        </Text>
        <Text style={[t.caption, styles.snippet]} numberOfLines={2}>
          {snippet(entry) || '—'}
        </Text>
      </View>
      <View style={styles.right}>
        <Text style={[t.caption, styles.dateLine]}>{dateLine}</Text>
        <Text style={[t.caption, styles.timeLine, tabular]}>{timeLine}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: 14,
    gap: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.border,
    backgroundColor: colors.bg,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: radii.pill,
    marginTop: 6,
  },
  body: { flex: 1, gap: 2 },
  title: { color: colors.ink, fontWeight: '600' },
  snippet: { color: colors.muted },
  right: { alignItems: 'flex-end', minWidth: 64 },
  dateLine: { color: colors.muted },
  timeLine: { color: colors.muted },
});
