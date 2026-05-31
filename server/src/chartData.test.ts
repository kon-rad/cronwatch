import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildChartDatasets,
  buildHeatmap,
  buildStrip,
  combineDocument,
  formatHm,
  splitEntriesByLocalDay,
  type DayInput,
  type EntryInput,
} from './chartData';

function day(date: string, cats: Record<string, number>): DayInput {
  return { date, categories: Object.entries(cats).map(([name, minutes]) => ({ name, minutes })) };
}

test('formatHm formats hours and minutes', () => {
  assert.equal(formatHm(0), '0m');
  assert.equal(formatHm(45), '45m');
  assert.equal(formatHm(60), '1h');
  assert.equal(formatHm(150), '2h30');
});

test('categoryTotals are sorted, percented, and labelled', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 120, sleep: 360 })],
    [],
  );
  assert.equal(ds.hasData, true);
  assert.equal(ds.categoryTotals[0].name, 'sleep');
  assert.equal(ds.categoryTotals[0].minutes, 360);
  assert.equal(ds.categoryTotals[0].pct, 75);
  assert.equal(ds.categoryTotals[0].hoursLabel, '6h');
  assert.equal(ds.categoryTotals[1].name, 'work');
  assert.equal(ds.categoryTotals[1].pct, 25);
});

test('categories beyond top 8 collapse into "other"', () => {
  const cats: Record<string, number> = {};
  for (let i = 0; i < 10; i++) cats[`c${i}`] = (i + 1) * 10;
  const ds = buildChartDatasets([day('2026-05-01', cats)], []);
  assert.equal(ds.categoryTotals.length, 9); // top 8 + other
  assert.equal(ds.categoryTotals[ds.categoryTotals.length - 1].name, 'other');
});

test('buckets use daily mode for <= 31 days', () => {
  const days = Array.from({ length: 10 }, (_, i) =>
    day(`2026-05-${String(i + 1).padStart(2, '0')}`, { work: 60 }),
  );
  const ds = buildChartDatasets(days, []);
  assert.equal(ds.buckets.mode, 'daily');
  assert.equal(ds.buckets.items.length, 10);
});

test('buckets roll up to weekly mode for > 31 days', () => {
  const days = Array.from({ length: 35 }, (_, i) => {
    const d = new Date(Date.UTC(2026, 4, 1) + i * 86400000);
    return day(d.toISOString().slice(0, 10), { work: 60 });
  });
  const ds = buildChartDatasets(days, []);
  assert.equal(ds.buckets.mode, 'weekly');
  assert.ok(ds.buckets.items.length <= 6);
});

test('byWeekday averages minutes across occurrences', () => {
  // Two Fridays (2026-05-01, 2026-05-08), one Saturday (2026-05-02)
  const ds = buildChartDatasets(
    [
      day('2026-05-01', { work: 100 }),
      day('2026-05-08', { work: 200 }),
      day('2026-05-02', { work: 60 }),
    ],
    [],
  );
  const fri = ds.byWeekday.find((w) => w.weekday === 'Fri')!;
  const sat = ds.byWeekday.find((w) => w.weekday === 'Sat')!;
  assert.equal(fri.avgMinutes, 150); // (100 + 200) / 2
  assert.equal(sat.avgMinutes, 60);
  assert.equal(ds.byWeekday.length, 7);
  assert.equal(ds.byWeekday[0].weekday, 'Mon');
});

test('goalProgress parses weekly hour targets and maps to a category', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 600 }), day('2026-05-08', { work: 600 })],
    ['Work 80 hours per week', 'Be happier'],
  );
  assert.equal(ds.goalProgress.length, 1);
  const gp = ds.goalProgress[0];
  assert.equal(gp.category, 'work');
  assert.equal(gp.unit, 'week');
  assert.equal(gp.targetHours, 80);
  // 1200m = 20h over 8 days => weekly = 20 / (8/7) = 17.5
  assert.equal(gp.actualHours, 17.5);
});

