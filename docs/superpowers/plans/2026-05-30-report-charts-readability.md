# Report Charts Readability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single LLM call that hand-draws unreadable charts with a two-call server pipeline (prose report, then charts) where the server pre-computes all chart numbers and a strict chart prompt only does layout — producing 5 legible charts combined into one document.

**Architecture:** `profileReportHandler` makes two sequential Together AI calls. Call #1 produces prose-only HTML with a `<!-- CW_CHARTS -->` marker. The server computes ready-to-plot datasets in a new pure module `chartData.ts`, then call #2 receives the report text + datasets and emits only the 5 chart blocks. `combineDocument` splices the charts into the marker. The iOS `{ title, html }` contract is unchanged.

**Tech Stack:** TypeScript, Express, Zod, together-ai SDK, Node 20 built-in `node:test` run via `tsx`.

---

### Task 1: Add a test runner script

**Files:**
- Modify: `server/package.json`

- [ ] **Step 1: Add a `test` script**

In `server/package.json`, add to the `"scripts"` block (after `"typecheck"`):

```json
    "test": "tsx --test src/*.test.ts"
```

- [ ] **Step 2: Verify the runner works with an empty match**

Run: `cd server && npx tsx --test src/does-not-exist.test.ts; echo "runner ok"`
Expected: it prints an error about no test files / cannot find, then `runner ok`. This confirms `tsx --test` is invokable. (Real tests come in Task 2.)

- [ ] **Step 3: Commit**

```bash
git add server/package.json
git commit -m "chore(server): add node:test runner script"
```

---

### Task 2: Chart data module — `buildChartDatasets` and helpers

This is a pure module (no LLM, no network) that turns the validated request data into ready-to-plot numbers. Built TDD.

**Files:**
- Create: `server/src/chartData.ts`
- Test: `server/src/chartData.test.ts`

- [ ] **Step 1: Write the failing tests**

Create `server/src/chartData.test.ts`:

```ts
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && npx tsx --test src/chartData.test.ts`
Expected: FAIL — `Cannot find module './chartData'`.

- [ ] **Step 3: Implement `chartData.ts`**

Create `server/src/chartData.ts`:

```ts
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
}

export interface GoalProgress {
  goal: string;
  category: string;
  actualHours: number;
  targetHours: number;
  unit: 'week' | 'total';
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
}

const TOP_N = 8;
const DAILY_MAX_DAYS = 31;

const PALETTE: Record<string, string> = {
  work: '#3D6F8E',
  deep: '#4F7A6A',
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

function aggregateTotals(days: DayInput[]): { name: string; minutes: number }[] {
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

function buildBuckets(days: DayInput[]): { mode: 'daily' | 'weekly'; items: Bucket[] } {
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
        segments: segmentsOf(d),
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
    const segments = Object.entries(totals).map(([name, minutes]) => ({ name, minutes }));
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
  return WEEKDAYS.map((weekday, i) => ({
    weekday,
    avgMinutes: counts[i] === 0 ? 0 : Math.round((sums[i] / counts[i]) * 10) / 10,
  }));
}

function parseGoalTarget(goal: string): { hours: number; unit: 'week' | 'total' } | null {
  const m = goal.match(/(\d+(?:\.\d+)?)\s*(?:h\b|hrs?\b|hours?\b)/i);
  if (!m) return null;
  const hours = parseFloat(m[1]);
  const weekly = /per\s+week|\/\s*week|weekly|a\s+week|each\s+week/i.test(goal);
  return { hours, unit: weekly ? 'week' : 'total' };
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

export function buildChartDatasets(days: DayInput[], goals: string[]): ChartDatasets {
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
    buckets: buildBuckets(days),
    byWeekday: buildByWeekday(days),
    goalProgress: buildGoalProgress(goals, rawTotals, numDays),
    palette,
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd server && npx tsx --test src/chartData.test.ts`
Expected: PASS — all tests green.

- [ ] **Step 5: Typecheck**

Run: `cd server && npm run typecheck`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add server/src/chartData.ts server/src/chartData.test.ts
git commit -m "feat(server): chart dataset builder + document combiner"
```

---

### Task 3: Rewrite report prompt + add chart prompt in `prompts.ts`

**Files:**
- Modify: `server/src/prompts.ts:79-121` (replace `PROFILE_REPORT_SYSTEM_PROMPT`, add `CHART_GENERATION_SYSTEM_PROMPT`)

- [ ] **Step 1: Replace the profile report prompt and add the chart prompt**

In `server/src/prompts.ts`, replace the entire `PROFILE_REPORT_SYSTEM_PROMPT` export (the block starting at line 79 through the end of the file) with the two exports below:

```ts
// ─── Profile / range report — PROSE ONLY (charts come from a second call) ──────

