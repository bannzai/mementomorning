import Foundation

extension String {
    /// 最後に表示した「一ヶ月の手紙」の通数を保存する UserDefaults キー。
    /// 0 は未表示、1 は最初の 30 回分を表示済み、2 は次の 30 回分まで表示済みを表す。
    static let lastPresentedOneMonthLetterNumber = "lastPresentedOneMonthLetterNumber"
}

/// 「一ヶ月の手紙」1 通を構成する回答数 (documents/PROJECT.md の節目の設計)。
let oneMonthLetterAnswerCount = 30

/// 現在表示できる次の「一ヶ月の手紙」の通数を返す。
///
/// 手紙は古いものから順番に一度ずつ表示する。1 通目は無料、2 通目以降はプレミアム限定。
/// 同じ入力には常に同じ結果を返す純粋関数で、表示済みの通数を進めるまで同じ手紙を返す。
func nextOneMonthLetterNumber(
    answerCount: Int,
    lastPresentedNumber: Int,
    isPremium: Bool
) -> Int? {
    let nextNumber = max(0, lastPresentedNumber) + 1
    guard answerCount / oneMonthLetterAnswerCount >= nextNumber else { return nil }
    guard nextNumber == 1 || isPremium else { return nil }
    return nextNumber
}

/// fullScreenCover(item:) で表示対象の通数を固定するための値。
struct OneMonthLetterPresentation: Identifiable {
    let milestoneNumber: Int

    var id: Int { milestoneNumber }
}
