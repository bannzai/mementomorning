import AppIntents
import AlarmKit
import SwiftData
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

    /// アラームを停止し、issue #2 のスパイク検証として追撃アラームを再登録する。
    /// 「未回答なら追撃」の本実装は回答状態の判定 (朝の問い画面) が前提になるため、ここでは回答状態を見ずに追撃を登録する。
    /// 追撃の可否は課金状態で決める (無料: freeTierSnoozeLimit 回まで / プレミアム: 無限追撃。issue #9)。
    /// 追撃の途中経過は appendStopIntentSpikeLog で逐次記録し、途中で kill されても直前までの痕跡が残るようにする
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

        let chaseCount = UserDefaults.standard.integer(forKey: .stopIntentChaseCount)
        guard shouldChase(chaseCount: chaseCount, isPremium: PremiumEntitlement.isPremium) else {
            appendStopIntentSpikeLog(message: "chase skipped: free tier snooze limit reached (\(chaseCount))")
            // 先行登録済みのバックアップを放置すると無料枠 (freeTierSnoozeLimit) を超えて発火するため、
            // 上限到達時に当日分の残りをキャンセルする (PR #30 レビュー指摘)
            await cancelRemainingBackupsAtSnoozeLimit()
            return .result()
        }

        // 追撃アラームは ScheduledAlarm へ記録しない (スパイクのため最小限にする)。
        // 未発火の間は reschedule の全キャンセルから UserDefaults の記録 (stopIntentChaseAlarmID) で保護され、
        // 発火後は次回 foreground の reschedule が OS 側から列挙して消すため残留しない
        let chaseAlarmID = UUID()
        let chaseFireDate = Date.now.addingTimeInterval(stopIntentChaseInterval)
        appendStopIntentSpikeLog(message: "schedule() attempting chase id=\(chaseAlarmID) fireDate=\(chaseFireDate.formatted(.iso8601))")
        do {
            // ja: 今日死ぬとしたら、何をやりたいか
            let title = LocalizedStringResource("If today were your last day, what would you want to do?")
            try await AlarmKitManager.schedule(id: chaseAlarmID, fireDate: chaseFireDate, title: title)
            // 登録に失敗した試行で無料枠を消費しないよう、カウントは schedule() の成功後に更新する (PR #30 レビュー指摘)
            UserDefaults.standard.set(chaseCount + 1, forKey: .stopIntentChaseCount)
            // openAppWhenRun による foreground 復帰の reschedule (全キャンセル) から
            // 発火前の追撃を保護するため、ID と発火予定を記録する (PR #30 レビュー指摘)
            UserDefaults.standard.set(chaseAlarmID.uuidString, forKey: .stopIntentChaseAlarmID)
            UserDefaults.standard.set(chaseFireDate.timeIntervalSince1970, forKey: .stopIntentChaseFireDate)
            // schedule() が throw しなくても実登録に失敗している可能性を潰すため、OS 側の一覧で確認する
            let registered = ((try? AlarmManager.shared.alarms) ?? []).contains { $0.id == chaseAlarmID }
            appendStopIntentSpikeLog(message: "schedule() succeeded registeredInAlarms=\(registered)")
        } catch {
            appendStopIntentSpikeLog(message: "schedule() failed error=\(error)")
        }
        return .result()
    }

    /// スヌーズ上限に達した時、当日分の残バックアップアラームをキャンセルして記録からも消す。
    /// キャンセル失敗は次回 reschedule の全キャンセルで回収されるため、ログに残して続行する
    @MainActor
    private func cancelRemainingBackupsAtSnoozeLimit() {
        let modelContext = PersistenceController.shared.container.mainContext
        let scheduledAlarms = (try? modelContext.fetch(FetchDescriptor<ScheduledAlarm>())) ?? []
        for backup in backupAlarmsToCancelAtSnoozeLimit(scheduledAlarms: scheduledAlarms, now: .now) {
            do {
                try AlarmManager.shared.cancel(id: backup.id)
                modelContext.delete(backup)
                appendStopIntentSpikeLog(message: "backup cancelled at snooze limit id=\(backup.id)")
            } catch {
                appendStopIntentSpikeLog(message: "backup cancel failed id=\(backup.id) error=\(error)")
            }
        }
        try? modelContext.save()
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
