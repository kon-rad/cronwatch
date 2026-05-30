import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable { case overview, today, placeholder, list, profile }

    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var rc: RevenueCatService
    @State private var selectedTab: Tab = .today
    @State private var previousTab: Tab = .today
    @State private var showCapture = false
    @State private var showPaywall = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                OverviewView()
                    .tabItem { Image(systemName: "house") }
                    .tag(Tab.overview)

                TodayView()
                    .tabItem { Image(systemName: "calendar") }
                    .tag(Tab.today)

                // Invisible center slot that creates the gap on either side of the FAB.
                Color.clear
                    .tabItem { Text("") }
                    .tag(Tab.placeholder)

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
            .onChange(of: selectedTab) { _, newTab in
                if newTab == .placeholder {
                    selectedTab = previousTab
                } else {
                    previousTab = newTab
                }
            }

            // Centered on the tab bar's top edge so 50% of the button overlaps above it.
            // Tab bar content = 49pt; button radius = 32pt → bottom padding = 49 - 32 = 17pt.
            HStack {
                Spacer()
                FloatingMicButton {
                    if rc.entitlement == .free {
                        showPaywall = true
                    } else {
                        showCapture = true
                    }
                }
                Spacer()
            }
            .padding(.bottom, 17)
        }
        .sheet(isPresented: $showCapture) {
            CaptureView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
