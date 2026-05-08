export function formatDurationHuman(ms: number): string {
  if (!Number.isFinite(ms) || ms <= 0) return '—';
  const totalMin = Math.round(ms / 60_000);
  const hours = Math.floor(totalMin / 60);
  const mins = totalMin % 60;
  if (hours === 0) return `${mins} min`;
  const hourPart = hours === 1 ? '1 hour' : `${hours} hours`;
  if (mins === 0) return hourPart;
  return `${hourPart} ${mins} min`;
}
