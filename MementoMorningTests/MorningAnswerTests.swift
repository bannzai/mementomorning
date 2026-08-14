import XCTest
@testable import MementoMorning

/// MorningAnswer のドメインメソッドのテスト
final class MorningAnswerTests: XCTestCase {
    func testSetTextUpdatesTextAndUpdatedDateTime() {
        let answer = MorningAnswer(answeredDate: .now, text: "家族と過ごす")
        let updatedDateTimeBeforeSet = answer.updatedDateTime

        answer.setText(text: "海を見に行く")

        XCTAssertEqual(answer.text, "海を見に行く")
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)
    }

    func testIsFulfilledIsNilOnInitialState() {
        XCTAssertNil(MorningAnswer(answeredDate: .now, text: "家族と過ごす").isFulfilled)
    }

    func testSetFulfilledUpdatesIsFulfilledAndUpdatedDateTime() {
        let answer = MorningAnswer(answeredDate: .now, text: "家族と過ごす")
        let updatedDateTimeBeforeSet = answer.updatedDateTime

        answer.setFulfilled(isFulfilled: true)

        XCTAssertEqual(answer.isFulfilled, true)
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)

        answer.setFulfilled(isFulfilled: false)

        XCTAssertEqual(answer.isFulfilled, false)
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)
    }
}
