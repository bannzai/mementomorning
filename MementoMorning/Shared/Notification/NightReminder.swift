import Foundation
import SwiftData
import UserNotifications

/// 夜リマインド (「守れてますか?」) のスケジュール。朝の回答と答え合わせしてループを閉じるリテンション装置
enum NightReminder {
    /// 夜リマインドの識別子の接頭辞。日付と時刻を後置した one-shot 通知を日数 × 本数だけ登録し、登録し直した後にこの接頭辞で残った古い通知を掃除する
    /// (繰り返し通知 1 本だった頃の識別子 "night-reminder" や、1 日 1 本だった頃の "night-reminder-2026-08-14" もこの接頭辞に一致するため、同じ掃除で削除される)
    static let requestIdentifierPrefix = "night-reminder"
    /// 通知タップのルーティングに使う識別子。request identifier ではなくこちらで判定することで、simctl push で流し込んだ通知でも同じ経路を再現できる
    static let categoryIdentifier = "NIGHT_REMINDER"

    /// 保留中の通知として同時に保持できる上限件数。超過分は登録されず直近 64 件だけが残る。
    /// ref: https://developer.apple.com/documentation/usernotifications (.claude/rules/ios-alarmkit-constraints.md)
    static let pendingNotificationLimit = 64

    /// 一度に登録する夜リマインドの日数。
    /// 本アプリで UserNotifications を使うのは夜リマインドだけのため、1 日あたり最大 maxNightReminderCount 本 × この日数 + デバッグ用 1 本が
    /// pendingNotificationLimit に収まるように決める (件数管理は実行時チェックではなく定数設計で行う。3 × 20 + 1 = 61 ≤ 64)。
    /// トレードオフとして、1 日 3 本にした分だけ先読みできる日数が短くなり、最後にアプリを開いてから 20 日を過ぎるとリマインドは止まる
    /// (次にアプリを開いた時の登録し直しで再開する)
    static let scheduledDayCount = 20

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

    /// 指定日・指定時刻の夜リマインドの識別子 ("night-reminder-2026-08-14-2100" 形式) を組み立てる。
    /// 日付と時刻の組ごとに一意にすることで、同じ日の同じ時刻への登録し直しが置換になる (1 日に複数本あっても互いを潰さない)
    static func requestIdentifier(day: Date, time: DateComponents, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        // 識別子はユーザーに見せる文字列ではないため、端末の暦・言語設定で表記が揺れない固定ロケールを使う
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return String(format: "%@-%@-%02d%02d", requestIdentifierPrefix, formatter.string(from: day), time.hour ?? 0, time.minute ?? 0)
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

    /// 今日から scheduledDayCount 日分、指定された時刻ごとの夜リマインドの通知リクエストを組み立てる
    ///
    /// 繰り返しトリガー 1 本ではなく日付つきの one-shot を並べることで、当日分だけ今朝の回答を引用した本文にできる。
    /// 組み立てる件数は多くても times.count × scheduledDayCount であり、times は effectiveNightReminderTimes が
    /// maxNightReminderCount 本までに制限するため pendingNotificationLimit に収まる (件数管理は実行時チェックではなく定数設計で行う)
    static func makeRequests(times: [DateComponents], todayAnswerText: String?, now: Date, calendar: Calendar) -> [UNNotificationRequest] {
        (0..<scheduledDayCount).flatMap { dayOffset -> [UNNotificationRequest] in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else {
                return []
            }
            return times.compactMap { time in
                guard let fireDate = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day),
                      // 過去日時の one-shot なカレンダートリガーは発火しないため、今日の通知時刻を過ぎている場合は当日分を登録しない
                      fireDate > now
                else {
                    return nil
                }
                return UNNotificationRequest(
                    identifier: requestIdentifier(day: day, time: time, calendar: calendar),
                    content: makeContent(answerText: dayOffset == 0 ? todayAnswerText : nil),
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                        repeats: false
                    )
                )
            }
        }
    }

    /// 通知の認可をリクエストし、許可されていれば夜リマインドを登録し直す
    ///
    /// 先に全件を登録し (同一識別子の add は保留中の既存リクエストを置換する)、全件の登録に成功してから今回登録しなかった古い分だけを削除する。
    /// この順序により、途中で登録に失敗しても既存のスケジュールが残る (先に削除すると失敗時に夜リマインドが 1 本も無い状態になる)。
    /// 主機能である AlarmKit のスケジュールを妨げないよう、UserNotifications 側のエラーは throw せず関数内で捕捉する
    static func requestAuthorizationAndSchedule(times: [DateComponents], todayAnswerText: String?) async {
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
            // 掃除の対象は登録前の保留分に限るため、add より先に控えておく。
            // 繰り返し通知 1 本だった頃の "night-reminder" もこの接頭辞に一致するため一緒に掃除される。デバッグ用は "debug-night-reminder" と別の名前空間にしてあるため巻き込まれない
            let existingIdentifiers = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(requestIdentifierPrefix) }
            let requests = makeRequests(times: times, todayAnswerText: todayAnswerText, now: .now, calendar: .current)
            for request in requests {
                try await center.add(request)
            }
            center.removePendingNotificationRequests(
                withIdentifiers: Array(Set(existingIdentifiers).subtracting(requests.map(\.identifier)))
            )
        } catch {
            print("[NightReminder] failed to schedule night reminder: \(error)")
        }
    }
}

/// 保存済みの設定 (NightReminderSetting) と課金状態から、実際に登録する夜リマインドの通知時刻を返す。
/// 取得に失敗した時は未設定と同じ既定の 1 本 (21:00) に倒す。夜リマインドが 1 本も鳴らない状態にするより、
/// 従来の固定時刻で鳴らし続ける方がユーザーの損失が小さいため
@MainActor
func scheduledNightReminderTimes(modelContext: ModelContext) -> [DateComponents] {
    effectiveNightReminderTimes(
        times: ((try? NightReminderSetting.all(modelContext: modelContext)) ?? []).map {
            DateComponents(hour: $0.hour, minute: $0.minute)
        },
        isPremium: PremiumEntitlement.isPremium
    )
}

/// 保存済みの設定と今朝の回答から夜リマインドを登録し直す。今朝の回答を既に手元に持っている呼び出し側は
/// NightReminder.requestAuthorizationAndSchedule を直接使う。
/// 回答の取得に失敗した時は、登録済みのパーソナライズ通知を汎用文言で上書きしないよう登録し直さない (次の呼び出しで再試行される)
@MainActor
func rescheduleNightReminder(modelContext: ModelContext) async {
    do {
        await NightReminder.requestAuthorizationAndSchedule(
            times: scheduledNightReminderTimes(modelContext: modelContext),
            todayAnswerText: try MorningAnswer.answer(day: .now, calendar: .current, modelContext: modelContext)?.text
        )
    } catch {
        print("[NightReminder] failed to fetch today's answer: \(error)")
    }
}
