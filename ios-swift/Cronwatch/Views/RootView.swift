import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            if !auth.isReady {
                Palette.bg.ignoresSafeArea()
            } else if auth.currentUser == nil {
                SignInView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.currentUser)
        .animation(.easeInOut(duration: 0.2), value: auth.isReady)
    }
}
