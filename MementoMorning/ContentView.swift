import Combine
import SwiftUI
import SwiftData

/// 起動直後に表示するルート画面 (ホーム)。
/// 基準日 (今日の 0 時) を保持し、日付を跨いで foreground 復帰した時はクエリごと作り直して翌朝の状態に追従させる。
/// 回答が 7 件に達したら、7 日の節目「七つの朝」(SevenMorningsPage) を一度だけ表示する
struct ContentView: View {
    /// RootView が朝の問い (fullScreenCover) や夜の振り返り (sheet) を提示中かどうか。
    /// 共有を促すダイアログ (issue #74) はホームが前面にある時にだけ出すため、提示中は出さず閉じた後に判定し直す
    var isRootModalPresented = false

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
            HomeContent(
                today: today,
                // 7 日の節目のシートも同じモーダル層に出るため、閉じるまで共有を促すダイアログを出さない
                isCoveredByOtherScreen: isRootModalPresented || isSevenMorningsPagePresented
            )
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
        // 表示済みフラグのリセット (開発者メニュー) 後に、再起動なしで再表示を確認できるようにする
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
    /// 全期間の回答数 (答えた日数 N)。件数だけ必要なため全 MorningAnswer を @Query で保持せず fetchCount で取得し、
    /// SwiftData の保存通知 (ModelContext.didSave) で再計算して過去分を含む回答の追加・削除に追随させる
    @State private var answeredCount = 0
    /// 編集画面 (AnswerEditPage) を開く対象の回答
    @State private var editTargetAnswer: MorningAnswer?
    /// 共有カード (AnswerShareCardPage) を開く対象の回答。「共有」リンクと共有を促すダイアログの両方から開く
    @State private var shareTargetAnswer: MorningAnswer?
    /// 共有を促すダイアログ (issue #74) を表示中かどうか
    @State private var isSharePromptPresented = false
    /// 共有を促すダイアログを直近に表示した日時 (epoch 秒。0 = 未記録)。
    /// Date は @AppStorage で扱えないため Double で監視し、読み取りは lastSharePromptDate() を使う
    @AppStorage(.lastSharePromptDate) private var lastSharePromptDate: Double = 0
    /// 7 日の節目を表示済みかどうか。節目の提示が確定する前に共有を促すダイアログを出さないための判定に使う
    @AppStorage(.isSevenMorningsMilestonePresented) private var isSevenMorningsMilestonePresented = false
    /// 直近の再スケジュールで発生したエラー。Rescheduler が書き込み、成功時に削除される。
    /// トグル切替の失敗 (画面は OFF なのにアラームが残る等) をホーム上でも可視化する
    @AppStorage(.lastRescheduleError) private var lastRescheduleError: String?

    /// ホームの基準日 (今日の 0 時)。ContentView が日付跨ぎで更新する
    let today: Date
    /// ホームの上に別画面 (朝の問い・夜の振り返り・7 日の節目) が提示されているかどうか。
    /// 提示中に共有を促すダイアログを出すと、その画面と一緒に閉じられたり提示に失敗したりするため、閉じた後に出す
    let isCoveredByOtherScreen: Bool

