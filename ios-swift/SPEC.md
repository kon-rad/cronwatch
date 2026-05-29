# Cronwatch iOS Native — Port Spec

This is a native SwiftUI port of the React Native/Expo client at
`../client`. Read this before writing any code, and follow the contracts
exactly — multiple agents are writing files in parallel and the names,
signatures, and folder layout MUST match.

Source RN app to mirror:
- `../client/app/` — screens (sign-in, today, overview, profile, capture, entry/[id], paywall)
- `../client/components/` — TodayGrid, Donut, CategoryDot
- `../client/services/` — auth, entries, capture, firebase, revenuecat
- `../client/theme/` — tokens, typography, categories
- `../client/utils/time.ts` — time helpers
- `../client/types/` — entry, user, capture, subscription
- `../docs/architecture.md`, `../docs/design-prompts.md`, `../README.md` — design language

## Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI
- **Min iOS:** 17.0
- **Project format:** XcodeGen (`project.yml`) generates the `.xcodeproj`.
- **Bundle ID:** `com.konradgnat.cronwatch`
- **Display name:** Cronwatch
- **Dependencies (SPM):**
  - `https://github.com/firebase/firebase-ios-sdk` (FirebaseAuth, FirebaseFirestore, FirebaseStorage)
  - `https://github.com/google/GoogleSignIn-iOS` (GoogleSignIn, GoogleSignInSwift)
  - `https://github.com/RevenueCat/purchases-ios` (RevenueCat)

## File tree

```
ios-swift/
├── README.md
├── .gitignore
├── .env.example
├── project.yml                      # XcodeGen
└── Cronwatch/
    ├── Info.plist
    ├── CronwatchApp.swift
    ├── AppEnvironment.swift
    ├── Models/
    │   ├── AppUser.swift
    │   ├── Entry.swift
    │   └── Subscription.swift
    ├── Theme/
    │   ├── Colors.swift
    │   ├── Spacing.swift
    │   ├── Typography.swift
    │   └── Categories.swift
    ├── Utils/
    │   └── TimeUtils.swift
    ├── Services/
    │   ├── FirebaseBootstrap.swift
    │   ├── AuthService.swift
    │   ├── EntriesService.swift
    │   ├── AudioRecorder.swift
    │   ├── CaptureService.swift
    │   └── RevenueCatService.swift
    ├── Resources/
    │   └── Assets.xcassets/
    │       ├── Contents.json
    │       ├── AppIcon.appiconset/Contents.json
    │       └── AccentColor.colorset/Contents.json
    └── Views/
        ├── RootView.swift
        ├── Auth/
        │   └── SignInView.swift
        ├── Tabs/
        │   ├── MainTabView.swift
        │   ├── TodayView.swift
        │   ├── TodayGridView.swift
        │   ├── OverviewView.swift
        │   └── ProfileView.swift
        ├── Capture/
        │   ├── CaptureView.swift
        │   └── WaveformView.swift
        ├── Entry/
        │   └── EntryEditView.swift
        ├── Paywall/
        │   └── PaywallView.swift
        └── Common/
            ├── CategoryDotView.swift
            ├── DonutView.swift
            └── FloatingMicButton.swift
```

## Type contracts (every agent must match)

```swift
// Models/AppUser.swift
import Foundation

struct AppUser: Hashable, Identifiable, Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    var id: String { uid }
}

// Models/Entry.swift
import Foundation

enum EntrySource: String, Codable { case voice, text }

struct Entry: Identifiable, Hashable, Codable {
    let id: String
    var category: String
    var note: String
    var startTime: Date
    var endTime: Date
    var source: EntrySource
    var transcript: String?
    let createdAt: Date
}

struct CapturedEntryDraft: Codable, Equatable {
    var category: String
    var note: String
    var startTime: Date
    var endTime: Date
}

// Models/Subscription.swift
import Foundation

enum Entitlement: String, Codable { case free, weekly, yearly }

struct SubscriptionStatus: Codable, Equatable {
    let entitlement: Entitlement
    let renewsAt: Date?
}
```

## Theme contracts

