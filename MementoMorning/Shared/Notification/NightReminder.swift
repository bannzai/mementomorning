import Foundation
import UserNotifications

/// 夜リマインド (「守れてますか?」) のスケジュール。朝の回答と答え合わせしてループを閉じるリテンション装置
enum NightReminder {
    /// 夜リマインドの識別子の接頭辞。日付を後置した one-shot 通知を日数分登録し、登録し直す時はこの接頭辞で保留中の通知をまとめて掃除する
    /// (繰り返し通知 1 本だった頃の識別子 "night-reminder" もこの接頭辞に一致するため、同じ掃除で削除される)
    static let requestIdentifierPrefix = "night-reminder"
    /// 通知タップのルーティングに使う識別子。request identifier ではなくこちらで判定することで、simctl push で流し込んだ通知でも同じ経路を再現できる
    static let categoryIdentifier = "NIGHT_REMINDER"

    /// 夜リマインドの通知時刻 (時)。リマインドのカスタマイズはプレミアム機能のため、無料機能では固定値にする
    static let hour = 21
    /// 夜リマインドの通知時刻 (分)
    static let minute = 0

    /// 一度に登録する夜リマインドの日数。
    /// 保留中の通知は最大 64 件という制約に対し、本アプリで UserNotifications を使うのは夜リマインドだけのため、30 日分 + デバッグ用 1 本でも上限に十分収まる (件数管理は実行時チェックではなく定数設計で行う)。
    /// トレードオフとして、最後にアプリを開いてから 30 日を過ぎるとリマインドは止まる (次にアプリを開いた時の登録し直しで再開する)
    static let scheduledDayCount = 30

    /// 通知本文に引用する回答テキストの最大文字数。
    /// 折りたたみ表示の通知バナーで読める本文はおよそ 2 行 = 日本語全角で 50〜60 字のため、バナーで読み切れる範囲に収める
    static let answerTextMaxLength = 60

    /// 通知本文に引用するために回答テキストを整える。改行は通知バナーで詰めて表示されるため半角スペースに畳み、上限を超える分は省略記号にする
    static func truncatedAnswerText(text: String) -> String {
        let singleLineText = text.components(separatedBy: .newlines).joined(separator: " ")
        guard singleLineText.count > answerTextMaxLength else {
            return singleLineText
        }
        return String(singleLineText.prefix(answerTextMaxLength)) + "…"
    }

    /// 指定日の夜リマインドの識別子 ("night-reminder-2026-08-14" 形式) を組み立てる。日ごとに一意にすることで、同じ日への登録し直しが置換になる
    static func requestIdentifier(day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        // 識別子はユーザーに見せる文字列ではないため、端末の暦・言語設定で表記が揺れない固定ロケールを使う
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(requestIdentifierPrefix)-\(formatter.string(from: day))"
    }

    /// 夜リマインドの通知内容を組み立てる。answerText があればその朝の回答を引用し、無ければ汎用の文言にする
    static func makeContent(answerText: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        // ja: 守れてますか?
        content.title = String(localized: "Are you keeping it?")
        if let answerText {
            // ja: 今朝のあなた『(回答)』
            content.body = String(localized: "This morning you said '\(truncatedAnswerText(text: answerText))'")
        } else {
            // ja: 今朝の回答と答え合わせしましょう
            content.body = String(localized: "Check tonight against this morning's answer.")
        }
        content.categoryIdentifier = categoryIdentifier
        content.sound = .default
        return content
    }

    /// 今日から scheduledDayCount 日分の夜リマインドの通知リクエストを組み立てる
    ///
    /// 繰り返しトリガー 1 本ではなく日付つきの one-shot を並べることで、当日分だけ今朝の回答を引用した本文にできる。
    /// 保留中の通知は最大 64 件という制約に対し、組み立てる件数は多くても scheduledDayCount のため上限に収まる (件数管理は実行時チェックではなく定数設計で行う)
    static func makeRequests(todayAnswerText: String?, now: Date, calendar: Calendar) -> [UNNotificationRequest] {
        (0..<scheduledDayCount).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  // 過去日時の one-shot なカレンダートリガーは発火しないため、今日の通知時刻を過ぎている場合は当日分を登録しない
                  fireDate > now
            else {
                return nil
            }
            return UNNotificationRequest(
                identifier: requestIdentifier(day: day, calendar: calendar),
                content: makeContent(answerText: dayOffset == 0 ? todayAnswerText : nil),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
            )
        }
    }

    /// 通知の認可をリクエストし、許可されていれば夜リマインドを登録し直す
    ///
    /// 接頭辞に一致する保留中の通知を削除してから登録し直すため、何度呼んでも保留中の夜リマインドは scheduledDayCount 日分に保たれる。
    /// 主機能である AlarmKit のスケジュールを妨げないよう、UserNotifications 側のエラーは throw せず関数内で捕捉する
    static func requestAuthorizationAndSchedule(todayAnswerText: String?) async {
        let center = UNUserNotificationCenter.current()
        do {
            // バックグラウンド遷移時にも呼ばれるため、認可が未決定の時だけ要求して不要な認可ダイアログを避ける
            switch await center.notificationSettings().authorizationStatus {
            case .notDetermined:
                guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                    return
                }
            case .denied:
                return
            default:
                break
            }
            // 繰り返し通知 1 本だった頃の "night-reminder" もこの接頭辞で一緒に掃除される。デバッグ用は "debug-night-reminder" と別の名前空間にしてあるため巻き込まれない
            center.removePendingNotificationRequests(
                withIdentifiers: await center.pendingNotificationRequests()
                    .map(\.identifier)
                    .filter { $0.hasPrefix(requestIdentifierPrefix) }
            )
            for request in makeRequests(todayAnswerText: todayAnswerText, now: .now, calendar: .current) {
                try await center.add(request)
            }
        } catch {
            print("[NightReminder] failed to schedule night reminder: \(error)")
        }
    }
}
