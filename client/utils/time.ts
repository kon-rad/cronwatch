import type { Entry } from '@/types/entry';

export const MIN_PER_DAY = 24 * 60;

export function minutesSinceMidnight(iso: string): number {
  const d = new Date(iso);
  return d.getHours() * 60 + d.getMinutes();
}

export function entryDurationMin(e: Entry): number {
  return Math.max(15, Math.round((Date.parse(e.endTime) - Date.parse(e.startTime)) / 60_000));
}

export function formatHHMM(date: Date): string {
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  return `${hh}:${mm}`;
}

export function formatTimeFromIso(iso: string): string {
  return formatHHMM(new Date(iso));
}

export function formatDuration(min: number): string {
  if (min < 60) return `${min}m`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

export function formatLongDate(date: Date = new Date()): string {
  return date.toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });
}

export function totalTrackedMin(entries: Entry[]): number {
  return entries.reduce((sum, e) => sum + entryDurationMin(e), 0);
}

export function snapTo15(min: number): number {
  return Math.round(min / 15) * 15;
}
