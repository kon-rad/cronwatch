export const CATEGORIES = [
  { key: 'work', label: 'Work', color: '#3D6F8E' },
  { key: 'deep', label: 'Deep', color: '#4F7A6A' },
  { key: 'meeting', label: 'Meeting', color: '#B07845' },
  { key: 'study', label: 'Study', color: '#8A6FA3' },
  { key: 'exercise', label: 'Exercise', color: '#C8412C' },
  { key: 'sleep', label: 'Sleep', color: '#5C5C58' },
  { key: 'meal', label: 'Meal', color: '#E8A33D' },
  { key: 'break', label: 'Break', color: '#A8A89D' },
  { key: 'commute', label: 'Commute', color: '#7A8A95' },
  { key: 'entertain', label: 'Entertain', color: '#A05B7E' },
  { key: 'personal', label: 'Personal', color: '#9C8855' },
] as const;

export type CategoryKey = (typeof CATEGORIES)[number]['key'];

const CATEGORY_MAP: Record<string, (typeof CATEGORIES)[number]> = CATEGORIES.reduce(
  (acc, cat) => {
    acc[cat.key] = cat;
    return acc;
  },
  {} as Record<string, (typeof CATEGORIES)[number]>,
);

const FALLBACK_COLOR = '#5C5C58';

/**
 * Resolve a category key (or freeform label) to its swatch color.
 * Tries exact key match first, then case-insensitive label match,
 * then falls back to the muted ink color.
 */
export function colorForCategory(key: string): string {
  if (CATEGORY_MAP[key]) return CATEGORY_MAP[key].color;
  const lower = key.toLowerCase();
  const byLabel = CATEGORIES.find((c) => c.label.toLowerCase() === lower);
  if (byLabel) return byLabel.color;
  const byKey = CATEGORIES.find((c) => c.key.toLowerCase() === lower);
  if (byKey) return byKey.color;
  return FALLBACK_COLOR;
}

/**
 * Returns a 12%-alpha tint of the category color, suitable for the
 * row pill background on the Today grid.
 */
export function pillBgForCategory(key: string): string {
  const color = colorForCategory(key);
  // Convert #RRGGBB to rgba(r,g,b,0.12)
  const hex = color.replace('#', '');
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, 0.12)`;
}
