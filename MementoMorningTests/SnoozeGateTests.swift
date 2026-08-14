import XCTest
import SwiftData
@testable import MementoMorning

/// shouldChase (追撃アラーム再登録の可否判定) のテスト。
/// 無料は freeTierSnoozeLimit (2 回) を境界に打ち切られ、プレミアムは回数によらず追撃されることを確認する
final class SnoozeGateTests: XCTestCase {
    func testFreeTierChasesUntilLimit() {
        XCTAssertTrue(shouldChase(chaseCount: 0, isPremium: false))
        XCTAssertTrue(shouldChase(chaseCount: 1, isPremium: false))
    }

    func testFreeTierStopsChasingAtLimit() {
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit, isPremium: false))
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit + 1, isPremium: false))
    }

    func testPremiumChasesWithoutLimit() {
        XCTAssertTrue(shouldChase(chaseCount: 0, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: freeTierSnoozeLimit, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: 100, isPremium: true))
    }

    func testFreeTierSnoozeLimitMatchesPricingPlan() {
        // documents/PROJECT.md の課金設計「スヌーズ 2 回まで」と一致していることを固定する
        XCTAssertEqual(freeTierSnoozeLimit, 2)
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

        XCTAssertFalse(hasTodayAnswer(modelContext: modelContext, calendar: calendar))

        // 昨日の回答だけでは「今日の回答あり」にならない
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        modelContext.insert(MorningAnswer(answeredDate: yesterday, text: "友人に手紙を書く"))
        try modelContext.save()
        XCTAssertFalse(hasTodayAnswer(modelContext: modelContext, calendar: calendar))

        modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: .now), text: "家族と海を見に行く"))
        try modelContext.save()
        XCTAssertTrue(hasTodayAnswer(modelContext: modelContext, calendar: calendar))
    }
}
