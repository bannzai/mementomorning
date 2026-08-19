import Foundation

extension String {
    /// 共有を促すダイアログを直近に表示した日時 (epoch 秒) を保存する UserDefaults キー。
    /// 初回の回答の朝に一度出し、以降は 2 週間おきに出すための記録 (issue #74)
    static let lastSharePromptDate = "lastSharePromptDate"
}

/// 共有を促すダイアログを出す間隔 (日)。初回から 2 週間おき (issue #74)
let sharePromptIntervalDays = 14

/// 直近に共有を促すダイアログを表示した日時を返す。未記録なら nil
func lastSharePromptDate() -> Date? {
    // UserDefaults の double(forKey:) は未設定時に 0 を返すため、0 を「未記録」として扱う
    let epochSeconds = UserDefaults.standard.double(forKey: .lastSharePromptDate)
    guard epochSeconds > 0 else { return nil }
    return Date(timeIntervalSince1970: epochSeconds)
}

/// 共有を促すダイアログを表示したことを記録する。ユーザーが共有したかどうかに関わらず「表示した」時点で記録し、
/// 同じ 2 週間の中で毎朝出さないようにする (同じ日時で何度呼んでも同じ記録に収束する冪等な操作)
func recordSharePromptPresented(date: Date) {
    UserDefaults.standard.set(date.timeIntervalSince1970, forKey: .lastSharePromptDate)
}

/// 共有を促すダイアログを表示すべきかを判定する純粋関数。
/// 今日の回答がある朝に限り、一度も出していなければ出す (初回)。以降は前回の表示から
/// sharePromptIntervalDays (14 日) 以上経った朝に出す (日数は暦日で数え、時刻の差では数えない)。
/// 動画回答の文字起こしが終わる前 (本文が仮テキスト placeholderText のまま) は、仮テキストのカードを共有させないため出さない。
/// 文字起こしの完了や「直す」で本文が変わった時に判定し直す
func shouldPresentSharePrompt(
    todayAnswerText: String?,
    placeholderText: String,
    lastPromptedDate: Date?,
    today: Date,
    calendar: Calendar = .current
) -> Bool {
    guard let todayAnswerText, todayAnswerText != placeholderText else { return false }
    guard let lastPromptedDate else { return true }
    let elapsedDays = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: lastPromptedDate),
        to: calendar.startOfDay(for: today)
    ).day ?? 0
    return elapsedDays >= sharePromptIntervalDays
}
