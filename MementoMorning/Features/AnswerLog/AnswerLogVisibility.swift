import Foundation

/// 回答ログの閲覧可否の判定。無料枠は直近 7 日、プレミアムは全履歴 (課金設計は documents/PROJECT.md 参照)
enum AnswerLogVisibility {
    /// 無料枠で閲覧できる日数。PROJECT.md の課金設計「直近 7 日のログ」に合わせる
    static let freeTierDays = 7

    /// answeredDate の回答を現在の課金状態で閲覧できるか。
    /// 今日を 1 日目と数え、日単位の差が freeTierDays 未満 (0...6) なら無料でも閲覧できる。
    /// 日単位の差が 7 以上 (= 8 日以上前) の回答はプレミアムのみ閲覧できる
    static func isVisible(answeredDate: Date, isPremium: Bool, today: Date = .now, calendar: Calendar = .current) -> Bool {
        if isPremium {
            return true
        }
        guard let dayDiff = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: answeredDate),
            to: calendar.startOfDay(for: today)
        ).day else {
            return false
        }
        return dayDiff < freeTierDays
    }
}
