import AVFoundation
import Foundation
import os
import Photos
import Speech
import SwiftData

/// 動画回答の仮の回答本文。文字起こしが動画の音声トラックから置き換えるまでの文言で、
/// ホームの「今朝のことば」・ジャーナル・夜リマインドの引用にそのまま表示される
var videoAnswerPlaceholderText: String {
    // ja: 動画で答えました
    String(localized: "Answered with a video")
}

/// 動画回答の音声を文字起こしできる状態かを判定する純粋関数。
/// 権限が許可されていて、認識器が利用可能で、オンデバイス認識に対応している時だけ実行する
func isTranscriptionAvailable(
    authorizationStatus: SFSpeechRecognizerAuthorizationStatus,
    isRecognizerAvailable: Bool,
    supportsOnDeviceRecognition: Bool
) -> Bool {
    authorizationStatus == .authorized && isRecognizerAvailable && supportsOnDeviceRecognition
}

/// 文字起こしの結果を回答へ書き込んでよいかを判定する純粋関数。
/// 文字起こしは回答の確定より後に (画面が閉じた後も) 完了するため、その間に回答が変わっている可能性がある。
/// ユーザーが先に手で編集した回答や、同じ日に録り直された新しい動画の回答を、
/// 古い文字起こし結果で上書きしないよう、処理中かつ同じ動画を指している時だけ適用する
func shouldApplyTranscription(
    currentStatus: VideoTranscriptionStatus?,
    currentVideoAssetIdentifier: String?,
    transcribedVideoAssetIdentifier: String
) -> Bool {
    currentStatus == .pending && currentVideoAssetIdentifier == transcribedVideoAssetIdentifier
}

/// 写真ライブラリへ保存済みの動画回答の音声を文字起こしし、認識できた本文を返す。
/// 権限拒否・オンデバイス非対応の言語・動画の取得失敗・認識エラーはすべて nil を返す
/// (どの失敗も「仮テキストのまま残して手動編集を促す」という同じフォールバックに落ちるため、throw で区別しない)
func transcribeVideoAnswer(videoAssetIdentifier: String) async -> String? {
    // 音声認識の権限はここで初めて要求する。動画回答の権限リクエスト (requestVideoAnswerPermissions) には
    // 含めない。音声認識の拒否が動画回答自体をブロックしてはならないため
    let authorizationStatus = await requestSpeechRecognitionAuthorization()
    guard let recognizer = SFSpeechRecognizer(locale: .current) else { return nil }
    // オンデバイス認識だけを使い、サーバー認識へはフォールバックしない。
    // プライバシーポリシー「回答は端末の外に出ない」と整合させるため。
    // オンデバイス非対応の言語では文字起こしをスキップし、仮テキストのまま手動編集に委ねる
    guard isTranscriptionAvailable(
        authorizationStatus: authorizationStatus,
        isRecognizerAvailable: recognizer.isAvailable,
        supportsOnDeviceRecognition: recognizer.supportsOnDeviceRecognition
    ) else { return nil }

    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [videoAssetIdentifier], options: nil).firstObject else {
        return nil
    }
    let videoRequestOptions = PHVideoRequestOptions()
    // 対象は端末内に保存したばかりの動画のみで、iCloud からのダウンロード待ちはしない
    // (回答直後に走る処理のため、ネットワーク待ちで長時間走らせない)
    videoRequestOptions.isNetworkAccessAllowed = false
    let canResumeVideoRequest = makeResumeOnceGate()
    let videoAsset = await withCheckedContinuation { (continuation: CheckedContinuation<AVAsset?, Never>) in
        PHImageManager.default().requestAVAsset(forVideo: asset, options: videoRequestOptions) { videoAsset, _, _ in
            guard canResumeVideoRequest() else { return }
            continuation.resume(returning: videoAsset)
        }
    }
    // 編集済みの動画などでは URL を持たない AVComposition が返ることがあり、
    // ファイル URL を要求する SFSpeechURLRecognitionRequest には渡せないためスキップする
    guard let urlAsset = videoAsset as? AVURLAsset else { return nil }

    let request = SFSpeechURLRecognitionRequest(url: urlAsset.url)
    request.requiresOnDeviceRecognition = true
    // 途中経過は使わず確定結果だけを受け取る (仮テキストの置き換えは 1 回で足りる)
    request.shouldReportPartialResults = false
    let canResumeRecognition = makeResumeOnceGate()
    let transcription = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
        recognizer.recognitionTask(with: request) { result, error in
            if error != nil {
                guard canResumeRecognition() else { return }
                continuation.resume(returning: nil)
                return
            }
            guard let result, result.isFinal else { return }
            guard canResumeRecognition() else { return }
            continuation.resume(returning: result.bestTranscription.formattedString)
        }
    }
    // SFSpeechRecognizer が解放されると実行中の認識タスクがキャンセルされる。
    // 最後の参照が await より前になって途中で解放されないよう、結果を受け取るまで寿命を伸ばす
    withExtendedLifetime(recognizer) {}

    guard let transcription = transcription?.trimmingCharacters(in: .whitespacesAndNewlines),
          !transcription.isEmpty else {
        return nil
    }
    return transcription
}

