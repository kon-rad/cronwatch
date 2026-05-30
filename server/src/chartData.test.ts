import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildChartDatasets,
  combineDocument,
  formatHm,
  type DayInput,
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
