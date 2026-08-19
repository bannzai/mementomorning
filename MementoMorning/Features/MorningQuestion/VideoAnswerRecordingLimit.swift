import Foundation

/// 動画回答の最長録画時間 (秒)。issue #71 で 10 秒に決めた。
/// 朝のひと言の回答には十分な長さで、長い動画は写真ライブラリの容量と文字起こしの待ち時間を増やすだけのため短く固定する。
/// 実録画では AVCaptureMovieFileOutput.maxRecordedDuration に、疑似録画 (DEBUG) では自動停止のタイマーに、
/// 画面ではインジケーター (リング・タイマー) に、この 1 つの値を使う
let videoAnswerMaxRecordingDuration: TimeInterval = 10

/// 録画の進み具合 (0 = 開始直後、1 = 上限到達)。録画ボタンのリング状インジケーターの描画に使う。
/// 経過時間が上限を超えても 1、負でも 0 に丸める (停止デリゲートの遅延や時計のずれで範囲外になっても表示を壊さない)
func videoAnswerRecordingProgress(elapsed: TimeInterval) -> Double {
    min(max(elapsed / videoAnswerMaxRecordingDuration, 0), 1)
}

/// 録画タイマーの表示文字列 (`0:03 / 0:10` 形式。経過 / 上限)。秒は切り捨て、上限を超えた経過時間は上限で止める
func videoAnswerRecordingTimerText(elapsed: TimeInterval) -> String {
    let clampedElapsed = min(max(elapsed, 0), videoAnswerMaxRecordingDuration)
    return "\(formatMinutesSeconds(seconds: clampedElapsed)) / \(formatMinutesSeconds(seconds: videoAnswerMaxRecordingDuration))"
}

/// 録画中の点の不透明度。デザイン指定 (design_handoff_memento_morning/README.md: 1.6 秒周期で 0.25⇄0.8 のゆっくりした明滅) を、
/// アニメーション状態を持たず経過時間から決定的に算出する (開始時が最も明るく、0.8 秒後に最も暗くなる)
func videoAnswerRecordingDotOpacity(elapsed: TimeInterval) -> Double {
    let phase = (1 - cos(elapsed / 1.6 * 2 * .pi)) / 2
    return 0.8 - 0.55 * phase
}

/// 秒数を `m:ss` (分:秒。秒は切り捨て) にする
private func formatMinutesSeconds(seconds: TimeInterval) -> String {
    let wholeSeconds = Int(seconds.rounded(.down))
    return String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
}
