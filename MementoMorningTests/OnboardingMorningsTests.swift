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

/// ritualSummaryNote のテスト。
/// 6 通りの分岐と、「目的 > スヌーズ > 記憶 > 時間帯 > スマホ習慣」の優先順による上書きを検査する
final class RitualSummaryNoteTests: XCTestCase {
    func testAnswerSomedayWhenGoalStaysUndone() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .undone, snooze: nil, memory: nil, dayBegin: nil, firstMinutes: nil),
            .answerSomeday
        )
    }

    func testNoMoreSnoozingWhenSnoozingAlmostEveryMorning() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, snooze: .almostEvery, memory: nil, dayBegin: nil, firstMinutes: nil),
            .noMoreSnoozing
        )
    }

    func testMorningsKeptWhenRememberingAlmostNone() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, snooze: nil, memory: .almostNone, dayBegin: nil, firstMinutes: nil),
            .morningsKept
        )
    }

    func testDayBeginsMorningWhenDayStartsByEvening() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, snooze: nil, memory: nil, dayBegin: .evening, firstMinutes: nil),
            .dayBeginsMorning
        )
    }

    func testFirstMinutesToQuestionWhenScrolling() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, snooze: nil, memory: nil, dayBegin: nil, firstMinutes: .scrolling),
            .firstMinutesToQuestion
        )
    }

    func testStartsTomorrowWhenNothingApplies() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, snooze: nil, memory: nil, dayBegin: nil, firstMinutes: nil),
            .startsTomorrow
        )
    }

    func testStartsTomorrowWhenAllAnsweredButNoneMatches() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .notReally, snooze: .rarely, memory: .most, dayBegin: .morning, firstMinutes: .ritual),
            .startsTomorrow
        )
    }

    func testUndoneGoalWinsOverEveryOtherAnswer() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .undone, snooze: .almostEvery, memory: .almostNone, dayBegin: .evening, firstMinutes: .scrolling),
            .answerSomeday
        )
    }

    func testSnoozeWinsOverMemoryAndLaterAnswers() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .aFew, snooze: .almostEvery, memory: .almostNone, dayBegin: .evening, firstMinutes: .scrolling),
            .noMoreSnoozing
        )
    }

    func testMemoryWinsOverDayBeginAndFirstMinutes() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .aFew, snooze: .sometimes, memory: .almostNone, dayBegin: .evening, firstMinutes: .scrolling),
            .morningsKept
        )
    }

    func testDayBeginWinsOverFirstMinutes() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .aFew, snooze: .sometimes, memory: .most, dayBegin: .evening, firstMinutes: .scrolling),
            .dayBeginsMorning
        )
    }
}
