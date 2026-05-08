import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, RefreshControl, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import type { DocumentSnapshot } from 'firebase/firestore';
import { colors, spacing } from '@/theme/tokens';
import { type as t } from '@/theme/typography';
import { EntryRow } from '@/components/EntryRow';
import { getCurrentUser } from '@/services/auth';
import { loadMore, subscribeFirstPage } from '@/services/entries';
import type { Entry } from '@/types/entry';

const PAGE_SIZE = 50;

export default function List() {
  const router = useRouter();
  const [head, setHead] = useState<Entry[]>([]);
  const [tail, setTail] = useState<Entry[]>([]);
  const [headCursor, setHeadCursor] = useState<DocumentSnapshot | null>(null);
  const [tailCursor, setTailCursor] = useState<DocumentSnapshot | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  useEffect(() => {
    const uid = getCurrentUser()?.uid ?? 'stub-user';
    return subscribeFirstPage(uid, PAGE_SIZE, (entries, lastCursor) => {
      setHead(entries);
      setHeadCursor(lastCursor);
    });
  }, []);

  const onEndReached = useCallback(async () => {
    if (loadingMore || !hasMore) return;
    const cursor = tailCursor ?? headCursor;
    if (!cursor) return;
    const uid = getCurrentUser()?.uid ?? 'stub-user';
    setLoadingMore(true);
    try {
      const next = await loadMore(uid, cursor, PAGE_SIZE);
      setTail((prev) => [...prev, ...next.entries]);
      setTailCursor(next.lastCursor);
      setHasMore(next.hasMore);
    } finally {
      setLoadingMore(false);
    }
  }, [loadingMore, hasMore, headCursor, tailCursor]);

  const onRefresh = useCallback(() => {
    setTail([]);
    setTailCursor(null);
    setHasMore(true);
  }, []);

  const data = [...head, ...tail];

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <View style={styles.header}>
        <Text style={[t.title, { color: colors.ink }]}>Entries</Text>
      </View>
      <FlatList
        data={data}
        keyExtractor={(e) => e.id}
        renderItem={({ item }) => (
          <EntryRow entry={item} onPress={() => router.push(`/entry/view/${item.id}`)} />
        )}
        onEndReached={onEndReached}
        onEndReachedThreshold={0.4}
        refreshControl={<RefreshControl refreshing={false} onRefresh={onRefresh} />}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Text style={[t.body, { color: colors.muted }]}>No entries yet.</Text>
          </View>
        }
        ListFooterComponent={
          loadingMore ? (
            <View style={styles.footer}>
              <ActivityIndicator color={colors.muted} />
            </View>
          ) : null
        }
      />
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
  empty: { alignItems: 'center', justifyContent: 'center', padding: spacing.xl },
  footer: { padding: spacing.md, alignItems: 'center' },
});
