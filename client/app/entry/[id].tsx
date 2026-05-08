import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Minus, Plus, Trash2 } from 'lucide-react-native';
import { colors, radii, spacing } from '@/theme/tokens';
import { type as t, tabular } from '@/theme/typography';
import { CATEGORIES, colorForCategory } from '@/theme/categories';
import { deleteEntry, subscribeToToday, updateEntry } from '@/services/entries';
import { getCurrentUser } from '@/services/auth';
import { formatHHMM, snapTo15 } from '@/utils/time';
import type { Entry } from '@/types/entry';

export default function EntryEdit() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const uid = getCurrentUser()?.uid ?? 'stub-user';

  const [entry, setEntry] = useState<Entry | null>(null);
  const [category, setCategory] = useState('');
  const [note, setNote] = useState('');
  const [startMin, setStartMin] = useState(0);
  const [endMin, setEndMin] = useState(0);

  useEffect(() => {
    return subscribeToToday(uid, (entries) => {
      const found = entries.find((e) => e.id === id);
      if (found && !entry) {
        setEntry(found);
        setCategory(found.category);
        setNote(found.note);
        setStartMin(minutesOf(found.startTime));
        setEndMin(minutesOf(found.endTime));
      }
    });
  }, [id, uid, entry]);

  const startLabel = useMemo(() => formatTimeOfDay(startMin), [startMin]);
  const endLabel = useMemo(() => formatTimeOfDay(endMin), [endMin]);

  if (!entry) {
    return (
      <View style={[styles.root, { alignItems: 'center', justifyContent: 'center' }]}>
        <Text style={[t.caption, { color: colors.muted }]}>Entry not found.</Text>
      </View>
    );
  }

  const onSave = async () => {
    const baseDate = new Date(entry.startTime);
    const start = withMinutesOfDay(baseDate, startMin);
    const end = withMinutesOfDay(baseDate, Math.max(endMin, startMin + 15));
    await updateEntry(uid, entry.id, {
      category: category.trim() || entry.category,
      note: note.trim(),
      startTime: start.toISOString(),
      endTime: end.toISOString(),
    });
    router.back();
  };

  const onDelete = () => {
    Alert.alert('Delete entry?', 'This cannot be undone.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await deleteEntry(uid, entry.id);
          router.back();
        },
      },
    ]);
  };

  return (
    <View style={styles.root}>
      <View style={styles.handle} />
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Text style={[t.body, { color: colors.muted }]}>Cancel</Text>
        </Pressable>
        <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>Edit entry</Text>
        <Pressable onPress={onSave} hitSlop={12}>
          <Text style={[t.body, { color: colors.amber, fontWeight: '600' }]}>Save</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.scroll}>
        <Text style={[t.caption, styles.sectionLabel]}>CATEGORY</Text>
        <View style={styles.chipWrap}>
          {CATEGORIES.map((c) => {
            const selected = category === c.key;
            return (
              <Pressable
                key={c.key}
                onPress={() => setCategory(c.key)}
                style={[
                  styles.chip,
                  selected && {
                    borderColor: colors.amber,
                    backgroundColor: 'rgba(232, 163, 61, 0.10)',
                  },
                ]}
              >
                <View style={[styles.chipDot, { backgroundColor: c.color }]} />
                <Text style={[t.body, { color: colors.ink }]}>{c.label}</Text>
              </Pressable>
            );
          })}
        </View>

        <Text style={[t.caption, styles.sectionLabel]}>NOTE</Text>
        <TextInput
          style={[t.body, styles.noteInput]}
          value={note}
          onChangeText={setNote}
          multiline
          placeholder="What did you do?"
          placeholderTextColor={colors.muted}
        />

        <View style={styles.timeRow}>
          <TimeStepper
            label="START"
            value={startLabel}
            onMinus={() => setStartMin((m) => snapTo15(Math.max(0, m - 15)))}
            onPlus={() =>
              setStartMin((m) => {
                const next = snapTo15(Math.min(24 * 60 - 15, m + 15));
                if (next >= endMin) setEndMin(next + 15);
                return next;
              })
            }
          />
          <View style={{ width: spacing.md }} />
          <TimeStepper
            label="END"
            value={endLabel}
            onMinus={() =>
              setEndMin((m) => snapTo15(Math.max(startMin + 15, m - 15)))
            }
            onPlus={() => setEndMin((m) => snapTo15(Math.min(24 * 60, m + 15)))}
          />
        </View>

        <Pressable onPress={onDelete} style={styles.deleteBtn} hitSlop={8}>
          <Trash2 color={colors.danger} size={16} strokeWidth={1.75} />
          <Text style={[t.body, { color: colors.danger }]}>Delete entry</Text>
        </Pressable>
      </ScrollView>
    </View>
  );
}

function TimeStepper({
  label,
  value,
  onMinus,
  onPlus,
}: {
  label: string;
  value: string;
  onMinus: () => void;
  onPlus: () => void;
}) {
  return (
    <View style={styles.stepperWrap}>
      <Text style={[t.caption, styles.sectionLabel, { marginBottom: 4 }]}>{label}</Text>
      <View style={styles.stepper}>
        <Text style={[t.body, { color: colors.ink, flex: 1 }, tabular]}>{value}</Text>
        <Pressable onPress={onMinus} style={styles.stepBtn} hitSlop={6}>
          <Minus color={colors.ink} size={16} strokeWidth={1.75} />
        </Pressable>
        <Pressable onPress={onPlus} style={styles.stepBtn} hitSlop={6}>
          <Plus color={colors.ink} size={16} strokeWidth={1.75} />
        </Pressable>
      </View>
    </View>
  );
}

function minutesOf(iso: string): number {
  const d = new Date(iso);
  return d.getHours() * 60 + d.getMinutes();
}

function withMinutesOfDay(base: Date, totalMin: number): Date {
  const d = new Date(base);
  d.setHours(Math.floor(totalMin / 60), totalMin % 60, 0, 0);
  return d;
}

function formatTimeOfDay(totalMin: number): string {
  const d = new Date();
  d.setHours(Math.floor(totalMin / 60), totalMin % 60, 0, 0);
  return d
    .toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
    .toLowerCase();
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg, borderTopLeftRadius: 20, borderTopRightRadius: 20 },
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
  scroll: { padding: spacing.md, paddingBottom: spacing.xl * 2, gap: spacing.md },
  sectionLabel: {
    color: colors.muted,
    letterSpacing: 1.2,
    marginTop: spacing.sm,
  },
  chipWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: 8,
    borderRadius: radii.pill,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  chipDot: { width: 6, height: 6, borderRadius: 3 },
  noteInput: {
    color: colors.ink,
    backgroundColor: colors.white,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.border,
    minHeight: 72,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    textAlignVertical: 'top',
  },
  timeRow: { flexDirection: 'row', marginTop: spacing.sm },
  stepperWrap: { flex: 1 },
  stepper: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: 10,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  stepBtn: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.borderSoft,
  },
  deleteBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginTop: spacing.lg,
    alignSelf: 'flex-start',
  },
});
