import Foundation

enum EntrySource: String, Codable { case voice, text }

struct Entry: Identifiable, Hashable, Codable {
    let id: String
    let captureId: String
    var category: String
    var note: String
    var startTime: Date
    var endTime: Date
    var source: EntrySource
    var transcript: String?
    var audioUrl: String?
    let createdAt: Date
}

struct CapturedEntryDraft: Codable, Equatable {
    var category: String
    var note: String
    var startTime: Date
    var endTime: Date
}

struct Capture: Identifiable, Equatable {
    let captureId: String
    let source: EntrySource
    var transcript: String?
    var audioUrl: String?
    let createdAt: Date
    var blocks: [Entry]

    var id: String { captureId }
}
