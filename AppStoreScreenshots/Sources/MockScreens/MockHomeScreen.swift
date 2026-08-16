import SwiftUI

/// ホーム画面 (ContentView の HomeContent) のモック。
/// 次の朝の大時刻・トグル・今朝のことば・直近 14 日の粒ストリップを本番のトークンどおりに再現する
struct MockHomeScreen: View {
    var body: some View {
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
        .background(Color.ink)
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

    /// 直近 14 日の粒ストリップ + 答えた朝 N + テキストリンク行。
    /// 粒の 12 日分を回答済み (温白) にし、蓄積が進んだ状態を見せる
    private var footer: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<14, id: \.self) { index in
                    Circle()
                        // 5 番目と 9 番目だけ未回答にして、未回答の点が混ざる実際の見え方を再現する
                        .fill([5, 9].contains(index) ? Color.warmWhite.opacity(0.09) : Color.warmWhite)
                        .frame(width: 10, height: 10)
                        .overlay {
                            if index == 13 {
                                Circle()
                                    .stroke(Color.dawn.opacity(0.35), lineWidth: 3)
                                    .frame(width: 16, height: 16)
                            }
                        }
                }
            }
            // ja: 答えた朝 32
            Text("32 mornings answered")
                .font(.system(size: 11))
                .tracking(1.1)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
            HStack(spacing: 36) {
                // ja: ジャーナル
                Text("Journal")
                // ja: 人生カレンダー
                Text("Life Calendar")
                // ja: 設定
                Text("Settings")
            }
            .font(.system(size: 13))
            .tracking(1.3)
            .foregroundStyle(Color.warmWhite.opacity(0.65))
            .padding(.top, 12)
        }
    }
}