/// 動画回答の音声を文字起こしし、結果を今朝の回答の本文へ反映する。
/// 文字起こしの完了時点で回答が書き換わっている場合 (手動編集・録り直し) は適用しない
@MainActor
func transcribeAndApplyVideoAnswer(videoAssetIdentifier: String, answeredDate: Date, modelContext: ModelContext) async {
    guard let text = await transcribeVideoAnswer(videoAssetIdentifier: videoAssetIdentifier) else {
        // 失敗を処理中のままにすると「一ヶ月の手紙」が永久に待機するため、同じ動画を指している回答だけ失敗へ進める。
        // 保存通知を発生させることで、節目表示と共有ダイアログを失敗後の状態で再判定できる
        guard let answer = try? MorningAnswer.answer(day: answeredDate, calendar: .current, modelContext: modelContext) else {
            return
        }
        answer.markVideoTranscriptionFailed(videoAssetIdentifier: videoAssetIdentifier)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
        return
    }
    // 取得に失敗した時に未回答と誤認して新しい回答を作らないよう throwing 版で取り直し、失敗したら適用せず終える
    guard let answer = try? MorningAnswer.answer(day: answeredDate, calendar: .current, modelContext: modelContext) else {
        return
    }
    guard shouldApplyTranscription(
        currentStatus: answer.videoTranscriptionStatus,
        currentVideoAssetIdentifier: answer.videoAssetIdentifier,
        transcribedVideoAssetIdentifier: videoAssetIdentifier
    ) else { return }

    answer.completeVideoTranscription(text: text, videoAssetIdentifier: videoAssetIdentifier)
    do {
        try modelContext.save()
        // 仮テキストから認識結果への置き換えをホーム画面ウィジェットへ反映する (issue #46)
        reloadHomeWidgetTimelines()
    } catch {
        // 永続化されていない変更を mainContext に残すと、次回の reschedule がその未保存の値を fetch してしまうため破棄する
        modelContext.rollback()
        return
    }
    // 夜リマインドは登録時点の回答本文を引用するため、文字起こしの完了前にアプリを離脱すると
    // 当日分の通知が仮テキストを引用したまま残る。認識結果の保存に成功したら当日分を登録し直す
    // (通知本文が「今日の回答」の引用である当日の適用時に限る)
    if Calendar.current.isDateInToday(answeredDate) {
        // ロック画面の「今日の目標」(Live Activity) も仮テキスト「動画で答えました」のままのため、認識結果へ置き換える
        await refreshTodayAnswerLiveActivity(todayAnswerText: text)
        await NightReminder.requestAuthorizationAndSchedule(
            times: scheduledNightReminderTimes(modelContext: modelContext),
            todayAnswerText: text
        )
    }
}

/// 前回のプロセス終了で中断された文字起こしを failed へ進める。
/// ContentView のプロセス起動時に一度だけ呼び、処理中の回答が節目を永久に止めないようにする。
/// failed へ進んだ回答は次回以降取得されないため冪等
@MainActor
func recoverInterruptedVideoTranscriptions(modelContext: ModelContext) {
    let pendingStatus = VideoTranscriptionStatus.pending.rawValue
    let descriptor = FetchDescriptor<MorningAnswer>(
        predicate: #Predicate { $0.videoTranscriptionStatusRawValue == pendingStatus }
    )
    guard let answers = try? modelContext.fetch(descriptor), !answers.isEmpty else { return }
    for answer in answers {
        guard let videoAssetIdentifier = answer.videoAssetIdentifier else { continue }
        answer.markVideoTranscriptionFailed(videoAssetIdentifier: videoAssetIdentifier)
    }
    do {
        try modelContext.save()
    } catch {
        modelContext.rollback()
    }
}

/// 音声認識の権限をリクエストし、確定した権限状態を返す (完了ハンドラの async ラッパー)。
/// 決定済み (許可/拒否) の権限にシステムはダイアログを出さず現在の状態を返すため、何度呼んでも安全 (冪等)。
/// オンボーディングの練習ステップ (OnboardingPage) からも呼び、起き抜けの朝に不意のダイアログを出さないよう事前に確定させる
func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { authorizationStatus in
            continuation.resume(returning: authorizationStatus)
        }
    }
}

/// continuation を 1 回だけ resume するためのゲートを作る。true を返した呼び出しだけが resume してよい。
/// 音声認識の resultHandler は結果の後にエラーが届くなど複数回呼ばれることがあり、
/// 2 回目の resume はクラッシュする。ハンドラは任意のスレッドから呼ばれるため、ロックで直列化して判定する。
/// 動画回答の再生 (AnswerVideoPlayerPage) の PHImageManager 呼び出しからも使う
func makeResumeOnceGate() -> @Sendable () -> Bool {
    let isResumed = OSAllocatedUnfairLock(initialState: false)
    return {
        isResumed.withLock { isResumed in
            if isResumed { return false }
            isResumed = true
            return true
        }
    }
}
