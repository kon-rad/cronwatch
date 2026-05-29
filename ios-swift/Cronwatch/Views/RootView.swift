import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    @State private var userSettings: UserSettings = .empty
    @State private var settingsReady = false
    @State private var settingsUnsubscribe: (() -> Void)?
    @State private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if !auth.isReady || (auth.currentUser != nil && !settingsReady) {
                Palette.bg.ignoresSafeArea()
            } else if auth.currentUser == nil {
                SignInView()
                    .transition(.opacity)
            } else if showOnboarding, let uid = auth.currentUser?.uid {
                OnboardingFlow(
                    uid: uid,
                    onComplete: { hasCompletedOnboarding = true }
                )
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.currentUser?.uid)
        .animation(.easeInOut(duration: 0.2), value: auth.isReady)
        .animation(.easeInOut(duration: 0.2), value: settingsReady)
        .animation(.easeInOut(duration: 0.2), value: showOnboarding)
        .onAppear { subscribeToSettings() }
        .onDisappear {
            settingsUnsubscribe?()
            settingsUnsubscribe = nil
        }
        .onChange(of: auth.currentUser?.uid) { _, _ in
            hasCompletedOnboarding = false
            subscribeToSettings()
        }
    }

    private var showOnboarding: Bool {
        guard !hasCompletedOnboarding else { return false }
        return FeatureFlags.showOnboardingInDev || !userSettings.onboardingCompleted
    }

    private func subscribeToSettings() {
        settingsUnsubscribe?()
        settingsUnsubscribe = nil
        settingsReady = false

        guard let uid = auth.currentUser?.uid else {
            userSettings = .empty
            settingsReady = true
            return
        }

        var receivedFirst = false
        settingsUnsubscribe = UserSettingsService.shared.subscribe(uid: uid) { settings in
            self.userSettings = settings
            if !receivedFirst {
                receivedFirst = true
                self.settingsReady = true
            }
        }
    }
}
