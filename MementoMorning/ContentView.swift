import SwiftUI
import SwiftData

/// 起動直後に表示するルート画面 (ホーム)。
/// 基準日 (今日の 0 時) を保持し、日付を跨いで foreground 復帰した時はクエリごと作り直して翌朝の状態に追従させる。
/// 回答が 7 件に達したら、7 日の節目「七つの朝」(SevenMorningsPage) を一度だけ表示する
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    /// ホームの基準日 (今日の 0 時)。HomeContent のクエリ条件と粒ストリップの今日判定の基準になる
    @State private var today = Calendar.current.startOfDay(for: .now)

    /// 7 日の節目の表示判定用。判定は件数 (7 件に達したか) だけを見るため、取得条件は SevenMorningsPage と共有する
    @Query(sevenMorningsAnswersDescriptor) private var sevenMorningsAnswers: [MorningAnswer]

    /// 7 日の節目を表示済みかどうか。初回インストール時は未表示のため false から始める
    @AppStorage(.isSevenMorningsMilestonePresented) private var isSevenMorningsMilestonePresented = false

    /// 7 日の節目画面を表示中かどうか
    @State private var isSevenMorningsPagePresented = false

    var body: some View {
        NavigationStack {
            HomeContent(today: today)
                // 基準日が変わったら @Query の predicate を組み直すため view ごと作り直す
                .id(today)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            today = Calendar.current.startOfDay(for: .now)
        }
        .sheet(isPresented: $isSevenMorningsPagePresented) {
            SevenMorningsPage()
        }
        .onChange(of: sevenMorningsAnswers.count, initial: true) { _, _ in
            presentSevenMorningsIfNeeded()
        }
        // 表示済みフラグのリセット (DEBUG の開発者メニュー) 後に、再起動なしで再表示を確認できるようにする
        .onChange(of: isSevenMorningsMilestonePresented) { _, _ in
            presentSevenMorningsIfNeeded()
        }
    }

    /// 回答が 7 件に達していて未表示なら、7 日の節目画面を表示する
    private func presentSevenMorningsIfNeeded() {
        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に節目画面の表示とフラグの書き込みが走らないようここで打ち切る
        if isUnitTest { return }
        if shouldPresentSevenMorningsMilestone(
            answerCount: sevenMorningsAnswers.count,
            isPresented: isSevenMorningsMilestonePresented
        ) {
            isSevenMorningsPagePresented = true
        }
    }
}


/// ホーム画面本体 (デザイン handoff 1e / プロトタイプ home 準拠)。
/// 次の朝のアラーム時刻を中心に、今朝のことば・直近 14 日の粒ストリップ・各画面へのテキストリンクを置く
private struct HomeContent: View {
    @Environment(\.modelContext) private var modelContext
    /// 保存済みのアラーム設定。単一レコード運用のため先頭 1 件のみ使う
    @Query private var alarmSettings: [AlarmSetting]
    /// 今日の回答 (あれば「今朝のことば」として表示する)
    @Query private var todayAnswers: [MorningAnswer]
    /// 粒ストリップに表示する直近 14 日分の回答
    @Query private var stripAnswers: [MorningAnswer]
    /// 全期間の回答数 (答えた朝 N)。件数だけ必要なため fetchCount で取得して保持する
    @State private var answeredCount = 0
    /// 直近の再スケジュールで発生したエラー。Rescheduler が書き込み、成功時に削除される。
    /// トグル切替の失敗 (画面は OFF なのにアラームが残る等) をホーム上でも可視化する
    @AppStorage(.lastRescheduleError) private var lastRescheduleError: String?

    /// ホームの基準日 (今日の 0 時)。ContentView が日付跨ぎで更新する
    let today: Date

