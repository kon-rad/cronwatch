# CronWatch — Free Speech-to-Text Strategy (Replacing Deepgram)

_Last updated: 2026-06-06. Research-backed, codebase-specific. Sources cited inline._

**Goal:** drive transcription cost from Deepgram's ~$0.26–0.46/hr to **~$0** by moving speech-to-text **on-device**, keeping only the LLM-structuring step on the server. This is the industry-standard move in 2025–26, and it's exactly what our two closest direct competitors already do.

---

## TL;DR

- **Move STT on-device, per platform.** iOS 26+ → Apple **`SpeechAnalyzer`/`SpeechTranscriber`** (free, on-device, no time limit, faster than Whisper, accuracy ≥ Whisper for conversational English). iOS 16–25 → **`SFSpeechRecognizer`** with `requiresOnDeviceRecognition = true` (free; the legacy 1-min limit is irrelevant for our 5–20s clips). Android → **`SpeechRecognizer`** with `EXTRA_PREFER_OFFLINE` (free).
- **Change the server contract:** add a `/capture-text` endpoint that takes the **transcript string** (not audio) and runs the existing Together LLM step. Keep the audio `/capture` endpoint alive but repoint its fallback away from Deepgram.
- **Keep a cheap cloud fallback** for old OS / failures: **Cloudflare Workers AI** ($0.00051/min, free daily tier) or **Groq whisper-large-v3-turbo** ($0.04/hr), or **self-hosted whisper.cpp** on the existing DigitalOcean droplet ($0 marginal). All are 85–93% cheaper than Deepgram even when used.
- **Net effect:** ~$0 for the overwhelming majority of utterances; a sub-penny-per-hour tail; privacy story upgraded ("on-device, your words never leave your phone") which reinforces the open-source/privacy positioning.

---

## 1. How transcription works today

**Pipeline:** record audio (m4a/AAC) → upload to server → **Deepgram** transcribes → **Together (Llama-3.3-70B)** structures text into time entries → return drafts to client.

| Stage | Location | Detail |
|---|---|---|
| iOS record | `ios-swift/Cronwatch/Services/AudioRecorder.swift:29` | `AVAudioRecorder`, `kAudioFormatMPEG4AAC`, 44.1 kHz, mono, `.medium` |
| Android record | `android/.../service/AudioRecorder.kt:23` | `MediaRecorder`, MPEG-4/AAC, 96 kbps, 44.1 kHz |
| iOS upload | `ios-swift/Cronwatch/Services/CaptureService.swift:34` | multipart POST → `/capture` with `audio`, `now`, `tz`; Firebase token auth |
| Android upload | `android/.../service/CaptureService.kt:52` | multipart POST → `/capture` |
| Server endpoint | `server/src/index.ts:31` | `POST /capture`, multer in-memory, 25 MB limit |
| **Deepgram call** | `server/src/deepgram.ts:6` | `deepgram.listen.v1.media.transcribeFile()`, model `nova-3`, `language:'en'`, `punctuate:true`, `smart_format:true` |
| LLM structuring | `server/src/together.ts:128` | Llama-3.3-70B-Instruct-Turbo, temp 0.1, JSON output → validated entries |
| Config | `server/.env.example:16` | `DEEPGRAM_API_KEY`, `DEEPGRAM_MODEL=nova-3` |

**Key facts that make on-device easy here:**
- It's **100% server-side today** — no on-device STT exists yet, so this is additive.
- Utterances are **short (5–20s; min 0.5s enforced** at `CaptureView.swift:11`). Short clips dodge every limitation of the legacy Apple framework.
- English-only (`language:'en'`), simple parsing — no diarization, no exotic vocabulary. This is the "private capture" bucket, not the "AI-rewrite" bucket, so on-device is the natural fit.
- The valuable server step is the **LLM**, not transcription. We keep that.

---

## 2. Options analysis

### A. Apple on-device (iOS) — **the recommended primary path**

