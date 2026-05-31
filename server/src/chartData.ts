/**
 * Pure, LLM-free transforms that turn validated report request data into
 * ready-to-plot datasets. The chart-generation LLM receives these numbers and
 * only does layout — it never computes values. Also hosts combineDocument,
 * which merges the prose-report fragment with the charts fragment.
 */

export interface CategoryMinutesInput {
  name: string;
  minutes: number;
}

export interface DayInput {
  date: string; // yyyy-mm-dd
  categories: CategoryMinutesInput[];
}

export interface CategoryTotal {
  name: string;
  minutes: number;
  hoursLabel: string;
  pct: number; // 0-100, rounded to nearest integer
  color: string;
}

export interface DaySegment {
  name: string;
  minutes: number;
}

export interface Bucket {
  label: string; // short axis label, e.g. "05-24" or "May 24"
  segments: DaySegment[];
  totalMinutes: number;
}

export interface WeekdayAvg {
  weekday: string; // Mon..Sun
  avgMinutes: number;
  hoursLabel: string;
}

export interface GoalProgress {
  goal: string;
  category: string;
  actualHours: number;
  targetHours: number;
  unit: 'week' | 'total';
}

export interface EntryInput {
  category: string;
  startTime: string; // ISO 8601 with offset, e.g. "2026-05-08T09:00:00-07:00"
  endTime: string; // ISO 8601 with offset
}

/** A single entry clipped to one local calendar day. */
export interface DaySplitSegment {
  date: string; // yyyy-mm-dd (local)
  category: string;
  startMin: number; // minute-of-day [0,1440]
  endMin: number; // minute-of-day [0,1440]
}

export interface HeatmapData {
  /** [7][24] average minutes; rows Mon=0..Sun=6, cols hour 0..23. */
  cells: number[][];
  maxAvg: number;
}

export interface StripSegment {
  category: string;
  color: string;
  startMin: number;
  endMin: number;
}

export interface StripDay {
  date: string; // yyyy-mm-dd
  label: string; // MM-DD
  segments: StripSegment[];
}

export interface StripData {
  days: StripDay[];
}

export interface ChartDatasets {
  totalMinutes: number;
  numDays: number;
  hasData: boolean;
  categoryTotals: CategoryTotal[];
  buckets: { mode: 'daily' | 'weekly'; items: Bucket[] };
  byWeekday: WeekdayAvg[];
  goalProgress: GoalProgress[];
  palette: Record<string, string>;
  heatmap: HeatmapData;
  strip: StripData;
}

const TOP_N = 8;
const DAILY_MAX_DAYS = 31;

const PALETTE: Record<string, string> = {
  work: '#3D6F8E',
  meeting: '#B07845',
  study: '#8A6FA3',
  exercise: '#C8412C',
  sleep: '#5C5C58',
  meal: '#E8A33D',
  break: '#A8A89D',
  commute: '#7A8A95',
  entertain: '#A05B7E',
  personal: '#9C8855',
};

const FALLBACK_COLORS = ['#6E8B74', '#9A7B6A', '#7E7AA0', '#A0884F', '#5F8A8B', '#A86F6F'];
const OTHER_COLOR = '#A8A89D';

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

