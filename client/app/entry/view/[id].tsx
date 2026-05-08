import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Pause, Play } from 'lucide-react-native';
import {
  setAudioModeAsync,
  useAudioPlayer,
  useAudioPlayerStatus,
} from 'expo-audio';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { CATEGORIES, colorForCategory } from '@/theme/categories';
import { getEntry } from '@/services/entries';
import { getCurrentUser } from '@/services/auth';
import { useToast } from '@/services/toast';
import { formatDurationHuman } from '@/utils/duration';
import type { Entry } from '@/types/entry';

function categoryLabel(key: string): string {
  const found = CATEGORIES.find((c) => c.key === key);
  if (found) return found.label;
  const lower = key.toLowerCase();
  const byLabel = CATEGORIES.find((c) => c.label.toLowerCase() === lower);
  return byLabel ? byLabel.label : key || 'Entry';
}

function fmtDateLong(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });
}

function fmtTimeShort(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

export default function EntryView() {
  const router = useRouter();
  const toast = useToast();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [entry, setEntry] = useState<Entry | null>(null);
  const [notFound, setNotFound] = useState(false);

  const audioSource = entry?.audioUrl ?? null;
  const player = useAudioPlayer(audioSource);
  const status = useAudioPlayerStatus(player);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const uid = getCurrentUser()?.uid ?? 'stub-user';
      const e = await getEntry(uid, String(id));
      if (cancelled) return;
      if (!e) {
        setNotFound(true);
      } else {
        setEntry(e);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id]);

  useEffect(() => {
    void setAudioModeAsync({ playsInSilentMode: true, allowsRecording: false }).catch(() => {});
    return () => {
      try {
        player?.pause();
      } catch {
        // ignore — player may already be disposed
      }
    };
  }, [player]);

  const onTogglePlay = async () => {
    if (!player) return;
    try {
      if (status.playing) {
        player.pause();
      } else {
        if (status.didJustFinish || (status.duration > 0 && status.currentTime >= status.duration)) {
          await player.seekTo(0);
        }
        player.play();
      }
    } catch {
      toast.show({
        message: "Couldn't play audio",
        kind: 'error',
        duration: 3000,
      });
    }
  };

  if (notFound) {
    return (
      <View style={[styles.root, styles.center]}>
        <View style={styles.handle} />
        <Text style={[t.caption, { color: colors.muted }]}>Entry not found.</Text>
      </View>
    );
  }
  if (!entry) {
    return (
      <View style={[styles.root, styles.center]}>
        <View style={styles.handle} />
      </View>
    );
  }

  const start = new Date(entry.startTime);
  const end = new Date(entry.endTime);
  const duration = formatDurationHuman(end.getTime() - start.getTime());
  const playing = !!status.playing;
  const showPlay = !!entry.audioUrl;

  return (
    <View style={styles.root}>
      <View style={styles.handle} />
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Text style={[t.body, { color: colors.muted }]}>Done</Text>
        </Pressable>
        <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>Entry</Text>
        {showPlay ? (
          <Pressable
            onPress={onTogglePlay}
            hitSlop={12}
            accessibilityRole="button"
            accessibilityLabel={playing ? 'Pause' : 'Play'}
          >
            {playing ? (
              <Pause color={colors.amber} size={22} strokeWidth={1.75} />
            ) : (
              <Play color={colors.amber} size={22} strokeWidth={1.75} />
            )}
          </Pressable>
        ) : (
          <View style={{ width: 22 }} />
        )}
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.titleRow}>
          <View style={[styles.titleDot, { backgroundColor: colorForCategory(entry.category) }]} />
          <Text style={[t.title, { color: colors.ink }]}>{categoryLabel(entry.category)}</Text>
        </View>

        <Text style={[t.caption, styles.meta]}>
          {fmtDateLong(entry.startTime)} · {fmtTimeShort(entry.startTime)}
        </Text>

        <Text style={[t.caption, styles.meta, tabular]}>{duration}</Text>

        <Text style={[t.caption, styles.meta, tabular]}>
          {fmtTimeShort(entry.startTime)} — {fmtTimeShort(entry.endTime)}
        </Text>

        {entry.transcript ? (
          <Text style={[t.body, styles.transcript]} selectable>
            {entry.transcript}
          </Text>
        ) : entry.note ? (
          <Text style={[t.body, styles.transcript]} selectable>
            {entry.note}
          </Text>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
  },
  center: { alignItems: 'center', justifyContent: 'center' },
  handle: {
    alignSelf: 'center',
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.border,
    marginTop: spacing.sm,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  scroll: { padding: spacing.md, gap: spacing.sm, paddingBottom: spacing.xl * 2 },
  titleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  titleDot: { width: 10, height: 10, borderRadius: radii.pill },
  meta: { color: colors.muted },
  transcript: {
    color: colors.ink,
    marginTop: spacing.md,
    lineHeight: 22,
  },
});
