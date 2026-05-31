/**
 * Deterministic, LLM-free SVG/CSS chart renderer for profile reports.
 *
 * Consumes the pre-computed `ChartDatasets` from chartData.ts and emits a single
 * HTML fragment: one <style> block (every selector scoped under .cw-charts)
 * followed by <div class="cw-charts"> containing one card per chart. Pure
 * input->output: identical every run, unit-testable, and incapable of
 * hallucinating geometry.
 *
 * Geometry contract (do not change without updating the spec):
 * - Every <svg> uses viewBox="0 0 340 H" with width="100%", no fixed pixel
 *   width and no height attribute. 1 user unit ~= 1 screen pixel.
 * - ALL SVG text is font-size:12.
 * - Every division by a max is guarded against zero so coordinates never become
 *   NaN/Infinity. A chart whose data is empty/all-zero renders a muted
 *   "Not enough data to chart." line instead of an empty/NaN SVG.
 */

import type { ChartDatasets, CategoryTotal, Bucket, WeekdayAvg, GoalProgress } from './chartData';

const VIEW_W = 340;
const EMPTY_LINE = 'Not enough data to chart.';

/** Escape user-derived text for safe embedding in HTML/SVG. */
function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Truncate a category name to <= 13 chars + ellipsis. */
function truncName(name: string): string {
  return name.length > 13 ? `${name.slice(0, 13)}…` : name;
}

/** Round to at most 2 decimals; keeps coordinate strings compact. */
function n(x: number): string {
  return String(Math.round(x * 100) / 100);
}

function card(caption: string, body: string): string {
  return `<div class="cw-card"><div class="cw-eyebrow">${esc(caption)}</div>${body}</div>`;
}

function emptyCard(caption: string): string {
  return card(caption, `<p class="cw-empty">${EMPTY_LINE}</p>`);
}

// ─── 1. CATEGORY BREAKDOWN ─────────────────────────────────────────────────────

function categoryBreakdownCard(totals: CategoryTotal[]): string {
  if (totals.length === 0) return emptyCard('CATEGORY BREAKDOWN');
  const maxMinutes = Math.max(...totals.map((t) => t.minutes));
  if (maxMinutes <= 0) return emptyCard('CATEGORY BREAKDOWN');

  const rowH = 26;
  const top = 8;
  const labelW = 110; // fixed left column: swatch + name
  const swatch = 10;
  const barX = labelW;
  const barMaxW = 130; // leave room on the right for the value label
  const height = top + totals.length * rowH + 8;

  const rows = totals
    .map((t, i) => {
      const y = top + i * rowH;
      const barLen = maxMinutes === 0 ? 0 : (t.minutes / maxMinutes) * barMaxW;
      const cy = y + rowH / 2;
      const label = `${esc(t.hoursLabel)} (${t.pct}%)`;
      return [
        `<rect x="6" y="${n(cy - swatch / 2)}" width="${swatch}" height="${swatch}" rx="2" fill="${esc(t.color)}"/>`,
        `<text x="${6 + swatch + 6}" y="${n(cy + 4)}" font-size="12" fill="#111111">${esc(truncName(t.name))}</text>`,
        `<rect x="${barX}" y="${n(cy - 7)}" width="${n(barLen)}" height="14" rx="3" fill="${esc(t.color)}"/>`,
        `<text x="${n(barX + barLen + 6)}" y="${n(cy + 4)}" font-size="12" fill="#5C5C58">${label}</text>`,
      ].join('');
    })
    .join('');

  return card(
    'CATEGORY BREAKDOWN',
    `<svg viewBox="0 0 ${VIEW_W} ${height}" width="100%" role="img" aria-label="Category breakdown">${rows}</svg>`,
  );
}

// ─── 2. DAILY TIMELINE ─────────────────────────────────────────────────────────