    /// 今日・直近 14 日の predicate は初期化時にしか組めないため、明示的に init を定義する
    init(today: Date) {
        self.today = today
        var todayDescriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == today })
        // 1 日 1 件のため 1 件だけ取得する
        todayDescriptor.fetchLimit = 1
        _todayAnswers = Query(todayDescriptor)

        // 粒ストリップは今日を含む直近 14 日分。1 日 1 件のためこの本数で全日をカバーできる
        let stripStart = Calendar.current.date(byAdding: .day, value: -13, to: today)!
        var stripDescriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate >= stripStart })
        stripDescriptor.fetchLimit = 14
        _stripAnswers = Query(stripDescriptor)
    }

    var body: some View {
        VStack(spacing: 0) {
            nextMorningSection
            todayAnswerSection
            Spacer()
            footerSection
        }
        .frame(maxWidth: .infinity)
        .background(Color.ink.ignoresSafeArea())
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    DebugMenuPage()
                } label: {
                    Label {
                        Text(verbatim: "Developer Menu")
                    } icon: {
                        Image(systemName: "hammer")
                    }
                }
                .accessibilityIdentifier("debug_menu_link")
            }
            #endif
        }
        .onAppear {
            answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        }
    }

    /// 次の朝のアラーム時刻 (大時刻・残り時間・トグル)
    private var nextMorningSection: some View {
        VStack(spacing: 8) {
            // ja: 次の朝 · NEXT MORNING
            Text("NEXT MORNING")
                .font(.system(size: 10))
                .tracking(2.6)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
            if let alarmSetting = alarmSettings.first {
                NavigationLink {
                    AlarmSettingPage()
                } label: {
                    Text(verbatim: String(format: "%d:%02d", alarmSetting.hour, alarmSetting.minute))
                        .font(.system(size: 96, weight: .ultraLight))
                        .foregroundStyle(Color.warmWhite)
                }
                .buttonStyle(.plain)
                if alarmSetting.isEnabled {
                    TimelineView(.everyMinute) { context in
                        let remainingMinutes = Int(
                            nextOccurrence(
                                hour: alarmSetting.hour,
                                minute: alarmSetting.minute,
                                now: context.date,
                                calendar: .current
                            ).timeIntervalSince(context.date) / 60
                        )
                        // ja: あと %lld 時間 %lld 分 · 時刻をタップして変更
                        Text("In \(remainingMinutes / 60) hr \(remainingMinutes % 60) min · Tap the time to change")
                            .font(.system(size: 12))
                            .tracking(0.96)
                            .foregroundStyle(Color.warmWhite.opacity(0.4))
                    }
                } else {
                    // OFF 中はアラームが 1 件もスケジュールされないため、発火予定があるかのようなカウントダウンは出さない
                    // ja: アラームはオフ · 時刻をタップして変更
                    Text("Alarm is off · Tap the time to change")
                        .font(.system(size: 12))
                        .tracking(0.96)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                }
                alarmToggle(alarmSetting: alarmSetting)
                    .padding(.top, 26)
                if let lastRescheduleError, !lastRescheduleError.isEmpty {
                    // エラーメッセージはそのまま表示する (加工しない)。エラーも低彩度で表現する (デザイントークン参照)
                    Text(lastRescheduleError)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.warmWhite.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 36)
                        .accessibilityIdentifier("home_reschedule_error")
                }
            } else {
                NavigationLink {
                    AlarmSettingPage()
                } label: {
                    Text(verbatim: "--:--")
                        .font(.system(size: 96, weight: .ultraLight))
                        .foregroundStyle(Color.warmWhite.opacity(0.45))
                }
                .buttonStyle(.plain)
                // ja: 時刻をタップして設定
                Text("Tap the time to set your alarm")
                    .font(.system(size: 12))
                    .tracking(0.96)
                    .foregroundStyle(Color.warmWhite.opacity(0.4))
            }
        }
        .padding(.top, 110)
    }

    /// アラーム有効/無効のトグル (56×34 の pill。ON 背景は夜明け色 45%)
    private func alarmToggle(alarmSetting: AlarmSetting) -> some View {
        Button {
            toggleAlarm(alarmSetting: alarmSetting)
        } label: {
            ZStack(alignment: alarmSetting.isEnabled ? .trailing : .leading) {
                Capsule()
                    .fill(alarmSetting.isEnabled ? Color.dawn.opacity(0.45) : Color.warmWhite.opacity(0.14))
                Circle()
                    .fill(Color.warmWhite)
                    .frame(width: 28, height: 28)
                    .padding(3)
            }
            .frame(width: 56, height: 34)
            .animation(.easeInOut(duration: 0.3), value: alarmSetting.isEnabled)
        }
        .buttonStyle(.plain)
        // ja: アラーム
        .accessibilityLabel(String(localized: "Alarm"))
        .accessibilityValue(
            alarmSetting.isEnabled
                // ja: オン
                ? Text("On")
                // ja: オフ
                : Text("Off")
        )
        .accessibilityIdentifier("home_alarm_toggle")
    }

    /// 今朝のことば (回答済みの日のみ)。「直す」導線は編集画面 (#25 文字起こし確認の再利用) の実装時に追加する
    @ViewBuilder
    private var todayAnswerSection: some View {
        if let todayAnswer = todayAnswers.first {
            VStack(spacing: 7) {
                // ja: 今朝のことば
                Text("This morning's words")
                    .font(.system(size: 10))
                    .tracking(2.2)
                    .foregroundStyle(Color.dawn)
                // 回答は長さ制限のない自由入力のため、そのままでは収まらない長文だけ
                // 残り高さの範囲でスクロールして全文を読めるようにする
                ViewThatFits(in: .vertical) {
                    todayAnswerText(todayAnswer: todayAnswer)
                    ScrollView {
                        todayAnswerText(todayAnswer: todayAnswer)
                    }
                }
            }
            .padding(.top, 56)
            .accessibilityIdentifier("home_today_answer")
        }
    }

    /// 今朝のことばの回答本文
    private func todayAnswerText(todayAnswer: MorningAnswer) -> some View {
        Text(todayAnswer.text)
            .font(.system(size: 17, weight: .light))
            .tracking(0.68)
            .foregroundStyle(Color.warmWhite)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
    }

    /// 直近 14 日の粒ストリップ + 答えた朝 N + テキストリンク行
    private var footerSection: some View {
        let calendar = Calendar.current
        let answeredDays = Set(stripAnswers.map { calendar.startOfDay(for: $0.answeredDate) })
        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                // 今日を右端に、古い順で 14 日分並べる
                ForEach((0..<14).reversed(), id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                    Circle()
                        .fill(answeredDays.contains(day) ? Color.warmWhite : Color.warmWhite.opacity(0.09))
                        .frame(width: 10, height: 10)
                        .overlay {
                            // 今日の粒だけに夜明け色のリングを添える (アクセントは各画面 1 箇所まで)
                            if day == today {
                                Circle()
                                    .stroke(Color.dawn.opacity(0.35), lineWidth: 3)
                                    .frame(width: 16, height: 16)
                            }
                        }
                }
            }
            // ja: 答えた朝 %lld
            Text("\(answeredCount) mornings answered")
                .font(.system(size: 11))
                .tracking(1.1)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
            HStack(spacing: 8) {
                NavigationLink {
                    AnswerLogPage()
                } label: {
                    // ja: ジャーナル
                    Text("Journal")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                }
                NavigationLink {
                    LifeCalendarPage()
                } label: {
                    // ja: 人生カレンダー
                    Text("Life Calendar")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                }
                NavigationLink {
                    AlarmSettingPage()
                } label: {
                    // ja: 設定
                    Text("Settings")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                }
            }
            .font(.system(size: 13))
            .tracking(1.3)
            .foregroundStyle(Color.warmWhite.opacity(0.65))
            .padding(.top, 12)
        }
        .padding(.bottom, 24)
    }

    /// アラームの有効/無効を切り替えて再スケジュールする。
    /// 再スケジュールの失敗は Rescheduler が lastRescheduleError へ書き込み、@AppStorage 経由でトグル下に表示される
    private func toggleAlarm(alarmSetting: AlarmSetting) {
        alarmSetting.setIsEnabled(isEnabled: !alarmSetting.isEnabled)
        do {
            try modelContext.save()
        } catch {
            // 永続化されていない変更を残すと foreground 復帰時の reschedule が未保存の値を拾うため破棄する
            modelContext.rollback()
            return
        }
        Task { await reschedule(modelContext: modelContext) }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 毎朝 5:50 のアラーム + 今日と昨日の回答がある状態のサンプル
        let _ = {
            let calendar = Calendar.current
            modelContext.insert(AlarmSetting(hour: 5, minute: 50))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: .now), text: "家族と海を見に行く"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: .now)!), text: "友人に手紙を書く"))
            try! modelContext.save()
        }()
        ContentView()
            .modelContainer(container)
    }
}
