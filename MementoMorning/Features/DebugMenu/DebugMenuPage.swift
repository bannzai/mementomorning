import SwiftUI
import SwiftData
import UserNotifications

#if DEBUG
/// 開発者メニュー。動作確認・E2E テストで到達困難な状態を作るための DEBUG 限定ページ
/// (.claude/rules/debug-menu-for-verification.md 参照。リモート simulator からも操作できるようアプリ内 UI で提供する)
struct DebugMenuPage: View {
    /// 検証用の夜リマインドの識別子。本番の夜リマインドは "night-reminder" 接頭辞に一致する保留中の通知を掃除してから登録し直すため、その接頭辞に一致しない別の名前空間にして巻き込まれないようにする
    private static let testRequestIdentifier = "debug-night-reminder"
    /// 検証用の夜リマインドが発火するまでの秒数。アラーム発火の確認は「1〜2 分後」に登録して画面表示で判定する運用に合わせる
    private static let testTimeInterval: TimeInterval = 60

    @Environment(\.modelContext) private var modelContext

    /// オンボーディング完了フラグ。false に戻すと RootView が即座にオンボーディングへ切り替わる
    @AppStorage(.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
    /// 検証用のプレミアム強制フラグ。課金状態のゲート (全履歴・無限追撃) の動作確認に使う (再実行しても壊れない冪等なトグル)
    @AppStorage(.debugPremiumOverride) private var debugPremiumOverride = false

    /// 現在の回答件数。デバッグ操作の結果を画面上で確認できるように表示する
    @State private var morningAnswerCount = 0
    /// 今日の回答。夜の振り返り (isFulfilled) の記録状態を画面上で確認できるように表示する
    @State private var answer: MorningAnswer?

    var body: some View {
        List {
            Section {
                Text(verbatim: "回答件数 (MorningAnswer): \(morningAnswerCount)")
                    .accessibilityIdentifier("debug_morning_answer_count")
                Text(verbatim: "今日の回答: \(answerStateText)")
                    .accessibilityIdentifier("debug_today_answer_state")
            }
            Section {
                Button {
                    seedSampleAnswersIfNeeded(modelContext: modelContext)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "サンプル回答を投入 (10 日分)")
                }
                .accessibilityIdentifier("debug_seed_sample_answers")

                Button(role: .destructive) {
                    deleteAllMorningAnswers()
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "全回答を削除")
                }
                .accessibilityIdentifier("debug_delete_all_answers")

                Button {
                    // 削除は未設定でも成功する (冪等)。リセットすると回答 7 件以上なら ContentView が節目画面を再表示する
                    UserDefaults.standard.removeObject(forKey: .isSevenMorningsMilestonePresented)
                } label: {
                    Text(verbatim: "七つの朝の節目をリセット")
                }
                .accessibilityIdentifier("debug_reset_seven_mornings_milestone")
            }
            // デザインシェル (機能配線前の画面) の描画確認用の導線。
            // 朝の問いはアラーム停止 (#4)、ペイウォールはジャーナルのロック行からも開ける
            Section {
                NavigationLink {
                    QuestionPage()
                } label: {
                    Text(verbatim: "QuestionPage を開く (デザインシェル)")
                }
                .accessibilityIdentifier("debug_open_question_page")

                NavigationLink {
                    PaywallPage()
                } label: {
                    Text(verbatim: "PaywallPage を開く (デザインシェル)")
                }
                .accessibilityIdentifier("debug_open_paywall_page")
            }
            Section {
                Button {
                    seedTodayAnswer()
                } label: {
                    Text(verbatim: "今日の回答を投入")
                }
                .accessibilityIdentifier("debug_seed_today_answer")

                Button {
                    seedYesterdayAnswer()
                } label: {
                    Text(verbatim: "昨日の回答を投入")
                }
                .accessibilityIdentifier("debug_seed_yesterday_answer")

                Button {
                    Task {
                        await scheduleNightReminderForTest()
                        refreshAnswerStates()
                    }
                } label: {
                    Text(verbatim: "夜リマインドを 1 分後に登録")
                }
                .accessibilityIdentifier("debug_schedule_night_reminder_test")
            }
            Section {
                Text(verbatim: "アラーム発火記録: \(alarmFiredStateText)")
                    .accessibilityIdentifier("debug_alarm_fired_state")

                Button {
                    // 発火記録は「直近の発火日時に収束する」冪等な操作。再実行しても記録が今に更新されるだけ
                    recordAlarmFired(date: .now)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "アラーム発火を今すぐ記録")
                }
                .accessibilityIdentifier("debug_record_alarm_fired")

                Button(role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: .lastAlarmFiredDate)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "アラーム発火記録を削除")
                }
                .accessibilityIdentifier("debug_clear_alarm_fired")
            } header: {
                Text(verbatim: "朝の問い (issue #4)")
            }
            Section {
                Text(verbatim: "オンボーディング完了 (hasCompletedOnboarding): \(hasCompletedOnboarding)")
                    .accessibilityIdentifier("debug_onboarding_state")
                // 新規インストール直後のオンボーディングを再現する (フラグを戻すだけで、回答・アラーム設定は消さない。既に false なら何もせず冪等)
                Button {
                    hasCompletedOnboarding = false
                } label: {
                    Text(verbatim: "オンボーディングをリセット")
                }
                .accessibilityIdentifier("debug_reset_onboarding")
            }
            Section {
                Text(verbatim: "プレミアム判定 (isPremium): \(PremiumEntitlement.isPremium)")
                    .accessibilityIdentifier("debug_premium_state")

                Toggle(isOn: $debugPremiumOverride) {
                    Text(verbatim: "プレミアムを強制 (上書き)")
                }
                .accessibilityIdentifier("debug_premium_override_toggle")

                NavigationLink {
                    PaywallPage()
                } label: {
                    Text(verbatim: "ペイウォールを開く")
                }
                .accessibilityIdentifier("debug_open_paywall")
            }
        }
        .navigationTitle(Text(verbatim: "開発者メニュー"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshAnswerStates()
        }
    }

    /// 今日の回答の有無と夜の振り返りの記録状態を表す表示用の文字列
    private var answerStateText: String {
        guard let answer else {
            return "なし"
        }
        return "\(answer.text) (isFulfilled: \(answer.isFulfilled?.description ?? "nil"))"
    }

    /// アラーム発火記録の表示用の文字列
    private var alarmFiredStateText: String {
        lastAlarmFiredDate()?.formatted(.iso8601) ?? "なし"
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

    /// 検証用に昨日の回答を作る。既に昨日の回答があれば何もしない (冪等)。今日の回答には触れない。
    /// 朝の問い画面の「昨日の回答を、今日やる?」の選択式入力は「昨日の回答あり + 今日未回答」でしか出ないため、
    /// 今日の回答がある場合は Delete all answers → 本操作の順で状態を作る
    private func seedYesterdayAnswer() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        guard fetchMorningAnswer(answeredDate: yesterday, modelContext: modelContext) == nil else {
            return
        }
        modelContext.insert(
            MorningAnswer(answeredDate: Calendar.current.startOfDay(for: yesterday), text: "母に長い電話をかける")
        )
        do {
            try modelContext.save()
            refreshAnswerStates()
        } catch {
            // 保存失敗を握りつぶすと未投入なのに投入済みに見えるため、変更を破棄して開発中に気づけるよう落とす
            modelContext.rollback()
            assertionFailure(error.localizedDescription)
        }
    }

    /// 検証用の夜リマインドを 1 分後に登録する。今日の回答があれば本番と同じ引用つきの本文になるため、パーソナライズの表示をその場で確認できる。
    /// 同一識別子の add は保留中の既存リクエストを置換するため、事前削除なしでも何度押しても保留は 1 本に保たれる
    private func scheduleNightReminderForTest() async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return
            }
            try await center.add(
                UNNotificationRequest(
                    identifier: Self.testRequestIdentifier,
                    content: NightReminder.makeContent(answerText: fetchMorningAnswer(answeredDate: .now, modelContext: modelContext)?.text),
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
