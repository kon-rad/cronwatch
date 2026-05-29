# Cronwatch — App Store Copy

Source of truth for App Store Connect listing fields. All fields are within Apple's character limits (counted below). Replace placeholder URLs (`cronwatch.app/...`, support email) with the live ones before submitting.

---

## Subtitle

**Limit:** 30 characters
**Used:** 25

```
Voice-first time tracking
```

---

## Promotional Text

**Limit:** 170 characters
**Used:** 133

Promotional Text appears at the top of the listing and can be updated without a new build — use it for launches, seasonal angles, or new features.

```
You can only manage what you measure. Tap +, speak what you did, and Cronwatch lays out your day on a 15-minute grid — automatically.
```

### Alternates (rotate any time)

- (147) `New: weekly insights show where your time actually went — and how it compares to what you said matters. Tap +, speak, and Cronwatch does the rest.`
- (134) `Stop starting timers. Just say what you did. Cronwatch transcribes, structures, and lays it onto a 15-minute grid for your day.`
- (118) `Voice in, structured day out. Cronwatch turns "deep work 9 to 10:30" into a real entry on your time grid.`

---

## Keywords

**Limit:** 100 characters (comma-separated, no spaces after commas)
**Used:** 99

Apple indexes app name + subtitle automatically — these keywords intentionally avoid `voice`, `time`, and `tracking` (already in the subtitle) to maximize unique terms.

```
tracker,timer,productivity,focus,deep work,log,journal,timesheet,pomodoro,planner,calendar,daily,ai
```

### Alternate (with competitor terms — higher ASO ceiling, slightly higher rejection risk)

```
tracker,timer,productivity,focus,deep work,log,journal,timesheet,toggl,rescuetime,pomodoro,planner
```

---

## Description

**Limit:** 4000 characters
**Used:** ~2,500

```
You can only manage what you measure.

Cronwatch is the simplest way to see where your time actually goes. Tap the + button, say what you did, and your day takes shape — automatically.

HOW IT WORKS

1. Tap the + button from any screen.
2. Speak what you're doing — "deep work on the auth refactor from 9 to 10:30," or just "lunch with Sara."
3. Cronwatch transcribes what you said, structures it into a clean entry, and drops it onto your day.

No timers to start. No menus to dig through. No friction between living and recording.

WHAT YOU SEE

Your day, laid out as a 96-row grid of 15-minute increments. Empty rows are gaps. Filled rows show their category and a one-line note. Patterns become visible without you having to look for them.

WHY VOICE

Most time trackers fail for the same reason: starting a timer interrupts the work you're trying to track. Cronwatch flips it. You don't clock things as they happen — you tell it, in your own words, what you just did. It's how you'd describe your day to a friend, except the app is listening, organizing, and rendering it in real time.

WHAT'S COMING

Cronwatch is built around a single belief: the gap between your stated values and your actual behavior is the most important number nobody tracks. Updates on the way will surface that gap:

• Monthly calendar heatmap — your shape, week by week.
• Deep-work hours this week vs. last — one number, instant signal.
• Invest / Maintain / Leak ratio — what kind of time was it, really?
• Values drift — "you said exercise mattered. It was 2% of your tracked time this month."

PRIVACY

Sign in with Google or Apple. Entries are stored against your account in Google Cloud Firestore and restricted to you. Audio is transcribed and discarded by default — only the structured text entry is kept. Cronwatch is open source under the MIT license, so every line of code that touches your data is readable.

SUBSCRIPTION

Cronwatch offers two auto-renewing subscriptions:

• Weekly — $4 / week
• Yearly — $40 / year (20% off)

Payment is charged to your Apple ID at confirmation of purchase. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the period at the same price. Manage or cancel in Settings → Apple ID → Subscriptions.

Privacy Policy: https://cronwatch.app/privacy
Terms of Service: https://cronwatch.app/terms
Support: hello@cronwatch.app
```

---

## What's New (release notes)

**Limit:** 4000 characters
**Used:** ~700

For the v1 launch / native iOS rewrite:

```
Welcome to Cronwatch.

This is v1 — voice-first time tracking, native on iOS.

What's in the box:
• Global + button — capture from any screen with voice or text
• Automatic transcription and entry structuring (start time, end time, category, note)
• 15-minute grid view of your day, 96 rows, scrollable
• Sign in with Google or Apple, via Firebase
• Weekly and Yearly subscriptions

Cronwatch was previously a React Native prototype. This release rebuilds it as a native iOS app for faster capture, smoother scrolling, and tighter sign-in.

Coming soon: monthly heatmap, deep-work weekly trend, and the values-drift report.

If you hit a bug or have a request, email hello@cronwatch.app — replies come from a human (the founder).
```

---

## Pre-submission checklist

- [ ] Replace `https://cronwatch.app/privacy` with the live Privacy Policy URL.
- [ ] Replace `https://cronwatch.app/terms` with the live Terms of Service URL.
- [ ] Replace `hello@cronwatch.app` with the real support email (App Store Connect requires a working address).
- [ ] Verify the auto-renewing subscription disclosure text matches the prices configured in App Store Connect (weekly $4 / yearly $40 are placeholder figures from the README — confirm against RevenueCat / App Store Connect).
- [ ] Decide between the safer keyword string (default above) and the competitor-term variant. Toggl/RescueTime in keywords is widely tolerated by Apple but is technically against guideline 5.2.4 — risk is rejection, not removal post-approval.
- [ ] Re-count Promotional Text after any edit — 170 characters is tight.
