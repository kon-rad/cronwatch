import Foundation

enum WeekReportError: Error, LocalizedError {
    case proxyURLMissing
    case notSignedIn
    case requestFailed(Int, String?)
    case decoding(String)
    case malformed(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .proxyURLMissing:                 return "Capture proxy URL is not set."
        case .notSignedIn:                     return "Not signed in."
        case .requestFailed(let s, let detail): return "Report failed (\(s))\(detail.map { ": \($0)" } ?? "")"
        case .decoding(let reason):             return "Decoding failed: \(reason)"
        case .malformed(let reason):            return reason
        case .network(let err):                 return err.localizedDescription
        }
    }
}

enum WeekReportService {
    static func generate(
        goals: [String],
        weekStart: Date,
        weekEnd: Date,
        days: [DayAggregate]
    ) async throws -> WeekReport {
        guard let proxy = AppEnvironment.captureProxyURL else {
            throw WeekReportError.proxyURLMissing
        }
        guard let token = await AuthService.shared.idToken() else {
            throw WeekReportError.notSignedIn
        }

        let endpoint = proxy.appendingPathComponent("week-report")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let payload: [String: Any] = [
            "goals": goals,
            "weekStart": isoFormatter.string(from: weekStart),
            "weekEnd": isoFormatter.string(from: weekEnd),
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

        do { request.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        catch { throw WeekReportError.network(error) }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw WeekReportError.network(error) }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw WeekReportError.requestFailed(status, readError(data))
        }

        let decoded: WeekReport
        do { decoded = try JSONDecoder().decode(WeekReport.self, from: data) }
        catch { throw WeekReportError.decoding(error.localizedDescription) }

        guard !decoded.ideas.isEmpty else {
            throw WeekReportError.malformed("Server returned no ideas")
        }
        return decoded
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
