import SwiftUI

/// 朝の問い画面 (MorningQuestionPage) のモック。
/// 問いに答えて確定する直前の状態を、本番の骨格 (問い 27pt/light + 回答 25pt/light + primary pill) に忠実に再現する
struct MockMorningQuestionScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 40) {
                // ja: 今日死ぬとしたら、何をやりたいか
                Text("If today were your last day, what would you want to do?")
                    .font(.system(size: 27, weight: .light))
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)

                // ja: 家族と海を見に行く
                Text("Go see the ocean with my family")
                    .font(.system(size: 25, weight: .light))
                    .lineSpacing(12)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 110)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)

            Spacer()

            // ja: これで確定する
            MockPillLabel(label: Text("Make it today's answer"))
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
        .foregroundStyle(Color.warmWhite)
    }
}
