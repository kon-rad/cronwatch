import SwiftUI
import UIKit

struct SignInView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Palette.amber)
                            .frame(width: 56, height: 56)
                        Image(systemName: "clock")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(Palette.white)
                    }

                    Text("Cronwatch")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, Spacing.md)

                    Text("Speak your time. See your day.")
                        .font(.cwBody)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, Spacing.xs)
                }

                Spacer()

                VStack(spacing: Spacing.sm) {
                    appleButton
                    if AppEnvironment.googleIOSClientID != nil {
                        googleButton
                    }
                    termsCaption
                        .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    private var appleButton: some View {
        Button {
            Task { try? await auth.signInWithApple() }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Palette.white)
                Text("Continue with Apple")
                    .font(.cwBody)
                    .foregroundStyle(Palette.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Palette.ink)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Apple")
    }

    private var googleButton: some View {
        Button {
            let vc = topViewController()
            guard let vc else { return }
            Task { try? await auth.signInWithGoogle(presenting: vc) }
        } label: {
            HStack(spacing: Spacing.sm) {
                Text("G")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Continue with Google")
                    .font(.cwBody)
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Palette.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Google")
    }

    private var termsCaption: some View {
        HStack(spacing: 0) {
            Text("By continuing you agree to our ")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
            Text("Terms")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
                .underline()
            Text(" and ")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
            Text("Privacy")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
                .underline()
            Text(".")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
        }
        .multilineTextAlignment(.center)
    }

    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