```swift
// Theme/Colors.swift  (palette mirrors client/theme/tokens.ts)
import SwiftUI

enum Palette {
    static let bg          = Color(hex: "#FAFAF7")
    static let ink         = Color(hex: "#111111")
    static let muted       = Color(hex: "#5C5C58")
    static let border      = Color(hex: "#ECECEA")
    static let borderSoft  = Color(hex: "#F2F2EF")
    static let amber       = Color(hex: "#E8A33D")
    static let amberSoft   = Color(hex: "#FBEFD8")
    static let white       = Color.white
    static let danger      = Color(hex: "#C8412C")
}

extension Color {
    init(hex: String) { /* parse #RRGGBB / #RRGGBBAA */ }
}

// Theme/Spacing.swift
import CoreGraphics

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let fab: CGFloat = 28
    static let pill: CGFloat = 999
}

// Theme/Typography.swift  — Inter not bundled; use system rounded/default
import SwiftUI

extension Font {
    static let cwTitle   = Font.system(size: 22, weight: .semibold)
    static let cwBody    = Font.system(size: 15, weight: .medium)
    static let cwCaption = Font.system(size: 12, weight: .medium)
}

extension Text {
    func tabularNumbers() -> Text { self.monospacedDigit() }
}

// Theme/Categories.swift
import SwiftUI

struct CategoryDef: Hashable {
    let key: String
    let label: String
    let color: Color
}

enum Categories {
    static let all: [CategoryDef] = [
        .init(key: "work",      label: "Work",      color: Color(hex: "#3D6F8E")),
        .init(key: "deep",      label: "Deep",      color: Color(hex: "#4F7A6A")),
        .init(key: "meeting",   label: "Meeting",   color: Color(hex: "#B07845")),
        .init(key: "study",     label: "Study",     color: Color(hex: "#8A6FA3")),
        .init(key: "exercise",  label: "Exercise",  color: Color(hex: "#C8412C")),
        .init(key: "sleep",     label: "Sleep",     color: Color(hex: "#5C5C58")),
        .init(key: "meal",      label: "Meal",      color: Color(hex: "#E8A33D")),
        .init(key: "break",     label: "Break",     color: Color(hex: "#A8A89D")),
        .init(key: "commute",   label: "Commute",   color: Color(hex: "#7A8A95")),
        .init(key: "entertain", label: "Entertain", color: Color(hex: "#A05B7E")),
        .init(key: "personal",  label: "Personal",  color: Color(hex: "#9C8855")),
    ]
    static func color(for key: String) -> Color { /* exact key, then case-insensitive label/key, fallback muted #5C5C58 */ }
    static func pillBackground(for key: String) -> Color { /* same color at 12% alpha */ }
    static func label(for key: String) -> String { /* lookup or return key */ }
}
```

## Utils contract

```swift
// Utils/TimeUtils.swift
import Foundation

enum TimeUtils {
    static let minPerDay = 24 * 60

    static func minutesSinceMidnight(_ date: Date) -> Int
    static func entryDurationMin(_ entry: Entry) -> Int          // max(15, round((end-start)/60))
    static func formatDuration(_ minutes: Int) -> String         // "6h 15m", "45m", "2h"
    static func formatLongDate(_ date: Date = Date()) -> String  // "Tuesday, May 5"
    static func formatHHmm(_ date: Date) -> String               // "09:30"
    static func formatTimeOfDay(_ minutesOfDay: Int) -> String   // "9:30 am"
    static func snapTo15(_ minutes: Int) -> Int
    static func totalTrackedMin(_ entries: [Entry]) -> Int
    static func startOfToday(_ now: Date = Date()) -> Date
    static func endOfToday(_ now: Date = Date()) -> Date
    static func minutesOfDay(of date: Date) -> Int               // alias of minutesSinceMidnight
    static func date(_ baseDate: Date, withMinutesOfDay totalMin: Int) -> Date
}
```

## Service contracts

