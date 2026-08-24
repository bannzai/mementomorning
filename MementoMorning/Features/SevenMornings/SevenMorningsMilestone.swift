import Foundation

extension String {
    /// 7 日の節目「七つの朝」を表示済みかどうかを保存する UserDefaults キー。
    /// 回答が 7 件に達した朝に一度だけ表示するための記録 (issue #10)
    static let isSevenMorningsMilestonePresented = "isSevenMorningsMilestonePresented"
}

/// 節目の対象になる回答数。7 日の節目「七つの朝」の 7 (documents/PROJECT.md の節目の設計)
let sevenMorningsMilestoneAnswerCount = 7

/// 7 日の節目「七つの朝」を表示すべきかを判定する。一度表示したら二度と自動表示しない (冪等)
func shouldPresentSevenMorningsMilestone(answerCount: Int, isPresented: Bool) -> Bool {
    !isPresented && answerCount >= sevenMorningsMilestoneAnswerCount
}
