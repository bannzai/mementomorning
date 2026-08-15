import XCTest
@testable import MementoMorning

/// 7 日の節目「七つの朝」の表示判定のテスト
final class SevenMorningsMilestoneTests: XCTestCase {
    func testNotPresentedUntilSevenAnswers() {
        XCTAssertFalse(shouldPresentSevenMorningsMilestone(answerCount: 0, isPresented: false))
        XCTAssertFalse(shouldPresentSevenMorningsMilestone(answerCount: 6, isPresented: false))
    }

    func testPresentedWhenAnswersReachSeven() {
        XCTAssertTrue(shouldPresentSevenMorningsMilestone(answerCount: 7, isPresented: false))
    }

    /// サンプル投入等で一気に 7 件を超えた場合も表示する
    func testPresentedWhenAnswersExceedSeven() {
        XCTAssertTrue(shouldPresentSevenMorningsMilestone(answerCount: 10, isPresented: false))
    }

    /// 一度表示したら回答が増えても再表示しない (冪等)
    func testNotPresentedTwice() {
        XCTAssertFalse(shouldPresentSevenMorningsMilestone(answerCount: 7, isPresented: true))
        XCTAssertFalse(shouldPresentSevenMorningsMilestone(answerCount: 100, isPresented: true))
    }
}
