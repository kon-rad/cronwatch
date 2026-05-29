# Home Page Brainstorm — Charts & Data Points

**Mission:** Help people use their time better. *You can only manage what you can measure.*

## Proposed layout (top → bottom)

1. **Header** — date, tracked vs. open today
2. **Monthly calendar heatmap** — every day this month, colored by dominant category or total tracked minutes (user's explicit ask)
3. **Insight section** — one or two of the ideas below, rotated or pinned
4. **Today's 24h grid** — existing view, scrollable

The goal of section 3 is to surface a single "*so what?*" each time the user opens the app — a fact that changes behavior, not just a number.

---

## Top 20 ideas for charts & data points

### Pattern reveal — "where is my time actually going?"

#### 1. Monthly category heatmap (the calendar)
A 5×7 grid of the month. Each cell is a day, filled with the dominant category's color, with opacity scaled by total tracked minutes. Tap a day to drill in. Empty days show as faint outlines — gaps become visible.
*Why:* The whole month at a glance. Patterns ("I never deep-work on Fridays") jump out.

#### 2. Time-of-day × day-of-week heatmap
24 rows (hours) × 7 cols (Mon–Sun). Cell color = dominant category for that hour, averaged across the last 4 weeks. Reveals your actual rhythm.
*Why:* Shows when you reliably do focused work — and when you reliably don't. Schedule accordingly.

#### 3. Category trend sparklines (last 30 days)
One sparkline per category, sorted by minutes this month. Eye-readable in 2 seconds.
*Why:* "Exercise is trending down" is more actionable than "you did 4h of exercise this month."

#### 4. Untracked time %
"68% of waking hours tracked this month." Big number, with a thin progress ring.
*Why:* If 40% of your day is invisible, no other chart is trustworthy. Drives capture habit.

---

### Signal vs. noise — "what *kind* of time?"

#### 5. Invest / Maintain / Leak ratio
Group categories into Invest (deep, study, exercise), Maintain (meal, commute, sleep, break), Leak (entertain). Stacked horizontal bar for the week. User-configurable groupings.
*Why:* Raw category breakdown doesn't tell you if you're winning. This does.

#### 6. Deep-work hours this week vs. last week
Single hero number. "**12h 30m** deep work this week ↑ 18% vs last." Color: green if up, amber if flat, red if down.
*Why:* One metric to rule them all for knowledge workers. Trend > absolute.

#### 7. Context-switching index
Count of distinct entries per day, averaged over the week. Higher = more fragmented. Pair with a one-line interpretation: "You averaged 14 switches/day. Last week: 9."
*Why:* Long blocks beat scattered minutes for most "investment" categories.

#### 8. Longest unbroken focus block this week
"Your longest deep-work session this week: **2h 14m** on Tuesday." Plus a small bar showing each day's longest block.
*Why:* Personal records are motivating. Reinforces flow-state behavior.

---

### Goal pacing — "am I on track?"

#### 9. Weekly goal progress rings
Up to 3 user-set goals (e.g. "8h deep / week", "4h exercise / week"). Apple-Watch-style rings with hours-remaining text.
*Why:* Goal pacing converts measurement into management. Without a target, data is trivia.

#### 10. Monthly forecast
"At this pace you'll finish the month with **62h** deep work (goal: 80h)." Small projection line.
*Why:* Mid-month course-correction is more useful than end-of-month autopsy.

#### 11. Pace vs. yourself (4-week baseline)
For each top category, a small bar: "this week" vs. "your 4-wk average." Shows regression and improvement against your own norm — not someone else's.
*Why:* Personal baseline is the only fair comparison.

---

### Streaks & momentum

#### 12. Per-category streaks
"🟧 12 days exercise · 5 days deep work · 0 days study (broken yesterday)." Beats a single tracking streak.
*Why:* The current streak rewards just opening the app. Category streaks reward actual behavior.

#### 13. Personal-best callouts
Rotating: "Longest deep session ever: **3h 42m** on May 7." "Most exercise in a week: 6h on week of Apr 14."
*Why:* Anchors progress in concrete memorable wins.

---

### Rhythm of the day

#### 14. Start-of-day / end-of-day clock
Two small circular clocks: average time of your first entry, average time of your last. "You start at 8:42, stop at 22:15 on average."
*Why:* Reveals lifestyle drift. "I'm starting later every week."

#### 15. Most productive hour
"Your best hour this month is **09:00–10:00**: 11h of deep work logged there." With a 24-bar mini-histogram.
*Why:* Defends your golden hour from meeting creep.

#### 16. Weekday vs. weekend split
Donut comparison. Two donuts side by side. Useful to see if your "values" survive the weekend.
*Why:* Many people leak time on weekends without knowing it.

---

### Reflection prompts

#### 17. Best day this month
"**Tuesday May 6**: 6h deep, 2h exercise, 8h sleep. Want a day like this tomorrow?" Tap to see the full 24h grid for that day. Optional "pin as template."
*Why:* Find the recipe that already worked. Replicate.

#### 18. Anomaly callout
"You did 4h of meetings yesterday — **3× your average**." Or: "0 minutes of exercise in 6 days."
*Why:* Surfaces what's worth noticing without making the user dig.

#### 19. Values drift
Set "important" categories at onboarding (e.g., exercise + deep). Show: "You said exercise matters. It was **2%** of your tracked time this month." Gentle, factual.
*Why:* The single most behavior-changing chart — gap between stated values and actual behavior.

---

### Capture-quality nudge

#### 20. Capture coverage by hour
A thin 24-bar bar at the top of the calendar showing which hours of the day you most commonly track vs. miss. Reveals capture blind-spots (e.g., evenings always untracked).
*Why:* Improves the data itself. Better data → better insight loop.

---

## Bonus / future ideas (not in top 20)

- **Quote of the week** — pull a striking transcript snippet from voice captures
- **Composite daily score (0–100)** — weighted by user goals; risky (gamifies the wrong thing)
- **Sleep × productivity correlation** — needs a few months of data to be reliable
- **AI weekly recap** — natural-language summary every Sunday: "This week you ..."
- **Cohort/percentile** — "you tracked more than 80% of Cronwatch users this week" (only if it doesn't feel creepy)
- **Drift alerts** — push notification when a category trends down for 3 weeks straight

---

## Recommended starting set (if we pick 3 for v1 of the new home section)

Below the calendar, rotate or stack:

1. **Deep-work this week vs. last** (idea #6) — one hero number, instant signal
2. **Invest / Maintain / Leak ratio** (idea #5) — the "so what" framing
3. **Values drift** (idea #19) — the behavior-changing one

This trio answers: *Did I move forward? What kind of time was it? Does it match what I said mattered?*