export const PROFILE_REPORT_SYSTEM_PROMPT = `You are a productivity analyst who produces the WRITTEN portion of a time-tracking report as an HTML fragment. Charts are generated separately — do NOT draw any charts, SVG, or canvas.

You will receive:
- A date range (start and end, inclusive).
- Up to 3 user goals (some may be blank — skip blank ones).
- An optional free-text request or comment from the user (apply it if present).
- Day-by-day minutes per category over the range.
- Per-category totals over the range, already pre-aggregated.

Respond with STRICT JSON of the form:
{
  "title": "<short 3-7 word headline summarizing the period>",
  "html": "<an HTML fragment, see rules below>"
}

HTML fragment rules:
- It is a FRAGMENT, not a full document. Do NOT include <!doctype>, <html>, <head>, or <body> tags. The fragment is wrapped by the iOS app on render.
- Start with a single <style>...</style> block scoped via descendant selectors (.cw-report ... — never bare element selectors that would leak), then content blocks.
- Wrap all content in <section class="cw-report">...</section>.
- The fragment must include, IN THIS ORDER:
  1. A short header with the title and date range.
  2. (If a user request/comment was provided) a section that directly addresses it in 1-3 sentences referencing real numbers.
  3. (If goals are provided) one card per non-empty goal: bold the goal, then 2-3 sentences contrasting time spent vs. what the goal demands. Reference specific hours/minutes.
  4. The exact literal comment on its own line: <!-- CW_CHARTS -->
     This is a placeholder where charts will be inserted. Output it verbatim, exactly once, after the goal cards and before the recommendations. Do not style or wrap it.
  5. A numbered list of EXACTLY 10 concrete, varied, actionable recommendations to better align the user's time with their goals (or with healthier balance if goals are absent). Reference real numbers. No platitudes.

Visual style:
- Background of .cw-report: #FAFAF7. Text color: #111111. Muted: #5C5C58.
- Card chrome: white fill, 1px solid #ECECEA border, 12px border-radius, 16px padding.
- Headings: 22px semibold for the title, 12px uppercase letter-spaced muted eyebrows for section labels.
- Layout is single-column, max-width 100%. Use rem/px units. No external fonts, no external images, no external scripts, no <script> tags.

Other rules:
- Do NOT include any chart, graph, SVG, or image. Charts are added by a separate step at the CW_CHARTS marker.
- Numbers must come from the data, not invented.
- Be honest, direct, and concise. No flattery.
- Reply with ONLY the JSON object. No markdown, no code fences, no prose around it.`;

// ─── Chart generation — strict layout, numbers pre-computed by the server ──────