test('goalProgress skips goals with no numeric target or no category match', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 60 })],
    ['sleep 8 hours', 'study more'],
  );
  // "sleep 8 hours" has a target but no "sleep" category tracked -> skipped
  // "study more" has no number -> skipped
  assert.equal(ds.goalProgress.length, 0);
});

test('hasData is false when nothing is tracked', () => {
  const ds = buildChartDatasets([day('2026-05-01', {})], []);
  assert.equal(ds.hasData, false);
  assert.equal(ds.totalMinutes, 0);
});

test('combineDocument splices charts into the marker', () => {
  const out = combineDocument('<section>A<!-- CW_CHARTS -->B</section>', '<div>charts</div>');
  assert.equal(out, '<section>A<div>charts</div>B</section>');
});

test('combineDocument appends before last </section> when marker missing', () => {
  const out = combineDocument('<section>A</section>', '<div>charts</div>');
  assert.equal(out, '<section>A<div>charts</div></section>');
});

test('combineDocument removes the marker when charts are empty', () => {
  const out = combineDocument('<section>A<!-- CW_CHARTS -->B</section>', '');
  assert.equal(out, '<section>AB</section>');
});

// ─── splitEntriesByLocalDay ───────────────────────────────────────────────────

test('splitEntriesByLocalDay parses wall-clock prefix and ignores offset', () => {
  const segs = splitEntriesByLocalDay([
    { category: 'work', startTime: '2026-05-08T09:00:00-07:00', endTime: '2026-05-08T10:30:00-07:00' },
  ]);
  assert.equal(segs.length, 1);
  assert.deepEqual(segs[0], { date: '2026-05-08', category: 'work', startMin: 540, endMin: 630 });
});

test('splitEntriesByLocalDay skips malformed strings and end<=start', () => {
  const segs = splitEntriesByLocalDay([
    { category: 'a', startTime: 'not-a-date', endTime: '2026-05-08T10:00:00Z' },
    { category: 'b', startTime: '2026-05-08T10:00:00Z', endTime: 'also-bad' },
    { category: 'c', startTime: '2026-05-08T10:00:00Z', endTime: '2026-05-08T10:00:00Z' }, // end == start
    { category: 'd', startTime: '2026-05-08T11:00:00Z', endTime: '2026-05-08T10:00:00Z' }, // end < start
    { category: 'ok', startTime: '2026-05-08T08:00:00Z', endTime: '2026-05-08T09:00:00Z' },
  ]);
  assert.equal(segs.length, 1);
  assert.equal(segs[0].category, 'ok');
});

test('splitEntriesByLocalDay splits an entry across local midnight', () => {
  const segs = splitEntriesByLocalDay([
    { category: 'sleep', startTime: '2026-05-08T23:00:00Z', endTime: '2026-05-09T06:30:00Z' },
  ]);
  assert.equal(segs.length, 2);
  assert.deepEqual(segs[0], { date: '2026-05-08', category: 'sleep', startMin: 1380, endMin: 1440 });
  assert.deepEqual(segs[1], { date: '2026-05-09', category: 'sleep', startMin: 0, endMin: 390 });
});

// ─── buildHeatmap ─────────────────────────────────────────────────────────────

test('buildHeatmap averages minutes by distinct weekday occurrences', () => {
  // Two Mondays, each 60m at 09:00. Average should be 60, not 120.
  const days: DayInput[] = [
    { date: '2026-05-04', categories: [{ name: 'work', minutes: 60 }] }, // Monday
    { date: '2026-05-11', categories: [{ name: 'work', minutes: 60 }] }, // Monday
  ];
  const entries: EntryInput[] = [
    { category: 'work', startTime: '2026-05-04T09:00:00Z', endTime: '2026-05-04T10:00:00Z' },
    { category: 'work', startTime: '2026-05-11T09:00:00Z', endTime: '2026-05-11T10:00:00Z' },
  ];
  const hm = buildHeatmap(entries, days);
  assert.equal(hm.cells.length, 7);
  assert.equal(hm.cells[0].length, 24);
  assert.equal(hm.cells[0][9], 60); // Mon, hour 9
  assert.equal(hm.maxAvg, 60);
});

