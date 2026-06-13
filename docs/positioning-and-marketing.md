# CronWatch — Positioning & Marketing Strategy

_Last updated: 2026-06-06. Research-backed. Sources cited inline._

This document answers four questions:
1. **Who is the target audience** (and which segment to win first)?
2. **How does CronWatch compare** to other tools on the market?
3. **What is the best positioning / angle**?
4. **How do we market it** (channels, in priority order)?

---

## TL;DR — the one-paragraph strategy

CronWatch is **voice-first, privacy-first time tracking**: tap, say what you did, and your day fills in on a 15-minute grid — no timers to start or forget. The **mechanic itself is no longer white space** (a free near-clone, "Time Aware," already ships, and "voice → AI-structured log" is a 2025–26 commodity pattern). So we do **not** win on "voice." We win on three defensible bets: **(1)** the _stated-priorities-vs-actual-time_ insight layer (nobody else holds up that mirror), **(2)** open source + privacy as a **trust brand**, and **(3)** a sharp **beachhead: adults with ADHD / time-blindness**, for whom "no timer to start" is a literal answer to their #1 complaint. Lead message: **"Just say what you did. See where your day actually went."** Anti-friction is the hook, the behavioral mirror is the reward, privacy is the trust layer. Launch via **ASO → Show HN (lead with open source) → build-in-public + community**, and reconcile the subscription price with the OSS crowd up front.

---

## 1. Target audience

### The segment map

| Segment | Pain for CronWatch | Willingness to pay | Verdict |
|---|---|---|---|
| **ADHD / time-blindness** | **Very high** | **High** | **★ Beachhead** |
| Indie hackers / founders | Moderate–high | High | Expansion #1 |
| Quantified-self | High engagement | Moderate | Niche, loyal, evangelists |
| Executives / coaches | Moderate | Very high | Expansion #2 (B2B2C) |
| Digital minimalists | Moderate | Moderate | Aligns on privacy |
| General knowledge workers | Low–moderate | Moderate | Big TAM, weak pain |

### Why ADHD is the beachhead (not founders)

The ADHD failure mode is _exactly_ what CronWatch removes. The segment's defining complaint is that **timers and planners require the executive function ADHD users lack** — "they still take executive-function brainpower, like actually remembering to use them" ([Understood.org](https://www.understood.org/en/articles/adhd-ai-tools)). Voice capture is the canonical workaround: "If it takes more than two seconds to log a thought, the thought is gone forever" ([FLOWN](https://flown.com/blog/adhd/best-body-doubling-apps)); "ADHD brains generate ideas faster than they can write them… voice-to-text transcribes, and AI organises the chaos" ([Dr. Flett](https://courses.drflett.com/why-ai-might-be-the-best-thing-thats-ever-happened-to-your-childs-adhd-brain/)). That is CronWatch's tap-speak-auto-structure loop, verbatim.

