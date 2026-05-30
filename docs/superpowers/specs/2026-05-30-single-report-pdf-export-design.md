# Single range-based report with PDF export

**Date:** 2026-05-30
**Status:** Approved

## Goal

Collapse the two parallel report systems into one. Remove the "weekly" report
entirely. The single remaining report is the existing range-based report: the
user picks a start and end date, optionally adds a custom prompt, and the AI
generates an insightful data analysis with HTML/CSS + inline-SVG charts. The
report is viewed in-app as live HTML and can be exported as a PDF.

## Background

Two report systems exist today:

- **Weekly report** (Overview tab): `WeekReportView` / `WeekReportService` /
  `server/src/weekReport.ts` (`WEEK_REPORT_SYSTEM_PROMPT`). Returns structured
  goal analyses + 10 ideas, rendered natively, then also saved as a
  `ProfileReport`.
- **Range report** (Profile tab): `ReportComposerView` → `ProfileReportGenerator`
  → `server/src/profileReport.ts` (`PROFILE_REPORT_SYSTEM_PROMPT`). Already
  returns a self-contained HTML report (pie chart, heat map, 3 more SVG charts,
  10 recommendations), rendered in a `WKWebView` (`ReportDetailView`) and saved
  via `ProfileReportsService`.

The range report already matches the desired product. The work is to delete the
weekly system and add PDF export.

## Design

### 1. Remove the weekly report system

**iOS**
- Delete `Views/Overview/WeekReportView.swift`,
  `Services/WeekReportService.swift`, `Utils/WeekReportAggregator.swift`.
- Trim `Models/WeekReport.swift`: keep `CategoryMinutes` and `DayAggregate`
  (still used by `RangeAggregator` and `ProfileReportGenerator`); remove
  `GoalAnalysis` and `WeekReport`. Rename the file to `Models/Aggregates.swift`.
- `OverviewView.swift`: remove `showWeekReport`, `weekReportRange()`,
  `weekReportEligible`, `weekReportButtonEnabled`, `openWeekReport()`, and the
  `WeekReportView` sheet.

**Server**
- Delete `server/src/weekReport.ts`.
- Remove `WEEK_REPORT_SYSTEM_PROMPT` from `prompts.ts`.
- Remove the `weekReportHandler` import and `/week-report` route from `index.ts`.

### 2. One report category (kept as-is)

`ReportComposerView` is the single composer: start/end **date** pickers
(dates-only, default last 7 days, inclusive) + optional custom prompt,
paywall-gated for free users. `/profile-report` + `PROFILE_REPORT_SYSTEM_PROMPT`
are unchanged except tidying the stale "7-day totals" wording to "range totals."

### 3. Overview shortcut

Where the weekly button was, add a "Generate report" row (sparkles icon)
mirroring Profile's behavior: free users → `PaywallView`; otherwise present the
same `ReportComposerView`, and on success open `ReportDetailView`. No
goal-gating (goals are optional for the range report).

### 4. PDF export

- `ReportDetailView` keeps the `WKWebView` for viewing (responsive/scrollable).
- Add a trailing **Share** toolbar button that renders the report to PDF via
  `WKWebView.createPDF(configuration:)`, writes it to a temp file named from the
  sanitized `report.title` (fallback `"Cronwatch Report.pdf"`), and presents
  `UIActivityViewController`.
- The Share button is disabled until the web content finishes loading (tracked
  via the nav delegate's `didFinish`). PDF failure → `ToastCenter` error toast.

## Data flow (unchanged for generation)

`ReportComposer` → `EntriesService.fetchRange` → `RangeAggregator.aggregate` →
`ProfileReportGenerator.generate` (POST `/profile-report`) → `{title, html}` →
saved via `ProfileReportsService` → `ReportDetailView` renders HTML; Export =
WebView → PDF → share sheet.

## Testing

- iOS compiles with no dangling refs to removed types; server `tsc` passes;
  `/week-report` route removed.
- Manual: generate from both Profile and Overview; view; export → PDF opens with
  all charts intact; free user hits paywall from both entry points; weekly
  button gone.
