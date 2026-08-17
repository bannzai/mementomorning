import SwiftUI
import SwiftData

/// 朝の問い画面。アラーム発火後に全画面で表示し、「今日死ぬとしたら、何をやりたいか」に答えるまで閉じられないコア画面。
/// 回答が保存される (今日の MorningAnswer が成立する) と当日の残アラーム (バックアップ・追撃含む) を全キャンセルして閉じる。
/// 第一入力はインカメラ動画回答 (issue #24): 問いをプレビューにオーバーレイした状態で録画し、
/// 停止 = 回答完了として動画を写真アプリへ保存する。テキスト入力は代替手段として残し、
/// カメラ/マイク/写真の権限拒否時・カメラ非搭載環境 (シミュレータ) はテキスト入力へフォールバックする。
/// 回答完了の判定は入力手段によらず MorningAnswer の成立だけに依存させている。
/// 寝起きの内省の緩和策として、テキスト入力では昨日の回答があれば「昨日の回答を今日やる? YES / NO」の選択式から始める
struct MorningQuestionPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 回答入力テキスト
    @State private var text = ""
    /// 昨日の回答。選択式入力 (昨日の回答を今日やる?) の原資。無ければ最初から自由入力を出す
    @State private var yesterdayAnswer: MorningAnswer?
    /// 昨日の回答の再利用を断った (「別の答えを書く」を選んだ) かどうか。true で自由入力へ切り替える
    @State private var isYesterdayProposalDeclined = false
    /// 保存に失敗した場合のエラー。nil 以外で表示し、再タップで再試行できる
    @State private var saveError: String?
    /// 保存処理 (再スケジュール完了待ち) の実行中かどうか。連打による複数 Task の並行起動を防ぐ
    @State private var isSaving = false
    /// 自由入力欄のフォーカス
    @FocusState private var isTextFieldFocused: Bool

    /// インカメラ録画セッション
    @State private var camera = VideoAnswerCamera()
    /// ユーザーが代替手段 (テキスト入力) を選んだかどうか
    @State private var isTextInputSelected = false
    /// 動画回答を利用できない (権限拒否・カメラ非搭載) かどうか。true でテキスト入力へフォールバックする
    @State private var isVideoAnswerUnavailable = false
    /// 録画済みで写真ライブラリへの保存が未完了の動画ファイル。保存失敗時の再試行に使い、保存が成功したら削除して nil に戻す
    @State private var recordedVideoURL: URL?
    /// 写真ライブラリへ保存済みで、回答の確定 (complete) が未完了の動画の localIdentifier。
    /// 確定 (SwiftData 保存・reschedule) の失敗時に再録画・動画の重複保存をせず確定だけを再試行するために、確定が成功するまで保持する
    @State private var savedVideoAssetIdentifier: String?

    var body: some View {
        Group {
            if isTextInputSelected || isVideoAnswerUnavailable {
                textAnswerContent
            } else {
                videoAnswerContent
            }
        }
        .frame(maxWidth: .infinity)
        // 静かな世界観の墨色背景 (design_handoff_memento_morning/README.md の Design Tokens)
        .background(Color.ink.ignoresSafeArea())
        .foregroundStyle(Color.warmWhite)
        .onAppear {
            yesterdayAnswer = fetchMorningAnswer(
                answeredDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                modelContext: modelContext
            )
        }
    }

    /// 第一入力: インカメラ動画回答。問いをプレビューにオーバーレイし、録画停止で回答を確定する
    private var videoAnswerContent: some View {
        ZStack {
            if camera.isSessionRunning {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }
            // プレビュー (顔) の上でも問いと操作が読めるよう、上下に墨のスクリムを敷く
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.ink.opacity(0.75), Color.ink.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
                Spacer()
                LinearGradient(
                    colors: [Color.ink.opacity(0), Color.ink.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ja: 今日死ぬとしたら、何をやりたいか
                Text(String(localized: "If today were your last day, what would you want to do?"))
                    .font(.system(size: 27, weight: .light))
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("morning_question_text")
                    .padding(.top, 110)
                    .padding(.horizontal, 32)
                Spacer()
                VStack(spacing: 16) {
                    if let saveError {
                        // エラーメッセージはそのまま表示する (加工しない)。
                        // 行数を制限して操作ボタンを画面外へ押し出さない
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(Color.warmWhite.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .accessibilityIdentifier("morning_question_save_error")
                    }
                    if let recordedVideoURL {
                        Button {
                            saveVideoAnswer(fileURL: recordedVideoURL)
                        } label: {
                            // ja: 保存をやり直す
                            Text(String(localized: "Try saving again"))
                        }
                        .buttonStyle(PrimaryPillButtonStyle())
                        .disabled(isSaving)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("morning_question_retry_save_button")
                    } else if let savedVideoAssetIdentifier {
                        // 動画は写真ライブラリへ保存済みで、回答の確定 (SwiftData 保存・reschedule) だけが失敗した状態。
                        // 再録画も動画の重複保存もせず、確定だけを再試行する
                        Button {
                            retryCompleteVideoAnswer(videoAssetIdentifier: savedVideoAssetIdentifier)
                        } label: {
                            // ja: 保存をやり直す
                            Text(String(localized: "Try saving again"))
                        }
                        .buttonStyle(PrimaryPillButtonStyle())
                        .disabled(isSaving)
                        .padding(.horizontal, 32)
                        .accessibilityIdentifier("morning_question_retry_save_button")
                    } else if camera.isSessionRunning {
                        recordButton
                    } else {
                        preparingRecordingIndicator
                    }
                    Button {
                        // 録画中に切り替えた場合、放置された録画が完了して回答を確定しないよう明示的に止める
                        // (完了コールバック側でも isTextInputSelected を見て無視する)
                        camera.stopRecording()
                        isTextInputSelected = true
                    } label: {
                        // ja: テキストで答える
                        Text(String(localized: "Answer in text"))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.warmWhite.opacity(0.55))
                            .underline()
                    }
                    // 写真ライブラリへの保存・確定の実行中に切り替えると、テキスト入力中に動画回答が確定して画面が閉じてしまうため無効化する
                    .disabled(isSaving)
                    .accessibilityIdentifier("morning_question_text_input_link")
                }
                .padding(.bottom, 32)
            }
        }
        .task {
            await prepareVideoAnswer()
        }
        .onDisappear {
            camera.stop()
        }
    }

    /// セッションが起動するまでの代替表示。権限リクエスト中・カメラ起動中であることを示す。
    /// 押しても何も起きない録画ボタンを出すと、拒否されたのか準備中なのか分からない画面になるため置いている (issue #50)。
    /// 権限拒否・カメラ非搭載が確定した時は isVideoAnswerUnavailable が立ち、テキスト入力へ切り替わるためこの表示には留まらない
    private var preparingRecordingIndicator: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(Color.warmWhite)
            // ja: カメラを準備しています
            Text(String(localized: "Preparing the camera"))
                .font(.system(size: 12))
                .foregroundStyle(Color.warmWhite.opacity(0.55))
        }
        // 起動後に録画ボタン (72pt) へ置き換わっても下の導線が動かないよう高さを合わせる
        .frame(height: 72)
        .accessibilityIdentifier("morning_question_camera_preparing")
    }

    /// 録画の開始/停止ボタン。録画中は停止 (= 回答確定) の印として夜明け色の角丸を表示する
    private var recordButton: some View {
        Button {
            if camera.isRecording {
                camera.stopRecording()
            } else {
                camera.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.warmWhite.opacity(0.8), lineWidth: 3)
                    .frame(width: 72, height: 72)
                if camera.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.dawn)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.warmWhite)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .disabled(!camera.isSessionRunning || isSaving)
        .accessibilityLabel(
            camera.isRecording
                // ja: 録画を止めて回答を確定する
                ? Text("Stop recording and finish your answer")
                // ja: 録画を始める
                : Text("Start recording")
        )
        .accessibilityIdentifier("morning_question_record_button")
    }

    /// 代替手段: テキスト入力での回答フロー (issue #4 の画面骨格)
    private var textAnswerContent: some View {
        VStack(spacing: 0) {
            // 回答本文 (昨日の回答・自由入力) は長さ制限のない自由入力のため、
            // 本文領域をスクロール可能にして小さい端末や大きな Dynamic Type でも全文を読めるようにする。
            // 操作ボタンはスクロール外の下部固定にして常に押せるようにする
            ScrollView {
                VStack(spacing: 40) {
                    // ja: 今日死ぬとしたら、何をやりたいか
                    Text(String(localized: "If today were your last day, what would you want to do?"))
                        .font(.system(size: 27, weight: .light))
                        .lineSpacing(10)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("morning_question_text")

                    if isVideoAnswerUnavailable {
                        // ja: カメラを使えないため、テキストで答えます
                        Text(String(localized: "The camera isn't available, so answer in text."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("morning_question_video_unavailable_note")
                    }

                    if let yesterdayAnswer, !isYesterdayProposalDeclined {
                        // ja: 昨日の回答を、今日やる?
                        Text(String(localized: "Will you do yesterday's answer today?"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(yesterdayAnswer.text)
                            .font(.system(size: 25, weight: .light))
                            .lineSpacing(12)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("morning_question_yesterday_text")
                    } else {
                        // ja: ここに書く
                        TextField(String(localized: "Type here"), text: $text, axis: .vertical)
                            .font(.system(size: 25, weight: .light))
                            .lineLimit(3...6)
                            .multilineTextAlignment(.center)
                            .focused($isTextFieldFocused)
                            .accessibilityIdentifier("morning_question_text_field")
                    }
                }
                .padding(.top, 110)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 16) {
                if let saveError {
                    // エラーメッセージはそのまま表示する (加工しない)。
                    // 再スケジュール失敗時は最大で登録件数ぶんのエラーが連結されるため、
                    // 行数を制限して操作ボタンを画面外へ押し出さない (全文はアラーム設定画面でも確認できる)
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .accessibilityIdentifier("morning_question_save_error")
                }

                if let yesterdayAnswer, !isYesterdayProposalDeclined {
                    Button {
                        save(text: yesterdayAnswer.text)
                    } label: {
                        // ja: やる
                        Text(String(localized: "I will"))
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("morning_question_yes_button")

                    Button {
                        isYesterdayProposalDeclined = true
                        isTextFieldFocused = true
                    } label: {
                        // ja: 別の答えを書く
                        Text(String(localized: "Write a different answer"))
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier("morning_question_no_button")
                } else {
                    Button {
                        save(text: text)
                    } label: {
                        // ja: これで確定する
                        Text(String(localized: "Make it today's answer"))
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .disabled(isSaving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("morning_question_submit_button")
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    /// 動画回答の準備: 録画コールバックの接続 → 権限リクエスト → セッション起動。
    /// 権限が 1 つでも拒否されたらテキスト入力へフォールバックする (受け入れ条件)
    private func prepareVideoAnswer() async {
        camera.onFinished = { fileURL in
            // テキスト入力へ切り替えた後に完了した録画 (切替時の停止・onDisappear の stopRunning による確定) は
            // 回答にしない。放置すると入力中に動画回答が確定して画面が閉じてしまう
            guard !isTextInputSelected else {
                try? FileManager.default.removeItem(at: fileURL)
                return
            }
            saveVideoAnswer(fileURL: fileURL)
        }
        camera.onRecordingFailed = { message in
            saveError = message
        }
        camera.onUnavailable = {
            isVideoAnswerUnavailable = true
        }
        guard await requestVideoAnswerPermissions() else {
            isVideoAnswerUnavailable = true
            return
        }
        camera.start()
    }

    /// 録画済みの動画を写真ライブラリ (アルバム「Memento Morning」) へ保存し、成功したら回答を確定する。
    /// 保存に失敗した時は動画ファイルを保持したままエラーを表示し、「保存をやり直す」で再試行できる
    private func saveVideoAnswer(fileURL: URL) {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        recordedVideoURL = fileURL
        Task {
            do {
                let assetIdentifier = try await saveVideoAnswerToPhotoLibrary(fileURL: fileURL)
                // 一時ファイルの削除失敗は回答の成立に影響しないため無視する (temporaryDirectory は OS も掃除する)
                try? FileManager.default.removeItem(at: fileURL)
                recordedVideoURL = nil
                // 確定に失敗しても再録画・動画の重複保存なしで再試行できるよう、確定が成功するまで識別子を保持する
                savedVideoAssetIdentifier = assetIdentifier
                await complete(text: videoAnswerPlaceholderText, videoAssetIdentifier: assetIdentifier)
            } catch {
                saveError = "\(error)"
                isSaving = false
            }
        }
    }

    /// 写真ライブラリへ保存済みの動画で、回答の確定 (SwiftData 保存・reschedule) だけを再試行する
    private func retryCompleteVideoAnswer(videoAssetIdentifier: String) {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        Task {
            await complete(text: videoAnswerPlaceholderText, videoAssetIdentifier: videoAssetIdentifier)
        }
    }

    /// テキスト入力の回答を確定する
    private func save(text: String) {
        guard !isSaving else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveError = nil
        Task {
            await complete(text: trimmed)
        }
    }

    /// 回答を保存し、当日の残アラームを全キャンセルして画面を閉じる (テキスト・動画共通の確定処理)。
    /// 保存・再スケジュールに失敗した時は、止まったと誤解させないよう閉じずにエラーを表示する (再タップで再試行)
    private func complete(text: String, videoAssetIdentifier: String? = nil) async {
        // 同じ日の回答は 1 件に保つ (再入・レース時は既存回答の更新にする)。
        // 既存回答の取得失敗を未回答と誤認すると同じ日の回答を重複挿入してしまうため、
        // throwing 版で取得し、失敗は保存エラーと同じ扱いで中断する
        let today = Calendar.current.startOfDay(for: .now)
        do {
            if let answer = try MorningAnswer.answer(day: today, calendar: .current, modelContext: modelContext) {
                answer.setText(text: text)
                // nil (テキスト回答) も明示的にセットして消去する。動画の確定失敗後にテキストで答え直した時に
                // 古い動画を指し続けると、文字起こし (issue #25) がテキスト回答を動画回答として扱ってしまう
                answer.setVideoAssetIdentifier(videoAssetIdentifier: videoAssetIdentifier)
            } else {
                modelContext.insert(MorningAnswer(answeredDate: today, text: text, videoAssetIdentifier: videoAssetIdentifier))
            }
            try modelContext.save()
            // ホーム画面ウィジェットの「今日の答え」を保存の成功直後に反映する (issue #46)
            reloadHomeWidgetTimelines()
        } catch {
            // 永続化されていない変更を mainContext に残すと、次回の reschedule がその未保存の値を fetch してしまうため、
            // 変更を破棄してから中断する
            modelContext.rollback()
            saveError = "\(error)"
            isSaving = false
            return
        }

        // 回答が成立したので、ロック画面に「今日の目標」(Live Activity) を出す (issue #45)。
        // 後続の reschedule が失敗しても回答自体は成立しているため、reschedule の結果を待たずここで開始する
        await refreshTodayAnswerLiveActivity(todayAnswerText: text)

        // 回答の成立 → 当日の全アラーム (バックアップ・追撃含む) のキャンセル。
        // reschedule は回答済みの日を計画から除くため、全キャンセル → 全再登録で当日分だけが消える
        await reschedule(modelContext: modelContext)
        if let error = UserDefaults.standard.string(forKey: .lastRescheduleError) {
            saveError = error
            isSaving = false
        } else {
            if let videoAssetIdentifier {
                // 文字起こしは回答の成立 (アラーム停止) を待たせない。画面が閉じた後も走り続け、完了時に仮テキストを置き換える
                let modelContext = modelContext
                Task {
                    await transcribeAndApplyVideoAnswer(videoAssetIdentifier: videoAssetIdentifier, answeredDate: today, modelContext: modelContext)
                }
            }
            dismiss()
        }
    }
}

/// MorningQuestionPage の Preview
struct MorningQuestionPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 昨日の回答がある状態のプレビュー (カメラの無い Preview 環境ではテキスト入力へフォールバックし、選択式入力から始まる)
        let _ = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            modelContext.insert(
                MorningAnswer(
                    answeredDate: Calendar.current.startOfDay(
                        for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
                    ),
                    text: "家族と海を見に行く"
                )
            )
            try! modelContext.save()
        }()

        MorningQuestionPage()
            .modelContainer(container)
    }
}
