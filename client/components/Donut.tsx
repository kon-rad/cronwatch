import Svg, { Circle, G } from 'react-native-svg';
import { View } from 'react-native';
import { colorForCategory } from '@/theme/categories';

interface Slice {
  category: string;
  minutes: number;
}

export function Donut({
  size = 132,
  thickness = 18,
  slices,
}: {
  size?: number;
  thickness?: number;
  slices: Slice[];
}) {
  const r = (size - thickness) / 2;
  const circumference = 2 * Math.PI * r;
  const total = slices.reduce((s, sl) => s + sl.minutes, 0) || 1;

  let offset = 0;
  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size} style={{ transform: [{ rotate: '-90deg' }] }}>
        <G origin={`${size / 2}, ${size / 2}`}>
          {slices.map((sl, i) => {
            const fraction = sl.minutes / total;
            const length = circumference * fraction;
            const dasharray = `${length} ${circumference - length}`;
            const dashoffset = -offset;
            offset += length;
            return (
              <Circle
                key={`${sl.category}-${i}`}
                cx={size / 2}
                cy={size / 2}
                r={r}
                stroke={colorForCategory(sl.category)}
                strokeWidth={thickness}
                strokeDasharray={dasharray}
                strokeDashoffset={dashoffset}
                fill="none"
              />
            );
          })}
        </G>
      </Svg>
    </View>
  );
}
