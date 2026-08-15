import AlarmKit
import Foundation
import SwiftData

/// 直近の reschedule タスク。
/// reschedule は await 中に中断されるため、複数呼び出しが交錯すると cancelAll / delete / schedule が
/// 重複実行され、アラームの重複登録や ScheduledAlarm の不整合が起きる。
/// タスクを連結して直列実行するためのグローバル状態 (MainActor 上でのみ触る)
@MainActor
private var latestRescheduleTask: Task<Void, Never>?

extension String {
    /// 直近の再スケジュールで発生したエラーを保存する UserDefaults キー。
    /// 成功時は削除される。AlarmSettingPage が @AppStorage で監視して失敗を可視化する
    static let lastRescheduleError = "lastRescheduleError"
}

/// 1 回の再スケジュールで AlarmKit へ登録する最大件数。
/// AlarmKit の上限値は非公開 (AlarmError.maximumLimitReached が存在する) なため、
/// UserNotifications の 64 件制限を参考に半分程度へ抑える定数設計 (.claude/rules/ios-alarmkit-constraints.md)
let maxScheduledAlarmCount = 30

/// reschedule と同じ直列キューで任意のアラーム操作を実行する。
/// StopAlarmIntent の追撃登録が reschedule (全キャンセル) と並行すると、
/// 「reschedule が保護記録を読む → Intent が登録を完了する → 古い集合で cancelAll」の順序で
/// 追撃が消される競合があるため、アラーム登録系の操作はこのキューへ連結して全順序を保証する (PR #30 レビュー指摘)
@MainActor
func performSerializedAlarmOperation(operation: @MainActor @escaping () async -> Void) async {
    let previousTask = latestRescheduleTask
    let task = Task {
        await previousTask?.value
        await operation()
    }
    latestRescheduleTask = task
    await task.value
}

/// エンジンの出力に従い「全キャンセル → 全再登録」を実行し、ScheduledAlarm 記録を更新する。
/// foreground 復帰時・設定変更時に手続的に呼ぶ (リアクティブな自動実行はしない。
/// 状態変化検知の自動実行は不意の解除・登録がアンコントローラブルになるため避ける)。
/// 全キャンセル → 全再登録の冪等方式のため、同じ状態で何度呼んでも結果は同じになる。
/// 並行呼び出しはタスク連結で直列化される (後勝ちで最終状態は最後の呼び出し時点の設定を反映する)
@MainActor
func reschedule(modelContext: ModelContext) async {
    await performSerializedAlarmOperation {
        // 有効なアラーム設定がある場合だけ認可を要求する。設定が無い/OFF の状態で拒否されると、
        // 後から設定を保存してもシステムの認可ダイアログは再表示できず、以降の登録が全件失敗し続けるため
        // (production の認可導線。拒否された場合は後続の schedule が throw し、エラーとして可視化される)
        let alarmSetting = (try? modelContext.fetch(FetchDescriptor<AlarmSetting>()))?.first
        if let alarmSetting, alarmSetting.isEnabled, AlarmKitManager.authorizationState == .notDetermined {
            _ = try? await AlarmKitManager.requestAuthorization()
        }
        // キュー待ち・認可ダイアログ表示の間に時刻が進んでいる可能性があるため、現在時刻は実行直前に取得する
        // (待機がアラーム設定時刻を跨ぐと、古い now では過去の発火日時を生成してしまう)
        await performReschedule(now: .now, modelContext: modelContext)
    }
}

