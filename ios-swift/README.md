# Cronwatch (iOS, native SwiftUI)

**📲 Now live on the App Store: [Download Cronwatch](https://apps.apple.com/us/app/cronwatch/id6767232025)**

A native SwiftUI port of the React Native / Expo client at [`../client`](../client). Same product, same design language, same Firestore data model — just rewritten as a pure Swift app for iOS.

Voice-first time tracking: tap the mic, say what you did, see your day on a 15-minute grid.

## Requirements

- macOS with Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Setup

1. Copy the example env file:

   ```sh
   cp .env.example .env
   ```

2. Fill in any keys you have. Empty values are fine — the app falls back to **stub mode** for any missing service (see below).

3. Source the env and generate the Xcode project:

   ```sh
   set -a && source .env && set +a
   xcodegen generate
   ```

   `xcodegen` substitutes the `$(VAR)` placeholders in `project.yml` into the generated `Info.plist`. `AppEnvironment` reads them back from the bundle at runtime, falling back to `ProcessInfo.processInfo.environment` for development.

4. Open the generated project:

   ```sh
   open Cronwatch.xcodeproj
   ```

5. Build and run (`Cmd+R`).

## Stub mode

The app is fully runnable without any keys. When the relevant env var is missing, services route to in-memory stubs that mirror the RN client's behavior:

- **Auth**: Apple/Google sign-in resolves to a fixed user — `Emma Mori` (`emma@cronwatch.app`, uid `stub-user`) — after a short fake delay.
- **Entries**: held in an in-memory array for the session only. `subscribeToToday` emits on every mutation. Nothing persists across launches.
- **Capture**: `transcribe` returns a canned transcript ("deep work on the auth refactor from 9 to 10:30") after ~600 ms; `structure` returns a `CapturedEntryDraft` after ~500 ms.
- **RevenueCat**: entitlement is always `.free`.

Add real keys to `.env`, re-run `xcodegen generate`, and the same code paths switch to live Firebase / Deepgram-via-proxy / Together-via-proxy / RevenueCat.

## RN → Swift mapping

Concise overview — see [`SPEC.md`](SPEC.md) for the full contract.

| RN file (`../client/...`)              | Swift file (`Cronwatch/...`)                |
|----------------------------------------|---------------------------------------------|
| `app/_layout.tsx`                      | `CronwatchApp.swift`, `Views/RootView.swift` |
| `app/sign-in.tsx`                      | `Views/Auth/SignInView.swift`               |
| `app/(tabs)/_layout.tsx`               | `Views/Tabs/MainTabView.swift`              |
| `app/(tabs)/today.tsx`                 | `Views/Tabs/TodayView.swift`                |
| `app/(tabs)/overview.tsx`              | `Views/Tabs/OverviewView.swift`             |
| `app/(tabs)/profile.tsx`               | `Views/Tabs/ProfileView.swift`              |
| `app/capture.tsx`                      | `Views/Capture/CaptureView.swift`           |
| `app/entry/[id].tsx`                   | `Views/Entry/EntryEditView.swift`           |
| `app/paywall.tsx`                      | `Views/Paywall/PaywallView.swift`           |
| `components/TodayGrid.tsx`             | `Views/Tabs/TodayGridView.swift`            |
| `components/Donut.tsx`                 | `Views/Common/DonutView.swift`              |
| `components/CategoryDot.tsx`           | `Views/Common/CategoryDotView.swift`        |
| `services/firebase.ts`                 | `Services/FirebaseBootstrap.swift`          |
| `services/auth.ts`                     | `Services/AuthService.swift`                |
| `services/entries.ts`                  | `Services/EntriesService.swift`             |
| `services/capture.ts`                  | `Services/CaptureService.swift` + `AudioRecorder.swift` |
| `services/revenuecat.ts`               | `Services/RevenueCatService.swift`          |
| `theme/tokens.ts`                      | `Theme/Colors.swift`, `Theme/Spacing.swift` |
| `theme/typography.ts`                  | `Theme/Typography.swift`                    |
| `theme/categories.ts`                  | `Theme/Categories.swift`                    |
| `utils/time.ts`                        | `Utils/TimeUtils.swift`                     |
| `types/entry.ts` / `user.ts` / etc.    | `Models/Entry.swift`, `Models/AppUser.swift`, `Models/Subscription.swift` |

## Caveats

- **Inter font is not bundled.** The RN app uses Inter; this port uses the system font (San Francisco). If you want Inter, add the `.ttf` files to `Cronwatch/Resources/Fonts/`, register them in `project.yml` under `info.properties.UIAppFonts`, and update `Theme/Typography.swift`.
- **Sign in with Apple** uses the native `SignInWithAppleButton` flow (nonce + SHA256). To actually persist the resulting credential as a Firestore-backed user, the **Apple provider must be enabled in the Firebase console** for your project. In stub mode (no Firebase keys) it skips that and just publishes the stub user.
- **Sign in with Google** requires `GOOGLE_IOS_CLIENT_ID` to be set. The `GoogleSignIn-iOS` SDK auto-registers a URL scheme equal to the *reversed* client ID (e.g. `com.googleusercontent.apps.387703217931-abc...`) — you do not need to add it to `Info.plist` manually as long as the client ID is provided via `AppEnvironment`. The SDK resolves the inbound URL via `GIDSignIn.sharedInstance.handle(url)` in `AppDelegate.application(_:open:options:)`.
- **Deepgram and Together AI keys MUST NOT ship in the binary.** Set `CAPTURE_PROXY_URL` to a Firebase Cloud Function (or equivalent) that authenticates incoming requests by Firebase ID token and forwards to the upstream services. The client only ever calls `<PROXY>/transcribe` and `<PROXY>/structure`.
- **Bundle ID** is `com.konradgnat.cronwatch`.
