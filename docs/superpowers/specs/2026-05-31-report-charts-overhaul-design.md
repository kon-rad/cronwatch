# Report Charts Overhaul — Design

**Date:** 2026-05-31
**Status:** Approved (implementation authorized via subagents)

## Problem

The generated profile-report charts don't show anything helpful, and the current
charts lack the axis/legend labels needed to tell what they represent. All current
charts are "totals" views (category breakdown, daily timeline, weekday average,
goal progress) — none use the *clock time* of entries, so the report can't answer
"when do I spend my time?".

The renderer is deterministic, LLM-free SVG/HTML (`server/src/chartRender.ts`),
fed by pre-computed datasets (`server/src/chartData.ts`). Output is a single HTML
fragment displayed in a **JS-disabled** `WKWebView` on iOS, ~340px wide, all SVG
text at 12px. PDF export renders the same HTML.

## Decision

Render **four** chart cards, in this order:

1. **Time-of-day heatmap** (NEW) — when you're active
2. **Daily rhythm strip** (NEW) — clock-time placement of categories per day
3. **Category breakdown** (KEEP + label) — total time per category
4. **Goal progress** (KEEP, conditional) — actual vs. target

The existing **daily timeline** (stacked totals) and **average by day of week**
cards are **removed** — heatmap + strip supersede them.

Every chart must carry: a title (eyebrow), axis labels, a units note and/or
legend, and value labels where they fit.

## Data contract change (Approach A)

The two new charts need per-entry clock times, which the server does not currently
receive. iOS will send a new **`entries`** array alongside the existing aggregated
`days`. All binning/rendering stays server-side.

### Server request schema (`server/src/profileReport.ts`)

Add an **optional** field (back-compatible; absent ⇒ new charts render their empty
state):

```ts
entries: z.array(z.object({
  category: z.string().min(1).max(40),
  startTime: z.string(),   // ISO 8601 with offset, e.g. "2026-05-08T09:00:00-07:00"
  endTime: z.string(),     // ISO 8601 with offset
})).max(20000).optional(),
```

### iOS payload (`ProfileReportGenerator.swift`)

Add alongside `days`:

```swift
"entries": entries.map { e in
  [
    "category": e.category,
    "startTime": iso8601.string(from: e.startTime),
    "endTime": iso8601.string(from: e.endTime),
  ]
}
```

`entries` (the raw `[Entry]` for the range) are already available in
`ReportGenerationCoordinator` (from `EntriesService.fetchRange()`) — thread them
into `ProfileReportGenerator.generate()`. Use a fractional-second-free ISO8601
formatter **with timezone offset** so local wall-clock time is recoverable.

## Time parsing (deterministic, no tz library)

Parse the **wall-clock prefix** of each ISO string (the `YYYY-MM-DDTHH:MM`
portion before the offset). That is the user's local time and is what both charts
bucket on — no timezone math, fully deterministic. Reject malformed strings (skip
the entry). Split each entry at local midnight into per-local-day segments; an
entry where `end <= start` is skipped.

## Chart 1 — Time-of-day heatmap

- **Grid:** 7 rows (Mon→Sun, top→bottom) × 24 columns (hours 0–23).
- **Cell value:** *average minutes per occurrence* of that (weekday, hour).
  - Numerator: total minutes landing in that (weekday, hour) across the range,
    allocating each per-day segment's minutes into the hour buckets it overlaps.
  - Denominator: number of distinct dates in the range that fall on that weekday
    (reuse the per-weekday occurrence count already computed for weekday averages,
    derived from the `days` dates). Zero occurrences ⇒ cell value 0.
- **Color:** single-hue intensity ramp keyed on `value / maxAvg` (guard maxAvg=0).
  Light (e.g. `#EEF3F1`) → dark (e.g. category-work blue `#3D6F8E`). 0 ⇒ empty
  cell color `#F4F4F1`.
