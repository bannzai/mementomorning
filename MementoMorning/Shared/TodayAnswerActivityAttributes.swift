import ActivityKit

/// ロック画面に「今日の目標」(今日の回答) を表示する Live Activity の属性 (issue #45)。
/// ActivityKit はアプリと Widget Extension の間で属性の型名と Codable 表現を照合するため、
/// この型は両ターゲットの sources に所属させる (project.yml の MementoMorningWidget 参照)
struct TodayAnswerActivityAttributes: ActivityAttributes {
    /// Live Activity の可変状態
    struct ContentState: Codable, Hashable {
        /// 今日の回答本文。文字起こしの完了・編集で置き換わる
        var text: String
    }
}
