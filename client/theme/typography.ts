// The design spec calls for weights 600 / 450 / 500. React Native's font weight
// system does not support 450, so we use 500 for body. Inter is loaded through
// @expo-google-fonts/inter at app boot.
export const type = {
  title: { fontFamily: 'Inter_600SemiBold', fontSize: 22, lineHeight: 28 },
  body: { fontFamily: 'Inter_500Medium', fontSize: 15, lineHeight: 22 },
  caption: { fontFamily: 'Inter_500Medium', fontSize: 12, lineHeight: 16 },
};

export const tabular = { fontVariant: ['tabular-nums' as const] };
