import XCTest
import SwiftUI
@testable import MementoMorning

/// 七つの朝の共有カード (7 件まとめ) の 1 枚画像書き出しのテスト。
/// 日本語・英語どちらの回答でも固定サイズで画像化できることを検証する
@MainActor
final class SevenMorningsShareCardRenderTests: XCTestCase {
    /// 6 日前から今日まで毎朝答えた 7 件分のサンプル回答を作る (SwiftData コンテナへは挿入しない。描画にはプロパティの読み取りしか要らないため)
    private func makeSevenAnswers(texts: [String]) -> [MorningAnswer] {
        texts.enumerated().map { index, text in
            MorningAnswer(
                answeredDate: Calendar.current.startOfDay(
                    for: Calendar.current.date(byAdding: .day, value: index - 6, to: .now)!
                ),
                text: text
            )
        }
    }

    func testRenderJapaneseAnswersProducesFixedSizeImage() {
        let image = renderSevenMorningsShareCardImage(
            answers: makeSevenAnswers(texts: [
                "家族と海を見に行く",
                "母に長い電話をかける",
                "行きつけの店で好きなものを食べる",
                "友人に手紙を書く",
                "子どもと一日中遊ぶ",
                "誰にも言えなかったことを伝える",
                "朝日を最後まで眺める",
            ]),
            locale: Locale(identifier: "ja")
        )
        XCTAssertEqual(image?.size.width, SevenMorningsShareCardView.width)
        XCTAssertEqual(image?.size.height, SevenMorningsShareCardView.height)
    }

    func testRenderEnglishAnswersProducesFixedSizeImage() {
        let image = renderSevenMorningsShareCardImage(
            answers: makeSevenAnswers(texts: [
                "Watch the sea with my family",
                "Call my mother for a long talk",
                "Eat my favorite meal at the usual place",
                "Write a letter to an old friend",
                "Spend the whole day playing with my kids",
                "Say the thing I never dared to say",
                "Watch the sunrise until the very end",
            ]),
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(image?.size.width, SevenMorningsShareCardView.width)
        XCTAssertEqual(image?.size.height, SevenMorningsShareCardView.height)
    }
}
