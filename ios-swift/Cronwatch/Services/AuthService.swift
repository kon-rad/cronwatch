import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import UIKit

enum AuthServiceError: Error, LocalizedError {
    case firebaseNotConfigured
    case googleClientIDMissing
    case missingIdentityToken
    case unexpectedCredentialType
    case userMappingFailed
    case notSignedIn
    case unsupportedProvider

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:  return "Firebase is not configured. Check the FIREBASE_* values in ios-swift/.env."
        case .googleClientIDMissing:  return "GOOGLE_IOS_CLIENT_ID is not set."
        case .missingIdentityToken:   return "Sign-in did not return an identity token."
        case .unexpectedCredentialType: return "Unexpected Apple credential type."
        case .userMappingFailed:      return "Couldn't read the signed-in user."
        case .notSignedIn:            return "No signed-in user found."
        case .unsupportedProvider:    return "Sign-in provider not supported for account deletion. Please contact support."
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isReady: Bool = false

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
            throw AuthServiceError.firebaseNotConfigured
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
            throw AuthServiceError.missingIdentityToken
        }

        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        let result = try await Auth.auth().signIn(with: oauthCredential)
        guard let appUser = Self.toAppUser(result.user) else {
            throw AuthServiceError.userMappingFailed
        }
        currentUser = appUser
        return appUser
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AppUser {
        guard FirebaseBootstrap.isConfigured else {
            throw AuthServiceError.firebaseNotConfigured
        }
        guard let clientID = AppEnvironment.googleIOSClientID else {
            throw AuthServiceError.googleClientIDMissing
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.missingIdentityToken
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        guard let appUser = Self.toAppUser(authResult.user) else {
            throw AuthServiceError.userMappingFailed
        }
        currentUser = appUser
        return appUser
    }

    func signOut() async {
        GIDSignIn.sharedInstance.signOut()
        if FirebaseBootstrap.isConfigured {
            try? Auth.auth().signOut()
        }
        currentUser = nil
    }

    func deleteAccount(presenting viewController: UIViewController) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.notSignedIn
        }
        let providerIDs = user.providerData.map { $0.providerID }
        if providerIDs.contains("apple.com") {
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
                throw AuthServiceError.missingIdentityToken
            }
            let oauthCredential = OAuthProvider.appleCredential(
                withIDToken: identityToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            try await user.reauthenticate(with: oauthCredential)
        } else if providerIDs.contains("google.com") {
            guard let clientID = AppEnvironment.googleIOSClientID else {
                throw AuthServiceError.googleClientIDMissing
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthServiceError.missingIdentityToken
            }
            let accessToken = result.user.accessToken.tokenString
            let googleCredential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            do {
                try await user.reauthenticate(with: googleCredential)
            } catch {
                GIDSignIn.sharedInstance.signOut()
                throw error
            }
        } else {
            throw AuthServiceError.unsupportedProvider
        }
        try await user.delete()
        currentUser = nil
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
    }

    func idToken() async throws -> String {
        guard FirebaseBootstrap.isConfigured, let user = Auth.auth().currentUser else {
            throw AuthServiceError.notSignedIn
        }
        return try await user.getIDToken()
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
            continuation?.resume(throwing: AuthServiceError.unexpectedCredentialType)
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
