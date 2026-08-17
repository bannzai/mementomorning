import RevenueCat
import XCTest

@testable import MementoMorning

/// ペイウォールの無料トライアル表記が使う購読期間の変換 (dateComponents(subscriptionPeriod:)) のテスト。
/// 無料トライアルの期間は固定文言ではなく offering の introductory offer から組み立てるため、
/// 単位の取り違え (週を月として出す等) が実際と異なる無料期間の表示に直結する
final class PaywallSubscriptionPeriodTests: XCTestCase {
    /// 日の期間が day に入ること
    func testDayPeriod() {
        XCTAssertEqual(dateComponents(subscriptionPeriod: SubscriptionPeriod(value: 3, unit: .day)).day, 3)
    }

    /// 週の期間が weekOfMonth に入ること (DateComponents に week が無いため)
    func testWeekPeriod() {
        let components = dateComponents(subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .week))
        XCTAssertEqual(components.weekOfMonth, 1)
        XCTAssertNil(components.day)
    }

    /// 月の期間が month に入ること
    func testMonthPeriod() {
        XCTAssertEqual(dateComponents(subscriptionPeriod: SubscriptionPeriod(value: 2, unit: .month)).month, 2)
    }

    /// 年の期間が year に入ること
    func testYearPeriod() {
        XCTAssertEqual(dateComponents(subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .year)).year, 1)
    }

    /// PROJECT.md の課金設計「年額のみ 7 日間無料トライアル」に対応する P1W が
    /// DateComponentsFormatter で期間の文字列になること (英語ロケールで「1 week」)
    func testWeekPeriodFormatsAsDuration() throws {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day]
        formatter.calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US")
            return calendar
        }()

        XCTAssertEqual(
            formatter.string(from: dateComponents(subscriptionPeriod: SubscriptionPeriod(value: 1, unit: .week))),
            "1 week"
        )
    }
}