export function formatHm(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h${String(m).padStart(2, '0')}`;
}

function colorFor(name: string, index: number): string {
  return PALETTE[name] ?? FALLBACK_COLORS[index % FALLBACK_COLORS.length];
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** weekday index Mon=0..Sun=6 from a yyyy-mm-dd string (UTC to avoid tz drift). */
function weekdayIndex(date: string): number {
  const d = new Date(`${date}T00:00:00Z`);
  return (d.getUTCDay() + 6) % 7; // JS: Sun=0 -> shift so Mon=0
}

export function aggregateTotals(days: DayInput[]): { name: string; minutes: number }[] {
  const totals: Record<string, number> = {};
  const order: string[] = [];
  for (const day of days) {
    for (const cat of day.categories) {
      if (totals[cat.name] === undefined) order.push(cat.name);
      totals[cat.name] = (totals[cat.name] ?? 0) + cat.minutes;
    }
  }
  return order
    .map((name) => ({ name, minutes: totals[name] ?? 0 }))
    .sort((a, b) => b.minutes - a.minutes);
}

function buildCategoryTotals(
  rawTotals: { name: string; minutes: number }[],
  totalMinutes: number,
): CategoryTotal[] {
  let working = rawTotals;
  if (rawTotals.length > TOP_N) {
    const head = rawTotals.slice(0, TOP_N);
    const tailMinutes = rawTotals.slice(TOP_N).reduce((sum, t) => sum + t.minutes, 0);
    working = [...head, { name: 'other', minutes: tailMinutes }];
  }
  return working.map((t, i) => ({
    name: t.name,
    minutes: t.minutes,
    hoursLabel: formatHm(t.minutes),
    pct: totalMinutes === 0 ? 0 : Math.round((t.minutes / totalMinutes) * 100),
    color: t.name === 'other' ? OTHER_COLOR : colorFor(t.name, i),
  }));
}

/**
 * Normalizes a list of segments against the allowed palette names, remapping any
 * unknown name to 'other' and summing minutes for merged names while preserving
 * first-seen order. Keeps bucket segment names in sync with the palette keys.
 */
function remapSegments(segments: DaySegment[], allowed: Set<string>): DaySegment[] {
  const merged: Record<string, number> = {};
  const order: string[] = [];
  for (const seg of segments) {
    const name = allowed.has(seg.name) ? seg.name : 'other';
    if (merged[name] === undefined) order.push(name);
    merged[name] = (merged[name] ?? 0) + seg.minutes;
  }
  return order.map((name) => ({ name, minutes: merged[name] }));
}

function buildBuckets(
  days: DayInput[],
  allowed: Set<string>,
): { mode: 'daily' | 'weekly'; items: Bucket[] } {
  const sorted = [...days].sort((a, b) => a.date.localeCompare(b.date));
  const segmentsOf = (day: DayInput): DaySegment[] =>
    day.categories.map((c) => ({ name: c.name, minutes: c.minutes }));
  const totalOf = (day: DayInput): number =>
    day.categories.reduce((sum, c) => sum + c.minutes, 0);

  if (sorted.length <= DAILY_MAX_DAYS) {
    return {
      mode: 'daily',
      items: sorted.map((d) => ({
        label: d.date.slice(5), // MM-DD
        segments: remapSegments(segmentsOf(d), allowed),
        totalMinutes: totalOf(d),
      })),
    };
  }

  // Weekly rollup: group into consecutive 7-day windows starting at the first date.
  const items: Bucket[] = [];
  for (let i = 0; i < sorted.length; i += 7) {
    const chunk = sorted.slice(i, i + 7);
    const totals: Record<string, number> = {};
    for (const d of chunk) for (const c of d.categories) totals[c.name] = (totals[c.name] ?? 0) + c.minutes;
    const segments = remapSegments(
      Object.entries(totals).map(([name, minutes]) => ({ name, minutes })),
      allowed,
    );
    items.push({
      label: chunk[0].date.slice(5),
      segments,
      totalMinutes: segments.reduce((sum, s) => sum + s.minutes, 0),
    });
  }
  return { mode: 'weekly', items };
}

function buildByWeekday(days: DayInput[]): WeekdayAvg[] {
  const sums = new Array(7).fill(0);
  const counts = new Array(7).fill(0);
  for (const day of days) {
    const idx = weekdayIndex(day.date);
    sums[idx] += day.categories.reduce((s, c) => s + c.minutes, 0);
    counts[idx] += 1;
  }
  return WEEKDAYS.map((weekday, i) => {
    const avgMinutes = counts[i] === 0 ? 0 : Math.round((sums[i] / counts[i]) * 10) / 10;
    return {
      weekday,
      avgMinutes,
      hoursLabel: formatHm(Math.round(avgMinutes)),
    };
  });
}

function parseGoalTarget(goal: string): { hours: number; unit: 'week' | 'total' } | null {
  const m = goal.match(/(\d+(?:\.\d+)?)\s*(?:h\b|hrs?\b|hours?\b)/i);
  if (!m) return null;
  const hours = parseFloat(m[1]);
  const weekly = /per\s+week|\/\s*week|weekly|a\s+week|each\s+week/i.test(goal);
  return { hours, unit: weekly ? 'week' : 'total' };
}

/** Inclusive day span between the earliest and latest dates (1 for a single day). */
function spanDays(days: DayInput[]): number {
  if (days.length === 0) return 0;
  const times = days.map((d) => Date.parse(`${d.date}T00:00:00Z`));
  const min = Math.min(...times);
  const max = Math.max(...times);
  return Math.round((max - min) / 86400000) + 1;
}

function buildGoalProgress(
  goals: string[],
  totals: { name: string; minutes: number }[],
  numDays: number,
): GoalProgress[] {
  const out: GoalProgress[] = [];
  for (const goal of goals) {
    const target = parseGoalTarget(goal);
    if (!target) continue;
    const cat = totals.find((t) => new RegExp(`\\b${escapeRegExp(t.name)}\\b`, 'i').test(goal));
    if (!cat) continue;
    const actualTotalHours = cat.minutes / 60;
    const weeks = numDays / 7;
    const actualHours =
      target.unit === 'week' && weeks > 0
        ? Math.round((actualTotalHours / weeks) * 10) / 10
        : Math.round(actualTotalHours * 10) / 10;
    out.push({
      goal,
      category: cat.name,
      actualHours,
      targetHours: target.hours,
      unit: target.unit,
    });
  }
  return out;
}

/**
 * Parse the wall-clock prefix `YYYY-MM-DDTHH:MM` of an ISO 8601 string. The text
 * before any timezone offset IS the user's local wall-clock time, so we use it
 * directly — no timezone math. Returns null for malformed input.
 */
function parseWallClock(iso: string): { date: string; minute: number } | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(iso);
  if (!m) return null;
  const [, yy, mo, dd, hh, mm] = m;
  const month = Number(mo);
  const dayNum = Number(dd);
  const hour = Number(hh);
  const min = Number(mm);
  if (month < 1 || month > 12) return null;
  if (dayNum < 1 || dayNum > 31) return null;
  if (hour > 23 || min > 59) return null;
  return { date: `${yy}-${mo}-${dd}`, minute: hour * 60 + min };
}

/** Add `n` days to a yyyy-mm-dd date string (UTC math to avoid tz drift). */
function addDays(date: string, n: number): string {
  const t = Date.parse(`${date}T00:00:00Z`) + n * 86400000;
  return new Date(t).toISOString().slice(0, 10);
}

/**
 * Split each entry into per-local-day segments at local midnight. Each segment is
 * `{ date, category, startMin, endMin }` with minute-of-day in [0,1440]. Entries
 * with malformed start/end strings or where end <= start are skipped.
 */
export function splitEntriesByLocalDay(entries: EntryInput[]): DaySplitSegment[] {
  const out: DaySplitSegment[] = [];
  for (const e of entries) {
    const start = parseWallClock(e.startTime);
    const end = parseWallClock(e.endTime);
    if (!start || !end) continue;

    const startAbs = Date.parse(`${start.date}T00:00:00Z`) + start.minute * 60000;
    const endAbs = Date.parse(`${end.date}T00:00:00Z`) + end.minute * 60000;
    if (endAbs <= startAbs) continue;

    let cursorDate = start.date;
    let cursorMin = start.minute;
    // Walk day by day until we reach the end date.
    // Bound the loop defensively to avoid runaway on pathological input.
    let guard = 0;
    while (guard++ < 4000) {
      const isLastDay = cursorDate === end.date;
      const segEnd = isLastDay ? end.minute : 1440;
      if (segEnd > cursorMin) {
        out.push({
          date: cursorDate,
          category: e.category,
          startMin: cursorMin,
          endMin: segEnd,
        });
      }
      if (isLastDay) break;
      cursorDate = addDays(cursorDate, 1);
      cursorMin = 0;
    }
  }
  return out;
}

/**
 * Allocate a segment's minutes across the hour buckets [0,23] it overlaps.
 * A 09:00–10:30 segment contributes 60 to hour 9 and 30 to hour 10.
 */
function allocateToHours(startMin: number, endMin: number, acc: number[]): void {
  let cursor = startMin;
  while (cursor < endMin) {
    const hour = Math.floor(cursor / 60);
    if (hour > 23) break;
    const hourEnd = (hour + 1) * 60;
    const segEnd = Math.min(endMin, hourEnd);
    acc[hour] += segEnd - cursor;
    cursor = segEnd;
  }
}

/**
 * Time-of-day heatmap. Cell value = total minutes landing in that (weekday,hour)
 * across the range, divided by the number of distinct dates in `days` falling on
 * that weekday (so two Mondays each with 60m at 09:00 => cell[Mon][9] = 60).
 * All divisions guarded; never produces NaN/Infinity.
 */
export function buildHeatmap(entries: EntryInput[], days: DayInput[]): HeatmapData {
  // Distinct weekday-occurrence counts from the days array (each date once).
  const occ = new Array(7).fill(0);
  const seenDates = new Set<string>();
  for (const d of days) {
    if (seenDates.has(d.date)) continue;
    seenDates.add(d.date);
    occ[weekdayIndex(d.date)] += 1;
  }

  // Total minutes per [weekday][hour].
  const totals: number[][] = Array.from({ length: 7 }, () => new Array(24).fill(0));
  for (const seg of splitEntriesByLocalDay(entries)) {
    const wd = weekdayIndex(seg.date);
    allocateToHours(seg.startMin, seg.endMin, totals[wd]);
  }

  let maxAvg = 0;
  const cells: number[][] = totals.map((row, wd) =>
    row.map((total) => {
      const count = occ[wd];
      const avg = count > 0 ? total / count : 0;
      if (avg > maxAvg) maxAvg = avg;
      return avg;
    }),
  );

  return { cells, maxAvg };
}

/**
 * Daily rhythm strip. One entry per local day present in the entries' split,
 * sorted ascending by date, each carrying its category-colored clock segments.
 */
export function buildStrip(entries: EntryInput[], palette: Record<string, string>): StripData {
  const byDate = new Map<string, StripSegment[]>();
  for (const seg of splitEntriesByLocalDay(entries)) {
    const color = palette[seg.category] ?? OTHER_COLOR;
    const list = byDate.get(seg.date) ?? [];
    list.push({
      category: seg.category,
      color,
      startMin: seg.startMin,
      endMin: seg.endMin,
    });
    byDate.set(seg.date, list);
  }

  const dates = [...byDate.keys()].sort((a, b) => a.localeCompare(b));
  return {
    days: dates.map((date) => ({
      date,
      label: date.slice(5), // MM-DD
      segments: byDate.get(date) ?? [],
    })),
  };
}

export function buildChartDatasets(
  days: DayInput[],
  goals: string[],
  entries: EntryInput[] = [],
): ChartDatasets {
  const rawTotals = aggregateTotals(days);
  const totalMinutes = rawTotals.reduce((sum, t) => sum + t.minutes, 0);
  const numDays = days.length;
  const categoryTotals = buildCategoryTotals(rawTotals, totalMinutes);
  const palette: Record<string, string> = {};
  for (const c of categoryTotals) palette[c.name] = c.color;

  return {
    totalMinutes,
    numDays,
    hasData: totalMinutes > 0,
    categoryTotals,
    buckets: buildBuckets(days, new Set(Object.keys(palette))),
    byWeekday: buildByWeekday(days),
    goalProgress: buildGoalProgress(goals, rawTotals, spanDays(days)),
    palette,
    heatmap: buildHeatmap(entries, days),
    strip: buildStrip(entries, palette),
  };
}

const CHARTS_MARKER = '<!-- CW_CHARTS -->';

/**
 * Merge the prose-report fragment with the charts fragment. Splices charts into
 * the marker when present; otherwise inserts before the last </section>; passing
 * an empty chartsHtml cleanly removes the marker (graceful degradation).
 */
export function combineDocument(reportHtml: string, chartsHtml: string): string {
  if (reportHtml.includes(CHARTS_MARKER)) {
    return reportHtml.replace(CHARTS_MARKER, chartsHtml);
  }
  if (chartsHtml === '') return reportHtml;
  const idx = reportHtml.lastIndexOf('</section>');
  if (idx !== -1) return reportHtml.slice(0, idx) + chartsHtml + reportHtml.slice(idx);
  return reportHtml + chartsHtml;
}
