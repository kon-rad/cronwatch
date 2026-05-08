import { formatRowDateTime } from './listDate';

describe('formatRowDateTime', () => {
  test('returns localized date and time lines', () => {
    const out = formatRowDateTime('2026-05-08T18:30:00Z'); // 2:30 PM Eastern
    expect(out.dateLine).toBe('May 8');
    expect(out.timeLine.toLowerCase()).toContain('2:30');
    expect(out.timeLine.toUpperCase()).toContain('PM');
  });
  test('rolls over to previous day when UTC date differs from local date', () => {
    const out = formatRowDateTime('2026-05-09T02:00:00Z');
    expect(out.dateLine).toBe('May 8');
  });
  test('handles January single-digit days', () => {
    const out = formatRowDateTime('2026-01-03T15:00:00Z');
    expect(out.dateLine).toBe('Jan 3');
  });
});