    /// 今日の predicate は初期化時にしか組めないため、明示的に init を定義する
    init(today: Date, isCoveredByOtherScreen: Bool) {
        self.today = today
        self.isCoveredByOtherScreen = isCoveredByOtherScreen
        var todayDescriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == today })
        // 1 日 1 件のため 1 件だけ取得する
        todayDescriptor.fetchLimit = 1
        _todayAnswers = Query(todayDescriptor)
    }

    var body: some View {
        VStack(spacing: 0) {
            nextMorningSection
            todayAnswerSection
            Spacer()
            footerSection
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Color.ink
                // 答えた朝の粒が背景として下から積もる (issue #117)。前面の操作 UI を妨げないよう当たり判定は持たせない。
                // 粒は温白 9% (未回答の粒と同じ弱さ) で、大時刻や文字の可読性を保つ
                MorningDotsPhysicsView(
                    dotCount: answeredCount,
                    dotDiameter: 12,
                    dotColor: UIColor(Color.warmWhite.opacity(0.09)),
                    newestDotRingColor: nil
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
        .toolbar {
            #if DEBUG
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    DebugMenuPage()
                } label: {
                    Label {
                        Text(verbatim: "開発者メニュー")
                    } icon: {
                        Image(systemName: "hammer")
                    }
                }
                .accessibilityIdentifier("debug_menu_link")
            }
            #endif
        }
        .sheet(item: $editTargetAnswer) { answer in
            AnswerEditPage(answer: answer)
        }
        .sheet(item: $shareTargetAnswer) { answer in
            AnswerShareCardPage(answer: answer)
        }
        // ja: 今朝のことばを、共有しませんか
        .alert("Share this morning's words?", isPresented: $isSharePromptPresented, presenting: todayAnswers.first) { answer in
            Button {
                shareTargetAnswer = answer
            } label: {
                // ja: 共有
                Text("Share")
            }
            Button(role: .cancel) {
            } label: {
                // ja: 今はしない
                Text("Not now")
            }
        } message: { _ in
            // ja: 今朝のことばが、静かな一枚のカードになります
            Text("Your answer becomes a quiet card you can pass along.")
        }
        .onAppear {
            answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        }
        // 回答の保存・削除 (過去分を含む) のたびに「答えた日数」を再計算する。
        // 朝の問い (fullScreenCover) が閉じてもホームの onAppear は再発火しないため、保存通知を再計算の起点にする
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        }
        // 回答が成立してホームへ戻った時 (今日の回答が現れた時)・起動時点で今日の回答がある時に加え、
        // 動画回答の文字起こしの完了や「直す」で本文が仮テキストから変わった時にも判定する
        .onChange(of: todayAnswers.first?.text, initial: true) { _, _ in
            presentSharePromptIfNeeded()
        }
        // 朝の問い・7 日の節目などが閉じてホームが前面に戻った時に判定し直す
        .onChange(of: isCoveredByOtherScreen) { _, _ in
            presentSharePromptIfNeeded()
        }
        // 表示記録のリセット (開発者メニュー) 後に、再起動なしで再表示を確認できるようにする
        .onChange(of: lastSharePromptDate) { _, _ in
            presentSharePromptIfNeeded()
        }
    }

    /// 今日の回答があり、初回または前回の表示から 2 週間以上経っていれば、共有を促すダイアログを表示する。
    /// 表示した時点で日時を記録し、ユーザーが「あとで」を選んでも同じ 2 週間の中では再表示しない
    private func presentSharePromptIfNeeded() {
        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中にダイアログの表示と記録の書き込みが走らないよう打ち切る。
        // 多言語スクリーンショット・Preview は今日の回答を持つサンプルを表示するため、撮影・描画確認をダイアログで覆わない
        if isUnitTest || isSnapshotUITest || isPreview { return }
        if isCoveredByOtherScreen || isSharePromptPresented { return }
        // 7 件目の回答が成立した更新では、親 (ContentView) が節目シートを提示する変更がまだ isCoveredByOtherScreen に
        // 伝わっていないことがある。節目が提示されるべき状態 (件数が 7 件以上で未表示) なら節目を優先して待ち、
        // シートが閉じて isCoveredByOtherScreen が変わった時に判定し直す (節目シートの上に出したり、競合で出ないまま記録したりしない)
        if shouldPresentSevenMorningsMilestone(
            answerCount: (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0,
            isPresented: isSevenMorningsMilestonePresented
        ) { return }
        guard shouldPresentSharePrompt(
            todayAnswerText: todayAnswers.first?.text,
            placeholderText: videoAnswerPlaceholderText,
            lastPromptedDate: MementoMorning.lastSharePromptDate(),
            today: today
        ) else { return }
        recordSharePromptPresented(date: .now)
        isSharePromptPresented = true
    }

    /// 次の朝のアラーム時刻 (大時刻・残り時間・トグル)
    private var nextMorningSection: some View {
        VStack(spacing: 8) {
            // ja: アラーム
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
                    .fill(alarmSetting.isEnabled ? Color.alarmToggleOn : Color.warmWhite.opacity(0.14))
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

    /// 今朝のことば (回答済みの日のみ)。
    /// 動画回答の文字起こしの誤認識を直せるよう、本文の下に編集画面 (AnswerEditPage) への「直す」導線を置く
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
                HStack(spacing: 20) {
                    Button {
                        editTargetAnswer = todayAnswer
                    } label: {
                        // ja: 直す
                        Text("Fix")
                            .underline()
                    }
                    .accessibilityIdentifier("home_today_answer_edit_link")
                    // 撮影後にジャーナルへ回らなくても、今朝のことばをその場から共有カードにできる導線 (issue #74)。
                    // 動画回答の文字起こしが終わる前 (本文が仮テキストのまま) は、仮テキストのカードを共有させないため出さない
                    if todayAnswer.text != videoAnswerPlaceholderText {
                        Button {
                            shareTargetAnswer = todayAnswer
                        } label: {
                            // ja: 共有
                            Text("Share")
                                .underline()
                        }
                        .accessibilityIdentifier("home_today_answer_share_link")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.warmWhite.opacity(0.55))
                .padding(.top, 5)
            }
            .padding(.top, 56)
            // accessibilityIdentifier を素の VStack に付けると子要素の identifier まで上書きされ、
            // 「直す」ボタン (home_today_answer_edit_link) を自動操作から引けなくなる。
            // コンテナ要素として宣言して、自身の identifier と子の identifier を両立させる (issue #50)
            .accessibilityElement(children: .contain)
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

    /// 答えた日数 N + テキストリンク行。
    /// 直近 14 日の粒ストリップは、背景に積もる粒 (issue #117) に役割を置き換えて廃止した
    private var footerSection: some View {
        VStack(spacing: 16) {
            // ja: 答えた日数 %lld日
            Text("\(answeredCount) mornings answered")
                .font(.system(size: 11))
                .tracking(1.1)
                .foregroundStyle(Color.warmWhite.opacity(0.55))
            HStack(spacing: 4) {
                NavigationLink {
                    AnswerLogPage()
                } label: {
                    // ja: ジャーナル
                    Text("Journal")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                }
                NavigationLink {
                    DotsPage()
                } label: {
                    // ja: 点
                    Text("Dots")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                }
                NavigationLink {
                    MonthCalendarPage()
                } label: {
                    // ja: カレンダー
                    Text("Calendar")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                }
                NavigationLink {
                    AlarmSettingPage()
                } label: {
                    // ja: 設定
                    Text("Settings")
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                }
            }
            .font(.system(size: 13))
            .tracking(1.3)
            .foregroundStyle(Color.warmWhite.opacity(0.75))
            .padding(.top, 8)
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
            // Preview の body は複数回評価される。共有 in-memory コンテナへの重複挿入で
            // 回答が 7 件に達すると節目シートが開いてしまうため、挿入を冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
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
