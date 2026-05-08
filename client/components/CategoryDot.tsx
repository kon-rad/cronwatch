import { View } from 'react-native';
import { colorForCategory } from '@/theme/categories';

export function CategoryDot({ category, size = 6 }: { category: string; size?: number }) {
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: colorForCategory(category),
      }}
    />
  );
}
