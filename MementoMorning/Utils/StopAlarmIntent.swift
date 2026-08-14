import AppIntents
import AlarmKit
import UIKit

/// アラーム停止用の Intent。
/// openAppWhenRun = true でアプリを開かせ、foreground 復帰時の再スケジュールへ繋げる。
/// public なのは AppIntents ランタイムの制約のため。internal だと停止操作時に mangledTypeName から
/// 型を解決できず「Could not find an intent with identifier」で perform() が実行されない
/// (シミュレータ実測 + https://developer.apple.com/forums/thread/746696 )
public struct StopAlarmIntent: LiveActivityIntent {
    /// Intent のタイトル
    // ja: アラームを止める
    public static var title: LocalizedStringResource = "Stop Alarm"
    /// Intent の説明
    // ja: アラームを停止して Memento Morning を開きます
    public static var description = IntentDescription("Stop the alarm and open Memento Morning")
    /// 実行時にアプリを開く
    public static var openAppWhenRun = true

    /// 停止対象のアラーム ID (UUID を String で保持する。AppIntents の Parameter は UUID を直接サポートしない)
    @Parameter(title: "alarmID")
    var alarmID: String

    /// AppIntents は引数なし init を要求するため明示的に定義する
    public init() {
        self.alarmID = ""
    }

    /// 指定した UUID でアラームを停止する Intent を作成する
    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    /// アラームを停止し、未回答なら追撃アラームを再登録する (「答えるまで止まらない」の中核)。
    /// 回答完了の判定は「今日の MorningAnswer が成立しているか」だけに依存し、回答手段 (テキスト / 動画) に依存しない。
    /// フル再スケジュールは行わず追撃 1 本の登録に留める (intent の実行時間予算の中で最小限にする。
    /// 全体の計画は openAppWhenRun による foreground 復帰時の reschedule が担う)。
    /// 途中経過は appendStopIntentSpikeLog で逐次記録し、途中で kill されても直前までの痕跡が残るようにする
    public func perform() async throws -> some IntentResult {
        // applicationState は MainActor 経由でのみ読める。
        // schedule() 実行時点で background だったかを判定する材料として最初に記録する
        // (openAppWhenRun = true により perform() 前後でアプリが前面化する可能性があるため)
        let applicationState = await MainActor.run { UIApplication.shared.applicationState }
        appendStopIntentSpikeLog(message: "perform() entered applicationState=\(applicationStateDescription(applicationState: applicationState))")

        if let alarmID = UUID(uuidString: alarmID) {
            do {
                try AlarmKitManager.stop(id: alarmID)
                appendStopIntentSpikeLog(message: "stop(id:) succeeded id=\(alarmID)")
            } catch {
                appendStopIntentSpikeLog(message: "stop(id:) failed id=\(alarmID) error=\(error)")
            }
        } else {
            appendStopIntentSpikeLog(message: "stop(id:) skipped: invalid alarmID=\(alarmID)")
        }

        // 停止操作が届いた = アラームは発火済み。朝の問いの提示判定と追撃計画の起点として記録する
        recordAlarmFired(date: .now)

        let todayAnswered = await MainActor.run {
            fetchMorningAnswer(answeredDate: .now, modelContext: PersistenceController.shared.container.mainContext) != nil
        }
        guard !todayAnswered else {
            appendStopIntentSpikeLog(message: "chase skipped: today already answered")
            return .result()
        }

        // 追撃アラームは ScheduledAlarm へ記録しない (intent 内での SwiftData 書き込みを避けて最小限にする)。
        // 記録が無くても次回 foreground の reschedule が cancelAll で OS 側から列挙して消すため残留しない
        let chaseAlarmID = UUID()
        let chaseFireDate = Date.now.addingTimeInterval(TimeInterval(chaseAlarmIntervalMinutes * 60))
        appendStopIntentSpikeLog(message: "schedule() attempting chase id=\(chaseAlarmID) fireDate=\(chaseFireDate.formatted(.iso8601))")
        do {
            // ja: 今日死ぬとしたら、何をやりたいか
            let title = LocalizedStringResource("If today were your last day, what would you want to do?")
            try await AlarmKitManager.schedule(id: chaseAlarmID, fireDate: chaseFireDate, title: title)
            // schedule() が throw しなくても実登録に失敗している可能性を潰すため、OS 側の一覧で確認する
            let registered = ((try? AlarmManager.shared.alarms) ?? []).contains { $0.id == chaseAlarmID }
            appendStopIntentSpikeLog(message: "schedule() succeeded registeredInAlarms=\(registered)")
        } catch {
            appendStopIntentSpikeLog(message: "schedule() failed error=\(error)")
        }
        return .result()
    }

    /// applicationState をログ用の文字列にする
    private func applicationStateDescription(applicationState: UIApplication.State) -> String {
        switch applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown(\(applicationState.rawValue))"
        }
    }
}