- **Labels (required):**
  - Left gutter: 3-letter weekday per row (Mon…Sun).
  - Bottom axis: hour ticks at 12a / 6a / 12p / 6p / 12a (cols 0, 6, 12, 18, and
    right edge).
  - Eyebrow title: `WHEN YOU'RE ACTIVE`.
  - Scale legend: small "less ▢▢▢▢ more" swatch row with note
    `avg per day · darker = more time`.
- **Empty state:** all-zero / no entries ⇒ standard "Not enough data to chart."

## Chart 2 — Daily rhythm strip

- **Layout:** one vertical bar per day across the **full range** (bars scale
  thinner as count grows — accepted trade-off). Midnight (0h) at top → midnight
  (24h) at bottom.
- **Blocks:** each per-day entry segment drawn as a category-colored rect at its
  clock position (`startMin/1440 … endMin/1440` of plot height).
- **Labels (required):**
  - Left gutter: hour ticks `12a, 6a, 12p, 6p, 12a` with faint gridlines.
  - Bottom axis: date labels (MM-DD), thinned to ~≤10 shown, rotated −45° when
    crowded (reuse the daily-timeline label-step + rotate logic).
  - Eyebrow title: `YOUR DAYS`.
  - Category legend below (reuse `categoryTotals` names/colors, `truncName`).
- **Empty state:** no entries ⇒ "Not enough data to chart."

## Chart 3 — Category breakdown (keep, add labels)

Keep existing horizontal bars (name + bar + `Xh (Y%)`). Add a one-line units
caption under the eyebrow: `Total time tracked per category`. Keep top-8 + other.

## Chart 4 — Goal progress (keep)

Unchanged; conditional on `goalProgress.length > 0`.

## Implementation surface

- `server/src/chartData.ts`
  - Add `EntryInput`, `HeatmapData` (`{ cells: number[][] /*7×24 avg min*/, maxAvg }`),
    `StripData` (`{ days: { date, label, segments: { category, color, startMin, endMin }[] }[] }`).
  - Add pure builders: `buildHeatmap(entries, days)`, `buildStrip(entries, palette)`,
    plus a shared `splitEntriesByLocalDay(entries)` helper that parses wall-clock
    time. Extend `buildChartDatasets(days, goals, entries = [])` and `ChartDatasets`.
- `server/src/chartRender.ts`
  - Add `heatmapCard(...)`, `dailyStripCard(...)`; add the units caption to
    `categoryBreakdownCard`; update `renderCharts` card order to
    `[category? no → heatmap, strip, category, goal?]` per Decision; **remove**
    `dailyTimelineCard` and `weekdayRhythmCard` from output (delete the now-unused
    functions). Hold the geometry contract: `viewBox="0 0 340 H"`, `width="100%"`,
    12px text, no NaN/Infinity, guarded divisions.
- `server/src/profileReport.ts` — extend `requestSchema` with optional `entries`;
  pass `parsed.data.entries ?? []` into `buildChartDatasets`.
- iOS — `ProfileReportGenerator.generate()` accepts + serializes `entries`;
  `ReportGenerationCoordinator` passes the fetched range entries through.

## Testing

- `server/src/chartData.test.ts`
  - `buildHeatmap` averages by weekday occurrences (e.g. 2 Mondays → divide by 2),
    allocates minutes to correct hour buckets, splits across midnight.
  - `buildStrip` produces per-day segments with correct `startMin/endMin`, clips
    midnight-spanning entries, colors from palette.
  - `splitEntriesByLocalDay` handles offsets, malformed strings (skipped),
    `end<=start` (skipped).
  - `buildChartDatasets` works with `entries` omitted (back-compat).
- `server/src/chartRender.test.ts`
  - Heatmap card contains all 7 weekday labels + hour-axis labels + scale legend;
    strip contains hour ticks + ≥1 date label + legend; category card contains the
    units caption. No `NaN`/`Infinity`/`undefined` substrings. Output has exactly
    the 4 (or 3 without goals) expected card captions and no longer emits
    `DAILY TIMELINE` / `AVERAGE BY DAY OF WEEK`.
- Run `npm test`, `npm run typecheck`, `npm run lint` in `server/`.
