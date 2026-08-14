import Foundation
import OSLog

// issue #2 のスパイク検証 (stopIntent の perform() 内 schedule() が background で通るか実機検証) 用の計測コード。
// 検証完了後は本実装 (未回答判定つき追撃再スケジュール) に置き換えて削除する

extension String {
    /// stopIntent スパイク検証の痕跡ログを保存する UserDefaults キー。
    /// perform() の実行有無・appState・schedule() の成否を改行区切りで追記し、
    /// AlarmSettingPage が @AppStorage で監視して実機上でそのまま読めるようにする
    static let stopIntentSpikeLog = "stopIntentSpikeLog"
    /// 連続追撃回数を保存する UserDefaults キー。アプリが foreground になったらリセットされる
    static let stopIntentChaseCount = "stopIntentChaseCount"
}

/// 追撃アラームの発火間隔 (秒)。
/// 検証を短時間で回すため、CLAUDE.md の「アラーム発火の確認は 1〜2 分後のアラームで行う」に合わせて 2 分にする
let stopIntentChaseInterval: TimeInterval = 120

/// 連続追撃の上限回数。
/// openAppWhenRun が実機でも機能しない場合 (issue #3 のシミュレータ実測と同じ現象) に、
/// 停止のたびに追撃が再登録されて鳴り続ける事態を防ぐ。検証には 1 回の追撃発火で十分なため少数に抑える
let stopIntentChaseCountLimit = 3

/// スパイク検証ログの unified log 出力先。
/// UserDefaults の痕跡と二重化し、アプリが途中で kill されても Console / log collect で回収できるようにする
private let stopIntentSpikeLogger = Logger(subsystem: "com.bannzai.MementoMorning", category: "StopIntentSpike")

/// スパイク検証の痕跡を UserDefaults と unified log の両方へ記録する。
/// perform() が途中で kill されても直前までの痕跡が残るよう、イベントごとに即時保存する
func appendStopIntentSpikeLog(message: String) {
    let line = "\(Date.now.formatted(.iso8601)) \(message)"
    stopIntentSpikeLogger.notice("\(line, privacy: .public)")
    let joined = [UserDefaults.standard.string(forKey: .stopIntentSpikeLog), line]
        .compactMap { $0 }
        .joined(separator: "\n")
    UserDefaults.standard.set(joined, forKey: .stopIntentSpikeLog)
}
