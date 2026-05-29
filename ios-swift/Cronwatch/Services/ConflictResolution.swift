import Foundation

struct DateRange: Equatable, Codable {
    let start: Date
    let end: Date
}

enum ConflictAction: Equatable, Codable {
    case delete
    case trim(startTime: Date, endTime: Date)
    case split(left: DateRange, right: DateRange)
}

struct Resolution: Equatable, Codable {
    let entryId: String
    let originalStart: Date
    let originalEnd: Date
    let originalSource: EntrySource
    let category: String
    let note: String
    let transcript: String?
    let captureId: String
    let action: ConflictAction
}

struct ResolutionPlan: Equatable, Codable {
    let captureId: String
    let source: EntrySource
    let transcript: String?
    let drafts: [CapturedEntryDraft]
    let resolutions: [Resolution]

    var hasConflicts: Bool { !resolutions.isEmpty }
}
