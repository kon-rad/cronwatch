import Foundation

enum ReportStatus: String {
    case generating
    case ready
    case failed
}

struct ProfileReport: Identifiable, Hashable {
    let id: String
    var title: String
    var html: String
    var rangeStart: Date
    var rangeEnd: Date
    var customPrompt: String?
    let createdAt: Date
    var status: ReportStatus = .ready
    var errorMessage: String?
}
