import Foundation

struct CaptureResult: Equatable {
    let transcript: String
    let drafts: [CapturedEntryDraft]
}

enum CaptureError: Error, LocalizedError {
    case proxyURLMissing
    case captureFailed(Int, String?)
    case structureFailed(Int, String?)
    case notSignedIn
    case decoding(String)
    case emptyDrafts
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .proxyURLMissing:                    return "Capture proxy URL is not set."
        case .captureFailed(let s, let detail):   return "Capture failed (\(s))\(detail.map { ": \($0)" } ?? "")"
        case .structureFailed(let s, let detail): return "Structure failed (\(s))\(detail.map { ": \($0)" } ?? "")"
        case .notSignedIn:                        return "Not signed in."
        case .decoding(let reason):               return "Decoding failed: \(reason)"
        case .emptyDrafts:                        return "Empty response."
        case .network(let err):                   return err.localizedDescription
        }
    }
}

enum CaptureService {

    // MARK: - Public

    static func capture(audioURL: URL,
                        provider: TranscriptionProvider = .deepgram,
                        now: Date = Date()) async throws -> CaptureResult {
        guard let proxy = AppEnvironment.captureProxyURL else {
            throw CaptureError.proxyURLMissing
        }

        let token = try await requireIdToken()
        let endpoint = proxy.appendingPathComponent("capture")
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let audioData: Data
        do { audioData = try Data(contentsOf: audioURL) }
        catch { throw CaptureError.network(error) }

        let ext = audioURL.pathExtension.lowercased().isEmpty ? "m4a" : audioURL.pathExtension.lowercased()
        let mime = mimeForExtension(ext)
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.\(ext)\"\r\n")
        body.appendString("Content-Type: \(mime)\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n")
        body.appendField(name: "now", value: isoString(from: now), boundary: boundary)
        body.appendField(name: "tz", value: TimeZone.current.identifier, boundary: boundary)
        if let serverProvider = provider.serverValue {
            body.appendField(name: "provider", value: serverProvider, boundary: boundary)
        }
        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw CaptureError.network(error) }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw CaptureError.captureFailed(status, readError(data))
        }

        struct Payload: Decodable {
            let transcript: String
            let drafts: [DraftWire]
        }

        let decoded: Payload
        do { decoded = try JSONDecoder().decode(Payload.self, from: data) }
        catch { throw CaptureError.decoding(error.localizedDescription) }

        let drafts = try decoded.drafts.map { try $0.toModel() }
        guard !drafts.isEmpty else { throw CaptureError.emptyDrafts }

        return CaptureResult(
            transcript: decoded.transcript,
            drafts: drafts
        )
    }

    static func structureText(_ text: String, now: Date = Date()) async throws -> [CapturedEntryDraft] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let proxy = AppEnvironment.captureProxyURL else {
            throw CaptureError.proxyURLMissing
        }

        let token = try await requireIdToken()
        let endpoint = proxy.appendingPathComponent("structure")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "transcript": trimmed,
            "now": isoString(from: now),
            "tz": TimeZone.current.identifier,
        ]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        catch { throw CaptureError.network(error) }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw CaptureError.network(error) }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw CaptureError.structureFailed(status, readError(data))
        }

        struct Payload: Decodable { let drafts: [DraftWire] }
        let decoded: Payload
        do { decoded = try JSONDecoder().decode(Payload.self, from: data) }
        catch { throw CaptureError.decoding(error.localizedDescription) }

        let drafts = try decoded.drafts.map { try $0.toModel() }
        guard !drafts.isEmpty else { throw CaptureError.emptyDrafts }
        return drafts
    }

    // MARK: - Helpers

    private struct DraftWire: Decodable {
        let category: String
        let note: String
        let startTime: String
        let endTime: String

        func toModel() throws -> CapturedEntryDraft {
            guard let start = parseISODate(startTime), let end = parseISODate(endTime) else {
                throw CaptureError.decoding("Invalid draft date: \(startTime) / \(endTime)")
            }
            return CapturedEntryDraft(category: category, note: note, startTime: start, endTime: end)
        }
    }

    private static func requireIdToken() async throws -> String {
        do {
            return try await AuthService.shared.idToken()
        } catch is AuthServiceError {
            throw CaptureError.notSignedIn
        } catch {
            let ns = error as NSError
            print("[CaptureService] getIDToken failed — domain: \(ns.domain), code: \(ns.code), desc: \(ns.localizedDescription)")
            if !ns.userInfo.isEmpty {
                print("[CaptureService] getIDToken userInfo: \(ns.userInfo)")
            }
            throw CaptureError.network(error)
        }
    }

    private static func readError(_ data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let s = json["error"] as? String, !s.isEmpty {
            return s
        }
        let s = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty ?? true) ? nil : s
    }

    private static func mimeForExtension(_ ext: String) -> String {
        switch ext {
        case "wav":  return "audio/wav"
        case "mp3":  return "audio/mpeg"
        case "webm": return "audio/webm"
        case "ogg":  return "audio/ogg"
        case "caf":  return "audio/x-caf"
        default:     return "audio/m4a"
        }
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseISODate(_ s: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: s) { return d }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: s)
    }
}

private extension Data {
    mutating func appendString(_ s: String) {
        if let d = s.data(using: .utf8) { append(d) }
    }

    mutating func appendField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString(value)
        appendString("\r\n")
    }
}
