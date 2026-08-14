import SwiftUI

/// 共有カードの本体。回答 1 件を静かな 1 枚画像として表現する (スクリーンショット共有の導線。ideamemo#187 参照)
struct AnswerShareCardView: View {
    let answeredDate: Date
    let text: String

    /// 共有カードの一辺 (pt)。ImageRenderer の scale 3 で 1080px 四方になり、SNS の正方形投稿にそのまま使える
    static let sideLength: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            // ja: 今日死ぬとしたら、何をやりたいか
            Text("If today were your last day, what would you want to do?")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer()
            Text(text)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                // 長文の回答でもカードの固定サイズからあふれないよう縮小して収める
                .minimumScaleFactor(0.5)
            Spacer()
            VStack(spacing: 6) {
                Text(answeredDate, format: .dateTime.year().month().day())
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.white.opacity(0.6))
                Text(verbatim: "Memento Morning")
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(.white.opacity(0.35))
                    .kerning(1.5)
            }
        }
        .padding(36)
        .frame(width: Self.sideLength, height: Self.sideLength)
        .background(Color.black)
    }
}