/// reschedule の本体。直列化のため reschedule 経由でのみ呼ぶ。
/// 設定の読み取り・既存アラームの全キャンセルに失敗した場合は、既存状態を壊さないよう中断する (fail-closed)。
/// 失敗内容は lastRescheduleError キーで UserDefaults に保存し、アラーム設定画面で可視化する
@MainActor
private func performReschedule(now: Date, modelContext: ModelContext) async {
    let alarmSetting: AlarmSetting?
    do {
        // アラーム設定は単一レコード運用のため先頭 1 件を使う
        alarmSetting = try modelContext.fetch(FetchDescriptor<AlarmSetting>()).first
    } catch {
        // 読み取り失敗を「設定が無い」と誤認すると全アラームを代替なしで消してしまうため中断する
        UserDefaults.standard.set("\(error)", forKey: .lastRescheduleError)
        return
    }

    let existing = (try? modelContext.fetch(FetchDescriptor<ScheduledAlarm>())) ?? []

    // 発火予定日時が過ぎた記録があれば、そのアラームは発火した (またはスワイプ消去された) とみなして発火日時を記録する。
    // stopIntent の perform() が実行されない環境 (issue #3 のシミュレータ実測) やスワイプ消去でも、
    // foreground 復帰時にここで発火を検知して朝の問い (MorningQuestionPage) の提示へ繋げる。
    // 記録には main の発火日時だけを使う。バックアップは main より後 (+backupAlarmIntervalMinutes×n) のため
    // 深夜のアラームでは日付を跨ぐことがあり、跨いだ日時で記録すると「前日の朝」の発火を翌日の問いとして
    // 提示してしまう (バックアップが発火済みならその main も必ず発火予定日時を過ぎている)
    if let firedDate = existing.filter({ $0.origin == ScheduledAlarmOrigin.main }).map(\.fireDate).filter({ $0 <= now }).max() {
        recordAlarmFired(date: firedDate)
    }

    // 回答済みの日はアラームを鳴らさない。今日より先の日はまだ回答できないため今日の回答だけ調べれば足りる
    let answeredDates: Set<Date> = fetchMorningAnswer(answeredDate: now, modelContext: modelContext) != nil
        ? [Calendar.current.startOfDay(for: now)]
        : []

    let planned = planAlarms(
        now: now,
        alarmSetting: alarmSetting,
        answeredDates: answeredDates,
        alarmFiredDate: lastAlarmFiredDate()
    )

    // 停止直後に登録された未発火の追撃アラームは全キャンセルから保護する。
    // openAppWhenRun による foreground 復帰はこの reschedule を追撃の登録直後に走らせるため、
    // 無条件に消すと追撃が一度も発火しない (PR #30 レビュー指摘)。
    // 保護しない (記録も掃除する) のは次の 2 つの場合:
    // - 今日の回答が済んでいる (回答後は追撃も止めてよい。連続追撃カウントもここでリセットし、翌朝のスヌーズ枠を戻す)
    // - アラーム設定が OFF (OFF 表示のまま追撃だけが鳴り続けるのを防ぐ。PR #30 レビュー指摘)
    let preservedAlarmIDs: Set<UUID>
    let todayAnswered = hasTodayAnswer(modelContext: modelContext)
    if todayAnswered {
        // 回答が成立した朝の追撃は役目を終えた。連続追撃カウント (スヌーズ消費数) もリセットし、翌朝の無料枠を戻す
        UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
    }
    if todayAnswered || alarmSetting?.isEnabled != true {
        UserDefaults.standard.removeObject(forKey: .stopIntentChaseAlarmID)
        UserDefaults.standard.removeObject(forKey: .stopIntentChaseFireDate)
        preservedAlarmIDs = []
    } else {
        preservedAlarmIDs = Set(
            [protectedChaseAlarmID(
                chaseAlarmID: UserDefaults.standard.string(forKey: .stopIntentChaseAlarmID).flatMap(UUID.init(uuidString:)),
                chaseFireDate: (UserDefaults.standard.object(forKey: .stopIntentChaseFireDate) as? Double).map(Date.init(timeIntervalSince1970:)),
                now: now
            )].compactMap { $0 }
        )
    }

    do {
        try AlarmKitManager.cancelAll(preservedAlarmIDs: preservedAlarmIDs)
    } catch {
        // 途中まで消えている可能性があるため実際の残数で判断する。
        // 残っていれば中断 (fail-closed。次回 foreground の再スケジュールで自己修復する)。
        // 全て消えていれば発火済み等の無害なエラーとみなして続行する
        if AlarmKitManager.hasRemainingAlarms(preservedAlarmIDs: preservedAlarmIDs) {
            UserDefaults.standard.set("\(error)", forKey: .lastRescheduleError)
            return
        }
    }

    for scheduled in existing {
        modelContext.delete(scheduled)
    }

    var scheduleErrors: [String] = []
    // AlarmKit の件数上限に達した場合に直近のアラームが優先されるよう、発火日時の近い順に登録し、
    // maxScheduledAlarmCount で 1 回の再スケジュールあたりの登録件数にキャップをかける
    for plan in planned.sorted(by: { $0.fireDate < $1.fireDate }).prefix(maxScheduledAlarmCount) {
        let alarmID = UUID()
        do {
            // ja: 今日死ぬとしたら、何をやりたいか
            let title = LocalizedStringResource("If today were your last day, what would you want to do?")
            try await AlarmKitManager.schedule(id: alarmID, fireDate: plan.fireDate, title: title)
        } catch {
            // 一部のアラームだけ登録に失敗するケース (件数上限等) も沈黙させず記録する
            scheduleErrors.append("\(error)")
            continue
        }

        modelContext.insert(ScheduledAlarm(id: alarmID, fireDate: plan.fireDate, origin: plan.origin))
    }

    do {
        try modelContext.save()
    } catch {
        // OS アラームは登録済みなのに記録が残らないと UI が古い状態を表示し続けるため、成功扱いにしない
        scheduleErrors.append("\(error)")
    }

    if scheduleErrors.isEmpty {
        UserDefaults.standard.removeObject(forKey: .lastRescheduleError)
    } else {
        UserDefaults.standard.set(scheduleErrors.joined(separator: "\n"), forKey: .lastRescheduleError)
    }
}
