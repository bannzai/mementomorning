import SwiftUI

/// ホーム画面 (ContentView の HomeContent) のモック。
/// 次の朝の大時刻・トグル・今朝のことば・背景に積もった粒を本番のトークンどおりに再現する
struct MockHomeScreen: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ink
            dotPile
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(verbatim: "NEXT MORNING")
                        .font(.system(size: 10))
                        .tracking(2.6)
                        .foregroundStyle(Color.warmWhite.opacity(0.45))
                    Text(verbatim: "5:50")
                        .font(.system(size: 96, weight: .ultraLight))
                        .foregroundStyle(Color.warmWhite)
                    // ja: あと 7 時間 20 分 · 時刻をタップして変更
                    Text("In 7 hr 20 min · Tap the time to change")
                        .font(.system(size: 12))
                        .tracking(0.96)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                    mockAlarmToggle
                        .padding(.top, 26)
                }
                .padding(.top, 90)

                VStack(spacing: 7) {
                    // ja: 今朝のことば
                    Text("This morning's words")
                        .font(.system(size: 10))
                        .tracking(2.2)
                        .foregroundStyle(Color.dawn)
                    // ja: 家族と海を見に行く
                    Text("Go see the ocean with my family")
                        .font(.system(size: 17, weight: .light))
                        .tracking(0.68)
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .padding(.top, 56)

                Spacer()

                footer
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// アラーム ON のトグル (56×34 pill、ON 背景は夜明け色 45%)
    private var mockAlarmToggle: some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(Color.dawn.opacity(0.45))
            Circle()
                .fill(Color.warmWhite)
                .frame(width: 28, height: 28)
                .padding(3)
        }
        .frame(width: 56, height: 34)
    }

    /// 画面下部に積もった粒の山 (本番ホームの背景表現)。
    /// 本番は物理で積もるが、スクリーンショットは毎回同じ絵にするため物理・乱数を使わず静止した俵積みを描く
    private var dotPile: some View {
        // 行間は直径 (12) の 0.88 倍 (俵積みで自然に噛み合う高さ) になるよう負の spacing を入れる
        VStack(spacing: -12 * 0.12) {
            // 上から 8, 11, 13 粒の計 32 粒。「答えた朝 32」の表示と数を一致させる
            ForEach([8, 11, 13], id: \.self) { count in
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            // 粒は温白 9% (未回答の粒と同じ弱さ)。大時刻や文字の可読性を保つ
                            .fill(Color.warmWhite.opacity(0.09))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }

    /// 答えた朝 N + テキストリンク行。
    /// 直近 14 日の粒ストリップは、背景に積もる粒に役割を置き換えて廃止した
    private var footer: some View {
        VStack(spacing: 16) {
            // ja: 答えた朝 32
            Text("32 mornings answered")
                .font(.system(size: 11))
                .tracking(1.1)
                .foregroundStyle(Color.warmWhite.opacity(0.55))
            HStack(spacing: 24) {
                // ja: ジャーナル
                Text("Journal")
                // ja: 点
                Text("Dots")
                // ja: カレンダー
                Text("Calendar")
                // ja: 設定
                Text("Settings")
            }
            .font(.system(size: 13))
            .tracking(1.3)
            .foregroundStyle(Color.warmWhite.opacity(0.75))
            .padding(.top, 12)
        }
    }
}
