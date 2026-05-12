import SwiftUI
import UIKit
import GoogleSignIn

@main
struct CronwatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthService.shared
    @StateObject private var rc = RevenueCatService.shared
    @StateObject private var toasts = ToastCenter.shared
    @StateObject private var queue = CaptureQueue.shared
    @StateObject private var bridge = CaptureQueueToastBridge()

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                ToastHost()
            }
            .environmentObject(auth)
            .environmentObject(rc)
            .environmentObject(toasts)
            .environmentObject(queue)
            .preferredColorScheme(.light)
            .tint(Palette.amber)
            .onAppear {
                bridge.observe(queue: queue, toasts: toasts)
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseBootstrap.configureIfPossible()
        RevenueCatService.shared.configureIfNeeded()
        AuthService.shared.startListening()
        CaptureQueue.cleanupOrphans()
        return true
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