```swift
// Services/FirebaseBootstrap.swift
import Foundation
import FirebaseCore

enum FirebaseBootstrap {
    /// Returns true if Firebase was configured (real backend) and false if running in stub mode.
    /// Call once from CronwatchApp init. Idempotent.
    @discardableResult
    static func configureIfPossible() -> Bool

    static private(set) var isConfigured: Bool
}

// Services/AuthService.swift
import Foundation

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isReady: Bool

    func startListening()                                   // attach Firebase auth listener (or stub flush)
    func signInWithApple() async throws -> AppUser
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AppUser
    func signOut() async
    func idToken() async -> String?
}

// In stub mode (no Firebase), signing in produces a fixed AppUser:
//   uid: "stub-user", email: "emma@cronwatch.app", displayName: "Emma Mori", photoURL: nil

// Services/EntriesService.swift
import Foundation

@MainActor
final class EntriesService {
    static let shared = EntriesService()

    /// Subscribe to today's entries (sorted by startTime asc). Returns a cancel closure.
    func subscribeToToday(uid: String, onChange: @escaping ([Entry]) -> Void) -> () -> Void

    func createEntry(uid: String, draft: CapturedEntryDraft, source: EntrySource, transcript: String?) async throws -> Entry
    func updateEntry(uid: String, id: String, category: String?, note: String?, startTime: Date?, endTime: Date?) async throws
    func deleteEntry(uid: String, id: String) async throws
}

// Services/AudioRecorder.swift  (AVAudioRecorder wrapper, m4a, AAC)
import Foundation
import AVFoundation

@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false

    func requestPermission() async -> Bool
    func start() throws
    func stop() -> URL?    // returns m4a file URL or nil if not recording
}

// Services/CaptureService.swift
import Foundation

enum CaptureError: Error {
    case proxyURLMissing
    case transcribeFailed(Int)
    case structureFailed(Int)
    case decoding
    case network(Error)
}

enum CaptureService {
    /// POSTs the file to <PROXY>/transcribe. In stub mode, sleeps ~600ms and returns a canned string.
    static func transcribe(audioURL: URL) async throws -> String

    /// POSTs JSON {transcript, now} to <PROXY>/structure. Stub returns a draft with category="deep", note=transcript, start=end=now.
    static func structure(transcript: String, now: Date = Date()) async throws -> CapturedEntryDraft
}

// Services/RevenueCatService.swift
import Foundation

@MainActor
final class RevenueCatService: ObservableObject {
    static let shared = RevenueCatService()

    @Published private(set) var entitlement: Entitlement = .free

    func configureIfNeeded()
    func refreshEntitlement() async -> Entitlement
    func restore() async -> Entitlement
    func identify(uid: String) async
}
```

## App entry point

```swift
// CronwatchApp.swift
import SwiftUI

@main
struct CronwatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var rc = RevenueCatService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(rc)
                .preferredColorScheme(.light)
                .tint(Palette.amber)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseBootstrap.configureIfPossible()
        RevenueCatService.shared.configureIfNeeded()
        AuthService.shared.startListening()
        return true
    }

    // Google Sign-In URL handling (if present)
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // GIDSignIn.sharedInstance.handle(url)
        return false
    }
}
```

## AppEnvironment

```swift
// AppEnvironment.swift
import Foundation

/// All runtime configuration. Reads from Info.plist (which is populated from
/// build settings / xcconfig in production) with environment-variable fallback
/// for development. Returns nil for missing values so services can fall back
/// to stub mode.
enum AppEnvironment {
    static var firebaseAPIKey: String?              { value(for: "FIREBASE_API_KEY") }
    static var firebaseProjectID: String?           { value(for: "FIREBASE_PROJECT_ID") }
    static var firebaseAppID: String?               { value(for: "FIREBASE_APP_ID") }
    static var firebaseSenderID: String?            { value(for: "FIREBASE_MESSAGING_SENDER_ID") }
    static var firebaseStorageBucket: String?       { value(for: "FIREBASE_STORAGE_BUCKET") }
    static var googleIOSClientID: String?           { value(for: "GOOGLE_IOS_CLIENT_ID") }
    static var captureProxyURL: URL?                { value(for: "CAPTURE_PROXY_URL").flatMap(URL.init(string:)) }
    static var revenueCatAPIKey: String?            { value(for: "REVENUECAT_API_KEY_IOS") }

    private static func value(for key: String) -> String? {
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String, !s.isEmpty, !s.hasPrefix("$(") { return s }
        if let s = ProcessInfo.processInfo.environment[key], !s.isEmpty { return s }
        return nil
    }
}
```

## Conventions

