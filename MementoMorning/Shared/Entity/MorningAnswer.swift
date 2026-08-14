import Foundation
import SwiftData

/// 毎朝の問い「今日死ぬとしたら何をやりたいか」へのユーザーの回答。1 日 1 件蓄積され、人生ジャーナルの最小単位になる
@Model
final class MorningAnswer {
    @Attribute(.unique) var id: UUID
    var createdDateTime: Date = Date.now
    private(set) var updatedDateTime: Date = Date.now

    /// 回答が属する日 (その日の 0 時)。同じ日の回答は 1 件に保つ
    private(set) var answeredDate: Date
    /// 回答本文 (ユーザーの自由入力)
    private(set) var text: String
    /// 夜の振り返りの記録。true = やれた / false = やれていない / nil = 未記録。180 日の節目「まだ、やれていないこと」の原資データ
    private(set) var isFulfilled: Bool?

    init(id: UUID = .init(), answeredDate: Date, text: String) {
        self.id = id
        self.answeredDate = answeredDate
        self.text = text
    }

    /// text を更新する
    func setText(text: String) {
        self.text = text
        self.updatedDateTime = .now
    }

    /// 夜の振り返りの記録を更新する
    func setFulfilled(isFulfilled: Bool) {
        self.isFulfilled = isFulfilled
        self.updatedDateTime = .now
    }
}

/// 指定日 (0 時基準) の回答を取得する。1 日 1 件のため 1 件だけ取得する
@MainActor
func fetchMorningAnswer(answeredDate: Date, modelContext: ModelContext, calendar: Calendar = .current) -> MorningAnswer? {
    let day = calendar.startOfDay(for: answeredDate)
    var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == day })
    descriptor.fetchLimit = 1
    return try? modelContext.fetch(descriptor).first
}
