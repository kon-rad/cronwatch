import Foundation

enum ProfileReportGeneratorError: Error, LocalizedError {
    case proxyURLMissing
    case notSignedIn
    case requestFailed(Int, String?)
    case decoding(String)
    case network(Error)
    case rangeTooLong
    case rangeInverted

    var errorDescription: String? {
        switch self {
        case .proxyURLMissing:                  return "Capture proxy URL is not set."
        case .notSignedIn:                      return "Not signed in."
        case .requestFailed(let s, let detail): return "Report failed (\(s))\(detail.map { ": \($0)" } ?? "")"
        case .decoding(let reason):             return "Decoding failed: \(reason)"
        case .network(let err):                 return err.localizedDescription
        case .rangeTooLong:                     return "Pick a range of 92 days or less."
        case .rangeInverted:                    return "End date must be on or after start date."
        }
    }
}

struct GeneratedReport {
    let title: String
    let html: String
}

enum ProfileReportGenerator {
    static let maxRangeDays = 92

    static func generate(
        rangeStart: Date,
        rangeEnd: Date,
        goals: [String],
        customPrompt: String?,
        days: [DayAggregate]
    ) async throws -> GeneratedReport {
        guard let proxy = AppEnvironment.captureProxyURL else {
            throw ProfileReportGeneratorError.proxyURLMissing
        }
        let token = try await AuthService.shared.idToken()

        let endpoint = proxy.appendingPathComponent("profile-report")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // LLM generation can be slow — give it room to finish.
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let isoDay = DateFormatter()
        isoDay.calendar = .current
        isoDay.locale = Locale(identifier: "en_US_POSIX")
        isoDay.dateFormat = "yyyy-MM-dd"

        var payload: [String: Any] = [
            "rangeStart": isoDay.string(from: rangeStart),
            "rangeEnd": isoDay.string(from: rangeEnd),
            "tz": TimeZone.current.identifier,
            "days": days.map { day in
                [
                    "date": day.date,
                    "categories": day.categories.map { cat in
                        ["name": cat.name, "minutes": cat.minutes]
                    },
                ]
            },
        ]
        let trimmedGoals = goals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !trimmedGoals.isEmpty {
            payload["goals"] = trimmedGoals
        }
        if let cp = customPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !cp.isEmpty {
            payload["customPrompt"] = cp
        }

        do { request.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        catch { throw ProfileReportGeneratorError.network(error) }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw ProfileReportGeneratorError.network(error) }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ProfileReportGeneratorError.requestFailed(status, readError(data))
        }

        struct Payload: Decodable { let title: String; let html: String }
        do {
            let decoded = try JSONDecoder().decode(Payload.self, from: data)
            return GeneratedReport(title: decoded.title, html: decoded.html)
        } catch {
            throw ProfileReportGeneratorError.decoding(error.localizedDescription)
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
}
