# Cronwatch Architecture

Cronwatch is a voice-first time tracking app. Users speak (or type) what they did, and the app structures that input into time blocks aligned to a 15-minute grid for the day. This document describes the system architecture, data flow, and integration points.

## Goals

- **Frictionless capture** — one tap on a global FAB to log time from any view.
- **Voice-first** — speech is the primary input; typing is a fallback.
- **Structured output** — every entry lands in Firestore as a typed record with category, note, and a start/end timestamp.
- **15-minute grid** — the day is rendered as a table of 15-minute increments so users can see coverage and gaps at a glance.

## High-Level Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                            Mobile Client                             │
│                                                                      │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│   │   List View  │    │ Profile View │    │  Capture FAB │           │
│   │ (15-min grid)│    │ (auth + sub) │    │   (global)   │           │
│   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘           │
│          │                   │                   │                   │
│          └────────── Bottom Navigation ──────────┘                   │
│                                                                      │
│   Voice recorder ──► audio buffer ──► upload                         │
└──────────┬─────────────────┬───────────────────────┬─────────────────┘
           │                 │                       │
           │ Auth            │ Firestore /           │ Audio + text
           │ (Google/Apple)  │ Storage               │
           ▼                 ▼                       ▼
   ┌──────────────┐   ┌──────────────┐       ┌──────────────┐
   │ Firebase Auth│   │  Firestore   │       │   Deepgram   │
   │              │   │  + Storage   │       │ (transcribe) │
   └──────────────┘   └──────┬───────┘       └──────┬───────┘
                             │                      │
                             │                      ▼
                             │              ┌──────────────┐
                             │              │  Together AI │
                             │              │  Llama 3.3   │
                             │              │ (structure)  │
                             │              └──────┬───────┘
                             │                     │
                             └─────── write ◄──────┘

           ┌──────────────┐
           │  RevenueCat  │  ($4/week, $40/year — 20% off)
           └──────────────┘
```

## Client Application

The client is a mobile app with three primary surfaces and a global capture button.

### Views

1. **List view (Today)**
   - Bottom-navigation tab.
   - Renders the current day as a vertical table of 15-minute increments (96 rows from `00:00` to `23:45`).
   - Each row shows the entry that covers that slot (category, note) or empty state.
   - Tapping a row opens the underlying entry for edit/delete.

2. **Profile view**
   - Bottom-navigation tab.
   - Displays the signed-in user's profile and email.
   - Shows current subscription status (free / weekly / yearly) sourced from RevenueCat.
   - Provides sign-out and account management.

3. **Capture (FAB)**
   - A floating "+" button anchored bottom-right, present on every view.
   - Two modes: **voice** (default — hold to record) and **text** (typed fallback).
   - On submit, runs the capture pipeline (below) and writes the resulting entry to Firestore.

### Bottom Navigation

The bottom navigation hosts the List and Profile tabs. The capture FAB floats above the bar and is always reachable.

## Authentication

- **Provider:** Firebase Auth.
- **Sign-in methods:**
  - Google (Gmail) Sign-In
  - Apple Sign-In
- The signed-in `user.uid` scopes all Firestore reads and writes via security rules.

## Data Storage

### Firestore

All entries are stored in Firestore under a per-user collection.

```
users/{uid}
  profile: { email, displayName, createdAt }
  entries/{entryId}
    category:    string
    note:        string
    startTime:   timestamp
    endTime:     timestamp
    source:      "voice" | "text"
    transcript:  string?     // raw transcript when source = voice
    createdAt:   timestamp
```

**Security rules** (sketch):

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

### Firebase Storage

- Optional retention of raw audio for debugging / re-processing.
- Path: `users/{uid}/audio/{entryId}.m4a`.
- Excluded from default reads; can be cleared by the user.

## Capture Pipeline

The end-to-end pipeline that turns a tap on the FAB into a structured Firestore entry.

```
1. User taps + (FAB)
2. Client records audio   ──►  (or user types text)
3. Audio uploaded to Deepgram ──► transcript (string)
4. Transcript sent to Together AI (Llama 3.3) with a structuring prompt
5. Model returns JSON (validated client-side):
      { category, note, startTime, endTime }
