import SwiftUI

/// 夜の振り返り画面 (NightReflectionPage) のモック。
/// 「守れてますか?」の問いと今朝の回答、やれた / やれていないの二択を本番のトークンどおりに再現する
struct MockNightReflectionScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 30) {
                VStack(spacing: 6) {
                    // ja: 守れてますか?
                    Text("Are you keeping it?")
                        .font(.system(size: 21, weight: .light))
                        .tracking(1.68)
                        .foregroundStyle(Color.warmWhite)
                    Text(verbatim: "ARE YOU KEEPING IT?")
                        .font(.system(size: 10))
                        .tracking(2.0)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                }

                // ja: 家族と海を見に行く
                Text("Go see the ocean with my family")
                    .font(.system(size: 25, weight: .light))
                    .tracking(0.75)
                    .lineSpacing(25 * 0.8)
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 110)
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity)

            Spacer()

            VStack(spacing: 14) {
                // ja: やれた
                MockPillLabel(label: Text("I did"))
                // ja: やれていない
                MockPillLabel(label: Text("Not yet"), isPrimary: false)
                // ja: 空白は空白のまま残ります
                Text("Blank days remain blank.")
                    .font(.system(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Color.warmWhite.opacity(0.3))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }
}
