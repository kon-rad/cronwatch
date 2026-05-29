# Cronwatch — Android (Kotlin / Jetpack Compose)

Native Android port of the React Native client at `../client`. Mirrors the
current RN app exactly: four tabs (Overview, Today, List, Profile), the
fire-and-forget voice capture pipeline, the `/capture` and `/structure`
proxy endpoints, Firebase Auth + Firestore + Storage, and RevenueCat
subscriptions.

See [`SPEC.md`](./SPEC.md) for the file-by-file contract that this port
follows.

## Stack

- Kotlin 2.1 + JDK 17 + Gradle 8.10
- Jetpack Compose + Material 3 (visual style overrides M3 defaults)
- minSdk 26, targetSdk 35
- Hilt for DI
- Firebase Android SDK (Auth, Firestore, Storage)
- AndroidX CredentialManager for Google Sign-In (no Apple sign-in on Android)
- WorkManager + JSON file persistence for the capture queue (survives app kill)
- MediaRecorder for capture, Media3 ExoPlayer for playback
- kotlinx.serialization for JSON, plain `HttpURLConnection` for the proxy calls

## Quick start

```bash
cd android
cp .env.example local.properties   # then fill values, or leave blank for stub mode
./gradlew :app:installDebug
```

If `local.properties` keys are missing or blank, the corresponding subsystem
runs in stub mode and the app stays usable without any backend setup. The
canned user signs in as Emma Mori at `emma@cronwatch.app`.

If you have not yet generated the Gradle wrapper jar, run once on a host
with Gradle 8.10+ installed:

```bash
gradle wrapper --gradle-version 8.10.2
```

This writes `gradle/wrapper/gradle-wrapper.jar`. The wrapper properties
file is already committed.

## Configuration

Cronwatch reads everything from `BuildConfig`, populated by `local.properties`
or environment variables at build time:

| Key | Used by |
|---|---|
| `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET` | Firebase Auth + Firestore + Storage |
| `GOOGLE_WEB_CLIENT_ID` | CredentialManager (must be a *Web* OAuth client tied to the Firebase project) |
| `CAPTURE_PROXY_URL` | `/capture` (multipart) and `/structure` (JSON) endpoints; same server the RN client targets |
| `REVENUECAT_API_KEY_ANDROID` | RevenueCat |

You can also drop a real `google-services.json` into `app/`; the build
script auto-applies the `google-services` plugin if it's present.

## Project layout

```
android/
├── SPEC.md                  Port spec (file-by-file RN → Kotlin map)
├── README.md
├── .env.example
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/
│   ├── libs.versions.toml
│   └── wrapper/gradle-wrapper.properties
└── app/
    ├── build.gradle.kts
    ├── proguard-rules.pro
    └── src/main/
        ├── AndroidManifest.xml
        ├── res/                   colors, themes, mipmaps, raw/categories.json
        └── java/app/cronwatch/
            ├── CronwatchApp.kt    @HiltAndroidApp; configures Firebase, auth listener, RevenueCat, captureQueue hydrate
            ├── MainActivity.kt    Single Compose host
            ├── AppEnvironment.kt  Reads BuildConfig with stub-mode fallback
            ├── di/                Hilt modules (mostly empty; constructor injection)
            ├── nav/CronwatchNav.kt
            ├── model/             AppUser, Entry, Capture, CapturedEntryDraft, Subscription
            ├── theme/             Palette, Spacing, Typography, Categories, CronwatchTheme
            ├── util/              TimeUtils, DurationUtils, ListDateUtils
            ├── service/           Firebase, Auth, Entries, AudioRecorder, Capture, CaptureQueue + Worker, RevenueCat, ToastBus
            └── ui/
                ├── root/RootScreen.kt
                ├── auth/SignInScreen.kt
                ├── tabs/          MainTabs + Overview + Today + TodayGrid + List + Profile
                ├── capture/CaptureSheet.kt
                ├── entry/         EntryViewSheet, EntryEditSheet
                ├── paywall/PaywallSheet.kt
                └── common/        CategoryDot, Donut, FloatingMicButton, Waveform, Toast, CaptureRow, DraftBanner
```

## Auth

Google Sign-In through AndroidX CredentialManager, exchanging the Google
ID token for a Firebase OAuth credential. Make sure the
`GOOGLE_WEB_CLIENT_ID` is a Web client (not Android client) in the same
Google Cloud project that Firebase is using, and that "Sign in with Google"
is enabled in the Firebase Console.

Apple sign-in is intentionally omitted on Android.

## Capture pipeline

1. `CaptureSheet`'s record button starts `AudioRecorder` (MediaRecorder, m4a/AAC) on press-down and stops on release.
2. The audio file is copied to `filesDir/captures/` and a `CaptureJob` is appended to a JSON queue at `filesDir/capture-queue.json`.
3. `CaptureQueue` schedules a `OneTimeWorkRequest` (unique, `APPEND_OR_REPLACE`) running `CaptureWorker`.
4. The worker drains the queue: for each job, POST `multipart/form-data` to `<CAPTURE_PROXY_URL>/capture` with a Bearer ID token. The response is `{ transcript, audioUrl, audioKey, drafts[] }`.
5. Each draft becomes one Firestore document under `users/{uid}/entries`, batched, with a shared `captureId`.
6. On failure, the job stays in the queue as `error` and surfaces in `DraftBanner` on the List tab.

The text path POSTs to `<CAPTURE_PROXY_URL>/structure` and creates entries
inline (no queue, no audio).

## Stub mode

Mirrors the RN client. Active per-subsystem when its env vars are missing.

- Auth: 250 ms sleep then signs in as `AppUser(uid="stub-user", email="emma@cronwatch.app", displayName="Emma Mori")`.
- Entries: in-memory list, `subscribeToday` emits on every mutation, `subscribeFirstPage` returns sorted descending.
- Capture: 600 ms sleep, returns a canned transcript + one draft.
- RevenueCat: returns `free`.

## Known caveats

- Inter font is not bundled; the system default is used (same trade-off as `ios-swift/`).
- The "This week · daily average" bars on Overview render as zeros pending a weekly aggregate query — match the RN client.
- Purchase flow on the paywall is non-functional in this build; it shows a toast and dismisses. Wire RevenueCat `purchase()` with a real `StoreProduct` to enable.
