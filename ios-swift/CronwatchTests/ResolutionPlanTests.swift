import XCTest
@testable import Cronwatch

final class ResolutionPlanTests: XCTestCase {

    // MARK: - Helpers

    private func d(_ hour: Int, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 15
        comps.hour = hour
        comps.minute = minute
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func entry(id: String, _ startHour: Int, _ startMin: Int, _ endHour: Int, _ endMin: Int, category: String = "deep") -> Entry {
        Entry(
            id: id,
            captureId: "c_existing_\(id)",
            category: category,
            note: "existing",
            startTime: d(startHour, startMin),
            endTime: d(endHour, endMin),
            source: .voice,
            transcript: nil,
            createdAt: d(0)
        )
    }

    private func draft(_ startHour: Int, _ startMin: Int, _ endHour: Int, _ endMin: Int, category: String = "work") -> CapturedEntryDraft {
        CapturedEntryDraft(
            category: category,
            note: "new",
            startTime: d(startHour, startMin),
            endTime: d(endHour, endMin)
        )
    }

    private func plan(existing: [Entry], drafts: [CapturedEntryDraft]) -> ResolutionPlan {
        EntriesService.buildResolutionPlan(
            existing: existing,
            drafts: drafts,
            captureId: "c_new",
            source: .voice,
            transcript: "t"
        )
    }

    // MARK: - Cases

    func test_noOverlap_returnsEmptyResolutions() {
        let p = plan(existing: [entry(id: "e1", 11, 0, 12, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertTrue(p.resolutions.isEmpty)
    }

    func test_touchingBoundary_isNotOverlap() {
        // Half-open intervals: existing [10, 11), draft [9, 10) -> no overlap.
        let p = plan(existing: [entry(id: "e1", 10, 0, 11, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertTrue(p.resolutions.isEmpty)
    }

    func test_newFullyContainsExisting_deletesExisting() {
        let p = plan(existing: [entry(id: "e1", 10, 0, 11, 0)], drafts: [draft(9, 0, 12, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].entryId, "e1")
        XCTAssertEqual(p.resolutions[0].action, .delete)
    }

    func test_equalRanges_deletesExisting() {
        let p = plan(existing: [entry(id: "e1", 9, 0, 10, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .delete)
    }

    func test_newOverlapsLeftSideOfExisting_trimsLeftAway() {
        // existing 9:30-11, draft 9-10 -> existing becomes 10-11
        let p = plan(existing: [entry(id: "e1", 9, 30, 11, 0)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .trim(startTime: d(10, 0), endTime: d(11, 0)))
    }

    func test_newOverlapsRightSideOfExisting_trimsRightAway() {
        // existing 8-9:30, draft 9-10 -> existing becomes 8-9
        let p = plan(existing: [entry(id: "e1", 8, 0, 9, 30)], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .trim(startTime: d(8, 0), endTime: d(9, 0)))
    }

    func test_existingFullyContainsNew_splitsExisting() {
        // existing 9-11, draft 10-10:30 -> existing becomes 9-10 and 10:30-11
        let p = plan(existing: [entry(id: "e1", 9, 0, 11, 0)], drafts: [draft(10, 0, 10, 30)])
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(
            p.resolutions[0].action,
            .split(
                left: DateRange(start: d(9, 0), end: d(10, 0)),
                right: DateRange(start: d(10, 30), end: d(11, 0))
            )
        )
    }

    func test_resolutionCarriesSourceAndCategoryFromExisting() {
        let e = Entry(
            id: "e1",
            captureId: "c1",
            category: "study",
            note: "n",
            startTime: d(9, 0),
            endTime: d(10, 0),
            source: .text,
            transcript: "old",
            createdAt: d(0)
        )
        let p = plan(existing: [e], drafts: [draft(9, 0, 10, 0)])
        XCTAssertEqual(p.resolutions[0].originalSource, .text)
        XCTAssertEqual(p.resolutions[0].category, "study")
        XCTAssertEqual(p.resolutions[0].transcript, "old")
        XCTAssertEqual(p.resolutions[0].captureId, "c1")
    }

    func test_multipleDrafts_resolveAgainstSingleExisting_defensiveDelete() {
        // existing 9-12 spanning two drafts at 9:30-10 and 11-11:30 would
        // produce 3 surviving pieces (9-9:30, 10-11, 11:30-12). The algorithm
        // only supports 0/1/2 pieces and defensively returns .delete.
        let p = plan(
            existing: [entry(id: "e1", 9, 0, 12, 0)],
            drafts: [draft(9, 30, 10, 0), draft(11, 0, 11, 30)]
        )
        XCTAssertEqual(p.resolutions.count, 1)
        XCTAssertEqual(p.resolutions[0].action, .delete)
    }

    func test_multipleExistingEntries_allReceiveResolutions() {
        let p = plan(
            existing: [
                entry(id: "e1", 8, 0, 9, 30),   // partial right overlap
                entry(id: "e2", 10, 0, 11, 0),  // fully contained
            ],
            drafts: [draft(9, 0, 12, 0)]
        )
        XCTAssertEqual(p.resolutions.count, 2)
        let byId = Dictionary(uniqueKeysWithValues: p.resolutions.map { ($0.entryId, $0.action) })
        XCTAssertEqual(byId["e1"], .trim(startTime: d(8, 0), endTime: d(9, 0)))
        XCTAssertEqual(byId["e2"], .delete)
    }

    func test_emptyExisting_returnsEmptyResolutions() {
        let p = plan(existing: [], drafts: [draft(9, 0, 10, 0)])
        XCTAssertTrue(p.resolutions.isEmpty)
        XCTAssertEqual(p.drafts.count, 1)
    }
}