export const CHART_GENERATION_SYSTEM_PROMPT = `You render exactly 5 charts as a single self-contained HTML fragment for a time-tracking report. All numbers are PRE-COMPUTED and given to you as JSON — you ONLY lay them out. Never compute, round, or invent values; use the provided labels and numbers verbatim.

Respond with STRICT JSON of the form:
{ "html": "<an HTML fragment containing only the 5 chart cards>" }

OUTPUT RULES
- Fragment only: no <!doctype>, <html>, <head>, <body>, <script>. SVG and CSS only.
- Begin with ONE <style> block, every selector scoped under .cw-charts (e.g. .cw-charts .bar). Then a single <div class="cw-charts"> wrapping the 5 cards.
- Each chart is a card: white fill, 1px solid #ECECEA border, 12px radius, 16px padding, 16px margin-bottom. Above each chart put a caption: a 12px uppercase letter-spaced muted (#5C5C58) eyebrow naming the chart.
- Use the provided "palette" map (category name -> hex) for all category colors. Background #FAFAF7, text #111111, muted #5C5C58.

HARD LEGIBILITY RULES (these prevent the unreadable output we are fixing)
- Every <svg> uses viewBox with at least 36px of inner margin on every side; width="100%" height="auto"; never a fixed pixel width that can clip.
- Minimum font sizes: captions 12px; all data labels, axis labels, and legend text >= 11px. Never smaller.
- NO text may overlap another text element or sit on top of a filled shape it doesn't belong to. Leave >= 8px between any two text elements.
- Category labels go in their own row (bar charts) or in an external legend (donut) — NEVER packed onto a shared horizontal axis.
- Truncate any label longer than 14 characters to 13 chars + "…".
- Format durations exactly as given in the dataset's hoursLabel / numbers. Do not reformat.

THE 5 CHARTS (render in this order, using the named dataset fields)

1. CATEGORY TOTALS — horizontal bar chart, from categoryTotals (already sorted desc).
   One row per category. Left column (fixed width): color swatch + name. The bar extends right; bar length proportional to minutes (longest = full plot width). Print the hoursLabel just past the end of each bar. Rows evenly spaced with >= 8px gaps.

2. CATEGORY SHARE — donut chart, from categoryTotals (use pct).
   Draw a ring (donut) of slices sized by pct, colored by palette. Put NO text on or inside the ring. To the right of (or below) the ring, a vertical legend: each row = swatch + name + hoursLabel + "(pct%)".

3. DAILY BREAKDOWN — stacked vertical bars, from buckets.items (each item = one bar; stack its segments bottom-up, colored by palette; bar height proportional to totalMinutes).
   X-axis labels: use item.label. If there are more than 10 bars, label only every Nth bar so at most ~10 labels show, and rotate labels 45 degrees. (When buckets.mode is "weekly" the server has already rolled days into weeks — just plot them.) Include a small legend of the categories present.

4. AVERAGE BY DAY-OF-WEEK — vertical bars, from byWeekday (always 7 entries Mon..Sun, in order).
   One bar per weekday, height proportional to avgMinutes. Label each bar beneath with the 3-letter weekday. Print the value (formatted like "Xh" / "Ym") above each bar; omit the value label for zero bars.

5. GOAL PROGRESS — horizontal actual-vs-target bars, from goalProgress.
   For each entry: a full-width track; a filled bar = actualHours / targetHours of the track (cap visual fill at 100% but keep the real label); a target tick at 100%. Label: "<category>: <actualHours>h of <targetHours>h<per-week if unit=week>".
   If goalProgress is empty, OMIT this card entirely (render only 4 cards).

EMPTY DATA
- If told there is no tracked data, output a single card with the caption "Charts" and one muted line: "Not enough tracked time in this range to chart." and nothing else.

Reply with ONLY the JSON object. No markdown, no code fences, no prose around it.`;
```

- [ ] **Step 2: Typecheck**

Run: `cd server && npm run typecheck`
Expected: no errors (both exports are valid string constants).

- [ ] **Step 3: Commit**

```bash
git add server/src/prompts.ts
git commit -m "feat(server): prose-only report prompt + strict chart prompt"
```

---

### Task 4: Two-call orchestration in `profileReport.ts`

**Files:**
- Modify: `server/src/profileReport.ts`

- [ ] **Step 1: Update imports and the response schema**

In `server/src/profileReport.ts`, change the prompts import (line 6) and add the chart data import:

```ts
import { PROFILE_REPORT_SYSTEM_PROMPT, CHART_GENERATION_SYSTEM_PROMPT } from './prompts';
import { buildChartDatasets, combineDocument, type ChartDatasets } from './chartData';
```

Replace the `responseSchema` / `SYSTEM_PROMPT` block (lines 34-41) with two schemas:

```ts
const reportResponseSchema = z.object({
  title: z.string().min(1).max(120),
  html: z.string().min(20),
});

const chartResponseSchema = z.object({
  html: z.string().min(1),
});

