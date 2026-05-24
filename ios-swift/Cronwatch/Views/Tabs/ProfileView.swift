import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var rc: RevenueCatService
    @Environment(\.openURL) private var openURL

    @State private var showPaywall = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAlert = false
    @State private var userSettings: UserSettings = .empty
    @State private var goalsUnsubscribe: (() -> Void)?

    private let appVersion = "1.0.0"
    private let githubURL = URL(string: "https://github.com/kon-rad/cronwatch")!
    private let privacyURL = URL(string: "https://cronwatch.xyz/privacy")!
    private let termsURL = URL(string: "https://cronwatch.xyz/terms")!

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identityRow

                    SectionView(label: "SUBSCRIPTION") {
                        subscriptionCard
                    }

                    if let uid = auth.currentUser?.uid {
                        ProfileReportsSection(uid: uid, goals: userSettings.goals
                            .filter { $0.isSet }
                            .map { goal -> String in
                                let hrs = goal.weeklyTargetHours.truncatingRemainder(dividingBy: 1) == 0
                                    ? "\(Int(goal.weeklyTargetHours))h"
                                    : String(format: "%.1fh", goal.weeklyTargetHours)
                                return "\(Categories.label(for: goal.category)): \(hrs)/week"
                            })
                    }

                    SectionView(label: "ACCOUNT") {
                        VStack(spacing: 0) {
                            RowView(label: "Sign out", isFirst: true) {
                                showSignOutAlert = true
                            }
                            RowView(label: "Delete account", isFirst: false) {
                                showDeleteAlert = true
                            }
                        }
                    }

                    SectionView(label: "ABOUT") {
                        VStack(spacing: 0) {
                            RowView(label: "Version", isFirst: true, trailing: AnyView(
                                Text(appVersion)
                                    .font(.cwBody)
                                    .foregroundStyle(Palette.muted)
                            ))
                            RowView(label: "Source on GitHub", isFirst: false) {
                                openURL(githubURL)
                            }
                            RowView(label: "Privacy", isFirst: false) {
                                openURL(privacyURL)
                            }
                            RowView(label: "Terms", isFirst: false) {
                                openURL(termsURL)
                            }
                        }
                    }

                    Text("MADE QUIETLY · CRONWATCH")
                        .font(.cwCaption)
                        .tracking(1.2)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, 160)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable {
                _ = await rc.refreshEntitlement()
            }
        }
        .task {
            _ = await rc.refreshEntitlement()
        }
        .onAppear { subscribeToGoals() }
        .onDisappear {
            goalsUnsubscribe?()
            goalsUnsubscribe = nil
        }
        .onChange(of: auth.currentUser?.uid) { _, _ in
            subscribeToGoals()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Sign out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
        }
        .alert("Delete account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await auth.signOut() }
            }
        } message: {
            Text("This permanently removes your entries. This cannot be undone.")
        }
    }

    private func subscribeToGoals() {
        goalsUnsubscribe?()
        goalsUnsubscribe = nil
        guard let uid = auth.currentUser?.uid else {
            userSettings = .empty
            return
        }
        goalsUnsubscribe = UserSettingsService.shared.subscribe(uid: uid) { settings in
            self.userSettings = settings
        }
    }

    private var initials: String {
        let raw = auth.currentUser?.displayName ?? auth.currentUser?.email ?? "C"
        let parts = raw.split { $0.isWhitespace }
        let letters = parts.compactMap { $0.first }.prefix(2)
        let s = String(letters).uppercased()
        return s.isEmpty ? "C" : s
    }

    private var identityRow: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Palette.muted)
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.cwBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.currentUser?.displayName ?? "Cronwatch user")
                    .font(.cwTitle)
                    .foregroundStyle(Palette.ink)
                if let email = auth.currentUser?.email {
                    Text(email)
                        .font(.cwCaption)
                        .foregroundStyle(Palette.muted)
                }
            }
            Spacer()
        }
    }

    private var planLabel: String {
        switch rc.entitlement {
        case .weekly: return "Weekly plan"
        case .yearly: return "Yearly plan"
        case .free:   return "Free plan"
        }
    }

    private var planSub: String {
        rc.entitlement == .free ? "No active subscription" : "Renews automatically"
    }

    private var subscriptionCard: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(planLabel)
                    .font(.cwBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.ink)
                Text(planSub)
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Button {
                showPaywall = true
            } label: {
                Text(rc.entitlement == .free ? "Upgrade" : "Manage")
                    .font(.cwBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .background(Palette.amber)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
    }
}

private struct SectionView<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
                .padding(.bottom, Spacing.sm)
            content()
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.border, lineWidth: 1)
                )
        }
        .padding(.top, Spacing.lg)
    }
}

private struct RowView: View {
    let label: String
    var isFirst: Bool = false
    var trailing: AnyView? = nil
    var onPress: (() -> Void)? = nil

    init(label: String,
         isFirst: Bool = false,
         trailing: AnyView? = nil,
         onPress: (() -> Void)? = nil) {
        self.label = label
        self.isFirst = isFirst
        self.trailing = trailing
        self.onPress = onPress
    }

    var body: some View {
        Button {
            onPress?()
        } label: {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Palette.border)
                        .frame(height: 0.5)
                }
                HStack(spacing: Spacing.sm) {
                    Text(label)
                        .font(.cwBody)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    if let trailing {
                        trailing
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(onPress == nil && trailing == nil)
        .allowsHitTesting(onPress != nil)
    }
}
