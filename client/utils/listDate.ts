export function formatRowDateTime(iso: string): { dateLine: string; timeLine: string } {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return { dateLine: '', timeLine: '' };
  const dateLine = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  const timeLine = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
  return { dateLine, timeLine };
}
