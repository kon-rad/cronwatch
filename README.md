# Cronwatch

Voice-first time tracking. Tap the **+** button, say what you did, and Cronwatch turns it into a structured entry on a 15-minute grid for your day.

> Open source. MIT licensed.

## How it works

1. Tap the global **+** button from any view.
2. Speak (or type) what you're doing — e.g. *"deep work on the auth refactor from 9 to 10:30"*.
3. Cronwatch transcribes the audio with **Deepgram**, sends the text to **Together AI** (Llama 3.3) to structure it into JSON, and writes the entry to **Firestore**.
4. Your day appears as a table of 15-minute increments in the List view.

## Features

- **List view** — today as a 15-minute grid (96 rows), ordered chronologically, with bottom-tab navigation.
- **Profile view** — signed-in email, account, subscription status.
- **Global capture FAB** — always reachable; supports voice and text input.
- **Smart defaults** — if you don't say a time, the entry uses the moment of capture; if you do, it parses the range out of your speech.
- **Auth** — Sign in with Google (Gmail) or Apple, via Firebase Auth.
- **Subscriptions** — Weekly $4 or Yearly $40 (20% off), managed by RevenueCat.

## JSON contract

Every captured entry is normalized to:

```json
{
  "category":  "work",
  "note":      "auth refactor",
  "startTime": "2026-05-04T09:00:00Z",
  "endTime":   "2026-05-04T10:30:00Z"
}
```

If `startTime` / `endTime` aren't specified by the user, both default to the current capture time. All times are stored in UTC.

## Tech stack

| Layer        | Choice                                       |
|--------------|----------------------------------------------|
| Auth         | Firebase Auth (Google + Apple)               |
| Database     | Cloud Firestore                              |
| File storage | Firebase Storage (optional raw audio)        |
| Transcription| Deepgram                                     |
| LLM          | Together AI — Llama 3.3                      |
| Payments     | RevenueCat                                   |

See [`docs/architecture.md`](docs/architecture.md) for the full architecture, data model, and capture pipeline.

## Getting started

### Prerequisites

- A Firebase project with **Authentication**, **Firestore**, and **Storage** enabled.
- API keys for **Deepgram**, **Together AI**, and **RevenueCat**.
- The platform toolchain for the client (see the client subdirectory once added).

### Configuration

Cronwatch reads its secrets from environment variables. Copy `.env.example` to `.env` (or use your platform's secret manager) and fill in:

```
FIREBASE_PROJECT_ID=
FIREBASE_API_KEY=
DEEPGRAM_API_KEY=
TOGETHER_API_KEY=
TOGETHER_MODEL=meta-llama/Llama-3.3-70B-Instruct-Turbo
REVENUECAT_API_KEY=
```

> **Don't ship Deepgram or Together AI keys in the client binary.** Proxy those calls through a Firebase Cloud Function (or equivalent) authenticated by the user's Firebase ID token.

### Firestore data model

```
users/{uid}
  profile/             { email, displayName, createdAt }
  entries/{entryId}    { category, note, startTime, endTime, source, transcript, createdAt }
```

Security rules should restrict reads and writes to `request.auth.uid == uid`.

## Roadmap

- [ ] Editing entries inline from the 15-minute grid
- [ ] Week and month views
- [ ] Categories with colors and quick-pick chips
- [ ] CSV / Notion / Google Calendar export
- [ ] Local-first offline capture with sync

## Contributing

Issues and PRs are welcome. For non-trivial changes, open an issue first to discuss the approach.

1. Fork the repo and create a feature branch.
2. Make your change with tests where appropriate.
3. Open a PR describing the change and any tradeoffs.

## License

[MIT](LICENSE)
