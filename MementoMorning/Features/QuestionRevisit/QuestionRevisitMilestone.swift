import Foundation
import SwiftData

extension String {
    /// 90 日の節目「問い直し」を表示済みかどうかを保存する UserDefaults キー。
    /// 回答が 90 件に達した朝に一度だけ表示するための記録 (issue #187)
    static let isQuestionRevisitMilestonePresented = "isQuestionRevisitMilestonePresented"
}

/// 節目の対象になる回答数。90 日の節目「問い直し」の 90 (documents/PROJECT.md の節目の設計)
let questionRevisitMilestoneAnswerCount = 90

/// 90 日の節目「問い直し」を表示すべきかを判定する。
/// 課金線はプレミアム (documents/PROJECT.md の節目の設計) のため、無料では件数が揃っても表示しない。
/// 一度表示したら二度と自動表示しない (冪等)
func shouldPresentQuestionRevisitMilestone(answerCount: Int, isPresented: Bool, isPremium: Bool) -> Bool {
    !isPresented && isPremium && answerCount >= questionRevisitMilestoneAnswerCount
}

/// 「問い直し」で左右に並べる回答のうち、古い順で number 件目 (1 始まり) の 1 件だけを取得する。
/// 履歴系クエリのため fetchLimit を設定する (.claude/rules/swiftdata-guidelines.md)
func questionRevisitAnswerDescriptor(number: Int) -> FetchDescriptor<MorningAnswer> {
    var descriptor = FetchDescriptor<MorningAnswer>(
        sortBy: [SortDescriptor(\MorningAnswer.answeredDate, order: .forward)]
    )
    descriptor.fetchOffset = max(1, number) - 1
    descriptor.fetchLimit = 1
    return descriptor
}

/// 「問い直し」に並べる 1 件目と 90 件目が揃い、処理中の動画文字起こしが無いかを返す。
/// 表示した時点で表示済みになり再表示しないため、文字起こしの仮テキストのまま節目を消費しないよう pending の間は待つ。
/// 文字起こし失敗は待機対象にせず、回答本文 (仮テキスト) をそのまま並べる (isOneMonthLetterReady と同じ扱い)
func isQuestionRevisitReady(videoTranscriptionStatuses: [VideoTranscriptionStatus?]) -> Bool {
    videoTranscriptionStatuses.count == 2 && !videoTranscriptionStatuses.contains(.pending)
}
