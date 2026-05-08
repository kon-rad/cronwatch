# Cronwatch — Design Prompts

Prompts for the design team, one per screen. Each one carries the same design language so the app feels like a single piece of work.

## Shared design language

Use these defaults across every screen unless a prompt says otherwise.

- **Mood:** calm, focused, quietly modern. Think Apple Notes × Linear. The product is about *seeing your day clearly*, so the UI should get out of the way.
- **Palette:** near-white background (`#FAFAF7`) and near-black ink (`#111`). One accent — a warm amber (`#E8A33D`) reserved for the FAB, the active nav tab, and primary CTAs. Subtle neutral greys for borders and dividers (`#ECECEA`, `#9A9A95`).
- **Typography:** one humanist sans (Inter or SF Pro). Three sizes only — Title 22/600, Body 15/450, Caption 12/500. Tabular numerals for all times.
- **Shape & spacing:** 12 px corner radius on cards and buttons; 28 px on the FAB. 16 px base spacing unit. Generous whitespace; no heavy shadows — at most a soft `0 1 2 rgba(0,0,0,0.04)`.
- **Iconography:** thin 1.5 px stroke, rounded line caps. Lucide-style.
- **Motion:** quick and soft. 150–200 ms ease-out on taps, 250 ms spring on the FAB and sheets. Nothing bouncy or showy.

---

## 1. Sign-in

A first impression that feels trustworthy and unfussy.

- Centered wordmark **Cronwatch** at the top third, with a one-line tagline: *"Speak your time. See your day."*
- Two stacked buttons: **Continue with Apple** (filled black) and **Continue with Google** (white with thin border). Full width with 16 px gutters.
- Small caption at the bottom linking to Privacy and Terms.
- No illustrations or hero art — keep it quiet.

## 2. List view — Today

The home screen. Today's day rendered as a 15-minute grid.

- Top: today's date as a large title (`Tuesday, May 5`) with a smaller secondary line showing tracked vs. untracked time (e.g. *"6h 15m tracked"*).
- Body: a vertical table of 15-minute rows from `00:00` to `23:45`. Each row shows the time on the left in tabular numerals; the right side holds a soft pill with category + note when an entry covers that slot. Empty slots show a faint dotted divider — present but not noisy.
- Adjacent rows that share an entry visually merge into one continuous block (rounded top and bottom, square middle) so multi-slot entries read as a single bar.
- Bottom navigation: two tabs — **Today** and **Profile**. Active tab in amber.
- Floating **+** button bottom-right, amber, soft shadow, microphone icon inside.
- Pull-to-refresh and smooth scroll-to-now behavior on launch.

## 3. Capture sheet (FAB)

A focused modal sheet that appears when the **+** is tapped. The single most important interaction in the app.

- Bottom sheet covering ~70% of the screen, rounded top corners, drag handle.
- Big circular record button centered (amber, pulses subtly while recording). Above it: live waveform during recording, otherwise a single hint line: *"Hold to record, or type below."*
- Below the record button: a transcript area that fills with text live as Deepgram returns it.
- Secondary text-input row at the bottom for typed entries — same field, no toggle.
- Two actions in the top corners of the sheet: **Cancel** (left) and **Save** (right, amber, disabled until there's content).
- After save: brief inline confirmation (*"Logged."*) then the sheet dismisses and the new entry animates into place on the grid.

## 4. Entry detail / edit

Opens when a row on the grid is tapped. Same visual rhythm as Capture.

- Sheet style consistent with Capture.
- Editable fields in this order: **Category**, **Note**, **Start**, **End**.
- Category as a chip-style picker with recent categories surfaced first; free text always allowed.
- Times as inline pickers snapping to 15-minute increments.
- Footer: **Delete** as a quiet text button on the left; **Save** as the primary amber button on the right.

## 5. Profile

Personal, quiet, and rarely visited — but should still feel finished.

- Top: avatar (initials fallback), display name, signed-in email in caption grey.
- Section: **Subscription**. A single card showing current plan (Free, Weekly, or Yearly), next renewal date, and a button — **Upgrade** for free users, **Manage** for subscribers. Don't oversell; one calm card is enough.
- Section: **Account**. Rows for sign out and delete account. Delete uses red text only on the confirmation step, never the list itself.
- Section: **About**. Version number, link to source on GitHub, link to Privacy and Terms.
- Same bottom navigation as the List view; FAB stays visible.

## 6. Paywall

Reached from the **Upgrade** button. Convince without pressuring.

- Headline: *"Track your time without thinking about it."* Subhead: *"Voice in. Structured time out."*
- Three short feature rows with thin icons — voice capture, 15-minute grid, private by default.
- Two plan cards side by side:
  - **Yearly — $40/year** (badged *Best value — 20% off*)
  - **Weekly — $4/week**
  - Selected card outlined in amber; the other in neutral grey.
- Single primary button at the bottom: **Start subscription**. Below it, fine print with restore-purchases and terms links.
- No countdown timers, no fake discounts, no scare copy.

---

## Notes for handoff

- Build a small Figma library first: color tokens, type styles, the FAB, the entry pill, the 15-minute row, and the bottom nav. Every screen should compose from these pieces.
- Design light mode first; dark mode is a straight inversion of the neutral ramp with the same amber accent.
- All times in mocks should use tabular numerals so columns line up across rows.
