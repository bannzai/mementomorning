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
    /// 疑似録画モードのフラグ。カメラの無いシミュレータで動画回答のパイプラインを検証するために使う (冪等なトグル)
    @AppStorage(.debugSimulateVideoAnswer) private var debugSimulateVideoAnswer = false

    /// 現在の回答件数。デバッグ操作の結果を画面上で確認できるように表示する
    @State private var morningAnswerCount = 0
    /// 検証用の夜リマインド (debug-night-reminder) が保留中かどうか。
    /// 登録の非同期 Task の完了を E2E が画面表示で待てるようにする
    @State private var isTestNightReminderScheduled = false
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
                        await refreshTestNightReminderState()
                        refreshAnswerStates()
                    }
                } label: {
                    Text(verbatim: "夜リマインドを 1 分後に登録")
                }
                .accessibilityIdentifier("debug_schedule_night_reminder_test")

                // 登録は非同期 Task のため、E2E (Maestro) はこの表示が「登録済み」へ変わるのを待ってから
                // アプリを再起動する (完了前に stopApp するとテスト通知が登録されないままになる)
                Text(verbatim: "検証用夜リマインド: \(isTestNightReminderScheduled ? "登録済み" : "なし")")
                    .accessibilityIdentifier("debug_night_reminder_test_state")

                Button {
                    // 通知タップと同じ経路 (NotificationRouter) で夜の振り返りを開く。
                    // 通知バナーのタップは Maestro から安定して検出できないため、画面自体の確認・収録はここから行う
                    NotificationRouter.shared.nightReflectionNotificationDate = .now
                    NotificationRouter.shared.isNightReflectionPresented = true
                } label: {
                    Text(verbatim: "夜の振り返りを開く (通知タップ相当)")
                }
                .accessibilityIdentifier("debug_open_night_reflection")
            }
            Section {
                Button {
                    // ホームの「NEXT MORNING 7:00」表示をデモ収録・スクリーンショットで安定させるための定番時刻
                    Task { await setAlarm(fireDate: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!) }
                } label: {
                    Text(verbatim: "アラームを 7:00 に設定")
                }
                .accessibilityIdentifier("debug_set_alarm_seven_am")

                Button {
                    // アラーム発火の確認は「1〜2 分後のアラーム」で行う運用 (CLAUDE.md 検証方法) に合わせ、
                    // 分単位への切り捨て後も必ず 1 分以上先になる 120 秒後を発火時刻にする
                    Task { await setAlarm(fireDate: .now.addingTimeInterval(120)) }
                } label: {
                    Text(verbatim: "アラームを 2 分後に設定")
                }
                .accessibilityIdentifier("debug_set_alarm_in_two_minutes")

                // 回答済みの日は planAlarms が計画から除外するため、今日回答済みだと 2 分後に設定しても当日は鳴らない。
                // ボタンの前提条件として明示する (発火確認は「全回答を削除」→ 本ボタンの順で行う)
                Text(verbatim: "2 分後の発火確認は今日未回答が前提 (回答済みの日は鳴らない)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(verbatim: "アラーム設定 (issue #94)")
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
                // ON にすると VideoAnswerCamera が AVCapture を使わず、録画停止でフィクスチャ動画を
                // 「録画結果」として返す。以降 (写真ライブラリ保存・文字起こし・回答成立・アラームキャンセル) は本物のコードを通る
                Toggle(isOn: $debugSimulateVideoAnswer) {
                    Text(verbatim: "動画回答を疑似再現")
                }
                .accessibilityIdentifier("debug_simulate_video_answer")

                Text(verbatim: "フィクスチャの発話: \(debugVideoAnswerFixtureUtterance)")
                    .accessibilityIdentifier("debug_video_answer_fixture_utterance")

                Text(verbatim: "フィクスチャの同梱: \(debugVideoAnswerFixtureURL != nil)")
                    .accessibilityIdentifier("debug_video_answer_fixture_bundled")
            } header: {
                Text(verbatim: "動画回答 (issue #52)")
            }
            Section {
                Text(verbatim: "共有ダイアログの直近表示: \(sharePromptStateText)")
                    .accessibilityIdentifier("debug_share_prompt_state")

                Button {
                    // 削除は未記録でも成功する (冪等)。リセットすると今日の回答があればホームが共有を促すダイアログを再表示する
                    UserDefaults.standard.removeObject(forKey: .lastSharePromptDate)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "共有ダイアログの記録をリセット")
                }
                .accessibilityIdentifier("debug_reset_share_prompt")

                Button {
                    // 「2 週間おき」の再表示を待たずに確認するため、記録を 14 日前の同時刻へ戻す (何度押しても同じ日時に収束する冪等な操作)
                    recordSharePromptPresented(date: Calendar.current.date(byAdding: .day, value: -sharePromptIntervalDays, to: .now)!)
                    refreshAnswerStates()
                } label: {
                    Text(verbatim: "共有ダイアログの記録を 14 日前にする")
                }
                .accessibilityIdentifier("debug_backdate_share_prompt")
            } header: {
                Text(verbatim: "共有 (issue #74)")
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
            Task { await refreshTestNightReminderState() }
        }
    }

    /// 検証用の夜リマインドが保留中かを問い合わせて表示を最新化する
    private func refreshTestNightReminderState() async {
        isTestNightReminderScheduled = await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .contains { $0.identifier == Self.testRequestIdentifier }
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

    /// 共有を促すダイアログの直近表示日時の表示用の文字列
    private var sharePromptStateText: String {
        lastSharePromptDate()?.formatted(.iso8601) ?? "なし"
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
            // ホーム画面ウィジェットを未回答表示へ戻す (issue #46)
            reloadHomeWidgetTimelines()
        } catch {
            // 削除が永続化されていないのに Live Activity だけ畳むと表示と実データがずれるため、破棄して中断する
            modelContext.rollback()
            assertionFailure(error.localizedDescription)
            return
        }
        // 今日の回答が消えたので、ロック画面の「今日の目標」(Live Activity) も畳む
        Task { await refreshTodayAnswerLiveActivity(todayAnswerText: nil) }
    }

    /// 検証用に今日の回答を作る。既に今日の回答があれば何もしない。
    /// バックグラウンド遷移なしでロック画面の表示を確認できるよう、Live Activity の開始もその場で行う
    private func seedTodayAnswer() {
        guard fetchMorningAnswer(answeredDate: .now, modelContext: modelContext) == nil else {
            return
        }
        // ja: 自分のアプリを世界に出す
        let answer = MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: String(localized: "Ship my app to the world"))
        modelContext.insert(answer)
        do {
            try modelContext.save()
        } catch {
            // 保存されていない回答で Live Activity を開始しない (表示と実データがずれる)。破棄して中断する
            modelContext.rollback()
            assertionFailure(error.localizedDescription)
            return
        }
        // 投入した今日の回答をホーム画面ウィジェットへ反映する (issue #46)。保存の失敗時にリロードすると
        // 未保存の状態でウィジェットだけ更新要求が走るため、保存の成功後に限る
        reloadHomeWidgetTimelines()
        refreshAnswerStates()
        Task { await refreshTodayAnswerLiveActivity(todayAnswerText: answer.text) }
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
            // ja: 母に長い電話をかける
            MorningAnswer(answeredDate: Calendar.current.startOfDay(for: yesterday), text: String(localized: "Have a long phone call with my mother"))
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

    /// アラーム設定を fireDate の時・分へ更新して有効化し、再スケジュールする (単一レコード運用。無ければ作成する)。
    /// 何度実行しても同じ時刻・有効状態に収束する冪等な操作
    private func setAlarm(fireDate: Date) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
        do {
            if let alarmSetting = try modelContext.fetch(FetchDescriptor<AlarmSetting>()).first {
                alarmSetting.setTime(hour: components.hour!, minute: components.minute!)
                alarmSetting.setIsEnabled(isEnabled: true)
            } else {
                modelContext.insert(AlarmSetting(hour: components.hour!, minute: components.minute!))
            }
            try modelContext.save()
        } catch {
            // 保存されていない設定で AlarmKit へ登録しない (表示と実データがずれる)。破棄して中断する
            modelContext.rollback()
            assertionFailure(error.localizedDescription)
            return
        }
        await reschedule(modelContext: modelContext)
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