**iOS 26+ — `SpeechAnalyzer` + `SpeechTranscriber`** (the engine behind Notes/Voice Memos live transcription):
- Free, fully on-device, **no time limit**, ~55% faster than MacWhisper Large v3 Turbo, **~3–5% WER on clean English** (≥ Whisper for conversational speech).
- **Zero app-size cost** — models live in a system asset catalog (request via `AssetInventory.assetInstallationRequest`), not your bundle.
- ~40 locales incl. all major English variants. Async/`AsyncSequence` API; convert mic `AVAudioPCMBuffer` to `analyzer.bestAvailableAudioFormat` via `AVAudioConverter`, read results when `isFinal`.
- Caveat: **iOS 26-only**, not backward compatible. ([Apple docs](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app), [WWDC25 277](https://developer.apple.com/videos/play/wwdc2025/277/), [MacRumors](https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/))

**iOS 16–25 — `SFSpeechRecognizer`** with `requiresOnDeviceRecognition = true`:
- Free, on-device (honored only when `supportsOnDeviceRecognition == true`). ~9–10 on-device languages incl. English.
- The infamous **~1-minute session cap and 1,000 req/device/hr** limits **do not affect us** — clips are 5–20s. ([Apple SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer), [Picovoice 2026](https://picovoice.ai/blog/ios-speech-recognition/))

### B. Android on-device — `SpeechRecognizer` + `EXTRA_PREFER_OFFLINE`
- Free; needs the offline language pack installed (user-managed). Accuracy/coverage vary by OEM/Google-app version — less consistent than iOS but fine for English.
- Newer **ML Kit GenAI / Gemini Nano** (Pixel-class devices) is higher accuracy, system-managed ~1 GB model, rolling out. Use where available, else `EXTRA_PREFER_OFFLINE`, else cloud fallback. ([ML Kit GenAI](https://developers.google.com/ml-kit/genai/speech-recognition/android), [Gemini Nano](https://developer.android.com/ai/gemini-nano))

### C. WhisperKit (Argmax) — on-device Whisper for iOS, the high-accuracy fallback
- Swift/Core ML, runs on the Neural Engine, MIT-licensed, free. Models: tiny (~75 MB, 15–20% WER) → small (~500 MB, ~10%) → large-v3-turbo (~1.6 GB, ~8% mixed; Argmax reports ~2.2% optimized).
- Cost is **app size** (bundle tiny, lazy-download larger). Use only if you must support iOS <26 with higher accuracy or a language `SpeechAnalyzer` lacks. Otherwise SpeechAnalyzer wins on size/speed/maintenance. ([Argmax](https://www.argmaxinc.com/blog/whisperkit), [WhisperKit repo](https://github.com/argmaxinc/WhisperKit))

### D. Cheap cloud Whisper — the server-side fallback for old OS / failures

| Provider | Model | $/min | $/hr | Notes |
|---|---|---|---|---|
| **Cloudflare Workers AI** | whisper-large-v3-turbo | **$0.00051** | ~$0.031 | 10k free Neurons/day; edge |
| **Groq** | whisper-large-v3-turbo | ~$0.00067 | **$0.04** | 160–220× real-time; 10s min billing |
| Fireworks | Whisper-v3 | $0.0009–0.0015 | $0.054–0.09 | fast |
| Together (already integrated!) | Whisper-large-v3 | $0.0015 | $0.09 | same vendor as our LLM |
| OpenAI | whisper-1 | $0.006 | $0.36 | priciest |
| **Self-host whisper.cpp** | small/base | **~$0** | droplet only | CPU ≈1× real-time; needs ≥4 GB RAM |

([Cloudflare pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/), [Groq](https://groq.com/pricing), [Together STT](https://www.together.ai/blog/speech-to-text-whisper-apis), [whisper.cpp](https://github.com/ggml-org/whisper.cpp))

> Note: we **already use Together AI** for the LLM — adding Together Whisper as the fallback is the lowest-integration option ($0.09/hr, one vendor, one key). Cloudflare/Groq are cheaper; self-hosting is free but adds ops/latency.

### E. Deepgram (current baseline)
- Nova-3 batch **$0.258/hr**, streaming **$0.462/hr**. ([Deepgram pricing](https://deepgram.com/pricing))

**Ranking:** (1) iOS 26 SpeechAnalyzer → (2) iOS SFSpeechRecognizer on-device / Android offline → (3) WhisperKit for hard cases → (4) cheap cloud fallback (Together/Cloudflare/self-host) → (5) drop Deepgram as default.

---

## 3. What competitors do (validation)

Going on-device is the **standard move**, confirmed at our two closest rivals:

- **Time Aware – Voice Time Track** — App Store: _"On-device speech recognition means your words never leave your phone," "100% PRIVATE, 100% OFFLINE," "No accounts. No cloud sync."_ Free. (On-device confirmed; Apple-framework attribution is a strong inference — there's no other free, fully-offline path on iOS.) ([listing](https://apps.apple.com/il/app/time-aware-voice-time-track/id6757989946))
- **Speak To Track** — explicitly: _"Speech-to-text runs on-device using Apple's Speech framework… Parsing runs on-device via Apple's Foundation Models. 0 outbound requests."_ iOS 26 + iPhone 15 Pro. ([site](https://speaktotrackapp.com/))
- **Day One** — Apple speech API; on iOS 26 fully on-device, Apple-server fallback on older OS. The exact tiered model we should copy. ([Day One](https://dayoneapp.com/guides/tips-and-tutorials/audio-recording/))
- **Superwhisper** — local Whisper models, offline.

**Who stays cloud, and why** (the "AI-rewrite" bucket — Wispr Flow, AudioPen, Otter, Letterly, and cross-platform expense trackers Peggy/MonAi): their product is the **LLM polish/categorization across platforms**, so they keep one cloud codepath. Legit reasons to keep cloud STT: **Android parity, 99-language coverage, >98% accuracy/diarization, an existing server LLM pipeline, model reproducibility.** None of these strongly apply to an English-first, short-utterance iOS time-tracker — which is why the two pure time-trackers went on-device. ([Forasoft 2026 playbook](https://www.forasoft.com/blog/article/speech-recognition-with-neural-networks-on-ios-1621), [Picovoice](https://picovoice.ai/blog/ios-speech-recognition/))

**One mitigation note:** our parsing LLM (Together/Llama) currently lives server-side. We can keep it server-side and just feed it on-device transcript text — we do **not** need Apple Foundation Models, so we are **not** gated to iPhone 15 Pro the way Speak To Track is. On-device STT works back to iOS 16; only the *modern* SpeechAnalyzer path needs iOS 26.

---

## 4. Cost impact

Assume an active user does ~30 captures/day × ~12s ≈ 6 min/day ≈ 3 hr/month.

| Scenario | $/user/month | At 1,000 active users |
|---|---|---|
| **Deepgram nova-3 batch** (today) | ~$0.77 | ~$774/mo |
| Together Whisper fallback (all traffic) | ~$0.27 | ~$270/mo |
| Cloudflare/Groq (all traffic) | ~$0.09–0.12 | ~$90–120/mo |
| **On-device (target: ~95% of traffic)** + cheap cloud tail | **~$0.005–0.01** | **~$5–12/mo** |

On-device eliminates ~95%+ of transcription cost and turns a per-minute variable cost into roughly zero. (Rates: [Deepgram](https://deepgram.com/pricing), [Cloudflare](https://developers.cloudflare.com/workers-ai/platform/pricing/), [Groq](https://groq.com/pricing).)

---

## 5. Migration plan

### Design principle
Keep the LLM-structuring server step unchanged; change only **where transcription happens** and **what the client sends**. Audio stops leaving the device on the happy path.

### Server (smallest change, do first — unblocks both platforms)

1. **Add `POST /capture-text`** in `server/src/index.ts` (mirror `/capture` at `:31`) that accepts JSON `{ transcript, now, tz }`, skips Deepgram, and calls the existing `structureTranscript()` in `server/src/together.ts:128`. Reuse the same auth + response shape so clients change minimally.
2. **Refactor** so `/capture` (audio) and `/capture-text` share the post-transcription path (extract the Together call + validation into one function).
3. **Repoint the audio fallback** in `server/src/deepgram.ts`: introduce a `TRANSCRIBE_PROVIDER` env (`deepgram | together | cloudflare | groq | whispercpp`). Implement a Together-Whisper transcriber first (same vendor/key already present), keep Deepgram behind the flag as an emergency backstop. This makes `/capture` cheap even when used.
4. Keep the 25 MB multer limit and m4a handling as-is for the fallback path.

### iOS (the bulk of traffic)

5. **Add an on-device transcriber service** (e.g. `Services/SpeechTranscriber.swift`):
   - iOS 26+: `SpeechAnalyzer` + `SpeechTranscriber` (asset install check + `AVAudioConverter` to `bestAvailableAudioFormat`).
   - iOS 16–25: `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`.
   - Add `NSSpeechRecognitionUsageDescription` to Info.plist (mic permission already present).
6. **Wire into capture flow** (`CaptureView.swift:330` `onPressOut` / the queue at `:350`): after recording stops, transcribe the file (or transcribe live from buffers for instant UX), then call a new `CaptureService` method that POSTs **text** to `/capture-text` instead of audio to `/capture` (`CaptureService.swift:34`).
   - Option (better UX): stream transcription live during the hold so the transcript is ready the instant the user releases.
7. **Fallback:** if on-device transcription is unavailable (older device, permission denied, empty result), fall back to the existing audio upload to `/capture` (now backed by cheap cloud STT). Keep the recorded m4a until success so fallback is lossless.
8. **Privacy copy win:** surface "transcribed on your device" in the UI — reinforces the positioning doc's trust angle.

### Android

9. Mirror with `SpeechRecognizer` + `EXTRA_PREFER_OFFLINE` (and ML Kit GenAI where available). On result, POST text to `/capture-text` via `CaptureService.kt:52`; fall back to audio `/capture` when offline recognition is unavailable.

### Rollout & validation

10. **Ship server first**, then iOS behind a feature flag; A/B the on-device transcript quality vs Deepgram on a sample (the validation entries in `together.ts` already normalize categories, so compare structured-entry accuracy, not just raw WER).
11. **Quantify the iOS-version split** — determines how much traffic hits SpeechAnalyzer (iOS 26) vs SFSpeechRecognizer (16–25) vs cloud fallback. This is the one number to confirm before committing.
12. Once on-device is proven, **set `TRANSCRIBE_PROVIDER` away from Deepgram** and keep the Deepgram key only as a backstop. Cancel/scale down Deepgram once cloud-fallback volume is confirmed low.

### Effort estimate
- Server `/capture-text` + provider flag: **~0.5–1 day**.
- iOS on-device service + wiring + fallback: **~2–3 days** (SpeechAnalyzer + SFSpeechRecognizer dual path).
- Android: **~1–2 days**.
- Cheap-cloud fallback (Together Whisper): **~0.5 day** (key already present).

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| SpeechAnalyzer is iOS 26-only | Dual path: SFSpeechRecognizer on-device for iOS 16–25; cloud fallback below that |
| On-device WER worse on accents/noise | Cheap cloud fallback for low-confidence results; optionally bundle WhisperKit later |
| Apple may change SpeechAnalyzer model across OS updates | Acceptable for our simple parsing; cloud fallback pins quality if ever needed |
| Android offline packs inconsistent across OEMs | `EXTRA_PREFER_OFFLINE` → cloud fallback when unavailable |
| Losing Deepgram's punctuation/smart-format | The Together LLM step already normalizes/structures raw text — punctuation matters little downstream |
| Non-English users | Keep cloud fallback for unsupported on-device locales |

---

### Source index
On-device iOS: [Apple SpeechAnalyzer](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app) · [WWDC25 277](https://developer.apple.com/videos/play/wwdc2025/277/) · [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer) · [Picovoice iOS 2026](https://picovoice.ai/blog/ios-speech-recognition/) · [MacRumors faster-than-Whisper](https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/)
Android: [ML Kit GenAI](https://developers.google.com/ml-kit/genai/speech-recognition/android) · [Gemini Nano](https://developer.android.com/ai/gemini-nano)
Whisper on-device: [Argmax WhisperKit](https://www.argmaxinc.com/blog/whisperkit) · [WhisperKit repo](https://github.com/argmaxinc/WhisperKit) · [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
Cloud cost: [Deepgram](https://deepgram.com/pricing) · [Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai/platform/pricing/) · [Groq](https://groq.com/pricing) · [Together STT](https://www.together.ai/blog/speech-to-text-whisper-apis)
Competitors: [Time Aware](https://apps.apple.com/il/app/time-aware-voice-time-track/id6757989946) · [Speak To Track](https://speaktotrackapp.com/) · [Day One](https://dayoneapp.com/guides/tips-and-tutorials/audio-recording/) · [Forasoft playbook](https://www.forasoft.com/blog/article/speech-recognition-with-neural-networks-on-ios-1621)
