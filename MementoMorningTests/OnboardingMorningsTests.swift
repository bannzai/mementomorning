import XCTest

@testable import MementoMorning

/// morningsResultVariant のテスト。
/// 生まれ年から回数を数えられる場合と、数えずに普遍的な文言へ倒す場合の分岐を検査する
final class OnboardingMorningsTests: XCTestCase {
    func testCountedForTypicalBirthYear() {
        XCTAssertEqual(
            morningsResultVariant(birthYear: 1990, currentYear: 2026),
            .counted(lived: 36 * 365, remaining: (78 - 36) * 365)
        )
    }

    func testUnknownWhenBirthYearIsNotAnswered() {
        XCTAssertEqual(morningsResultVariant(birthYear: 0, currentYear: 2026), .unknown)
    }

    func testUnknownWhenBirthYearIsInTheFuture() {
        XCTAssertEqual(morningsResultVariant(birthYear: 2030, currentYear: 2026), .unknown)
    }

    func testUnknownWhenAgeReachesAverageLifeExpectancy() {
        XCTAssertEqual(morningsResultVariant(birthYear: 2026 - 78, currentYear: 2026), .unknown)
    }

    func testCountedJustBelowAverageLifeExpectancy() {
        XCTAssertEqual(
            morningsResultVariant(birthYear: 2026 - 77, currentYear: 2026),
            .counted(lived: 77 * 365, remaining: 1 * 365)
        )
    }

    func testCountedWhenBornThisYear() {
        XCTAssertEqual(
            morningsResultVariant(birthYear: 2026, currentYear: 2026),
            .counted(lived: 0, remaining: 78 * 365)
        )
    }
}
