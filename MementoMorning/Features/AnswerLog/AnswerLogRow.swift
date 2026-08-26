import SwiftUI

/// 回答 1 行 (日付 + 夜の結果 + 回答本文、ヘアライン区切り)。タップで共有カードを開く。
/// 動画で答えた行は本文の下に「動画を見返す」導線を添え、再生画面を開く (issue #80)。
/// ジャーナル (AnswerLogPage) の一覧と、カレンダー (MonthCalendarPage) で選んだ日の表示で同じ見た目を共有する
struct AnswerLogRow: View {
    /// 表示する回答
    let answer: MorningAnswer
    /// 行本体をタップした時の処理。共有カードを開く
    let shareAction: () -> Void
    /// 「動画を見返す」導線をタップした時の処理。引数は再生する動画の videoAssetIdentifier
    let replayVideoAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            shareCardButton
            if let videoAssetIdentifier = answer.videoAssetIdentifier {
                Button {
                    replayVideoAction(videoAssetIdentifier)
                } label: {
                    // ja: 動画を見返す
                    Text("Watch the video")
                        .font(.system(size: 11))
                        .tracking(1.1)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                        .underline()
                        .padding(.bottom, 19)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("journal_video_replay_link")
            }
        }
        .overlay(alignment: .bottom) {
            HairlineDivider()
        }
    }

    /// 回答本文の部分 (日付 + 夜の結果 + 回答本文)。タップで共有カードを開く
    private var shareCardButton: some View {
        let isToday = Calendar.current.isDateInToday(answer.answeredDate)
        return Button {
            shareAction()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Group {
                        if isToday {
                            // ja: 今日
                            Text("Today")
                        } else {
                            Text(answer.answeredDate, format: .dateTime.year().month().day())
                        }
                    }
                    .font(.system(size: 11))
                    .tracking(1.1)
                    // 今日の行の日付だけ夜明け色 (アクセントは各画面 1 箇所まで)
                    .foregroundStyle(isToday ? Color.dawn : Color.warmWhite.opacity(0.38))
                    Spacer()
                    // 過去の行の右端に夜の振り返りの結果を添える。未記録の行には何も表示しない
                    if !isToday, let isFulfilled = answer.isFulfilled {
                        Group {
                            if isFulfilled {
                                // ja: やれた
                                Text("I did")
                            } else {
                                Text(verbatim: "—")
                            }
                        }
                        .font(.system(size: 10))
                        .tracking(1.0)
                        .foregroundStyle(Color.warmWhite.opacity(0.35))
                    }
                }
                Text(answer.text)
                    .font(.system(size: 17, weight: .light))
                    .tracking(0.51)
                    .lineSpacing(17 * 0.6)
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 19)
            // 動画の行は「動画を見返す」導線が下の余白を受け持つため、本文側の下余白を詰める
            .padding(.bottom, answer.videoAssetIdentifier == nil ? 19 : 10)
            // plain スタイルの Button はラベルの描画領域しかタップに反応しないため、
            // 行全体に広げた透明領域もヒット対象にして行のどこを押しても共有カードを開けるようにする
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