function dailyTimelineCard(
  buckets: { mode: 'daily' | 'weekly'; items: Bucket[] },
  totals: CategoryTotal[],
  palette: Record<string, string>,
): string {
  const items = buckets.items;
  const maxTotal = items.length === 0 ? 0 : Math.max(...items.map((b) => b.totalMinutes));
  if (items.length === 0 || maxTotal <= 0) return emptyCard('DAILY TIMELINE');

  const top = 12;
  const plotH = 150;
  const axisY = top + plotH;
  const labelBandH = 44; // room for rotated labels
  const legendRowH = 18;

  // Legend uses category names/colors present in categoryTotals.
  const legendCats = totals.filter((t) => t.minutes > 0);
  const legendH = legendCats.length === 0 ? 0 : 8 + legendRowH * legendCats.length;
  const height = axisY + labelBandH + legendH + 8;

  const innerX = 8;
  const innerW = VIEW_W - innerX * 2;
  const slot = innerW / items.length;
  const barW = Math.max(4, Math.min(28, slot * 0.7));

  // Label every Nth bar so at most ~10 labels show.
  const step = items.length > 10 ? Math.ceil(items.length / 10) : 1;
  const rotate = items.length > 10;

  const bars = items
    .map((b, i) => {
      const cx = innerX + slot * i + slot / 2;
      const x = cx - barW / 2;
      let yCursor = axisY;
      const segs = b.segments
        .map((seg) => {
          const segH = maxTotal === 0 ? 0 : (seg.minutes / maxTotal) * plotH;
          yCursor -= segH;
          const fill = palette[seg.name] ?? '#A8A89D';
          return `<rect x="${n(x)}" y="${n(yCursor)}" width="${n(barW)}" height="${n(segH)}" fill="${esc(fill)}"/>`;
        })
        .join('');

      let label = '';
      if (i % step === 0) {
        const lx = cx;
        const ly = axisY + 14;
        const text = esc(b.label);
        label = rotate
          ? `<text x="${n(lx)}" y="${n(ly)}" font-size="12" fill="#5C5C58" text-anchor="end" transform="rotate(-45 ${n(lx)} ${n(ly)})">${text}</text>`
          : `<text x="${n(lx)}" y="${n(ly)}" font-size="12" fill="#5C5C58" text-anchor="middle">${text}</text>`;
      }
      return segs + label;
    })
    .join('');

  const baseline = `<line x1="${innerX}" y1="${axisY}" x2="${innerX + innerW}" y2="${axisY}" stroke="#ECECEA"/>`;

  const legend = legendCats
    .map((t, i) => {
      const ly = axisY + labelBandH + 4 + i * legendRowH;
      return [
        `<rect x="8" y="${n(ly)}" width="10" height="10" rx="2" fill="${esc(t.color)}"/>`,
        `<text x="24" y="${n(ly + 9)}" font-size="12" fill="#5C5C58">${esc(truncName(t.name))}</text>`,
      ].join('');
    })
    .join('');

  return card(
    'DAILY TIMELINE',
    `<svg viewBox="0 0 ${VIEW_W} ${n(height)}" width="100%" role="img" aria-label="Daily timeline">${baseline}${bars}${legend}</svg>`,
  );
}

// ─── 3. AVERAGE BY DAY OF WEEK ─────────────────────────────────────────────────

function weekdayRhythmCard(byWeekday: WeekdayAvg[]): string {
  const maxAvg = byWeekday.length === 0 ? 0 : Math.max(...byWeekday.map((w) => w.avgMinutes));
  if (byWeekday.length === 0 || maxAvg <= 0) return emptyCard('AVERAGE BY DAY OF WEEK');

  const top = 24; // room for value labels above bars
  const plotH = 140;
  const axisY = top + plotH;
  const labelBandH = 20;
  const height = axisY + labelBandH + 8;

  const innerX = 8;
  const innerW = VIEW_W - innerX * 2;
  const slot = innerW / byWeekday.length;
  const barW = Math.min(28, slot * 0.6);

  const bars = byWeekday
    .map((w, i) => {
      const cx = innerX + slot * i + slot / 2;
      const x = cx - barW / 2;
      const barH = maxAvg === 0 ? 0 : (w.avgMinutes / maxAvg) * plotH;
      const y = axisY - barH;
      const parts = [
        `<rect x="${n(x)}" y="${n(y)}" width="${n(barW)}" height="${n(barH)}" rx="3" fill="#3D6F8E"/>`,
        `<text x="${n(cx)}" y="${n(axisY + 14)}" font-size="12" fill="#5C5C58" text-anchor="middle">${esc(w.weekday)}</text>`,
      ];
      if (w.avgMinutes > 0) {
        parts.push(
          `<text x="${n(cx)}" y="${n(y - 5)}" font-size="12" fill="#111111" text-anchor="middle">${esc(w.hoursLabel)}</text>`,
        );
      }
      return parts.join('');
    })
    .join('');

  const baseline = `<line x1="${innerX}" y1="${axisY}" x2="${innerX + innerW}" y2="${axisY}" stroke="#ECECEA"/>`;

  return card(
    'AVERAGE BY DAY OF WEEK',
    `<svg viewBox="0 0 ${VIEW_W} ${height}" width="100%" role="img" aria-label="Average by day of week">${baseline}${bars}</svg>`,
  );
}

