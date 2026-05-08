import { useEffect, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { colorForCategory, pillBgForCategory } from '@/theme/categories';
import {
  entryDurationMin,
  formatDuration,
  formatTimeFromIso,
  minutesSinceMidnight,
} from '@/utils/time';
import type { Entry } from '@/types/entry';

const PX_PER_MIN = 1.4;
const HOUR_PX = 60 * PX_PER_MIN;
const TIME_COL_WIDTH = 56;

export function TodayGrid({ entries }: { entries: Entry[] }) {
  const router = useRouter();
  const scrollRef = useRef<ScrollView>(null);
  const [nowMin, setNowMin] = useState(() => {
    const d = new Date();
    return d.getHours() * 60 + d.getMinutes();
  });

  useEffect(() => {
    const id = setInterval(() => {
      const d = new Date();
      setNowMin(d.getHours() * 60 + d.getMinutes());
    }, 30_000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    const target = Math.max(0, nowMin * PX_PER_MIN - 200);
    const tid = setTimeout(() => scrollRef.current?.scrollTo({ y: target, animated: false }), 50);
    return () => clearTimeout(tid);
    // intentionally only on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const hours = Array.from({ length: 24 }, (_, h) => h);
  const dayHeight = 24 * HOUR_PX;

  return (
    <ScrollView
      ref={scrollRef}
      style={styles.scroll}
      contentContainerStyle={{ paddingBottom: 160 }}
      showsVerticalScrollIndicator={false}
    >
      <View style={[styles.canvas, { height: dayHeight }]}>
        {hours.map((h) => (
          <View key={h} style={[styles.hourRow, { top: h * HOUR_PX }]}>
            <Text style={[t.caption, { color: colors.muted }, tabular]}>
              {String(h).padStart(2, '0')}:00
            </Text>
          </View>
        ))}

        <View style={[styles.gridArea, { height: dayHeight }]}>
          <DottedDividers />

          {entries.map((e) => (
            <EntryBlock key={e.id} entry={e} onPress={() => router.push(`/entry/${e.id}`)} />
          ))}

          <NowLine nowMin={nowMin} />
        </View>
      </View>
    </ScrollView>
  );
}

function EntryBlock({ entry, onPress }: { entry: Entry; onPress: () => void }) {
  const startMin = minutesSinceMidnight(entry.startTime);
  const durMin = entryDurationMin(entry);
  const top = startMin * PX_PER_MIN;
  const height = Math.max(28, durMin * PX_PER_MIN - 2);
  const dotColor = colorForCategory(entry.category);
  const bg = pillBgForCategory(entry.category);

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.entryBlock,
        {
          top,
          height,
          backgroundColor: bg,
          opacity: pressed ? 0.85 : 1,
        },
      ]}
      accessibilityRole="button"
      accessibilityLabel={`${entry.category} ${entry.note}`}
    >
      <View style={styles.entryRow}>
        <View style={[styles.dot, { backgroundColor: dotColor }]} />
        <Text style={[t.body, styles.entryLabel, { color: colors.ink }]} numberOfLines={1}>
          <Text style={{ fontWeight: '600', textTransform: 'capitalize' }}>{entry.category}</Text>
          <Text style={{ color: colors.muted }}>{`  ·  ${entry.note}`}</Text>
        </Text>
        <Text style={[t.caption, { color: colors.muted }, tabular]}>
          {formatDuration(durMin)}
        </Text>
      </View>
      {height > 56 ? (
        <Text style={[t.caption, { color: colors.muted, marginTop: 4 }, tabular]}>
          {formatTimeFromIso(entry.startTime)}
        </Text>
      ) : null}
    </Pressable>
  );
}

function NowLine({ nowMin }: { nowMin: number }) {
  return (
    <View pointerEvents="none" style={[styles.nowLine, { top: nowMin * PX_PER_MIN }]}>
      <View style={styles.nowDot} />
      <View style={styles.nowBar} />
    </View>
  );
}

function DottedDividers() {
  // a faint dashed divider every quarter-hour, kept subtle
  const ticks = Array.from({ length: 24 * 4 }, (_, i) => i);
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      {ticks.map((q) => (
        <View
          key={q}
          style={{
            position: 'absolute',
            top: q * 15 * PX_PER_MIN,
            left: 0,
            right: 0,
            height: StyleSheet.hairlineWidth,
            backgroundColor: q % 4 === 0 ? colors.border : colors.borderSoft,
          }}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { flex: 1, backgroundColor: colors.bg },
  canvas: { position: 'relative', paddingHorizontal: spacing.md },
  hourRow: {
    position: 'absolute',
    left: spacing.md,
    width: TIME_COL_WIDTH,
    paddingTop: 2,
  },
  gridArea: {
    marginLeft: TIME_COL_WIDTH,
    position: 'relative',
  },
  entryBlock: {
    position: 'absolute',
    left: spacing.sm,
    right: spacing.xs,
    borderRadius: radii.md,
    paddingHorizontal: spacing.sm,
    paddingVertical: 6,
    overflow: 'hidden',
  },
  entryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  entryLabel: { flex: 1 },
  nowLine: {
    position: 'absolute',
    left: -10,
    right: 0,
    height: 1,
    backgroundColor: colors.amber,
    flexDirection: 'row',
    alignItems: 'center',
  },
  nowDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.amber,
    marginLeft: -4,
    marginTop: -4,
  },
  nowBar: { flex: 1, height: 1, backgroundColor: colors.amber },
});
