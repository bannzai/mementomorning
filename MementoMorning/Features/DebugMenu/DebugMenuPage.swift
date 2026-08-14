import SwiftUI
import SwiftData
import UserNotifications

#if DEBUG
/// 開発者メニュー。動作確認・E2E テストで到達困難な状態を作るための DEBUG 限定ページ
/// (.claude/rules/debug-menu-for-verification.md 参照。リモート simulator からも操作できるようアプリ内 UI で提供する)
struct DebugMenuPage: View {
    /// 検証用の夜リマインドの識別子。本番の夜リマインド (night-reminder) と分けて、互いのスケジュールを壊さないようにする
    private static let testRequestIdentifier = "night-reminder-debug"
    /// 検証用の夜リマインドが発火するまでの秒数。アラーム発火の確認は「1〜2 分後」に登録して画面表示で判定する運用に合わせる
    private static let testTimeInterval: TimeInterval = 60

    @Environment(\.modelContext) private var modelContext

    /// 現在の回答件数。デバッグ操作の結果を画面上で確認できるように表示する
    @State private var morningAnswerCount = 0
    /// 今日の回答。夜の振り返り (isFulfilled) の記録状態を画面上で確認できるように表示する
    @State private var answer: MorningAnswer?

    var body: some View {
        List {
            Section {
                Text(verbatim: "MorningAnswer: \(morningAnswerCount)")
                    .accessibilityIdentifier("debug_morning_answer_count")
                Text(verbatim: "Today's answer: \(answerStateText)")
                    .accessibilityIdentifier("debug_today_answer_state")
            }
            Section {
                Button {
                    seedSampleAnswersIfNeeded(modelContext: modelContext)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "Seed sample answers (10 days)")
                }
                .accessibilityIdentifier("debug_seed_sample_answers")

                Button(role: .destructive) {
                    deleteAllMorningAnswers()
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "Delete all answers")
                }
                .accessibilityIdentifier("debug_delete_all_answers")
            }
            Section {
                Button {
                    seedTodayAnswer()
                } label: {
                    Text(verbatim: "Seed today's answer")
                }
                .accessibilityIdentifier("debug_seed_today_answer")

                Button {
                    Task {
                        await scheduleNightReminderForTest()
                        refreshAnswerStates()
                    }
                } label: {
                    Text(verbatim: "Schedule night reminder in 1 minute")
                }
                .accessibilityIdentifier("debug_schedule_night_reminder_test")
            }
            Section {
                Text(verbatim: "Alarm fired: \(alarmFiredStateText)")
                    .accessibilityIdentifier("debug_alarm_fired_state")

                Button {
                    // 発火記録は「直近の発火日時に収束する」冪等な操作。再実行しても記録が今に更新されるだけ
                    recordAlarmFired(date: .now)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "Record alarm fired now")
                }
                .accessibilityIdentifier("debug_record_alarm_fired")

                Button(role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: .lastAlarmFiredDate)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "Clear alarm fired record")
                }
                .accessibilityIdentifier("debug_clear_alarm_fired")
            } header: {
                Text(verbatim: "Morning Question (issue #4)")
            }
        }
        .navigationTitle(Text(verbatim: "Developer Menu"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshAnswerStates()
        }
    }

    /// 今日の回答の有無と夜の振り返りの記録状態を表す表示用の文字列
    private var answerStateText: String {
        guard let answer else {
            return "none"
        }
        return "\(answer.text) (isFulfilled: \(answer.isFulfilled?.description ?? "nil"))"
    }

    /// アラーム発火記録の表示用の文字列
    private var alarmFiredStateText: String {
        lastAlarmFiredDate()?.formatted(.iso8601) ?? "none"
    }

    /// 回答件数と今日の回答の表示を最新化する
    private func refreshAnswerStates() {
        morningAnswerCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        answer = fetchMorningAnswer(answeredDate: .now, modelContext: modelContext)
    }

    /// 全回答を削除する (空の状態からやり直すためのデバッグ操作。空なら何もせず冪等)
    private func deleteAllMorningAnswers() {
        do {
            try modelContext.delete(model: MorningAnswer.self)
            try modelContext.save()
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    /// 検証用に今日の回答を作る。既に今日の回答があれば何もしない
    private func seedTodayAnswer() {
        guard fetchMorningAnswer(answeredDate: .now, modelContext: modelContext) == nil else {
            return
        }
        modelContext.insert(
            MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: "家族と海を見に行く")
        )
        try? modelContext.save()
        refreshAnswerStates()
    }

    /// 検証用の夜リマインドを 1 分後に登録する。同一識別子の add は保留中の既存リクエストを置換するため、事前削除なしでも何度押しても保留は 1 本に保たれる
    private func scheduleNightReminderForTest() async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return
            }
            try await center.add(
                UNNotificationRequest(
                    identifier: Self.testRequestIdentifier,
                    content: NightReminder.makeContent(),
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: Self.testTimeInterval, repeats: false)
                )
            )
        } catch {
            print("[DebugMenuPage] failed to schedule test night reminder: \(error)")
        }
    }
}

struct DebugMenuPage_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DebugMenuPage()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
#endif