// ─── 4. GOAL PROGRESS (conditional) ────────────────────────────────────────────

function goalProgressCard(goals: GoalProgress[]): string {
  if (goals.length === 0) return emptyCard('GOAL PROGRESS');

  const top = 8;
  const rowH = 46;
  const trackX = 8;
  const trackW = VIEW_W - trackX * 2;
  const trackH = 14;
  const height = top + goals.length * rowH + 8;

  const rows = goals
    .map((g, i) => {
      const y = top + i * rowH;
      const ratio = g.targetHours > 0 ? g.actualHours / g.targetHours : 0;
      const fillRatio = Math.max(0, Math.min(1, ratio));
      const fillW = fillRatio * trackW;
      const tickX = trackX + trackW; // target tick at 100%
      const suffix = g.unit === 'week' ? '/wk' : '';
      const label = `${esc(g.category)}: ${g.actualHours}h of ${g.targetHours}h${suffix}`;
      return [
        `<text x="${trackX}" y="${n(y + 12)}" font-size="12" fill="#111111">${label}</text>`,
        `<rect x="${trackX}" y="${n(y + 20)}" width="${trackW}" height="${trackH}" rx="3" fill="#ECECEA"/>`,
        `<rect x="${trackX}" y="${n(y + 20)}" width="${n(fillW)}" height="${trackH}" rx="3" fill="#4F7A6A"/>`,
        `<line x1="${n(tickX)}" y1="${n(y + 16)}" x2="${n(tickX)}" y2="${n(y + 20 + trackH + 4)}" stroke="#5C5C58" stroke-width="2"/>`,
      ].join('');
    })
    .join('');

  return card(
    'GOAL PROGRESS',
    `<svg viewBox="0 0 ${VIEW_W} ${height}" width="100%" role="img" aria-label="Goal progress">${rows}</svg>`,
  );
}

// ─── Composition ───────────────────────────────────────────────────────────────

const STYLE = `<style>
.cw-charts { background:#FAFAF7; color:#111111; max-width:100%; }
.cw-charts .cw-card { background:#ffffff; border:1px solid #ECECEA; border-radius:12px; padding:16px; margin-bottom:16px; }
.cw-charts .cw-eyebrow { font-size:12px; text-transform:uppercase; letter-spacing:.08em; color:#5C5C58; margin-bottom:10px; }
.cw-charts .cw-empty { font-size:12px; color:#5C5C58; margin:0; }
.cw-charts svg { display:block; width:100%; }
.cw-charts svg text { font-size:12px; }
</style>`;

export function renderCharts(datasets: ChartDatasets): string {
  const cards: string[] = [
    categoryBreakdownCard(datasets.categoryTotals),
    dailyTimelineCard(datasets.buckets, datasets.categoryTotals, datasets.palette),
    weekdayRhythmCard(datasets.byWeekday),
  ];
  if (datasets.goalProgress.length > 0) {
    cards.push(goalProgressCard(datasets.goalProgress));
  }
  return `${STYLE}<div class="cw-charts">${cards.join('')}</div>`;
}