- All `ObservableObject` services live on `@MainActor`.
- All async work uses Swift Concurrency (`async/await`, `Task`).
- Use `Date` everywhere (not ISO strings) — convert at Firestore boundary.
- Stub mode: when `AppEnvironment.firebaseProjectID == nil` (or the relevant key), services should run in-memory so the app is usable without secrets. Mirrors the React Native client behavior.
- No emojis in code or copy.
- No comments unless explaining non-obvious "why".
- Use `LinearGradient`/`Circle`/`Rectangle` SwiftUI primitives for the donut and waveform — no SVG library.
- Prefer `.sheet` for modals (capture, entry/[id], paywall).
- Use `@EnvironmentObject` for `AuthService` and `RevenueCatService` injected from `CronwatchApp`.

## Design language (mirror RN app)

- Background `#FAFAF7`, ink `#111`, single accent amber `#E8A33D`.
- 12 px radius on cards/buttons, 28 px on the FAB.
- 16 pt base spacing.
- 1.5 pt thin SF Symbols (`.regular` weight) for icons:
  - mic.fill, calendar, house, person, plus, xmark, chevron.right, square.and.arrow.up.on.square, lock, mic, square.grid.3x3, paperplane.fill, minus, plus, trash, apple.logo, clock
- Three type sizes only: 22/600 title, 15/500 body, 12/500 caption.
- Tabular numerals on time displays.
- Quick (150–200 ms) ease-out animations on taps; 250 ms spring on FAB and sheets.

## Screens — what each does (mirrors `client/app/`)

1. **SignInView**: centered Cronwatch wordmark + clock icon in amber circle, tagline "Speak your time. See your day.", two stacked buttons (Apple filled black, Google bordered white). Apple uses native `SignInWithAppleButton`. Google uses `GIDSignIn`.

2. **MainTabView**: `TabView` with three tabs — Overview (house), Today (calendar), Profile (person). Active tint `Palette.amber`. Floating mic FAB at bottom-right (above tab bar) opens `CaptureView` as a `.sheet`. Default tab is Today.

3. **TodayView** + **TodayGridView**: header with long date + "Xh Xm tracked / Xh Xm open" caption. Body scroll view with hour rows and 15-min dotted dividers, a scaled vertical canvas where each entry is positioned by start time. PX_PER_MIN = 1.4. Now-line in amber. Tap entry → opens `EntryEditView` sheet.

4. **OverviewView**: scrollable. Title "Overview", subtitle. Card with `DonutView` showing today's slices, big number = distinct categories, "Most:" pill. Below: "THIS WEEK · DAILY AVERAGE" with mocked horizontal bars. Below: "TRACKING STREAK" with 21 mocked bars.

5. **ProfileView**: avatar (initials in muted grey circle), name, email caption. Subscription card with plan name + Upgrade/Manage button (amber). Account section: Sign out, Delete account (with `Alert` confirm). About section: Version, Source on GitHub, Privacy, Terms.

6. **CaptureView** (sheet): drag handle, header (Cancel / "New entry" / Save), body with status text + waveform (when recording) or transcript text + circular amber record button (88×88) + "HOLD TO RECORD" caption + bottom text input row. Long-press the record button to record; release to send to transcribe; Save runs structure + create.

7. **EntryEditView** (sheet, `entry/[id]`): drag handle, header (Cancel / "Edit entry" / Save), category chip wrap, multiline note input, START/END time steppers (snap 15 min), red Delete button.

8. **PaywallView** (sheet): close X, headline, subheadline, three feature rows with SF Symbols, two side-by-side plan cards (Yearly badge "Best value · 20% off" / Weekly), "Start subscription" amber CTA, fine print with Restore / Terms.

## project.yml (XcodeGen)

