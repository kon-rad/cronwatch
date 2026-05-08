import { useEffect } from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Clock, Apple } from 'lucide-react-native';
import * as Google from 'expo-auth-session/providers/google';
import * as WebBrowser from 'expo-web-browser';
import { signInWithApple, signInWithGoogle } from '@/services/auth';
import { colors, spacing, radii } from '@/theme/tokens';
import { type as t } from '@/theme/typography';

WebBrowser.maybeCompleteAuthSession();

const GOOGLE_IOS_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID;
const GOOGLE_ANDROID_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_ANDROID_CLIENT_ID;
const GOOGLE_WEB_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID;
const googleConfigured = Boolean(GOOGLE_IOS_CLIENT_ID || GOOGLE_ANDROID_CLIENT_ID || GOOGLE_WEB_CLIENT_ID);

function GoogleButton() {
  const [request, response, promptAsync] = Google.useIdTokenAuthRequest({
    iosClientId: GOOGLE_IOS_CLIENT_ID,
    androidClientId: GOOGLE_ANDROID_CLIENT_ID,
    webClientId: GOOGLE_WEB_CLIENT_ID,
  });

  useEffect(() => {
    if (response?.type === 'success') {
      const idToken = response.params?.id_token;
      if (idToken) signInWithGoogle(idToken);
    }
  }, [response]);

  return (
    <Pressable
      disabled={!request}
      onPress={() => promptAsync()}
      style={({ pressed }) => [
        styles.btn,
        {
          backgroundColor: colors.white,
          borderWidth: 1,
          borderColor: colors.border,
          opacity: !request ? 0.5 : pressed ? 0.85 : 1,
        },
      ]}
      accessibilityRole="button"
      accessibilityLabel="Continue with Google"
    >
      <Text style={[t.body, { color: colors.ink, fontWeight: '600' }]}>G</Text>
      <Text style={[t.body, { color: colors.ink }]}>Continue with Google</Text>
    </Pressable>
  );
}

export default function SignIn() {
  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <View style={styles.center}>
        <View style={styles.logo}>
          <Clock color={colors.white} size={32} strokeWidth={1.75} />
        </View>
        <Text style={[t.title, { color: colors.ink, marginTop: spacing.md, fontSize: 32, lineHeight: 38 }]}>
          Cronwatch
        </Text>
        <Text style={[t.body, { color: colors.muted, marginTop: spacing.xs }]}>
          Speak your time. See your day.
        </Text>
      </View>
      <View style={styles.actions}>
        <Pressable
          onPress={() => signInWithApple()}
          style={({ pressed }) => [
            styles.btn,
            { backgroundColor: colors.ink, opacity: pressed ? 0.85 : 1 },
          ]}
          accessibilityRole="button"
          accessibilityLabel="Continue with Apple"
        >
          <Apple color={colors.white} size={18} fill={colors.white} />
          <Text style={[t.body, { color: colors.white }]}>Continue with Apple</Text>
        </Pressable>
        {googleConfigured && <GoogleButton />}
        <Text style={[t.caption, { color: colors.muted, textAlign: 'center', marginTop: spacing.sm }]}>
          By continuing you agree to our{' '}
          <Text style={{ textDecorationLine: 'underline' }}>Terms</Text> and{' '}
          <Text style={{ textDecorationLine: 'underline' }}>Privacy</Text>.
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg, justifyContent: 'space-between' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  logo: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.amber,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actions: { padding: spacing.md, gap: spacing.sm, paddingBottom: spacing.xl },
  btn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: 14,
    borderRadius: radii.md,
  },
});
