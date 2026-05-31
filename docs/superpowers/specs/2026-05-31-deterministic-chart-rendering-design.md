# Deterministic chart rendering for profile reports

**Date:** 2026-05-31
**Supersedes:** `2026-05-30-report-charts-readability-design.md` (the LLM-drawn-SVG approach, which this replaces)

## Problem

Profile reports are generated with two LLM calls. Call #1 writes the prose and emits a
`<!-- CW_CHARTS -->` marker. Call #2 (`CHART_GENERATION_SYSTEM_PROMPT`) receives fully
pre-computed numbers and is asked to **hand-write SVG charts**. This call fails the way
LLMs reliably fail at SVG geometry:

- The "donut" rendered as a single solid filled circle — the model could not compute
  pie-slice arc paths.
- The category bar chart rendered with no labels and no values — unreadable.
- A "HEAT MAP" card appeared even though heat maps are explicitly forbidden in the prompt
  — proof the model ignores the instructions.

The numbers are already computed deterministically in `chartData.ts`, so call #2 adds **no
value** and introduces **all** the rendering defects. The report WebView also runs with
JavaScript disabled, so charts must be static SVG/CSS — which we can generate perfectly in
code.

## Decision

Render charts deterministically in TypeScript from the existing datasets and **delete the
chart LLM call**. Charts become pixel-identical every run, cannot hallucinate, are
unit-testable, and the report costs one fewer LLM call.

## Charts (fixed set of 3, plus a conditional 4th)

All charts render at `viewBox="0 0 340 H"` with `width="100%"` and no fixed pixel width, so
1 user unit ≈ 1 screen pixel. All SVG text is `font-size: 12`. Colors come from
`datasets.palette`. No arc math is needed (the donut is gone).

1. **CATEGORY BREAKDOWN** — horizontal bars from `categoryTotals` (already sorted desc,
   top-8 + "other"). Each row: color swatch + truncated category name in a fixed left
   column, a bar scaled so the largest category fills the plot width, and the
   `hoursLabel (pct%)` printed just past the bar end. Replaces both the broken donut and the
   unlabeled bars.

2. **DAILY TIMELINE** — stacked vertical bars from `buckets.items`. Each bar is one day (or
   one week when `buckets.mode === "weekly"`); segments stack bottom-up colored by palette;
   bar height ∝ `totalMinutes`. X-axis labels use `item.label` verbatim; when there are more
   than 10 bars, label only every Nth bar (≤ ~10 labels) and rotate those 45°. A small
   category legend sits beneath.

3. **AVERAGE BY DAY OF WEEK** — vertical bars from `byWeekday` (always 7 entries, Mon–Sun in
   order). Bar height ∝ `avgMinutes`; 3-letter weekday label beneath each bar; the value
   (`hoursLabel`) printed above each non-zero bar.

4. **GOAL PROGRESS** *(conditional — only when `goalProgress` is non-empty)* — one
   horizontal actual-vs-target bar per goal: a full-width track, a filled bar =
   `actualHours / targetHours` of the track (visual fill capped at 100%, real label kept), a
   target tick at 100%, and the label `<category>: <actualHours>h of <targetHours>h` with
   `/wk` appended when `unit === "week"`.

## Architecture

### New module `server/src/chartRender.ts`

A single pure, LLM-free function:

```ts
export function renderCharts(datasets: ChartDatasets): string
```

Returns the same fragment shape call #2 produced: one `<style>` block with every selector
scoped under `.cw-charts`, followed by `<div class="cw-charts">` containing one card per
chart. Card chrome: white fill, `1px solid #ECECEA` border, `12px` radius, `16px` padding,
`16px` margin-bottom. Each card opens with a caption eyebrow (12px, uppercase, letter-spaced,
`#5C5C58`). Pure input→output makes it fully unit-testable and identical every run.

Internal helpers (private to the module), one per chart, each returning a card string:
`categoryBreakdownCard`, `dailyTimelineCard`, `weekdayRhythmCard`, `goalProgressCard`.
`renderCharts` composes them, appending the goal card only when `goalProgress` is non-empty.

### `server/src/profileReport.ts`

- Remove the second `together.chat.completions.create` call, `chartResponseSchema`, and
  `buildChartUserPrompt`.
- Replace with: `const chartsHtml = datasets.hasData ? renderCharts(datasets) : '';`
- `combineDocument(report.html, chartsHtml)` is unchanged (it still splices at the marker
  and degrades cleanly when `chartsHtml === ''`).
- Drop the now-unused `CHART_GENERATION_SYSTEM_PROMPT` import.

### `server/src/prompts.ts`

- Delete `CHART_GENERATION_SYSTEM_PROMPT`.
- `PROFILE_REPORT_SYSTEM_PROMPT` is unchanged — it already instructs the model not to draw
  charts and to emit the `<!-- CW_CHARTS -->` marker. That contract is preserved.

### `server/src/chartData.ts`

- Add a `hoursLabel: string` field to `WeekdayAvg` (computed via `formatHm(avgMinutes)`,
  rounded to whole minutes) so the renderer never reformats numbers — values are formatted
  once at the data layer. All other datasets are unchanged.

### iOS

No changes. `ReportDetailView` already wraps the fragment and renders it in the
JavaScript-disabled WKWebView; PDF export is unaffected.

## Error handling

- `datasets.hasData === false` → `renderCharts` is not called; the prose-only report renders
  (existing graceful path).
- A chart whose data is entirely empty or all-zero (e.g. no buckets, all weekday averages
  zero) renders its card with a single muted line ("Not enough data to chart.") instead of a
  zero-height or `NaN`-coordinate SVG.
- Bar scaling guards against divide-by-zero (max of 0 → all bars render at zero length, no
  `NaN`).

## Testing

Unit tests in `server/src/chartRender.test.ts` using `node:test` + `node:assert/strict`
(mirroring `chartData.test.ts`), driving the renderer from `buildChartDatasets(...)` output:

- 3 cards when no goals; 4 cards when an hour-based goal is present.
- Every category name, `hoursLabel`, and `pct` from `categoryTotals` appears in the output.
- Each weekday's `hoursLabel` appears; zero-average weekdays print no value label.
- Goal label string `"<category>: <actual>h of <target>h/wk"` appears for a weekly goal.
- No `NaN` or `Infinity` substring anywhere in the output (coordinate-math guard).
- Output contains the `.cw-charts` wrapper and a scoped `<style>` block; no `<script>`.
- Weekly-mode buckets (range > 31 days) produce one bar per week.

## Out of scope

- No changes to the prose prompt, the data aggregation logic, or the iOS app.
- No new chart types beyond the four above; no interactivity (WebView has JS disabled).
