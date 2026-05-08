import { formatDurationHuman } from './duration';

describe('formatDurationHuman', () => {
  test('zero ms returns em-dash', () => {
    expect(formatDurationHuman(0)).toBe('—');
  });
  test('negative ms returns em-dash', () => {
    expect(formatDurationHuman(-5_000)).toBe('—');
  });
  test('under one hour reports minutes', () => {
    expect(formatDurationHuman(45 * 60_000)).toBe('45 min');
  });
  test('one minute is "1 min"', () => {
    expect(formatDurationHuman(60_000)).toBe('1 min');
  });
  test('exactly one hour says "1 hour"', () => {
    expect(formatDurationHuman(60 * 60_000)).toBe('1 hour');
  });
  test('exactly two hours says "2 hours"', () => {
    expect(formatDurationHuman(2 * 60 * 60_000)).toBe('2 hours');
  });
  test('1h30m says "1 hour 30 min"', () => {
    expect(formatDurationHuman(90 * 60_000)).toBe('1 hour 30 min');
  });
  test('2h15m says "2 hours 15 min"', () => {
    expect(formatDurationHuman(135 * 60_000)).toBe('2 hours 15 min');
  });
  test('rounds to nearest minute', () => {
    expect(formatDurationHuman(89 * 60_000 + 30_000)).toBe('1 hour 30 min');
  });
});