It's also large, self-identifying, and reachable:
- **~13–16M U.S. adults** with current ADHD diagnosis, ~22M including children ([NCHStats](https://nchstats.com/adhd-us-statistics/)).
- **ADHD app market ≈ $500M in 2025, ~15% CAGR** ([Data Insights Market](https://www.datainsightsmarket.com/reports/adhd-apps-528471)).
- **r/ADHD ≈ 2M+ members** — a dense, addressable channel ([GummySearch](https://gummysearch.com/r/ADHD/)).
- **47% of ADHD adults are dissatisfied** with managing day-to-day life — high pain density → willingness to pay ([RuleMoney](https://blog.rulemoney.co.uk/a-rundown-of-the-top-budgeting-apps-for-people-with-adhd/)).

Note the closest _commercial_ analog, **Tiimo** (ADHD planner), won 2025 App Store iPhone App of the Year and ~40K downloads/month — built on ASO + organic ADHD TikTok + Apple editorial, not big ad spend ([Tiimo](https://www.tiimoapp.com/)). That's the playbook.

**Founders/execs are real but secondary** — they tolerate manual tools (Toggl, Rize) and their pain is less acute. Win ADHD first; expand to founders and coaches once the insight layer is strong.

---

## 2. Competitive comparison

### Headline finding: the mechanic is already contested

> **"Time Aware – Voice Time Track" (Tappect LLC)** is a near spec-for-spec clone: voice-first, on-device, 15/30/45/60-min intervals, color-coded day view, no accounts, CSV export — **and it's free** ([App Store](https://apps.apple.com/us/app/time-aware-voice-time-track/id6757989946)). A second analog, **Speak To Track** ("Just talk. We'll track it."), does on-device voice → structured charts for **$0.99 one-time** ([speaktotrackapp.com](https://speaktotrackapp.com/)). And the broader "speak it, AI logs it" pattern is commoditized across expenses (Peggy, MonAi) and journaling (Day One, Dayora).

**Implication:** "voice-first," "on-device," and "15-min grid" are **not** moats. Do not build the brand on them.

### The landscape

**Classic trackers (timer / billing-centric):**
| Tool | Mechanic | Price | Why not a direct rival |
|---|---|---|---|
| Toggl Track | One-tap manual timer | Free; ~$9–20/user/mo | Team/billing framing; timer-centric |
| Clockify | Manual timer | Free; $3.99–15.99/user/mo | Utilitarian, admin-focused; note $3.99 = our weekly |
| Harvest | Timer + invoicing | Free; ~$11–14/user/mo | An invoicing tool |
| **RescueTime** | **Fully automatic** | $12/mo or $78/yr | Closest in _intent_ ("where did my time go") but only sees **screen activity** — blind to meetings, offline, thinking, and gives no narrative |

**AI / automatic trackers (desktop, screen-bound):**
| Tool | Mechanic | Price | Gap CronWatch fills |
|---|---|---|---|
| Rize.io | Auto capture + AI | $9.99–12.99/mo | **Desktop-only**; blind to offline work |
| Timing (Mac) | Auto + AI summaries | ~$79/yr | **Mac-only** |
| Memtime | Passive app capture | ~$10–12/mo | Desktop; timesheet-recon framing |
| Rewind / Limitless | Continuous capture | — | **Dying** — Meta acquired Limitless Dec 2025, Rewind sunset ([WinBuzzer](https://winbuzzer.com/2025/12/05/meta-acquires-ai-wearables-startup-limitless-kills-pendant-sales-and-sunsets-rewind-app-xcxwbn/)). Validates appetite; shows cloud-capture privacy is a hard sell |

> **Key structural wedge:** _every_ AI auto-tracker is **desktop/screen-bound** and cannot see the meeting, the walk, or the deep thinking. CronWatch is **mobile + captures intent in your own words** — it sees the whole day.

**Personal / life loggers (our true peer set):**
| Tool | Mechanic | Price | Weakness |
|---|---|---|---|
| aTimeLogger | Manual tap start/stop | Freemium | Friction, dated UX, no voice/AI |
| Daylio | Tap mood + activity icons | Free; $4.99/mo or **$35.99/yr** | Mood-first, not a time grid; **pricing comparator users will feel** |
| Boosted | One-click + Pomodoro | Freemium | Manual taps, no voice |

**Planning-adjacent (sell the future, not the past):**
- **Sunsama** ($16/mo) — calm, intentional brand for founders/execs; plans _forward_. **Complementary**, and a tonal model to study.
- **Reclaim** ($10–22/mo), **Akiflow** ($19/mo, keyboard-first — the literal opposite of voice). **Clockwise** is **shutting down March 2026**.

> These tools answer "what should I do next." **None answer "where did my time actually go, in my own words, vs. what I said mattered."** That gap is ours.

### Honest scorecard — real vs. weak differentiation

**Weak / contested:** voice-first capture (Time Aware, free) · on-device/privacy (now table stakes via Apple Foundation Models) · 15-min grid (Time Aware has it) · price (sits _above_ free clones and $0.99 Speak To Track; weekly is aggressive).

**Real (if executed):**
1. **Priorities-vs-reality insight layer** — _no competitor_ confronts you with "you said deep work was #1; it was 6%." This is the strongest wedge. **Lean into it, not the mic.**
2. **Mobile + offline/meeting capture** — fills the blind spot of every desktop auto-tracker.
3. **Open source (MIT)** — genuinely rare in this set; a defensible **trust/community** moat for privacy-conscious + technical buyers.
4. **Premium reflective positioning** — the category splits into team-billing tools and mass-market mood apps; a tasteful, calm, _executive time-truth_ app is underserved.

---

## 3. Positioning & angle

### The stacked frame

> **Anti-friction is the hook → the behavioral mirror is the reward → privacy is the trust layer.**

- **Hook (mechanism):** No timers to start. No timers to forget. Just talk. Winning self-trackers "reduce the awkward gap between intention and action" ([Neurosity](https://neurosity.co/guides/best-productivity-frameworks-deep-workers)).
- **Reward (payoff):** A mirror of your real day. The best tools run a loop of **insight → decision → action → reflection** ([MyLifeNote](https://blog.mylifenote.ai/10-best-ai-tools-for-self-improvement-in-2026/)). Our "values drift" feature _is_ the mirror.
- **Trust (amplifier):** Private by design, on-device, open source. A trust line — **not** the headline.

Avoid leading with the QS classic "you can't manage what you don't measure" — it inherits quantified-self's engagement problem (people collect but don't engage) ([Mark Koester](https://www.markwk.com/quantified-self-mind-map.html)).

### Emotional driver: curiosity & gentle agency — **never guilt**

The top self-trackers explicitly _remove_ guilt, which is what converts the ADHD/burnout audience: Finch ("whatever it takes to get through the day," markets to ADHD/burnout, 2.34M downloads/90 days — [MediaPost](https://www.mediapost.com/publications/article/415234/self-care-app-finch-promotes-whatever-it-takes-to.html)); JoyScore ("No streak pressure. No guilt."); Focus Buddy ("You're not broken."). **Guilt-based framing repels our exact beachhead.**

### Lead messaging (test these)

- **Primary:** _"Just say what you did. See where your day actually went."_
- ADHD-targeted: _"Time tracking for brains that hate time tracking."_
- Mechanism: _"No timers to start. No timers to forget. Just talk."_
- Mirror: _"Your time, mirrored — and where it's drifting from what matters."_
- Trust line (secondary): _"Private by design. On-device. Open source."_

### One-line positioning statement

> **For people who lose track of where their time goes** (starting with ADHD/time-blindness), **CronWatch is a voice-first time tracker** that turns a spoken sentence into your real day on a 15-minute grid — **and shows you where it's drifting from what you said mattered.** Unlike timer apps you forget to start or screen-trackers that miss your real life, there's nothing to start and nothing to fudge.

---

## 4. Pricing

Current: **$3.99/wk · $39.99/yr.** Verdict: **on-trend; weekly may be underpriced.**

- **Weekly subscriptions now drive 55.5% of app revenue** (up from 43.3% two years ago) and **convert 1.7–7.4× better than annual** — users buy easy-exit, not savings ([Adapty](https://adapty.io/blog/weekly-monthly-annual-subscription-plan/)).
- Productivity **median weekly is $7.48** → our $3.99 is ~47% below; **test $4.99–$5.99.** Annual median is $38.42 → our $39.99 is right on ([Adapty benchmarks](https://adapty.io/blog/productivity-app-subscription-benchmarks/)).
- We **undercut** RescueTime ($78/yr) and Rize ($120+/yr); we sit near Daylio/Day One ($35.99/$34.99/yr) — fair "premium insight" position.
- **Watch-outs:** we're _above_ free clones (Time Aware) and $0.99 Speak To Track, and the OSS/privacy crowd is subscription-averse. **Reconcile explicitly:** "Open source & auditable; the subscription funds full-time development."
- **Plan:** weekly as the low-commitment on-ramp; anchor annual hard at the paywall ("$39.99/yr = $0.77/wk vs $3.99/wk"). Productivity buyers show a _trial penalty_ (direct buyers out-LTV trial users), so **A/B test a hard paywall vs. free trial** ([Adapty](https://adapty.io/blog/productivity-app-subscription-benchmarks/)).

---

## 5. Go-to-market — channels by effort-to-impact

| # | Tactic | Effort | Impact | Note |
|---|---|---|---|---|
| 1 | **ASO foundation** | Low | High | Free, compounds forever; niche = winnable long-tail |
| 2 | **Show HN** (lead with open source) | Low | High | OSS+privacy is HN's wheelhouse; 5k–30k visitors possible |
| 3 | **Build-in-public** (X + GitHub) | Med (ongoing) | High | Your channel for launches 2, 3, 4… |
| 4 | **Community feedback posts** | Low–Med | Med–High | r/SideProject, r/QuantifiedSelf first; r/ADHD only after earning standing |
| 5 | **SEO content** | Med (slow) | Med–High | "Time audit," "track time without timers" |
| 6 | **OSS directories** | Low | Med | awesome-ios, open-source-ios-apps, AlternativeTo |
| 7 | **Product Hunt** | Low–Med | Low–Med | Backlink/awareness, **not** signups |
| 8 | **Creator outreach** (ADHD + productivity) | Med–High | Med (high variance) | Mid-tier, credible ADHD creators |
| 9 | **TikTok/Reels** | High (ongoing) | Med–High if consistent | Where the ADHD audience lives |

### ASO specifics
Ranking weight: **app name (30) > subtitle (30) > keyword field (100, comma-separated, no spaces, never repeat words)**. Screenshots are now indexed for keywords _and_ drive ~60–70% of the install decision — first 3 show in search ([Dogtown Media](https://www.dogtownmedia.com/aso-2-0-advanced-app-store-optimization-strategies-for-2025/)). Use Apple **Product Page Optimization** with separate custom pages per audience (one for ADHD traffic, one for QS/dev). Suggested:
- **Name:** `CronWatch: Voice Time Tracker`
- **Subtitle:** `ADHD-friendly, private time log`
- **Keywords:** `time blindness,audit,journal,self tracking,quantified,hands free,offline,open source,activity,focus`
- Own the long-tail: `voice time tracker`, `talk to track time`, `ADHD timer`, `time blindness`, `where did my time go`, `track time without timers`.

### Launch sequence
1. **ASO first** (free, compounding) — do before any launch.
2. **Show HN** as flagship: link the GitHub repo + live demo, direct/specific title (no "best/first"), post Tue–Thu 9am–12pm ET, reply to every comment incl. critics. ~30–50 upvotes in hour one is decisive ([Lucas Costa](https://www.lucasfcosta.com/blog/hn-launch)).
3. **Product Hunt** same week for the SEO backlink — manage expectations (PH cohorts retain poorly).
4. **Seed OSS directories** (passive, durable).
5. **Begin build-in-public + SEO** now — they pay off on launches 2 and 3.

### Community rules (high reward, high ban risk)
**90/10 rule** (≤10% promotional), **frame as feedback not promo**, **message mods first.** Order: **r/SideProject** (welcomes "I built this") → **r/QuantifiedSelf** (perfect fit; lead with data-ownership/export) → **r/productivity, r/getdisciplined** (value-first content, one disclosed mention) → **r/ADHD** only after becoming a genuine participant; never link-drop there ([Conbersa](https://www.conbersa.ai/learn/reddit-self-promotion-rules)).

### The open-source flywheel (our strongest differentiator)
Treat OSS as a **trust + distribution multiplier**, not a license footnote. Analogs that grew on the "simple, private, open" pitch: **Wealthfolio** (OSS privacy-first tracker, HN front page + GitHub trending — [DEV](https://dev.to/afadil/how-i-built-an-open-source-app-that-went-viral-160p)), **Postiz** ($0→$2K MRR in ~4 months). HN exposure reliably converts to GitHub stars → social proof. Moves: polished README (screenshots, privacy stance, export story) as a conversion page; "open source" badge; listings on **awesome-ios**, **dkhamsing/open-source-ios-apps**, **AlternativeTo** (as a RescueTime/Toggl/Timery alternative); use OSS to defuse the subscription objection.

---

## 6. What to do next (concrete)

1. **Rewrite the App Store + landing hero** around _"Just say what you did. See where your day actually went."_ — anti-friction hook, mirror payoff, privacy trust line. De-emphasize "voice-first" as _the_ headline (it's contested).
2. **Ship and foreground the insight layer** (priorities-vs-actual / values drift). This is the real moat — make it visible in screenshots and the first session.
3. **Add an ADHD-targeted custom product page** + ADHD keywords; this is the beachhead.
4. **Polish the GitHub repo as a marketing asset**; prep the Show HN.
5. **A/B test weekly at $4.99–$5.99** and **hard paywall vs. free trial**.
6. **Differentiate explicitly against Time Aware** before assuming any "voice is white space" thesis — win on insight, taste, and brand, not the mechanic.

---

### Source index
Competitive: [Time Aware](https://apps.apple.com/us/app/time-aware-voice-time-track/id6757989946) · [Speak To Track](https://speaktotrackapp.com/) · [Toggl](https://toggl.com/track/pricing/) · [Clockify](https://clockify.me/pricing) · [RescueTime](https://www.rescuetime.com/pricing) · [Rize](https://rize.io/pricing) · [Timing](https://timingapp.com/pricing) · [Memtime](https://www.memtime.com/pricing) · [Rewind/Limitless–Meta](https://winbuzzer.com/2025/12/05/meta-acquires-ai-wearables-startup-limitless-kills-pendant-sales-and-sunsets-rewind-app-xcxwbn/) · [Daylio](https://daylio.net/) · [Sunsama](https://www.sunsama.com/pricing)
Audience/positioning: [Understood.org](https://www.understood.org/en/articles/adhd-ai-tools) · [FLOWN](https://flown.com/blog/adhd/best-body-doubling-apps) · [Data Insights ADHD market](https://www.datainsightsmarket.com/reports/adhd-apps-528471) · [NCHStats](https://nchstats.com/adhd-us-statistics/) · [r/ADHD](https://gummysearch.com/r/ADHD/) · [Neurosity](https://neurosity.co/guides/best-productivity-frameworks-deep-workers) · [Finch (MediaPost)](https://www.mediapost.com/publications/article/415234/self-care-app-finch-promotes-whatever-it-takes-to.html) · [Tiimo](https://www.tiimoapp.com/)
Pricing: [Adapty weekly vs annual](https://adapty.io/blog/weekly-monthly-annual-subscription-plan/) · [Adapty productivity benchmarks](https://adapty.io/blog/productivity-app-subscription-benchmarks/)
GTM: [Lucas Costa — HN launch](https://www.lucasfcosta.com/blog/hn-launch) · [Conbersa — Reddit rules](https://www.conbersa.ai/learn/reddit-self-promotion-rules) · [Dogtown — ASO 2.0](https://www.dogtownmedia.com/aso-2-0-advanced-app-store-optimization-strategies-for-2025/) · [Wealthfolio (DEV)](https://dev.to/afadil/how-i-built-an-open-source-app-that-went-viral-160p) · [awesome-ios](https://github.com/vsouza/awesome-ios) · [open-source-ios-apps](https://github.com/dkhamsing/open-source-ios-apps)
