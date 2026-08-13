import Foundation
import UserNotifications

/// 夜リマインド (「守れてますか?」) のスケジュール。朝の回答と答え合わせしてループを閉じるリテンション装置
enum NightReminder {
    /// 繰り返し通知 1 本を指す固定の識別子。同じ識別子で上書き登録することでスケジュールを冪等に保つ
    static let requestIdentifier = "night-reminder"
    /// 通知タップのルーティングに使う識別子。request identifier ではなくこちらで判定することで、simctl push で流し込んだ通知でも同じ経路を再現できる
    static let categoryIdentifier = "NIGHT_REMINDER"

    /// 夜リマインドの通知時刻 (時)。リマインドのカスタマイズはプレミアム機能のため、無料機能では固定値にする
    static let hour = 21
    /// 夜リマインドの通知時刻 (分)
    static let minute = 0

    /// 夜リマインドの通知内容を組み立てる
    static func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        // ja: 守れてますか?
        content.title = String(localized: "Are you keeping it?")
        // ja: 今朝の回答と答え合わせしましょう
        content.body = String(localized: "Check tonight against this morning's answer.")
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default
        return content
    }

    /// 夜リマインドの通知リクエストを組み立てる
    ///
    /// 保留中の通知は最大 64 件という制約に対し、毎日の繰り返しを 1 本の request で表現するため件数は常に 1 で収まる (件数管理は実行時チェックではなく定数設計で行う)
    static func makeRequest() -> UNNotificationRequest {
        UNNotificationRequest(
            identifier: requestIdentifier,
            content: makeContent(),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
        )
    }

    /// 通知の認可をリクエストし、許可されていれば夜リマインドを登録する
    ///
    /// 同じ識別子の保留中通知を削除してから登録するため、何度呼んでも保留中の夜リマインドは 1 本に保たれる。
    /// 主機能である AlarmKit のスケジュールを妨げないよう、UserNotifications 側のエラーは throw せず関数内で捕捉する
    static func requestAuthorizationAndSchedule() async {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
            try await center.add(makeRequest())
        } catch {
            print("[NightReminder] failed to schedule night reminder: \(error)")
        }
    }
}
