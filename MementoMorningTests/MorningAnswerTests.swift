import XCTest
import SwiftData
@testable import MementoMorning

/// MorningAnswer のドメインメソッドのテスト
final class MorningAnswerTests: XCTestCase {
    func testSetTextUpdatesTextAndUpdatedDateTime() {
        let answer = MorningAnswer(answeredDate: .now, text: "家族と過ごす")
        let updatedDateTimeBeforeSet = answer.updatedDateTime

        answer.setText(text: "海を見に行く")

        XCTAssertEqual(answer.text, "海を見に行く")
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)
    }

    func testIsFulfilledIsNilOnInitialState() {
        XCTAssertNil(MorningAnswer(answeredDate: .now, text: "家族と過ごす").isFulfilled)
    }

    func testVideoAssetIdentifierIsNilOnTextAnswer() {
        XCTAssertNil(MorningAnswer(answeredDate: .now, text: "家族と過ごす").videoAssetIdentifier)
    }

    func testInitStoresVideoAssetIdentifier() {
        XCTAssertEqual(
            MorningAnswer(answeredDate: .now, text: "動画で答えました", videoAssetIdentifier: "asset-1").videoAssetIdentifier,
            "asset-1"
        )
    }

    func testSetVideoAssetIdentifierUpdatesIdentifierAndUpdatedDateTime() {
        let answer = MorningAnswer(answeredDate: .now, text: "家族と過ごす")
        let updatedDateTimeBeforeSet = answer.updatedDateTime

        answer.setVideoAssetIdentifier(videoAssetIdentifier: "asset-2")

        XCTAssertEqual(answer.videoAssetIdentifier, "asset-2")
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)
    }

    func testSetVideoAssetIdentifierNilClearsIdentifier() {
        // 動画回答の後にテキストで答え直した時、古い動画を指し続けない
        let answer = MorningAnswer(answeredDate: .now, text: "動画で答えました", videoAssetIdentifier: "asset-3")

        answer.setVideoAssetIdentifier(videoAssetIdentifier: nil)

        XCTAssertNil(answer.videoAssetIdentifier)
    }

    func testSetFulfilledUpdatesIsFulfilledAndUpdatedDateTime() {
        let answer = MorningAnswer(answeredDate: .now, text: "家族と過ごす")
        let updatedDateTimeBeforeSet = answer.updatedDateTime

        answer.setFulfilled(isFulfilled: true)

        XCTAssertEqual(answer.isFulfilled, true)
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)

        answer.setFulfilled(isFulfilled: false)

        XCTAssertEqual(answer.isFulfilled, false)
        XCTAssertGreaterThanOrEqual(answer.updatedDateTime, updatedDateTimeBeforeSet)
    }

    /// 指定日の回答の取得 (カレンダーの日付タップから使う) を in-memory DB で確認する
    @MainActor
    func testAnswerOfDay() throws {
        let modelContext = ModelContext(
            try ModelContainer(
                for: PersistenceController.schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
        let calendar = Calendar.current
        // 日付変更の境界で .now が assertion ごとにずれるとテストが不安定になるため、基準の日を固定して全 assertion に渡す
        let today = calendar.startOfDay(for: .now)

        // 未回答の日は nil
        XCTAssertNil(try MorningAnswer.answer(day: today, calendar: calendar, modelContext: modelContext))

        modelContext.insert(MorningAnswer(answeredDate: today, text: "家族と海を見に行く"))
        try modelContext.save()

        XCTAssertEqual(try MorningAnswer.answer(day: today, calendar: calendar, modelContext: modelContext)?.text, "家族と海を見に行く")
        // 回答のない別の日を指定しても取り違えない
        XCTAssertNil(try MorningAnswer.answer(day: calendar.date(byAdding: .day, value: -1, to: today)!, calendar: calendar, modelContext: modelContext))
    }

    /// 日中の時刻を渡しても、その日の 0 時に正規化されて同じ回答が取得できる
    @MainActor
    func testAnswerOfDayNormalizesTimeToStartOfDay() throws {
        let modelContext = ModelContext(
            try ModelContainer(
                for: PersistenceController.schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        modelContext.insert(MorningAnswer(answeredDate: today, text: "友人に手紙を書く"))
        try modelContext.save()

        // 0 時ちょうどではない時刻 (正午) を渡す
        XCTAssertEqual(
            try MorningAnswer.answer(
                day: calendar.date(byAdding: .hour, value: 12, to: today)!,
                calendar: calendar,
                modelContext: modelContext
            )?.text,
            "友人に手紙を書く"
        )
    }
}