test('buildHeatmap allocates minutes across overlapping hour buckets', () => {
  const days: DayInput[] = [{ date: '2026-05-04', categories: [{ name: 'work', minutes: 90 }] }];
  const entries: EntryInput[] = [
    { category: 'work', startTime: '2026-05-04T09:00:00Z', endTime: '2026-05-04T10:30:00Z' },
  ];
  const hm = buildHeatmap(entries, days);
  assert.equal(hm.cells[0][9], 60); // full hour 9
  assert.equal(hm.cells[0][10], 30); // half of hour 10
});

test('buildHeatmap never produces NaN/Infinity with no entries', () => {
  const days: DayInput[] = [{ date: '2026-05-04', categories: [{ name: 'work', minutes: 0 }] }];
  const hm = buildHeatmap([], days);
  assert.equal(hm.maxAvg, 0);
  for (const row of hm.cells) for (const v of row) assert.ok(Number.isFinite(v));
});

// ─── buildStrip ───────────────────────────────────────────────────────────────

test('buildStrip groups segments per local day sorted ascending with colors', () => {
  const palette = { work: '#3D6F8E' };
  const strip = buildStrip(
    [
      { category: 'work', startTime: '2026-05-09T09:00:00Z', endTime: '2026-05-09T10:00:00Z' },
      { category: 'work', startTime: '2026-05-08T08:00:00Z', endTime: '2026-05-08T09:00:00Z' },
      { category: 'unknown', startTime: '2026-05-08T12:00:00Z', endTime: '2026-05-08T13:00:00Z' },
    ],
    palette,
  );
  assert.equal(strip.days.length, 2);
  assert.equal(strip.days[0].date, '2026-05-08');
  assert.equal(strip.days[0].label, '05-08');
  assert.equal(strip.days[1].date, '2026-05-09');
  const d0 = strip.days[0];
  assert.deepEqual(d0.segments[0], { category: 'work', color: '#3D6F8E', startMin: 480, endMin: 540 });
  // Unknown category falls back to the default color.
  assert.equal(d0.segments[1].color, '#A8A89D');
});

test('buildStrip splits midnight-spanning entries into two day rows', () => {
  const strip = buildStrip(
    [{ category: 'sleep', startTime: '2026-05-08T23:00:00Z', endTime: '2026-05-09T06:00:00Z' }],
    {},
  );
  assert.equal(strip.days.length, 2);
  assert.equal(strip.days[0].segments[0].endMin, 1440);
  assert.equal(strip.days[1].segments[0].startMin, 0);
});

// ─── buildChartDatasets back-compat ───────────────────────────────────────────

test('buildChartDatasets works with entries omitted (back-compat)', () => {
  const ds = buildChartDatasets([day('2026-05-01', { work: 120 })], []);
  assert.equal(ds.heatmap.maxAvg, 0);
  assert.equal(ds.strip.days.length, 0);
  assert.ok(Array.isArray(ds.heatmap.cells));
});

test('buildChartDatasets threads entries into heatmap and strip', () => {
  const ds = buildChartDatasets(
    [{ date: '2026-05-04', categories: [{ name: 'work', minutes: 60 }] }],
    [],
    [{ category: 'work', startTime: '2026-05-04T09:00:00Z', endTime: '2026-05-04T10:00:00Z' }],
  );
  assert.equal(ds.heatmap.cells[0][9], 60);
  assert.equal(ds.strip.days.length, 1);
});

test('bucket segments never reference a category missing from palette (>8 categories)', () => {
  const cats: Record<string, number> = {};
  for (let i = 0; i < 10; i++) cats[`c${i}`] = (i + 1) * 10;
  const ds = buildChartDatasets(
    [
      day('2026-05-01', cats),
      day('2026-05-02', cats),
    ],
    [],
  );
  const paletteKeys = new Set(Object.keys(ds.palette));
  for (const item of ds.buckets.items) {
    for (const seg of item.segments) {
      assert.ok(paletteKeys.has(seg.name), `segment "${seg.name}" missing from palette`);
    }
  }
});
