import SwiftUI

/// 7 日の節目「七つの朝」(SevenMorningsPage) のモック。
/// デザイン handoff 1h (mono 番号 01–07 + 回答 7 行 + secondary ボタン) を再現する
struct MockSevenMorningsScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // ja: 7日目の朝に
                Text("On the seventh morning")
                    .font(.system(size: 10))
                    .tracking(2.4)
                    .foregroundStyle(Color.dawn)
                // ja: 七つの朝
                Text("Seven Mornings")
                    .font(.system(size: 27, weight: .light))
                    .tracking(1.62)
                    .foregroundStyle(Color.warmWhite)
                // ja: 七日分の答えが、はじめて一枚に並びました
                Text("Seven answers, together on one page for the first time.")
                    .font(.system(size: 12))
                    .tracking(0.72)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 84)
            .padding(.horizontal, 36)

            VStack(spacing: 0) {
                // ja: 家族と海を見に行く
                morningRow(number: "01", answer: Text("Go see the ocean with my family"))
                // ja: 母に長い電話をかける
                morningRow(number: "02", answer: Text("Call my mother and talk for a while"))
                // ja: 行きつけの店で好きなものを食べる
                morningRow(number: "03", answer: Text("Eat my favorite meal at my favorite place"))
                // ja: 友人に手紙を書く
                morningRow(number: "04", answer: Text("Write a letter to an old friend"))
                // ja: 子どもと一日中遊ぶ
                morningRow(number: "05", answer: Text("Spend the whole day with my kids"))
                // ja: 誰にも言えなかったことを伝える
                morningRow(number: "06", answer: Text("Say what I never could"))
                // ja: 朝日を最後まで眺める
                morningRow(number: "07", answer: Text("Watch the sunrise to the end"))
            }
            .padding(.top, 28)
            .padding(.horizontal, 36)

            Spacer()

            // ja: この七日を、一枚に
            MockPillLabel(label: Text("Keep these seven days on one card"), isPrimary: false)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }

    /// 回答 1 行 (mono 番号 + 回答本文、ヘアライン区切り)
    private func morningRow(number: String, answer: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(verbatim: number)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.warmWhite.opacity(0.38))
            answer
                .font(.system(size: 15, weight: .light))
                .tracking(0.45)
                .foregroundStyle(Color.warmWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            HairlineDivider()
        }
    }
}
