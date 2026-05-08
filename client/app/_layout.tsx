import { Stack, useRouter, useSegments } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { View } from 'react-native';
import {
  useFonts,
  Inter_500Medium,
  Inter_600SemiBold,
} from '@expo-google-fonts/inter';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { onAuthStateChanged } from '@/services/auth';
import { ToastProvider, useToast } from '@/services/toast';
import {
  retry as retryCapture,
  subscribe as subscribeCaptureQueue,
  type Job,
} from '@/services/captureQueue';
import { colors } from '@/theme/tokens';
import type { AppUser } from '@/types/user';

export default function RootLayout() {
  const [fontsLoaded] = useFonts({ Inter_500Medium, Inter_600SemiBold });
  const [user, setUser] = useState<AppUser | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    return onAuthStateChanged((u) => {
      setUser(u);
      setAuthReady(true);
    });
  }, []);

  useEffect(() => {
    if (!authReady) return;
    const inAuth = segments[0] === '(auth)';
    if (!user && !inAuth) router.replace('/(auth)/sign-in');
    if (user && inAuth) router.replace('/(tabs)/today');
  }, [user, authReady, segments, router]);

  if (!fontsLoaded || !authReady) {
    return <View style={{ flex: 1, backgroundColor: colors.bg }} />;
  }

  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      <ToastProvider>
        <CaptureQueueBridge />
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }}>
          <Stack.Screen name="(auth)" />
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="capture" options={{ presentation: 'modal' }} />
          <Stack.Screen name="entry/[id]" options={{ presentation: 'modal' }} />
          <Stack.Screen name="entry/view/[id]" options={{ presentation: 'modal' }} />
          <Stack.Screen name="paywall" options={{ presentation: 'modal' }} />
        </Stack>
      </ToastProvider>
    </SafeAreaProvider>
  );
}

function CaptureQueueBridge() {
  const toast = useToast();
  const stickyRef = useRef<string | null>(null);
  const lastStatusRef = useRef<Map<string, Job['status']>>(new Map());

  useEffect(() => {
    return subscribeCaptureQueue((jobs) => {
      const statuses = lastStatusRef.current;

      const active = jobs.find((j) => j.status === 'queued' || j.status === 'running');
      if (active && stickyRef.current === null) {
        stickyRef.current = toast.show({ message: 'Processing entry…', kind: 'info' });
      }
      if (!active && stickyRef.current !== null) {
        toast.dismiss(stickyRef.current);
        stickyRef.current = null;
      }

      for (const j of jobs) {
        const prev = statuses.get(j.id);
        if (prev !== j.status) {
          if (j.status === 'done') {
            toast.show({ message: 'Entry saved.', kind: 'success', duration: 2000 });
          }
          if (j.status === 'error') {
            toast.show({
              message: "Couldn't save entry",
              kind: 'error',
              duration: 4000,
              action: { label: 'Retry', onPress: () => retryCapture(j.id) },
            });
          }
          statuses.set(j.id, j.status);
        }
      }
      for (const id of [...statuses.keys()]) {
        if (!jobs.find((j) => j.id === id)) statuses.delete(id);
      }
    });
  }, [toast]);

  return null;
}
