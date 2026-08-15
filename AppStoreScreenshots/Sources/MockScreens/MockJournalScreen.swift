import SwiftUI

/// ジャーナル画面 (AnswerLogPage) のモック。
/// 日付 + 回答 + 夜の結果のヘアライン区切り行と、無料枠のロック行を本番のトークンどおりに再現する
struct MockJournalScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                // ja: ジャーナル
                Text("Journal")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2.1)
                    .foregroundStyle(Color.warmWhite)
                Text(verbatim: "JOURNAL")
                    .font(.system(size: 9))
                    .tracking(2.34)
                    .foregroundStyle(Color.warmWhite.opacity(0.4))
            }
            .padding(.top, 70)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                journalRow(
                    // ja: 今日
                    dateLabel: Text("Today"),
                    // ja: 家族と海を見に行く
                    answer: Text("Go see the ocean with my family"),
                    isToday: true,
                    result: nil
                )
                journalRow(
                    dateLabel: Text(day(offset: -1), format: .dateTime.year().month().day()),
                    // ja: 母に長い電話をかける
                    answer: Text("Call my mother and talk for a while"),
                    isToday: false,
                    // ja: やれた
                    result: Text("I did")
                )
                journalRow(
                    dateLabel: Text(day(offset: -2), format: .dateTime.year().month().day()),
                    // ja: 友人に手紙を書く
                    answer: Text("Write a letter to an old friend"),
                    isToday: false,
                    result: Text(verbatim: "—")
                )
                journalRow(
                    dateLabel: Text(day(offset: -3), format: .dateTime.year().month().day()),
                    // ja: 朝日を最後まで眺める
                    answer: Text("Watch the sunrise to the end"),
                    isToday: false,
                    // ja: やれた
                    result: Text("I did")
                )
                journalRow(
                    dateLabel: Text(day(offset: -4), format: .dateTime.year().month().day()),
                    // ja: 誰にも言えなかったことを伝える
                    answer: Text("Say what I never could"),
                    isToday: false,
                    result: nil
                )
            }
            .padding(.horizontal, 32)

            VStack(spacing: 5) {
                // ja: 7日より前の朝は、プレミアムで。
                Text("Older mornings unlock with Premium.")
                    .font(.system(size: 12))
                    .tracking(0.96)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                // ja: すべての朝を見る
                Text("See every morning")
                    .font(.system(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Color.dawn)
            }
            .padding(.vertical, 28)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }

    /// 今日から offset 日ずらした日付。日付表記のローカライズは Text の format に任せる
    private func day(offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: .now)!
    }

    /// 回答 1 行 (日付 + 夜の結果 + 回答本文、ヘアライン区切り)
    private func journalRow(dateLabel: Text, answer: Text, isToday: Bool, result: Text?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                dateLabel
                    .font(.system(size: 11))
                    .tracking(1.1)
                    .foregroundStyle(isToday ? Color.dawn : Color.warmWhite.opacity(0.38))
                Spacer()
                if let result {
                    result
                        .font(.system(size: 10))
                        .tracking(1.0)
                        .foregroundStyle(Color.warmWhite.opacity(0.35))
                }
            }
            answer
                .font(.system(size: 17, weight: .light))
                .tracking(0.51)
                .foregroundStyle(Color.warmWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 19)
        .overlay(alignment: .bottom) {
            HairlineDivider()
        }
    }
}
