import XCTest
import SwiftUI
@testable import MementoMorning

/// 共有カードの 1 枚画像書き出しのテスト。日本語・英語どちらの回答でも固定サイズで画像化できることを検証する
@MainActor
final class AnswerShareCardRenderTests: XCTestCase {
    func testRenderJapaneseAnswerProducesFixedSizeImage() {
        let image = renderAnswerShareCardImage(
            answeredDate: .now,
            text: "家族と海を見に行く。それから、母に長い電話をかける",
            locale: Locale(identifier: "ja")
        )
        XCTAssertEqual(image?.size.width, AnswerShareCardView.sideLength)
        XCTAssertEqual(image?.size.height, AnswerShareCardView.sideLength)
    }

    func testRenderEnglishAnswerProducesFixedSizeImage() {
        let image = renderAnswerShareCardImage(
            answeredDate: .now,
            text: "Watch the sunrise with my family, then call my mother for a long talk",
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(image?.size.width, AnswerShareCardView.sideLength)
        XCTAssertEqual(image?.size.height, AnswerShareCardView.sideLength)
    }
}
