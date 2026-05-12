import Foundation
import FirebaseCore

enum FirebaseBootstrap {
    static private(set) var isConfigured: Bool = false

    @discardableResult
    static func configureIfPossible() -> Bool {
        if isConfigured { return true }

        guard let projectID = AppEnvironment.firebaseProjectID,
              let apiKey = AppEnvironment.firebaseAPIKey else {
            isConfigured = false
            return false
        }

        let appID = AppEnvironment.firebaseAppID ?? ""
        let senderID = AppEnvironment.firebaseSenderID ?? ""

        let options = FirebaseOptions(googleAppID: appID, gcmSenderID: senderID)
        options.apiKey = apiKey
        options.projectID = projectID
        if let bucket = AppEnvironment.firebaseStorageBucket, !bucket.isEmpty {
            options.storageBucket = bucket
        }

        FirebaseApp.configure(options: options)
        isConfigured = true
        return true
    }
}