6. Client writes entry to Firestore under users/{uid}/entries/{id}
7. List view reflects the new entry on the 15-minute grid
```

### 1. Recording

- Mic permission requested on first use.
- Audio captured in a Deepgram-supported format (e.g. `m4a`, `wav`, or streamed PCM).

### 2. Transcription — Deepgram

- Audio is sent to Deepgram's transcription API.
- Returns a plain-text transcript used as the LLM input.
- Errors fall back to a text input dialog ("we couldn't hear that — type it instead").

### 3. Structuring — Together AI (Llama 3.3)

- Endpoint: Together AI inference, model `Llama 3.3` (e.g. `meta-llama/Llama-3.3-70B-Instruct-Turbo`).
- The prompt instructs the model to output **only** JSON matching the schema below.
- The client validates the response against the schema before writing.

#### JSON schema

```json
{
  "category":  "string",            // short label, e.g. "work", "meetings"
  "note":      "string",            // free-form description from the transcript
  "startTime": "2026-05-04T10:00:00Z",  // ISO 8601
  "endTime":   "2026-05-04T10:30:00Z"   // ISO 8601
}
```

#### Defaults

- If the user does **not** specify a date or time, both `startTime` and `endTime` default to **the current capture time** (server's "now" passed into the prompt).
- If the user specifies a time or duration ("from 9 to 10", "for 30 minutes"), the model fills `startTime`/`endTime` accordingly.
- All times are normalized to UTC before writing; the client renders in the user's local timezone.

### 4. Persistence

- The validated JSON is enriched with `source`, `transcript`, `createdAt`, and written under `users/{uid}/entries/{entryId}`.
- The List view subscribes to today's entries via a Firestore query (`startTime` within today, ordered by `startTime`).

## Subscriptions — RevenueCat

Monetization is handled through RevenueCat, which fronts the App Store and Play Store IAP systems and exposes entitlement state to the client.

| Plan      | Price     | Notes                                         |
|-----------|-----------|-----------------------------------------------|
| Weekly    | $4 / week | Recurring weekly subscription.                |
| Yearly    | $40 / year | Effectively 20% off vs. weekly ($208/year).  |

- The client checks the active entitlement on launch and after purchase.
- Profile view surfaces current plan + manage/cancel link.
- Free tier (TBD) gates capture frequency or feature set; entitlement gating happens client-side guarded by RevenueCat.

## External Services Summary

| Service       | Purpose                                  |
|---------------|------------------------------------------|
| Firebase Auth | Google / Apple sign-in                   |
| Firestore     | Primary database for entries & profiles  |
| Firebase Storage | Optional raw-audio retention          |
| Deepgram      | Speech-to-text transcription             |
| Together AI   | Llama 3.3 inference for JSON structuring |
| RevenueCat    | Subscription management                  |

## Configuration

Each integration is configured via environment variables / build secrets — never committed.

```
FIREBASE_PROJECT_ID=...
FIREBASE_API_KEY=...
DEEPGRAM_API_KEY=...
TOGETHER_API_KEY=...
TOGETHER_MODEL=meta-llama/Llama-3.3-70B-Instruct-Turbo
REVENUECAT_API_KEY=...
```

API keys for Deepgram and Together AI must not ship in the client binary. They should be proxied through a Firebase Cloud Function (or equivalent backend) so requests are authenticated by the user's Firebase ID token before being forwarded to the upstream service.

## Privacy

- Audio is processed for transcription only; raw audio retention is opt-in.
- All user data lives under `users/{uid}` and is readable only by that user.
- Sign-out clears local caches; account deletion removes the user's Firestore subtree and Storage prefix.
