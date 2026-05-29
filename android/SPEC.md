# Cronwatch Android — Port Spec

Native Kotlin/Jetpack Compose port of the React Native client at `../client`.
Source of truth for behavior is the **RN client** (not the older `../ios-swift/SPEC.md`),
because the RN app has evolved past that snapshot (List tab, fire-and-forget
capture queue, view-only entry route, single `/capture` proxy endpoint).

## Stack

- Kotlin 2.0+, JDK 17
- minSdk 26, targetSdk 35, compileSdk 35
- Jetpack Compose + Material 3 (base only; visual style overrides M3)
- Hilt for DI
- Coroutines + StateFlow
- Firebase Android: Auth + Firestore + Storage
- AndroidX CredentialManager (Google Sign-In)
- RevenueCat Android SDK
- Media3 ExoPlayer for audio playback, MediaRecorder for capture
- WorkManager + DataStore for the persistent capture queue
- Gradle Kotlin DSL + version catalog

## Package

`app.cronwatch` (top-level Kotlin package)
Application id `com.konradgnat.cronwatch.android`

## File map (RN → Kotlin)

| RN file | Kotlin file |
|---|---|
| `client/theme/tokens.ts` | `theme/Palette.kt`, `theme/Spacing.kt` |
| `client/theme/typography.ts` | `theme/Typography.kt` |
| `client/theme/categories.ts` | `theme/Categories.kt` |
| `client/types/entry.ts` | `model/Entry.kt` |
| `client/types/user.ts` | `model/AppUser.kt` |
| `client/types/subscription.ts` | `model/Subscription.kt` |
| `client/types/capture.ts` | folded into `model/Entry.kt` (`CapturedEntryDraft`) |
| `client/utils/time.ts` | `util/TimeUtils.kt` |
| `client/utils/duration.ts` | `util/DurationUtils.kt` |
| `client/utils/listDate.ts` | `util/ListDateUtils.kt` |
| `client/services/firebase.ts` | `service/FirebaseBootstrap.kt` |
| `client/services/auth.ts` | `service/AuthService.kt` |
| `client/services/entries.ts` | `service/EntriesService.kt` |
| `client/services/capture.ts` | `service/CaptureService.kt` + `service/AudioRecorder.kt` |
| `client/services/captureQueue.ts` | `service/CaptureQueue.kt` + `service/CaptureWorker.kt` |
| `client/services/revenuecat.ts` | `service/RevenueCatService.kt` |
| `client/services/toast.tsx` | `service/ToastBus.kt` + `ui/common/Toast.kt` |
| `client/components/Donut.tsx` | `ui/common/Donut.kt` |
| `client/components/CategoryDot.tsx` | `ui/common/CategoryDot.kt` |
| `client/components/TodayGrid.tsx` | `ui/tabs/TodayGrid.kt` |
| `client/components/CaptureRow.tsx` | `ui/common/CaptureRow.kt` |
| `client/components/DraftBanner.tsx` | `ui/common/DraftBanner.kt` |
| `client/components/Toast.tsx` | `ui/common/Toast.kt` |
| `client/app/_layout.tsx` | `CronwatchApp.kt` + `MainActivity.kt` + `nav/CronwatchNav.kt` |
| `client/app/(auth)/sign-in.tsx` | `ui/auth/SignInScreen.kt` |
| `client/app/(tabs)/_layout.tsx` | `ui/tabs/MainTabsScreen.kt` + `ui/common/FloatingMicButton.kt` |
| `client/app/(tabs)/today.tsx` | `ui/tabs/TodayScreen.kt` |
| `client/app/(tabs)/list.tsx` | `ui/tabs/ListScreen.kt` |
| `client/app/(tabs)/overview.tsx` | `ui/tabs/OverviewScreen.kt` |
| `client/app/(tabs)/profile.tsx` | `ui/tabs/ProfileScreen.kt` |
| `client/app/capture.tsx` | `ui/capture/CaptureSheet.kt` |
| `client/app/entry/[id].tsx` | `ui/entry/EntryEditSheet.kt` |
| `client/app/entry/view/[id].tsx` | `ui/entry/EntryViewSheet.kt` |
| `client/app/paywall.tsx` | `ui/paywall/PaywallSheet.kt` |

## Palette (`theme/Palette.kt`)

| Token | Hex |
|---|---|
| bg | #FAFAF7 |
| ink | #111111 |
| muted | #5C5C58 |
| border | #ECECEA |
| borderSoft | #F2F2EF |
| amber | #E8A33D |
| amberSoft | #FBEFD8 |
| white | #FFFFFF |
| danger | #C8412C |

Radii: sm 8, md 12, lg 16, fab 28, pill 999.
Spacing: xs 4, sm 8, md 16, lg 24, xl 32.

## Auth

Google only via AndroidX CredentialManager → Firebase OAuthCredential.
No Apple sign-in on Android.
In **stub mode** (no `google-services.json` / no Firebase project),
sign-in completes after a 250 ms sleep and emits the canned user:
`AppUser(uid="stub-user", email="emma@cronwatch.app", displayName="Emma Mori", photoURL=null)`.

## Capture pipeline

Fire-and-forget. On record-release the modal closes immediately; a
`CaptureWorker` job is enqueued via WorkManager (audio copied to internal
files dir first). The worker POSTs `multipart/form-data` to
`<CAPTURE_PROXY_URL>/capture` (Bearer ID token), receives
`{transcript, audioUrl, audioKey, drafts[]}`, then atomically writes one
Firestore entry per draft under `users/{uid}/entries` sharing a single
`captureId`.

Text path: POST JSON to `<CAPTURE_PROXY_URL>/structure`, receive `{drafts[]}`,
create entries with `source: "text"`.

Errors keep the job in the queue tagged `error`; surfaced via `DraftBanner`
on the List tab.

## Environment

Read at startup from `BuildConfig` (populated from `local.properties` or
CI env). Missing values cause services to fall back to stub mode.

```
FIREBASE_PROJECT_ID
FIREBASE_API_KEY
FIREBASE_APP_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_STORAGE_BUCKET
GOOGLE_WEB_CLIENT_ID            # for CredentialManager / Firebase
CAPTURE_PROXY_URL
REVENUECAT_API_KEY_ANDROID
```

## Conventions

- One file per top-level Composable / class.
- Services are `@Singleton` Hilt-provided objects; UI receives them via
  hiltViewModel() ViewModels.
- Stub mode keeps in-memory state per-app-process; mirrors RN behavior.
- Firestore boundary uses `Timestamp`; everything in-app is `Instant`/`Date`.
- No comments except for non-obvious "why".
- No `m.` or `M_` prefixes; use Kotlin idiomatic names.
