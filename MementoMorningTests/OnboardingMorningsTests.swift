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
/// 6 通りの分岐と、「目的 > 起床 > 満足 > 時間帯 > スマホ習慣」の優先順による上書きを検査する
final class RitualSummaryNoteTests: XCTestCase {
    func testAnswerSomedayWhenGoalStaysUndone() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .undone, wake: nil, satisfaction: nil, dayBegin: nil, firstMinutes: nil),
            .answerSomeday
        )
    }

    func testNoMoreSnoozingWhenCannotWakeWithSingleAlarm() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, wake: .almostNever, satisfaction: nil, dayBegin: nil, firstMinutes: nil),
            .noMoreSnoozing
        )
    }

    func testProudMorningsWhenNotHappyWithMornings() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, wake: nil, satisfaction: .notReally, dayBegin: nil, firstMinutes: nil),
            .proudMornings
        )
    }

    func testDayBeginsMorningWhenDayStartsByEvening() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, wake: nil, satisfaction: nil, dayBegin: .evening, firstMinutes: nil),
            .dayBeginsMorning
        )
    }

    func testFirstMinutesToQuestionWhenScrolling() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, wake: nil, satisfaction: nil, dayBegin: nil, firstMinutes: .scrolling),
            .firstMinutesToQuestion
        )
    }

    func testStartsTomorrowWhenNothingApplies() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: nil, wake: nil, satisfaction: nil, dayBegin: nil, firstMinutes: nil),
            .startsTomorrow
        )
    }

    func testStartsTomorrowWhenAllAnsweredButNoneMatches() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .notReally, wake: .almostAlways, satisfaction: .mostly, dayBegin: .morning, firstMinutes: .ritual),
            .startsTomorrow
        )
    }

    func testUndoneGoalWinsOverEveryOtherAnswer() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .undone, wake: .almostNever, satisfaction: .notReally, dayBegin: .evening, firstMinutes: .scrolling),
            .answerSomeday
        )
    }

    func testWakeWinsOverSatisfactionAndLaterAnswers() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .aFew, wake: .almostNever, satisfaction: .notReally, dayBegin: .evening, firstMinutes: .scrolling),
            .noMoreSnoozing
        )
    }

    func testSatisfactionWinsOverDayBeginAndFirstMinutes() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .aFew, wake: .sometimes, satisfaction: .notReally, dayBegin: .evening, firstMinutes: .scrolling),
            .proudMornings
        )
    }

    func testDayBeginWinsOverFirstMinutes() {
        XCTAssertEqual(
            ritualSummaryNote(undoneGoal: .aFew, wake: .sometimes, satisfaction: .mostly, dayBegin: .evening, firstMinutes: .scrolling),
            .dayBeginsMorning
        )
    }
}

/// pledgeFiresToday のテスト。
/// 設定時刻より前なら当日、設定時刻ちょうど・設定時刻より後なら翌日と判定することを検査する
final class PledgeFiresTodayTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: hour, minute: minute))!
    }

    func testFiresTodayWhenNowIsBeforeAlarmTime() {
        XCTAssertTrue(pledgeFiresToday(alarmTime: date(hour: 7, minute: 0), now: date(hour: 6, minute: 0), calendar: calendar))
    }

    func testFiresTomorrowWhenNowIsAfterAlarmTime() {
        XCTAssertFalse(pledgeFiresToday(alarmTime: date(hour: 7, minute: 0), now: date(hour: 8, minute: 0), calendar: calendar))
    }

    func testFiresTomorrowWhenNowEqualsAlarmTime() {
        XCTAssertFalse(pledgeFiresToday(alarmTime: date(hour: 7, minute: 0), now: date(hour: 7, minute: 0), calendar: calendar))
    }

    func testFiresTodayOneMinuteBeforeAlarmTime() {
        XCTAssertTrue(pledgeFiresToday(alarmTime: date(hour: 7, minute: 0), now: date(hour: 6, minute: 59), calendar: calendar))
    }
}
