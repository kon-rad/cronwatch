import XCTest
@testable import Cronwatch

final class UserSettingsTests: XCTestCase {

    func test_empty_hasDefaultProfileFields() {
        let s = UserSettings.empty
        XCTAssertEqual(s.wantsToBeBetterAt, "")
        XCTAssertEqual(s.workType, "")
        XCTAssertEqual(s.vision3Years, "")
        XCTAssertEqual(s.vision5Years, "")
        XCTAssertEqual(s.vision10Years, "")
        XCTAssertFalse(s.onboardingCompleted)
    }

    func test_hasAnyGoal_falseWhenAllEmpty() {
        XCTAssertFalse(UserSettings.empty.hasAnyGoal)
    }

    func test_hasAnyGoal_trueWhenOneGoalSet() {
        var s = UserSettings.empty
        s.goals[0] = Goal(category: "work", weeklyTargetHours: 10)
        XCTAssertTrue(s.hasAnyGoal)
    }
}
