import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildChartDatasets, type DayInput, type EntryInput } from './chartData';
import { renderCharts } from './chartRender';

function day(date: string, cats: Record<string, number>): DayInput {
  return { date, categories: Object.entries(cats).map(([name, minutes]) => ({ name, minutes })) };
}

const SAMPLE_ENTRIES: EntryInput[] = [
  { category: 'work', startTime: '2026-05-04T09:00:00Z', endTime: '2026-05-04T12:00:00Z' },
  { category: 'work', startTime: '2026-05-05T09:00:00Z', endTime: '2026-05-05T11:30:00Z' },
];

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

test('heatmap card shows all 7 weekday labels, hour axis, and scale legend', () => {
  const days = [
    day('2026-05-04', { work: 180 }),
    day('2026-05-05', { work: 150 }),
  ];
  const ds = buildChartDatasets(days, [], SAMPLE_ENTRIES);
  const html = renderCharts(ds);

  assert.ok(html.includes("WHEN YOU'RE ACTIVE"), 'heatmap eyebrow missing');
  for (const wd of ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
    assert.ok(html.includes(`>${wd}<`), `weekday label "${wd}" missing`);
  }
  for (const tick of ['12a', '6a', '12p', '6p']) {
    assert.ok(html.includes(`>${tick}<`), `hour tick "${tick}" missing`);
  }
  assert.ok(html.includes('avg per day · darker = more time'), 'scale legend text missing');
});

test('strip card shows hour ticks, at least one date label, and a legend', () => {
  const days = [
    day('2026-05-04', { work: 180 }),
    day('2026-05-05', { work: 150 }),
  ];
  const ds = buildChartDatasets(days, [], SAMPLE_ENTRIES);
  const html = renderCharts(ds);

  assert.ok(html.includes('YOUR DAYS'), 'strip eyebrow missing');
  for (const tick of ['12a', '6a', '12p', '6p']) {
    assert.ok(html.includes(`>${tick}<`), `strip hour tick "${tick}" missing`);
  }
  assert.ok(html.includes('>05-04<') || html.includes('>05-05<'), 'date label missing');
  assert.ok(html.includes('>work<'), 'category legend missing');
});

test('category card shows the units caption', () => {
  const ds = buildChartDatasets([day('2026-05-01', { work: 120 })], []);
  const html = renderCharts(ds);
  assert.ok(html.includes('Total time tracked per category'), 'units caption missing');
});

test('output uses new captions and no longer emits the removed cards', () => {
  const ds = buildChartDatasets(
    [day('2026-05-04', { work: 180 }), day('2026-05-05', { work: 150 })],
    [],
    SAMPLE_ENTRIES,
  );
  const html = renderCharts(ds);
  assert.ok(html.includes("WHEN YOU'RE ACTIVE"));
  assert.ok(html.includes('YOUR DAYS'));
  assert.ok(html.includes('CATEGORY BREAKDOWN'));
  assert.ok(!html.includes('DAILY TIMELINE'), 'old DAILY TIMELINE card still present');
  assert.ok(!html.includes('AVERAGE BY DAY OF WEEK'), 'old weekday card still present');
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

test('output never contains NaN/Infinity/undefined even with entries', () => {
  const days = Array.from({ length: 14 }, (_, i) => {
    const d = new Date(Date.UTC(2026, 4, 1) + i * 86400000);
    return day(d.toISOString().slice(0, 10), { work: 120, sleep: 360 });
  });
  const entries: EntryInput[] = days.map((d) => ({
    category: 'work',
    startTime: `${d.date}T09:00:00Z`,
    endTime: `${d.date}T17:00:00Z`,
  }));
  const ds = buildChartDatasets(days, ['Work 40 hours per week'], entries);
  const html = renderCharts(ds);
  assert.ok(!html.includes('NaN'), 'output contains NaN');
  assert.ok(!html.includes('Infinity'), 'output contains Infinity');
  assert.ok(!html.includes('undefined'), 'output contains undefined');
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
