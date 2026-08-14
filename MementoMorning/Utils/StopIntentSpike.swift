import Foundation
import OSLog

// issue #2 のスパイク検証 (stopIntent の perform() 内 schedule() が background で通るか実機検証) 由来の痕跡ログ。
// perform() の実行経路 (intent 型解決・background での schedule()) は実機で未検証のまま残っているため、
// 本実装 (issue #4 の未回答判定つき追撃) でもログを残し続け、実機検証の完了後に削除する

extension String {
    /// stopIntent の痕跡ログを保存する UserDefaults キー。
    /// perform() の実行有無・appState・schedule() の成否を改行区切りで追記し、
    /// AlarmSettingPage が @AppStorage で監視して実機上でそのまま読めるようにする
    static let stopIntentSpikeLog = "stopIntentSpikeLog"
}

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
