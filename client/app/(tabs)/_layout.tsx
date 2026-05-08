import { Tabs, useRouter } from 'expo-router';
import { Pressable, View } from 'react-native';
import { Calendar, Home, User, Mic } from 'lucide-react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, radii, shadow } from '@/theme/tokens';

export default function TabsLayout() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <Tabs
        initialRouteName="today"
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: colors.amber,
          tabBarInactiveTintColor: colors.muted,
          tabBarStyle: {
            backgroundColor: colors.bg,
            borderTopColor: colors.border,
            borderTopWidth: 1,
          },
          tabBarShowLabel: false,
        }}
      >
        <Tabs.Screen
          name="overview"
          options={{
            tabBarIcon: ({ color, size }) => <Home color={color} size={size} strokeWidth={1.75} />,
          }}
        />
        <Tabs.Screen
          name="today"
          options={{
            tabBarIcon: ({ color, size }) => (
              <Calendar color={color} size={size} strokeWidth={1.75} />
            ),
          }}
        />
        <Tabs.Screen
          name="profile"
          options={{
            tabBarIcon: ({ color, size }) => <User color={color} size={size} strokeWidth={1.75} />,
          }}
        />
      </Tabs>
      <Pressable
        accessibilityLabel="Capture entry"
        accessibilityRole="button"
        onPress={() => router.push('/capture')}
        style={({ pressed }) => [
          {
            position: 'absolute',
            right: 20,
            bottom: insets.bottom + 64,
            width: 56,
            height: 56,
            borderRadius: radii.fab,
            backgroundColor: colors.amber,
            alignItems: 'center',
            justifyContent: 'center',
            transform: [{ scale: pressed ? 0.96 : 1 }],
          },
          shadow.fab,
        ]}
      >
        <Mic color={colors.white} size={24} strokeWidth={1.75} />
      </Pressable>
    </View>
  );
}
