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

import type {
  ChartDatasets,
  CategoryTotal,
  GoalProgress,
  HeatmapData,
  StripData,
} from './chartData';

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

/**
 * Card captions are developer-controlled constants (e.g. "WHEN YOU'RE ACTIVE"),
 * never user input, so they are emitted verbatim. An apostrophe is valid raw in
 * element text content and we want it to survive round-trips for tests/PDF.
 */
function card(caption: string, body: string): string {
  return `<div class="cw-card"><div class="cw-eyebrow">${caption}</div>${body}</div>`;
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
    `<p class="cw-caption">Total time tracked per category</p><svg viewBox="0 0 ${VIEW_W} ${height}" width="100%" role="img" aria-label="Category breakdown">${rows}</svg>`,
  );
}

// ─── 1. TIME-OF-DAY HEATMAP ────────────────────────────────────────────────────

const WEEKDAY_LABELS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const HOUR_TICKS: { col: number; label: string }[] = [
  { col: 0, label: '12a' },
  { col: 6, label: '6a' },
  { col: 12, label: '12p' },
  { col: 18, label: '6p' },
];

/** Linear interpolate between two #rrggbb hex colors; t in [0,1]. */
function lerpHex(from: string, to: string, t: number): string {
  const clamp = Math.max(0, Math.min(1, t));
  const fr = parseInt(from.slice(1, 3), 16);
  const fg = parseInt(from.slice(3, 5), 16);
  const fb = parseInt(from.slice(5, 7), 16);
  const tr = parseInt(to.slice(1, 3), 16);
  const tg = parseInt(to.slice(3, 5), 16);
  const tb = parseInt(to.slice(5, 7), 16);
  const r = Math.round(fr + (tr - fr) * clamp);
  const g = Math.round(fg + (tg - fg) * clamp);
  const b = Math.round(fb + (tb - fb) * clamp);
  const hx = (v: number): string => v.toString(16).padStart(2, '0');
  return `#${hx(r)}${hx(g)}${hx(b)}`;
}

const HEAT_EMPTY = '#F4F4F1';
const HEAT_LIGHT = '#EEF3F1';
const HEAT_DARK = '#3D6F8E';

function heatColor(value: number, maxAvg: number): string {
  if (value <= 0 || maxAvg <= 0) return HEAT_EMPTY;
  return lerpHex(HEAT_LIGHT, HEAT_DARK, value / maxAvg);
}

function heatmapCard(heatmap: HeatmapData): string {
  const { cells, maxAvg } = heatmap;
  if (cells.length === 0 || maxAvg <= 0) return emptyCard("WHEN YOU'RE ACTIVE");

  const gutter = 28; // left gutter for weekday row labels
  const top = 6;
  const cols = 24;
  const rows = 7;
  const plotW = VIEW_W - gutter - 6;
  const cellW = plotW / cols;
  const cellH = 16;
  const gridTop = top;
  const axisBandH = 16; // hour labels under the grid
  const legendBandH = 22;
  const height = gridTop + rows * cellH + axisBandH + legendBandH + 6;

  const rowLabels = WEEKDAY_LABELS.map((label, r) => {
    const cy = gridTop + r * cellH + cellH / 2 + 4;
    return `<text x="4" y="${n(cy)}" font-size="12" fill="#5C5C58">${esc(label)}</text>`;
  }).join('');

  const rects = cells
    .map((row, r) =>
      row
        .map((value, c) => {
          const x = gutter + c * cellW;
          const y = gridTop + r * cellH;
          const fill = heatColor(value, maxAvg);
          return `<rect x="${n(x)}" y="${n(y)}" width="${n(cellW)}" height="${cellH}" fill="${fill}"/>`;
        })
        .join(''),
    )
    .join('');

  const axisY = gridTop + rows * cellH + 12;
  const hourLabels =
    HOUR_TICKS.map((t) => {
      const x = gutter + t.col * cellW;
      return `<text x="${n(x)}" y="${n(axisY)}" font-size="12" fill="#5C5C58">${esc(t.label)}</text>`;
    }).join('') +
    `<text x="${n(gutter + plotW)}" y="${n(axisY)}" font-size="12" fill="#5C5C58" text-anchor="end">12a</text>`;

  // Scale legend: a few swatches light -> dark with a note.
  const legendY = axisY + 12;
  const swatchN = 5;
  const swatchW = 14;
  const swatches = Array.from({ length: swatchN }, (_, i) => {
    const t = i / Math.max(1, swatchN - 1);
    const fill = lerpHex(HEAT_LIGHT, HEAT_DARK, t);
    const x = gutter + i * (swatchW + 2);
    return `<rect x="${n(x)}" y="${n(legendY - 9)}" width="${swatchW}" height="10" fill="${fill}"/>`;
  }).join('');
  const legendTextX = gutter + swatchN * (swatchW + 2) + 6;
  const legendText = `<text x="${n(legendTextX)}" y="${n(legendY)}" font-size="12" fill="#5C5C58">avg per day · darker = more time</text>`;

  return card(
    "WHEN YOU'RE ACTIVE",
    `<svg viewBox="0 0 ${VIEW_W} ${n(height)}" width="100%" role="img" aria-label="When you're active">${rects}${rowLabels}${hourLabels}${swatches}${legendText}</svg>`,
  );
}

