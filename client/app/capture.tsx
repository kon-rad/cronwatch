import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Animated,
  Easing,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Mic, Send } from 'lucide-react-native';
import * as Haptics from 'expo-haptics';
import {
  AudioModule,
  RecordingPresets,
  setAudioModeAsync,
  useAudioRecorder,
  useAudioRecorderState,
} from 'expo-audio';
import { colors, radii, shadow, spacing } from '@/theme/tokens';
import { type as t } from '@/theme/typography';
import { captureFromAudio, captureFromText } from '@/services/capture';
import { createEntry } from '@/services/entries';
import { getCurrentUser } from '@/services/auth';

type Phase = 'idle' | 'recording' | 'transcribing' | 'structuring' | 'saved';

export default function Capture() {
  const router = useRouter();
  const [phase, setPhase] = useState<Phase>('idle');
  const [transcript, setTranscript] = useState('');
  const [typed, setTyped] = useState('');
  const pulse = useRef(new Animated.Value(1)).current;

  const audioRecorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);
  const recorderState = useAudioRecorderState(audioRecorder);
  const captureResultRef = useRef<Awaited<ReturnType<typeof captureFromAudio>> | null>(null);

  const hasContent = transcript.trim().length > 0 || typed.trim().length > 0;

  useEffect(() => {
    (async () => {
      const status = await AudioModule.requestRecordingPermissionsAsync();
      if (!status.granted) {
        Alert.alert('Microphone permission required', 'Cronwatch needs the mic to record entries.');
      }
      await setAudioModeAsync({ playsInSilentMode: true, allowsRecording: true });
    })();
  }, []);

  useEffect(() => {
    if (phase === 'recording') {
      const loop = Animated.loop(
        Animated.sequence([
          Animated.timing(pulse, {
            toValue: 1.08,
            duration: 700,
            easing: Easing.inOut(Easing.ease),
            useNativeDriver: true,
          }),
          Animated.timing(pulse, {
            toValue: 1,
            duration: 700,
            easing: Easing.inOut(Easing.ease),
            useNativeDriver: true,
          }),
        ]),
      );
      loop.start();
      return () => loop.stop();
    }
    pulse.setValue(1);
    return undefined;
  }, [phase, pulse]);

  const onPressIn = async () => {
    if (phase !== 'idle') return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    setTranscript('');
    captureResultRef.current = null;
    try {
      await audioRecorder.prepareToRecordAsync();
      audioRecorder.record();
      setPhase('recording');
    } catch (err) {
      console.warn('[capture] failed to start recording', err);
      Alert.alert('Could not start recording', err instanceof Error ? err.message : 'Unknown error');
      setPhase('idle');
    }
  };

  const onPressOut = async () => {
    if (phase !== 'recording') return;
    setPhase('transcribing');
    try {
      await audioRecorder.stop();
      const uri = audioRecorder.uri;
      if (!uri) throw new Error('Recording produced no file.');
      const result = await captureFromAudio(uri);
      captureResultRef.current = result;
      setTranscript(result.transcript);
      setPhase('idle');
    } catch (err) {
      console.warn('[capture] capture failed', err);
      Alert.alert('Capture failed', err instanceof Error ? err.message : 'Unknown error');
      setPhase('idle');
    }
  };

  const onSave = async () => {
    if (!hasContent) return;
    const isTyped = typed.trim().length > 0 && transcript.trim().length === 0;
    setPhase('structuring');
    try {
      const uid = getCurrentUser()?.uid;
      if (!uid) throw new Error('Not signed in.');

      if (isTyped) {
        const trimmed = typed.trim();
        const draft = await captureFromText(trimmed);
        await createEntry(uid, { ...draft, source: 'text', transcript: trimmed });
      } else {
        const result = captureResultRef.current;
        if (!result) throw new Error('Voice capture result is missing.');
        await createEntry(uid, {
          ...result.draft,
          source: 'voice',
          transcript: result.transcript,
          audioUrl: result.audioUrl,
        });
      }
      setPhase('saved');
      setTimeout(() => router.back(), 600);
    } catch (err) {
      console.warn('[capture] save failed', err);
      Alert.alert('Save failed', err instanceof Error ? err.message : 'Unknown error');
      setPhase('idle');
    }
  };

  const saveDisabled = !hasContent || phase === 'structuring' || phase === 'saved';
  const recordDisabled =
    phase === 'transcribing' || phase === 'structuring' || phase === 'saved';

  return (
    <View style={styles.root}>
      <View style={styles.handle} />
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Text style={[t.body, { color: colors.muted }]}>Cancel</Text>
        </Pressable>
        <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>
          {phase === 'saved' ? 'Logged.' : 'New entry'}
        </Text>
        <Pressable onPress={onSave} disabled={saveDisabled} hitSlop={12}>
          <Text
            style={[
              t.body,
              { color: saveDisabled ? colors.muted : colors.amber, fontWeight: '600' },
            ]}
          >
            Save
          </Text>
        </Pressable>
      </View>

      <View style={styles.body}>
        <Text style={[t.body, { color: colors.muted, textAlign: 'center' }]}>
          {phase === 'recording'
            ? 'Listening…'
            : phase === 'transcribing'
              ? 'Transcribing…'
              : phase === 'structuring'
                ? 'Structuring…'
                : transcript
                  ? null
                  : 'Hold to record, or type below.'}
        </Text>

        {transcript ? (
          <Text style={[t.body, styles.transcript]}>{transcript}</Text>
        ) : (
          <View style={styles.waveformPlaceholder}>
            {recorderState.isRecording ? (
              <Waveform />
            ) : (
              <Text style={[t.caption, { color: colors.muted, letterSpacing: 4 }]}>
                ............
              </Text>
            )}
          </View>
        )}

        <View style={styles.recordWrap}>
          <Animated.View style={{ transform: [{ scale: pulse }] }}>
            <Pressable
              onPressIn={onPressIn}
              onPressOut={onPressOut}
              disabled={recordDisabled}
              style={({ pressed }) => [
                styles.recordBtn,
                shadow.fab,
                { opacity: pressed && phase === 'idle' ? 0.95 : 1 },
              ]}
              accessibilityLabel="Hold to record"
              accessibilityRole="button"
            >
              {phase === 'transcribing' || phase === 'structuring' ? (
                <ActivityIndicator color={colors.white} />
              ) : (
                <Mic color={colors.white} size={28} strokeWidth={1.75} />
              )}
            </Pressable>
          </Animated.View>
          <Text style={[t.caption, { color: colors.muted, marginTop: spacing.sm, letterSpacing: 1 }]}>
            HOLD TO RECORD
          </Text>
        </View>
      </View>

      <View style={styles.footer}>
        <View style={styles.inputRow}>
          <TextInput
            style={[t.body, styles.input]}
            placeholder="Or type an entry…"
            placeholderTextColor={colors.muted}
            value={typed}
            onChangeText={setTyped}
            returnKeyType="send"
            onSubmitEditing={onSave}
            editable={phase === 'idle'}
          />
          {typed.trim().length > 0 ? (
            <Pressable onPress={onSave} hitSlop={8} accessibilityRole="button" accessibilityLabel="Send">
              <Send color={colors.amber} size={20} strokeWidth={1.75} />
            </Pressable>
          ) : null}
        </View>
      </View>
    </View>
  );
}

