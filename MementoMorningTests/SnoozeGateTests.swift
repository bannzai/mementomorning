import XCTest
import SwiftData
@testable import MementoMorning

/// スヌーズ上限の判定 (isSnoozeLimitSelectable / effectiveSnoozeLimit / shouldChase) のテスト。
/// 無料は freeTierSnoozeLimit (2 回) を境界に打ち切られ、プレミアムは設定した回数まで・無制限なら回数によらず追撃されることを確認する
final class SnoozeGateTests: XCTestCase {
    func testFreeTierChasesUntilLimit() {
        XCTAssertTrue(shouldChase(chaseCount: 0, snoozeLimit: nil, isPremium: false))
        XCTAssertTrue(shouldChase(chaseCount: 1, snoozeLimit: nil, isPremium: false))
    }

    func testFreeTierStopsChasingAtLimit() {
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit, snoozeLimit: nil, isPremium: false))
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit + 1, snoozeLimit: nil, isPremium: false))
    }

    func testFreeTierRespectsSmallerSelectedLimit() {
        XCTAssertTrue(shouldChase(chaseCount: 0, snoozeLimit: 1, isPremium: false))
        XCTAssertFalse(shouldChase(chaseCount: 1, snoozeLimit: 1, isPremium: false))
    }

    func testFreeTierClampsPremiumOnlyLimitToFreeTier() {
        // プレミアム失効後に残った回数や無制限は無料枠 (freeTierSnoozeLimit) に丸める
        XCTAssertEqual(effectiveSnoozeLimit(snoozeLimit: 10, isPremium: false), freeTierSnoozeLimit)
        XCTAssertEqual(effectiveSnoozeLimit(snoozeLimit: nil, isPremium: false), freeTierSnoozeLimit)
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit, snoozeLimit: 10, isPremium: false))
    }

    func testPremiumChasesUntilSelectedLimit() {
        XCTAssertEqual(effectiveSnoozeLimit(snoozeLimit: 5, isPremium: true), 5)
        XCTAssertTrue(shouldChase(chaseCount: 4, snoozeLimit: 5, isPremium: true))
        XCTAssertFalse(shouldChase(chaseCount: 5, snoozeLimit: 5, isPremium: true))
    }

    func testPremiumUnlimitedChasesWithoutLimit() {
        XCTAssertNil(effectiveSnoozeLimit(snoozeLimit: nil, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: 0, snoozeLimit: nil, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: freeTierSnoozeLimit, snoozeLimit: nil, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: 100, snoozeLimit: nil, isPremium: true))
    }

    func testSnoozeLimitSelectability() {
        // 無料は freeTierSnoozeLimit までの回数だけ選べ、それを超える回数と無制限はプレミアム限定
        XCTAssertTrue(isSnoozeLimitSelectable(snoozeLimit: 1, isPremium: false))
        XCTAssertTrue(isSnoozeLimitSelectable(snoozeLimit: freeTierSnoozeLimit, isPremium: false))
        XCTAssertFalse(isSnoozeLimitSelectable(snoozeLimit: freeTierSnoozeLimit + 1, isPremium: false))
        XCTAssertFalse(isSnoozeLimitSelectable(snoozeLimit: nil, isPremium: false))
        XCTAssertTrue(isSnoozeLimitSelectable(snoozeLimit: snoozeLimitChoices.upperBound, isPremium: true))
        XCTAssertTrue(isSnoozeLimitSelectable(snoozeLimit: nil, isPremium: true))
    }

    func testFreeTierSnoozeLimitMatchesPricingPlan() {
        // documents/PROJECT.md の課金設計「スヌーズ 2 回まで」と一致していることを固定する
        XCTAssertEqual(freeTierSnoozeLimit, 2)
        // issue #73 の選択肢「1〜10 の数字と無限」。無料枠は選択肢の範囲内にある
        XCTAssertEqual(snoozeLimitChoices, 1...10)
        XCTAssertTrue(snoozeLimitChoices.contains(freeTierSnoozeLimit))
    }

    /// スヌーズ間隔は未設定 (nil) と選択肢の範囲外を既定の 2 分に倒し、範囲内の設定値をそのまま使う
    func testEffectiveSnoozeIntervalMinutes() {
        XCTAssertEqual(effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: nil), defaultSnoozeIntervalMinutes)
        XCTAssertEqual(effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: 1), 1)
        XCTAssertEqual(effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: 5), 5)
        XCTAssertEqual(effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: snoozeIntervalChoices.upperBound), snoozeIntervalChoices.upperBound)
        // 改ざん・将来の選択肢変更で残った範囲外の値は既定値に倒す
        XCTAssertEqual(effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: 0), defaultSnoozeIntervalMinutes)
        XCTAssertEqual(effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: snoozeIntervalChoices.upperBound + 1), defaultSnoozeIntervalMinutes)
    }

    /// スヌーズ間隔の選択肢と既定値を固定する (issue #135。既定は設定導入前の固定値 2 分を踏襲)
    func testSnoozeIntervalChoicesAndDefault() {
        XCTAssertEqual(snoozeIntervalChoices, 1...10)
        XCTAssertEqual(defaultSnoozeIntervalMinutes, 2)
        XCTAssertTrue(snoozeIntervalChoices.contains(defaultSnoozeIntervalMinutes))
    }

    /// 追撃カウントのリセット条件 (今日の回答の有無) の判定を in-memory DB で確認する
    @MainActor
    func testHasTodayAnswer() throws {
        let container = try ModelContainer(
            for: PersistenceController.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let modelContext = ModelContext(container)
        let calendar = Calendar.current
        // 日付変更の境界で .now が assertion ごとにずれるとテストが不安定になるため、now を固定して全 assertion に渡す
        let now = Date.now
        let today = calendar.startOfDay(for: now)

        XCTAssertFalse(hasTodayAnswer(modelContext: modelContext, calendar: calendar, now: now))

        // 昨日の回答だけでは「今日の回答あり」にならない
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        modelContext.insert(MorningAnswer(answeredDate: yesterday, text: "友人に手紙を書く"))
        try modelContext.save()
        XCTAssertFalse(hasTodayAnswer(modelContext: modelContext, calendar: calendar, now: now))

        modelContext.insert(MorningAnswer(answeredDate: today, text: "家族と海を見に行く"))
        try modelContext.save()
        XCTAssertTrue(hasTodayAnswer(modelContext: modelContext, calendar: calendar, now: now))
    }
}