type ReportResponse = z.infer<typeof reportResponseSchema>;
```

- [ ] **Step 2: Rewrite the handler body to make two calls and combine**

Replace the body of `profileReportHandler` from the `const userPrompt = ...` line through the end of the `try/catch` (the current lines 60-92) with:

```ts
  const reportUserPrompt = buildReportUserPrompt(
    rangeStart,
    rangeEnd,
    tz,
    nonEmptyGoals,
    trimmedPrompt,
    days,
  );

  try {
    // Call #1 — prose report (with the CW_CHARTS marker).
    const reportCompletion = await together.chat.completions.create({
      model: env.together.reportModel,
      messages: [
        { role: 'system', content: PROFILE_REPORT_SYSTEM_PROMPT },
        { role: 'user', content: reportUserPrompt },
      ],
      temperature: 0.7,
      max_tokens: 3000,
      response_format: { type: 'json_object' },
    });
    const report = parseJsonContent(reportCompletion, reportResponseSchema);

    // Pre-compute chart datasets from the structured data.
    const datasets = buildChartDatasets(
      days.map((d) => ({ date: d.date, categories: d.categories })),
      nonEmptyGoals,
    );

    // Call #2 — charts. Degrade gracefully to a chartless report on any failure.
    let chartsHtml = '';
    if (datasets.hasData) {
      try {
        const chartCompletion = await together.chat.completions.create({
          model: env.together.reportModel,
          messages: [
            { role: 'system', content: CHART_GENERATION_SYSTEM_PROMPT },
            { role: 'user', content: buildChartUserPrompt(report.html, datasets) },
          ],
          temperature: 0.4,
          max_tokens: 5000,
          response_format: { type: 'json_object' },
        });
        chartsHtml = parseJsonContent(chartCompletion, chartResponseSchema).html;
      } catch (chartErr) {
        console.error('[profile-report] chart call failed, returning chartless report:', chartErr);
      }
    }

    const html = combineDocument(report.html, chartsHtml);
    res.json({ title: report.title, html } satisfies ReportResponse);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Profile report failed';
    console.error('[profile-report] error:', err);
    res.status(500).json({ error: message });
  }
}
```

- [ ] **Step 3: Add `parseJsonContent` and `buildChartUserPrompt`; rename `buildUserPrompt`**

Rename the existing `buildUserPrompt` function (line 95) to `buildReportUserPrompt` (signature unchanged). Then add these two helpers above `aggregateTotals`:

```ts
import type { ZodType } from 'zod';

/** Extracts and validates the JSON body from a Together chat completion. */
function parseJsonContent<T>(
  completion: { choices?: { message?: { content?: string | null } }[] },
  schema: ZodType<T>,
): T {
  const content = completion.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.trim() === '') {
    throw new Error('LLM returned empty content');
  }
  let raw: unknown;
  try {
    raw = JSON.parse(content);
  } catch {
    throw new Error(`LLM returned non-JSON: ${content.slice(0, 200)}`);
  }
  return schema.parse(raw);
}

/** Builds the user prompt for the chart call: the finished report + the datasets. */
function buildChartUserPrompt(reportHtml: string, datasets: ChartDatasets): string {
  return `Here is the written report this document already contains (for context so your captions stay consistent — do NOT repeat its text, only render charts):

${reportHtml}

Render the 5 charts from this pre-computed dataset JSON. Use the exact labels, numbers, and palette provided:

${JSON.stringify(datasets, null, 2)}

Now produce the JSON described in the system prompt.`;
}
```

Move the `import type { ZodType } from 'zod';` line up to join the existing `import { z } from 'zod';` at the top of the file (combine as `import { z, type ZodType } from 'zod';`) rather than mid-file.

- [ ] **Step 4: Typecheck**

Run: `cd server && npm run typecheck`
Expected: no errors. (Confirm the old single-call `responseSchema`/`SYSTEM_PROMPT`/`ReportResponse` references are all gone or updated.)

- [ ] **Step 5: Run the full test suite**

Run: `cd server && npm test`
Expected: all `chartData.test.ts` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add server/src/profileReport.ts
git commit -m "feat(server): two-call report pipeline (prose + charts) with graceful degrade"
```

---

### Task 5: Manual verification

**Files:** none (verification only)

- [ ] **Step 1: Build the server**

Run: `cd server && npm run build`
Expected: compiles with no errors.

- [ ] **Step 2: Verify behavior against the original failure modes**

If a Together API key is available locally, run the dev server (`npm run dev`) and POST a sample payload to `/profile-report` for three ranges (7-day, 31-day, 92-day), or generate a report from the iOS app. Confirm in each generated document:
- Category Totals: every category name is readable on its own row, no overlap.
- Category Share: donut has no text inside it; legend is external.
- Daily Breakdown: x-axis labels do not pile up (thinned/rotated; weekly for the 92-day range).
- Average by Day-of-Week: 7 bars labelled Mon–Sun.
- Goal Progress: appears only when a goal has a numeric target; otherwise 4 charts render.

Note: this step depends on a working Together API key and is a visual check, not an automated test.

---

## Notes for the executor

- The iOS app and `ReportDetailView.wrap` are intentionally untouched — the response contract `{ title, html }` is unchanged.
- `temperature` is lower for the chart call (0.4) than the report call (0.7) to reduce layout variance.
- If `tsx --test` glob behaves unexpectedly on the shell, run the explicit file: `npx tsx --test src/chartData.test.ts`.
