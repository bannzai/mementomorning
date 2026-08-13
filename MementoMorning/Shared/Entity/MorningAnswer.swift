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
}
