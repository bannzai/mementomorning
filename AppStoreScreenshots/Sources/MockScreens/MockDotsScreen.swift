import SwiftUI

/// 「点」画面 (DotsPage) のモック。
/// 答えた朝の数だけ粒が積もった山と、いちばん新しい朝の夜明けリングを再現する
struct MockDotsScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            // ja: 点
            Text("Dots")
                .font(.system(size: 15, weight: .medium))
                .tracking(2.1)
                .foregroundStyle(Color.warmWhite)
                .padding(.top, 70)
                .padding(.bottom, 14)

            // ja: ひと粒が、答えたひとつの朝
            Text("One dot, one answered morning.")
                .font(.system(size: 11))
                .tracking(0.66)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 40)

            Spacer()

            dotPile

            Spacer()

            VStack(spacing: 6) {
                // ja: 答えた朝 32
                Text("32 mornings answered")
                    .font(.system(size: 12))
                    .tracking(1.2)
                    .foregroundStyle(Color.warmWhite.opacity(0.55))
                // ja: 点は、いつかつながる。
                Text("The dots will connect.")
                    .font(.system(size: 11))
                    .tracking(0.88)
                    .foregroundStyle(Color.warmWhite.opacity(0.32))
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }

    /// 積もった粒の山。
    /// 本番は物理で積もるが、スクリーンショットは毎回同じ絵にするため物理・乱数を使わず静止した俵積みを描く
    private var dotPile: some View {
        // 行間は直径 (13) の 0.88 倍 (俵積みで自然に噛み合う高さ) になるよう負の spacing を入れる
        VStack(spacing: -13 * 0.12) {
            // 上から 1, 3, 4, 6, 8, 10 粒の計 32 粒。「答えた朝 32」の表示と数を一致させる
            ForEach(Array([1, 3, 4, 6, 8, 10].enumerated()), id: \.offset) { rowIndex, count in
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(Color.warmWhite)
                            .frame(width: 13, height: 13)
                            .overlay {
                                // 頂上の 1 粒 (いちばん新しい朝) にだけ夜明け色のリングを添える (アクセントは各画面 1 箇所まで)
                                if rowIndex == 0 {
                                    Circle()
                                        .stroke(Color.dawn.opacity(0.35), lineWidth: 3)
                                        .frame(width: 20, height: 20)
                                }
                            }
                    }
                }
            }
        }
    }
}
