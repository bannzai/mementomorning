import SwiftUI

/// アラームが鳴っている朝の瞬間のモック。
/// ホームの大時刻の骨格 (96pt ultraLight) を流用し、「時刻 + 鳴動中 + 問い + 答えて止める」で
/// 「朝、起きる時に使うアプリ」であることをスクリーンショット 1 枚目で伝えるための画面
struct MockAlarmRingingScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(verbatim: "MORNING ALARM")
                    .font(.system(size: 10))
                    .tracking(2.6)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                Text(verbatim: "5:50")
                    .font(.system(size: 96, weight: .ultraLight))
                    .foregroundStyle(Color.warmWhite)
                HStack(spacing: 8) {
                    // 鳴動中の点。アクセントは夜明け色 1 箇所のみ
                    Circle()
                        .fill(Color.dawn)
                        .frame(width: 6, height: 6)
                    // ja: アラームが鳴っています
                    Text("The alarm is ringing")
                        .font(.system(size: 12))
                        .tracking(0.96)
                        .foregroundStyle(Color.warmWhite.opacity(0.55))
                }
            }
            .padding(.top, 96)

            Spacer()

            // ja: 今日死ぬとしたら、何をやりたいか
            Text("If today were your last day, what would you want to do?")
                .font(.system(size: 26, weight: .light))
                .lineSpacing(10)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.warmWhite)
                .padding(.horizontal, 32)

            Spacer()

            // ja: 答えて、止める
            MockPillLabel(label: Text("Answer to stop"))
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }
}
