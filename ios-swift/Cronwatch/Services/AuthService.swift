import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import UIKit

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isReady: Bool = false

    private static let stubUser = AppUser(
        uid: "stub-user",
        email: "emma@cronwatch.app",
        displayName: "Emma Mori",
        photoURL: nil
    )

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var appleCoordinator: AppleSignInCoordinator?
    private var currentNonce: String?

    private init() {}

    func startListening() {
        guard FirebaseBootstrap.isConfigured else {
            isReady = true
            return
        }
        if authStateHandle != nil { return }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.currentUser = Self.toAppUser(user)
                self.isReady = true
            }
        }
    }

    func signInWithApple() async throws -> AppUser {
        guard FirebaseBootstrap.isConfigured else {
            try? await Task.sleep(nanoseconds: 250_000_000)
            currentUser = Self.stubUser
            return Self.stubUser
        }

        let nonce = Self.randomNonce()
        currentNonce = nonce
        let hashedNonce = Self.sha256(nonce)

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let credential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { cont in
            let coordinator = AppleSignInCoordinator(continuation: cont)
            self.appleCoordinator = coordinator
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
        }
        appleCoordinator = nil

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw NSError(domain: "AuthService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Apple sign-in did not return an identity token."])
        }

        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        let result = try await Auth.auth().signIn(with: oauthCredential)
        let appUser = Self.toAppUser(result.user) ?? Self.stubUser
        currentUser = appUser
        return appUser
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AppUser {
        guard FirebaseBootstrap.isConfigured, let clientID = AppEnvironment.googleIOSClientID else {
            try? await Task.sleep(nanoseconds: 250_000_000)
            currentUser = Self.stubUser
            return Self.stubUser
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Google sign-in did not return an ID token."])
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        let appUser = Self.toAppUser(authResult.user) ?? Self.stubUser
        currentUser = appUser
        return appUser
    }

    func signOut() async {
        // Always safe to call, even if user never went through Google flow.
        GIDSignIn.sharedInstance.signOut()
        if FirebaseBootstrap.isConfigured {
            try? Auth.auth().signOut()
            // The auth state listener will null out currentUser; do it eagerly too.
            currentUser = nil
        } else {
            currentUser = nil
        }
    }

    func idToken() async -> String? {
        guard FirebaseBootstrap.isConfigured, let user = Auth.auth().currentUser else {
            return nil
        }
        return try? await user.getIDToken()
    }

    // MARK: - Helpers

    private static func toAppUser(_ user: User?) -> AppUser? {
        guard let user else { return nil }
        return AppUser(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL?.absoluteString
        )
    }

    private static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate random bytes for nonce.") }
            for byte in randoms where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }
}

private final class AppleSignInCoordinator: NSObject,
                                            ASAuthorizationControllerDelegate,
                                            ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: NSError(domain: "AuthService", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected Apple credential type."]))
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the first foreground active scene's key window; fall back to a fresh window.
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        if let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return window
        }
        if let window = scenes.flatMap(\.windows).first {
            return window
        }
        return ASPresentationAnchor()
    }
}