```yaml
name: Cronwatch
options:
  bundleIdPrefix: com.konradgnat.cronwatch
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    DEVELOPMENT_TEAM: ""
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    CODE_SIGN_STYLE: Automatic
packages:
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk
    from: "11.0.0"
  GoogleSignIn:
    url: https://github.com/google/GoogleSignIn-iOS
    from: "8.0.0"
  RevenueCat:
    url: https://github.com/RevenueCat/purchases-ios
    from: "5.0.0"
targets:
  Cronwatch:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Cronwatch
        excludes:
          - "Info.plist"
    info:
      path: Cronwatch/Info.plist
      properties:
        CFBundleDisplayName: Cronwatch
        CFBundleShortVersionString: "1.0.0"
        CFBundleVersion: "1"
        UILaunchScreen: {}
        UIRequiredDeviceCapabilities: [arm64]
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        NSMicrophoneUsageDescription: "Cronwatch listens when you tap to capture an entry by voice."
        # Build-time injected from xcconfig / env (placeholders read by AppEnvironment):
        FIREBASE_API_KEY: $(FIREBASE_API_KEY)
        FIREBASE_PROJECT_ID: $(FIREBASE_PROJECT_ID)
        FIREBASE_APP_ID: $(FIREBASE_APP_ID)
        FIREBASE_MESSAGING_SENDER_ID: $(FIREBASE_MESSAGING_SENDER_ID)
        FIREBASE_STORAGE_BUCKET: $(FIREBASE_STORAGE_BUCKET)
        GOOGLE_IOS_CLIENT_ID: $(GOOGLE_IOS_CLIENT_ID)
        CAPTURE_PROXY_URL: $(CAPTURE_PROXY_URL)
        REVENUECAT_API_KEY_IOS: $(REVENUECAT_API_KEY_IOS)
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.konradgnat.cronwatch
        TARGETED_DEVICE_FAMILY: "1,2"
        ENABLE_PREVIEWS: YES
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
    dependencies:
      - package: Firebase
        product: FirebaseAuth
      - package: Firebase
        product: FirebaseFirestore
      - package: Firebase
        product: FirebaseStorage
      - package: GoogleSignIn
        product: GoogleSignIn
      - package: GoogleSignIn
        product: GoogleSignInSwift
      - package: RevenueCat
        product: RevenueCat
    entitlements:
      path: Cronwatch/Cronwatch.entitlements
      properties:
        com.apple.developer.applesignin:
          - Default
```

## .env.example

```
FIREBASE_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_STORAGE_BUCKET=

GOOGLE_IOS_CLIENT_ID=

REVENUECAT_API_KEY_IOS=

# Server-side proxy for Deepgram + Together AI (do NOT ship API keys in the binary)
CAPTURE_PROXY_URL=
```

## README content (high level)

- What this is (native SwiftUI port of the RN client)
- Requirements: macOS, Xcode 15+, `brew install xcodegen`
- Setup: copy `.env.example` to `.env`, run `xcodegen`, `open Cronwatch.xcodeproj`
- Stub mode (no env vars) for running without Firebase keys
- Mapping table: RN file → Swift file
- Caveats: Inter font is not bundled; system font is used. Apple/Google sign-in still require Firebase Auth providers configured in the Firebase console. Apple sign-in uses a nonce/SHA256 flow.

## Stub mode rules

These mirror the RN app exactly:

- Stub user: `AppUser(uid: "stub-user", email: "emma@cronwatch.app", displayName: "Emma Mori", photoURL: nil)`
- Stub entries: in-memory array, persisted only for the session, sorted by startTime ascending. `subscribeToToday` returns a snapshot immediately and emits on every mutation.
- Stub transcribe: 600 ms sleep → returns "deep work on the auth refactor from 9 to 10:30"
- Stub structure: 500 ms sleep → returns `CapturedEntryDraft(category: "deep", note: transcript, startTime: now, endTime: now)`
- Stub RevenueCat: returns `.free`.
- Apple sign-in / Google sign-in in stub mode: 250 ms sleep → publishes the stub user.

## Notes

- Use `.task { ... }` modifiers for screen-load subscriptions and clean them up via the returned cancel closure on `.onDisappear`.
- Use `Color.init(hex:)` from `Theme/Colors.swift`; do not redeclare it elsewhere.
- The donut renders as a single SwiftUI `ZStack` of `Circle().trim(from:to:).stroke(...)` rotated -90° — don't pull in a charting library.
- The waveform: 24 small bars, each animates between `0.3` and `1.0` scale on staggered delays.
- Long-press gesture on the record button: `.gesture(LongPressGesture(minimumDuration: 0.0).simultaneously(with: DragGesture(minimumDistance: 0)))` is one approach, or use `.onLongPressGesture(minimumDuration: 0.0, perform: {}, onPressingChanged: { pressing in ... })`. The release behavior must trigger transcribe.
