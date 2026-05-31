---
name: cronwatch
description: Read the user's Cronwatch time-tracking data — time entries and weekly goals — via the Cronwatch HTTP API. Use when the user asks about how they spent their time, their habits, schedule, focus, productivity, or weekly goal progress.
---

# Cronwatch API

Cronwatch is a voice-first time tracker. Each entry is a structured block of
time with a category, a short note, and a start/end timestamp. This skill lets
you read the user's entries and weekly goals over HTTPS with their API key.

Access is **read-only**. You cannot create, edit, or delete data.

## Authentication

Every request must send the user's secret key in the `X-Api-Key` header. Keys
begin with `cw_`.

```
X-Api-Key: cw_your_key_here
```

The user creates a key in the iOS app: **Profile → API Keys → +**. It is shown
once. An active subscription is required to create keys.

**Handling the key safely:**
- Read it from the `CRONWATCH_API_KEY` environment variable when available.
- Never print, log, echo, or paste the key into chat, code, or commits.
- If no key is configured, ask the user to create one and set
  `CRONWATCH_API_KEY` — do not guess.

## Base URL

```
https://api.cronwatch.xyz
```

## Endpoints

### GET /v1/entries — list time entries

Returns entries that overlap a date window, ordered by start time ascending.

Query parameters (all optional):

| Param   | Type      | Default     | Notes                                  |
|---------|-----------|-------------|----------------------------------------|
| `from`  | ISO 8601  | 7 days ago  | Lower bound on each entry's start time. |
| `to`    | ISO 8601  | now         | Upper bound on each entry's start time. |
| `limit` | integer   | 200         | 1–500. Max entries returned.            |

`from` must be strictly before `to`. Entries that start just before `from` but
end inside the window (e.g. overnight sleep) are included.

```bash
curl https://api.cronwatch.xyz/v1/entries \
  -H "X-Api-Key: $CRONWATCH_API_KEY" \
  -G \
  --data-urlencode "from=2026-01-01T00:00:00Z" \
  --data-urlencode "to=2026-01-31T23:59:59Z" \
  --data-urlencode "limit=500"
```

Response:

```json
{
  "entries": [
    {
      "id": "c_1737014400000_a1b2c3",
      "captureId": "c_1737014400000_a1b2c3",
      "category": "work",
      "note": "API architecture review",
      "startTime": "2026-01-16T09:00:00.000Z",
      "endTime":   "2026-01-16T10:30:00.000Z",
      "source": "voice",
      "transcript": "Spent ninety minutes on the API architecture…",
      "createdAt": "2026-01-16T10:31:22.000Z"
    }
  ],
  "count": 1
}
```

Entry fields:

| Field        | Type            | Description                                    |
|--------------|-----------------|------------------------------------------------|
| `id`         | string          | Unique entry identifier.                       |
| `captureId`  | string          | Voice capture this entry came from.            |
| `category`   | string          | Activity category, e.g. `work`, `admin`, `rest`. |
| `note`       | string          | Short summary of the block.                    |
| `startTime`  | ISO 8601 (UTC)  | When the block started.                        |
| `endTime`    | ISO 8601 (UTC)  | When the block ended.                          |
| `source`     | string          | How it was created, e.g. `voice`.              |
| `transcript` | string \| null  | Original voice transcript, when available.     |
| `createdAt`  | ISO 8601 (UTC)  | When the entry was recorded.                   |

Duration of an entry = `endTime − startTime`.

### GET /v1/me — profile and weekly goals

```bash
curl https://api.cronwatch.xyz/v1/me \
  -H "X-Api-Key: $CRONWATCH_API_KEY"
```

Response:

```json
{
  "uid": "8f2c…",
  "goals": [
    { "category": "work", "weeklyTargetHours": 20 },
    { "category": "rest", "weeklyTargetHours": 14 }
  ]
}
```

Use `/v1/me` to compare actual time logged (from `/v1/entries`) against the
user's weekly targets per category.

## Errors

Errors return a non-2xx status and a body of `{ "error": "message" }`.

| Status | Meaning                                                        |
|--------|---------------------------------------------------------------|
| 400    | Invalid `from`/`to`, or `from` is not before `to`.            |
| 401    | Missing, malformed, or unknown API key.                       |
| 500    | Server-side error — retry.                                     |

## Working with the data

- All times are UTC. Convert to the user's local timezone before summarizing
  their day or week.
- For "this week" / "last month" questions, compute the window yourself and
  pass it as `from`/`to`.
- To total time by category, sum each entry's `endTime − startTime` grouped by
  `category`.
- For long ranges, page by requesting successive windows (`limit` caps each
  response at 500).
- Don't fabricate entries. If the window is empty, say so.
