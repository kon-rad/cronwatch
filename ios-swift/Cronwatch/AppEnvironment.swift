import Foundation

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