// ─── 2. DAILY RHYTHM STRIP ─────────────────────────────────────────────────────

const STRIP_HOUR_TICKS: { min: number; label: string }[] = [
  { min: 0, label: '12a' },
  { min: 360, label: '6a' },
  { min: 720, label: '12p' },
  { min: 1080, label: '6p' },
  { min: 1440, label: '12a' },
];

function dailyStripCard(strip: StripData, totals: CategoryTotal[]): string {
  const days = strip.days;
  if (days.length === 0) return emptyCard('YOUR DAYS');

  const gutter = 28; // hour ticks + gridlines
  const top = 8;
  const plotH = 180;
  const axisY = top + plotH;
  const labelBandH = 44; // room for rotated date labels
  const legendRowH = 18;

  const legendCats = totals.filter((t) => t.minutes > 0);
  const legendH = legendCats.length === 0 ? 0 : 8 + legendRowH * legendCats.length;
  const height = axisY + labelBandH + legendH + 8;

  const innerX = gutter;
  const innerW = VIEW_W - innerX - 6;
  const slot = innerW / days.length;
  const barW = Math.max(2, Math.min(20, slot * 0.7));

  const minToY = (min: number): number => top + (min / 1440) * plotH;

  // Faint gridlines + hour ticks in the gutter.
  const gridAndTicks = STRIP_HOUR_TICKS.map((t) => {
    const y = minToY(t.min);
    const line = `<line x1="${innerX}" y1="${n(y)}" x2="${innerX + innerW}" y2="${n(y)}" stroke="#ECECEA"/>`;
    const text = `<text x="4" y="${n(y + 4)}" font-size="12" fill="#5C5C58">${esc(t.label)}</text>`;
    return line + text;
  }).join('');

  // Label every Nth day so at most ~10 labels show.
  const step = days.length > 10 ? Math.ceil(days.length / 10) : 1;
  const rotate = days.length > 10;

  const bars = days
    .map((d, i) => {
      const cx = innerX + slot * i + slot / 2;
      const x = cx - barW / 2;
      const segs = d.segments
        .map((seg) => {
          const y = minToY(seg.startMin);
          const h = Math.max(0, minToY(seg.endMin) - y);
          return `<rect x="${n(x)}" y="${n(y)}" width="${n(barW)}" height="${n(h)}" fill="${esc(seg.color)}"/>`;
        })
        .join('');

      let label = '';
      if (i % step === 0) {
        const lx = cx;
        const ly = axisY + 14;
        const text = esc(d.label);
        label = rotate
          ? `<text x="${n(lx)}" y="${n(ly)}" font-size="12" fill="#5C5C58" text-anchor="end" transform="rotate(-45 ${n(lx)} ${n(ly)})">${text}</text>`
          : `<text x="${n(lx)}" y="${n(ly)}" font-size="12" fill="#5C5C58" text-anchor="middle">${text}</text>`;
      }
      return segs + label;
    })
    .join('');

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
    'YOUR DAYS',
    `<svg viewBox="0 0 ${VIEW_W} ${n(height)}" width="100%" role="img" aria-label="Your days">${gridAndTicks}${bars}${legend}</svg>`,
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
.cw-charts .cw-caption { font-size:12px; color:#5C5C58; margin:0 0 8px; }
.cw-charts svg { display:block; width:100%; }
.cw-charts svg text { font-size:12px; }
</style>`;

export function renderCharts(datasets: ChartDatasets): string {
  const cards: string[] = [
    heatmapCard(datasets.heatmap),
    dailyStripCard(datasets.strip, datasets.categoryTotals),
    categoryBreakdownCard(datasets.categoryTotals),
  ];
  if (datasets.goalProgress.length > 0) {
    cards.push(goalProgressCard(datasets.goalProgress));
  }
  return `${STYLE}<div class="cw-charts">${cards.join('')}</div>`;
}
