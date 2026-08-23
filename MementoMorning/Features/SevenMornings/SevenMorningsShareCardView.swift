import SwiftUI

/// 7 日の節目「七つの朝」の共有カード。最初の 7 つの回答を静かな 1 枚画像として表現する (issue #108)
struct SevenMorningsShareCardView: View {
    /// カードに並べる回答 (answeredDate 昇順の最初の 7 件)
    let answers: [MorningAnswer]

    /// 共有カードの幅 (pt)。ImageRenderer の scale 3 で 1080px になる
    static let width: CGFloat = 360
    /// 共有カードの高さ (pt)。scale 3 で 1920px (9:16 の縦長) になり、SNS のストーリー投稿にそのまま使える。
    /// 回答 1 件のカード (AnswerShareCardView) と違い 7 件を窮屈にせず並べるため縦長にする
    static let height: CGFloat = 640

    var body: some View {
        VStack(spacing: 0) {
            // ja: 今日死ぬとしたら何をやりたいですか？
            Text("If today were your last day, what would you want to do?")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                ForEach(answers) { answer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(answer.answeredDate, format: .dateTime.year().month().day())
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(.white.opacity(0.5))
                        Text(answer.text)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            // 長文の回答でもカードの固定サイズからあふれないよう縮小して収める
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            VStack(spacing: 6) {
                // ja: 七つの朝
                Text("Seven Mornings")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                Text(verbatim: "Memento Morning")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.white.opacity(0.35))
                    .kerning(1.5)
            }
        }
        .padding(36)
        .frame(width: Self.width, height: Self.height)
        .background(Color.black)
    }
}

/// 七つの朝の共有カードを 1 枚画像に書き出す。locale はテストで日英両方のレイアウトを検証するために注入できるようにしている
@MainActor
func renderSevenMorningsShareCardImage(answers: [MorningAnswer], locale: Locale = .current) -> UIImage? {
    let renderer = ImageRenderer(
        content: SevenMorningsShareCardView(answers: answers)
            .environment(\.locale, locale)
    )
    // カード 360x640pt を 1080x1920px で書き出すため (SevenMorningsShareCardView.width / height のコメント参照)
    renderer.scale = 3
    return renderer.uiImage
}