function Waveform() {
  const bars = Array.from({ length: 24 }, (_, i) => i);
  return (
    <View style={styles.waveformRow}>
      {bars.map((i) => (
        <WaveBar key={i} delay={i * 60} />
      ))}
    </View>
  );
}

function WaveBar({ delay }: { delay: number }) {
  const v = useRef(new Animated.Value(0.3)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(v, {
          toValue: 1,
          duration: 400,
          delay,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: false,
        }),
        Animated.timing(v, {
          toValue: 0.3,
          duration: 400,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: false,
        }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [delay, v]);
  const height = v.interpolate({ inputRange: [0, 1], outputRange: [4, 28] });
  return <Animated.View style={[styles.waveBar, { height }]} />;
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
  body: {
    flex: 1,
    paddingHorizontal: spacing.md,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.lg,
  },
  transcript: {
    color: colors.ink,
    textAlign: 'center',
    paddingHorizontal: spacing.md,
  },
  waveformPlaceholder: {
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
  },
  waveformRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    height: 32,
  },
  waveBar: {
    width: 3,
    borderRadius: 2,
    backgroundColor: colors.amber,
  },
  recordWrap: { alignItems: 'center', marginTop: spacing.md },
  recordBtn: {
    width: 88,
    height: 88,
    borderRadius: 44,
    backgroundColor: colors.amber,
    alignItems: 'center',
    justifyContent: 'center',
  },
  footer: {
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.lg,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.white,
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  input: {
    flex: 1,
    color: colors.ink,
    paddingVertical: 4,
  },
});
