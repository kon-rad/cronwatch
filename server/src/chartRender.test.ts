import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildChartDatasets, type DayInput } from './chartData';
import { renderCharts } from './chartRender';

function day(date: string, cats: Record<string, number>): DayInput {
  return { date, categories: Object.entries(cats).map(([name, minutes]) => ({ name, minutes })) };
}

/** Count occurrences of class="cw-card" in the fragment. */
function countCards(html: string): number {
  return (html.match(/class="cw-card"/g) ?? []).length;
}

test('renders 3 cards when no goals are present', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 120, sleep: 360 })],
    [],
  );
  const html = renderCharts(ds);
  assert.equal(countCards(html), 3);
  assert.ok(!html.includes('GOAL PROGRESS'));
});

test('renders 4 cards when an hour-based goal is present', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 600 }), day('2026-05-08', { work: 600 })],
    ['Work 80 hours per week'],
  );
  const html = renderCharts(ds);
  assert.equal(countCards(html), 4);
  assert.ok(html.includes('GOAL PROGRESS'));
});

test('every categoryTotals name, hoursLabel, and pct appears in the output', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 120, sleep: 360, meal: 60 })],
    [],
  );
  const html = renderCharts(ds);
  for (const t of ds.categoryTotals) {
    assert.ok(html.includes(t.name), `name "${t.name}" missing`);
    assert.ok(html.includes(t.hoursLabel), `hoursLabel "${t.hoursLabel}" missing`);
    assert.ok(html.includes(`(${t.pct}%)`), `pct "${t.pct}%" missing`);
  }
});

test('each non-zero weekday hoursLabel appears; zero weekdays print no value', () => {
  // Single Friday with data; all other weekdays are zero.
  const ds = buildChartDatasets([day('2026-05-01', { work: 100 })], []);
  const html = renderCharts(ds);

  const fri = ds.byWeekday.find((w) => w.weekday === 'Fri')!;
  assert.ok(fri.avgMinutes > 0);
  assert.ok(html.includes(fri.hoursLabel), 'Friday hoursLabel missing');

  // Zero weekdays: the value text node "0m" must not be printed as a bar value.
  // The weekday axis labels (Mon..Sun) are always present, but no "0m" value.
  for (const w of ds.byWeekday) {
    if (w.avgMinutes === 0) {
      // hoursLabel for zero is "0m" — ensure it is not rendered as a value label.
      assert.ok(!html.includes('>0m<'), 'zero-weekday value label should be omitted');
    }
  }
});

test('weekly goal label appears as "<cat>: <actual>h of <target>h/wk"', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 600 }), day('2026-05-08', { work: 600 })],
    ['Work 80 hours per week'],
  );
  const html = renderCharts(ds);
  const gp = ds.goalProgress[0];
  const label = `${gp.category}: ${gp.actualHours}h of ${gp.targetHours}h/wk`;
  assert.ok(html.includes(label), `goal label "${label}" missing`);
});

test('output contains the .cw-charts wrapper and a scoped style block, no script', () => {
  const ds = buildChartDatasets([day('2026-05-01', { work: 120 })], []);
  const html = renderCharts(ds);
  assert.ok(html.includes('class="cw-charts"'), '.cw-charts wrapper missing');
  assert.ok(html.includes('<style>'), '<style> block missing');
  assert.ok(html.includes('.cw-charts'), 'scoped selector missing');
  assert.ok(!html.includes('<script'), 'should contain no <script>');
});

test('output contains no NaN or Infinity substring', () => {
  const ds = buildChartDatasets(
    [day('2026-05-01', { work: 120, sleep: 360 }), day('2026-05-02', { work: 90 })],
    ['Work 40 hours per week'],
  );
  const html = renderCharts(ds);
  assert.ok(!html.includes('NaN'), 'output contains NaN');
  assert.ok(!html.includes('Infinity'), 'output contains Infinity');
});

test('a >31-day range produces weekly buckets (one bar per week)', () => {
  const days = Array.from({ length: 35 }, (_, i) => {
    const d = new Date(Date.UTC(2026, 4, 1) + i * 86400000);
    return day(d.toISOString().slice(0, 10), { work: 60 });
  });
  const ds = buildChartDatasets(days, []);
  assert.equal(ds.buckets.mode, 'weekly');
  const html = renderCharts(ds);
  // One <rect> bar segment per weekly bucket (each week has a single 'work' segment).
  // Verify each weekly bucket label appears verbatim in the timeline card.
  for (const item of ds.buckets.items) {
    assert.ok(html.includes(`>${item.label}<`), `weekly bucket label "${item.label}" missing`);
  }
  assert.ok(ds.buckets.items.length <= 6);
});

test('empty/all-zero chart data renders a muted "Not enough data to chart." line', () => {
  // A single day with all-zero minutes: hasData is false at the dataset level, but
  // renderCharts still degrades each card gracefully if invoked directly.
  const ds = buildChartDatasets([day('2026-05-01', { work: 0 })], []);
  const html = renderCharts(ds);
  assert.ok(html.includes('Not enough data to chart.'));
  assert.ok(!html.includes('NaN'));
  assert.ok(!html.includes('Infinity'));
});
