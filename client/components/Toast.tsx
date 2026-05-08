import { useEffect, useRef } from 'react';
import { Animated, Easing, Pressable, StyleSheet, Text } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, radii, shadow, spacing } from '@/theme/tokens';
import { type as t } from '@/theme/typography';

export type ToastKind = 'info' | 'success' | 'error';

export type ToastViewProps = {
  message: string;
  kind: ToastKind;
  action?: { label: string; onPress: () => void };
  onDismiss: () => void;
};

const BG: Record<ToastKind, string> = {
  info: colors.ink,
  success: colors.amber,
  error: colors.danger,
};

export function ToastView({ message, kind, action, onDismiss }: ToastViewProps) {
  const insets = useSafeAreaInsets();
  const translate = useRef(new Animated.Value(-80)).current;

  useEffect(() => {
    Animated.timing(translate, {
      toValue: 0,
      duration: 220,
      easing: Easing.out(Easing.ease),
      useNativeDriver: true,
    }).start();
  }, [translate]);

  return (
    <Animated.View
      pointerEvents="box-none"
      style={[
        styles.wrap,
        {
          top: insets.top + spacing.sm,
          transform: [{ translateY: translate }],
        },
      ]}
    >
      <Pressable
        onPress={onDismiss}
        accessibilityRole="alert"
        style={[styles.toast, shadow.fab, { backgroundColor: BG[kind] }]}
      >
        <Text style={[t.body, styles.message]} numberOfLines={2}>
          {message}
        </Text>
        {action ? (
          <Pressable onPress={action.onPress} hitSlop={8} style={styles.actionWrap}>
            <Text style={[t.body, styles.action]}>{action.label}</Text>
          </Pressable>
        ) : null}
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    position: 'absolute',
    left: spacing.md,
    right: spacing.md,
  },
  toast: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    borderRadius: radii.md,
  },
  message: {
    flex: 1,
    color: colors.white,
    fontWeight: '600',
  },
  actionWrap: { paddingLeft: spacing.sm },
  action: {
    color: colors.white,
    fontWeight: '600',
    textDecorationLine: 'underline',
  },
});
