import XCTest

@testable import MementoMorning

/// 動画回答の最長録画時間 (issue #71: 10 秒) と、録画中インジケーターの算出のテスト
final class VideoAnswerRecordingLimitTests: XCTestCase {
    func testMaxRecordingDurationIsTenSeconds() {
        XCTAssertEqual(videoAnswerMaxRecordingDuration, 10)
    }

    func testProgressGrowsFromZeroToOne() {
        XCTAssertEqual(videoAnswerRecordingProgress(elapsed: 0), 0)
        XCTAssertEqual(videoAnswerRecordingProgress(elapsed: 2.5), 0.25)
        XCTAssertEqual(videoAnswerRecordingProgress(elapsed: 10), 1)
    }

    func testProgressIsClampedOutsideTheLimit() {
        // 停止デリゲートの遅延で上限を超えた経過時間や、時計のずれによる負の値でも表示を壊さない
        XCTAssertEqual(videoAnswerRecordingProgress(elapsed: 12), 1)
        XCTAssertEqual(videoAnswerRecordingProgress(elapsed: -1), 0)
    }

    func testTimerTextShowsElapsedOverLimit() {
        XCTAssertEqual(videoAnswerRecordingTimerText(elapsed: 0), "0:00 / 0:10")
        // 秒は切り捨て
        XCTAssertEqual(videoAnswerRecordingTimerText(elapsed: 3.9), "0:03 / 0:10")
        XCTAssertEqual(videoAnswerRecordingTimerText(elapsed: 10), "0:10 / 0:10")
    }

    func testTimerTextIsClampedOutsideTheLimit() {
        XCTAssertEqual(videoAnswerRecordingTimerText(elapsed: 12), "0:10 / 0:10")
        XCTAssertEqual(videoAnswerRecordingTimerText(elapsed: -1), "0:00 / 0:10")
    }

    func testDotOpacityBlinksBetweenDesignRange() {
        // 開始時が最も明るく (0.8)、半周期 (0.8 秒) 後に最も暗く (0.25)、1 周期 (1.6 秒) で戻る
        XCTAssertEqual(videoAnswerRecordingDotOpacity(elapsed: 0), 0.8, accuracy: 0.001)
        XCTAssertEqual(videoAnswerRecordingDotOpacity(elapsed: 0.8), 0.25, accuracy: 0.001)
        XCTAssertEqual(videoAnswerRecordingDotOpacity(elapsed: 1.6), 0.8, accuracy: 0.001)
        for elapsed in stride(from: 0.0, through: 10.0, by: 0.1) {
            let opacity = videoAnswerRecordingDotOpacity(elapsed: elapsed)
            XCTAssertGreaterThanOrEqual(opacity, 0.25 - 0.001)
            XCTAssertLessThanOrEqual(opacity, 0.8 + 0.001)
        }
    }
}
