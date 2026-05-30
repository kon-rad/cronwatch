import CryptoKit
import FirebaseFirestore
import Foundation

enum ApiKeyServiceError: Error, LocalizedError {
    case firebaseNotConfigured
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: return "Firebase is not configured."
        case .notAuthorized: return "Not authorized to modify this key."
        }
    }
}

@MainActor
final class ApiKeyService {
    static let shared = ApiKeyService()
    private init() {}

    // MARK: - List

    func list(uid: String) async throws -> [ApiKey] {
        guard FirebaseBootstrap.isConfigured else {
            throw ApiKeyServiceError.firebaseNotConfigured
        }
        let snap = try await Firestore.firestore()
            .collection("apiKeys")
            .whereField("uid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snap.documents.compactMap { Self.keyFromDocument(id: $0.documentID, data: $0.data()) }
    }

    // MARK: - Create

    /// Generates a new `cw_` key, stores only the hash, and returns the raw key (shown once).
    func create(uid: String, name: String) async throws -> (key: ApiKey, rawKey: String) {
        guard FirebaseBootstrap.isConfigured else {
            throw ApiKeyServiceError.firebaseNotConfigured
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let rawKey = Self.generateRawKey()
        let keyHash = Self.sha256(rawKey)
        let prefix = String(rawKey.prefix(12))
        let ref = Firestore.firestore().collection("apiKeys").document()
        let now = Date()
        try await ref.setData([
            "uid": uid,
            "name": trimmed,
            "keyHash": keyHash,
            "prefix": prefix,
            "createdAt": Timestamp(date: now),
        ])
        let key = ApiKey(id: ref.documentID, uid: uid, name: trimmed, prefix: prefix, createdAt: now)
        return (key, rawKey)
    }

    // MARK: - Delete

    func delete(uid: String, keyId: String) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw ApiKeyServiceError.firebaseNotConfigured
        }
        let ref = Firestore.firestore().collection("apiKeys").document(keyId)
        let snap = try await ref.getDocument()
        guard let data = snap.data(), data["uid"] as? String == uid else {
            throw ApiKeyServiceError.notAuthorized
        }
        try await ref.delete()
    }

    // MARK: - Refresh (delete + re-create with same name)

    func refresh(uid: String, keyId: String, name: String) async throws -> (key: ApiKey, rawKey: String) {
        try await delete(uid: uid, keyId: keyId)
        return try await create(uid: uid, name: name)
    }

    // MARK: - Helpers

    private static func generateRawKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return "cw_\(hex)"
    }

    private static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func keyFromDocument(id: String, data: [String: Any]) -> ApiKey? {
        guard
            let uid = data["uid"] as? String,
            let name = data["name"] as? String,
            let prefix = data["prefix"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }
        return ApiKey(id: id, uid: uid, name: name, prefix: prefix, createdAt: createdAt)
    }
}
