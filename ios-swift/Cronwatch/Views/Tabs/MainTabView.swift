import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable { case overview, today, list, profile }

    @EnvironmentObject var auth: AuthService
    @State private var selectedTab: Tab = .today
    @State private var showCapture = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                OverviewView()
                    .tabItem { Image(systemName: "house") }
                    .tag(Tab.overview)

                TodayView()
                    .tabItem { Image(systemName: "calendar") }
                    .tag(Tab.today)

                EntriesListView()
                    .tabItem { Image(systemName: "list.bullet") }
                    .tag(Tab.list)

                ProfileView()
                    .tabItem { Image(systemName: "person") }
                    .tag(Tab.profile)
            }
            .tint(Palette.amber)
            .toolbarBackground(Palette.bg, for: .tabBar)
            .toolbar(.visible, for: .tabBar)

            FloatingMicButton {
                showCapture = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 64)
        }
        .sheet(isPresented: $showCapture) {
            CaptureView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}
