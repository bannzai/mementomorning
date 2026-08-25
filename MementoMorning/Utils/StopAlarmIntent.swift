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

    /// アラームを停止し、未回答なら追撃アラームを再登録する (「答えるまで止まらない」の中核)。
    /// 回答完了の判定は「今日の MorningAnswer が成立しているか」だけに依存し、回答手段 (テキスト / 動画) に依存しない。
    /// 追撃の可否はスヌーズ設定と課金状態で決める (無料: freeTierSnoozeLimit 回まで / プレミアム: 設定した回数または無制限。issue #9 / #73)。
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

        // 停止操作が届いた = アラームは発火済み。朝の問い画面 (MorningQuestionPage) の提示判定の起点として、
        // 発火済みの main アラームの発火予定日時を記録する。停止時刻 (.now) は使わない
        // (深夜のバックアップ・追撃の停止が日付を跨ぐと「翌日の発火」として記録され、翌日の問いを誤提示するため)。
        // 過去の main の記録が無い場合 (直前の reschedule が削除済み等) は、既存の発火記録が同じ朝を指しているため更新しない
        await MainActor.run {
            let scheduledAlarms = (try? PersistenceController.shared.container.mainContext.fetch(FetchDescriptor<ScheduledAlarm>())) ?? []
            if let firedDate = scheduledAlarms.filter({ $0.origin == ScheduledAlarmOrigin.main }).map(\.fireDate).filter({ $0 <= Date.now }).max() {
                recordAlarmFired(date: firedDate)
            }
        }

        // 追撃の登録・上限処理は reschedule (全キャンセル) と同じ直列キューで行う。
        // 並行させると「reschedule が保護記録を読む → ここで登録が完了する → 古い集合で cancelAll」の
        // 順序で追撃が消される競合があるため (PR #30 レビュー指摘)
        await performSerializedAlarmOperation {
            await handleChaseAfterStop()
        }
        return .result()
    }

    /// 停止後の追撃処理。performSerializedAlarmOperation のキュー内で実行する (perform() から直接呼ばない)
    @MainActor
    private func handleChaseAfterStop() async {
        // 追撃はアラームが発火した朝 (発火記録の日) 限り。日付を跨いで停止された場合は追撃列を終了する
        // (跨いだ後は朝の問いが提示されず、回答で追撃を止める導線が無いまま鳴り続けてしまうため)
        guard let firedDate = lastAlarmFiredDate(), Calendar.current.isDate(firedDate, inSameDayAs: .now) else {
            appendStopIntentSpikeLog(message: "chase skipped: fired date is not today")
            cancelTodaysBackupAlarms()
            return
        }

        // 回答が成立していたら追撃しない (回答完了の唯一の判定)。判定の日は停止時刻ではなく発火記録の日を使う。
        // openAppWhenRun による foreground 復帰の reschedule でも当日分は消えるが、
        // 前面化が機能しない場合 (issue #3 のシミュレータ実測) に備えてここでも打ち切り、残りのバックアップも掃除する
        guard fetchMorningAnswer(answeredDate: firedDate, modelContext: PersistenceController.shared.container.mainContext) == nil else {
            appendStopIntentSpikeLog(message: "chase skipped: already answered")
            cancelTodaysBackupAlarms()
            return
        }

        // 検証用のプレミアム強制 (debugPremiumOverride) は TestFlight 配布判定 (isDeveloperMenuUnlocked) を通るが、
        // リリースビルドの判定はプロセスローカルに false から始まり、RootView の task の refreshDeveloperMenuUnlocked() が
        // 完了するまで解放されない。停止操作によるコールドローンチではその完了前にここへ到達し得て、
        // 強制プレミアム + スヌーズ無制限でも無料枠 (freeTierSnoozeLimit) に丸められ、追撃が 2 回で止まる (issue #135)。
        // 追撃の可否を決める前に判定の完了を待ってレースを塞ぐ (判定済みプロセスでは AppTransaction のキャッシュを読むだけで軽い)
        await refreshDeveloperMenuUnlocked()

        let chaseCount = UserDefaults.standard.integer(forKey: .stopIntentChaseCount)
        // スヌーズ上限はユーザー設定 (AlarmSetting.snoozeLimit) と課金状態から決める (issue #73)。
        // 設定の読み取り失敗は「設定値が nil (無制限)」と区別し、無料枠 freeTierSnoozeLimit を上限にする
        // (プレミアムで有限回数を設定していても、一時的な読み取りエラーで設定回数を超えて追撃し続けないため。PR #78 レビュー指摘)。
        // アラーム音も同じ設定から読む。読み取り失敗時は nil = システム標準音へ倒れる (鳴らないよりは標準音で鳴らす)
        let snoozeLimit: Int?
        let soundName: String?
        do {
            let alarmSetting = try PersistenceController.shared.container.mainContext.fetch(FetchDescriptor<AlarmSetting>()).first
            snoozeLimit = alarmSetting.flatMap(\.snoozeLimit)
            soundName = alarmSetting?.soundName
        } catch {
            appendStopIntentSpikeLog(message: "alarm setting fetch failed, fallback to free tier snooze limit error=\(error)")
            snoozeLimit = freeTierSnoozeLimit
            soundName = nil
        }
        // 「無限のはずが途中で止まった」を実機ログ (DeveloperLogPage) だけで切り分けられるよう、判定材料を記録する (issue #135)
        let isPremium = PremiumEntitlement.isPremium
        appendStopIntentSpikeLog(message: "chase decision chaseCount=\(chaseCount) snoozeLimit=\(snoozeLimit.map(String.init) ?? "unlimited") isPremium=\(isPremium) effectiveLimit=\(effectiveSnoozeLimit(snoozeLimit: snoozeLimit, isPremium: isPremium).map(String.init) ?? "unlimited")")
        guard shouldChase(chaseCount: chaseCount, snoozeLimit: snoozeLimit, isPremium: isPremium) else {
            appendStopIntentSpikeLog(message: "chase skipped: snooze limit reached (\(chaseCount))")
            // 先行登録済みのバックアップを放置するとスヌーズ上限を超えて発火するため、
            // 上限到達時に当日分の残りをキャンセルする (PR #30 レビュー指摘)
            cancelTodaysBackupAlarms()
            return
        }

        // 追撃アラームは ScheduledAlarm へ記録しない (スパイクのため最小限にする)。
        // 未発火の間は reschedule の全キャンセルから UserDefaults の記録 (stopIntentChaseAlarmID) で保護され、
        // 発火後は次回 foreground の reschedule が OS 側から列挙して消すため残留しない
        let chaseAlarmID = UUID()
        let chaseFireDate = Date.now.addingTimeInterval(stopIntentChaseInterval)
        appendStopIntentSpikeLog(message: "schedule() attempting chase id=\(chaseAlarmID) fireDate=\(chaseFireDate.formatted(.iso8601))")
        // 追撃の保護記録は schedule() の前に書く。完了後に書くと「OS 登録済み・記録前」の隙間が残るため
        // (直列化に加えた保険。未登録 ID の保護は cancelAll が読み飛ばすだけで無害。PR #30 レビュー指摘)
        UserDefaults.standard.set(chaseAlarmID.uuidString, forKey: .stopIntentChaseAlarmID)
        UserDefaults.standard.set(chaseFireDate.timeIntervalSince1970, forKey: .stopIntentChaseFireDate)
        do {
            // ja: 今日死ぬとしたら何をやりたいですか？
            let title = LocalizedStringResource("If today were your last day, what would you want to do?")
            try await AlarmKitManager.schedule(id: chaseAlarmID, fireDate: chaseFireDate, title: title, sound: resolveAlarmSound(soundName: soundName))
            // 登録に失敗した試行で無料枠を消費しないよう、カウントは schedule() の成功後に更新する (PR #30 レビュー指摘)
            UserDefaults.standard.set(chaseCount + 1, forKey: .stopIntentChaseCount)
            // schedule() が throw しなくても実登録に失敗している可能性を潰すため、OS 側の一覧で確認する
            let registered = ((try? AlarmManager.shared.alarms) ?? []).contains { $0.id == chaseAlarmID }
            appendStopIntentSpikeLog(message: "schedule() succeeded registeredInAlarms=\(registered)")
            // 追撃列が動き始めたら当日分のバックアップは不要になる。残すとプレミアム (上限なし) では
            // バックアップ停止ごとに追撃列が増殖し、複数列が短い間隔で鳴り続ける (PR #30 レビュー指摘)。
            // 追撃の登録に失敗した場合は、保険としてバックアップを残す
            cancelTodaysBackupAlarms()
        } catch {
            // 登録に失敗した追撃の記録を残すと、存在しない ID を保護し続けて掃除の判断を誤らせるため消す
            UserDefaults.standard.removeObject(forKey: .stopIntentChaseAlarmID)
            UserDefaults.standard.removeObject(forKey: .stopIntentChaseFireDate)
            appendStopIntentSpikeLog(message: "schedule() failed error=\(error)")
        }
    }

    /// 当日分の残バックアップアラームをキャンセルして記録からも消す。
    /// 追撃列の開始時 (追撃が保険を兼ねる) とスヌーズ上限到達時 (無料枠超過の防止) に呼ぶ。
    /// キャンセル失敗は次回 reschedule の全キャンセルで回収されるため、ログに残して続行する
    @MainActor
    private func cancelTodaysBackupAlarms() {
        let modelContext = PersistenceController.shared.container.mainContext
        let scheduledAlarms = (try? modelContext.fetch(FetchDescriptor<ScheduledAlarm>())) ?? []
        for backup in todaysBackupAlarmsToCancel(scheduledAlarms: scheduledAlarms, now: .now) {
            do {
                try AlarmManager.shared.cancel(id: backup.id)
                modelContext.delete(backup)
                appendStopIntentSpikeLog(message: "backup cancelled id=\(backup.id)")
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
