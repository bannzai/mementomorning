import SwiftUI

/// 人生カレンダー画面 (LifeCalendarPage) のモック。
/// 1 行 = 1 週間の粒グリッドに答えた朝が墨として埋まっていく様子を再現する
struct MockLifeCalendarScreen: View {
    /// グリッドの週数。本番の最低表示 (13 週) を超える蓄積が進んだ状態を見せる
    private let weekCount = 16
    /// 今日のセル位置 (最終週の 4 列目)。以降のセルは未来日のため描画しない
    private let todayIndex = 15 * 7 + 3

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                // ja: 人生カレンダー
                Text("Life Calendar")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2.1)
                    .foregroundStyle(Color.warmWhite)
                Text(verbatim: "LIFE IN WEEKS")
                    .font(.system(size: 9))
                    .tracking(2.34)
                    .foregroundStyle(Color.warmWhite.opacity(0.4))
            }
            .padding(.top, 70)
            .padding(.bottom, 14)

            // ja: 1行が一週間。答えた朝が、一粒ずつ残る。
            Text("Each row is a week. One dot for each answered morning.")
                .font(.system(size: 11))
                .tracking(0.66)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 40)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(13), spacing: 11), count: 7), spacing: 11) {
                ForEach(0..<(weekCount * 7), id: \.self) { index in
                    if index <= todayIndex {
                        Circle()
                            .fill(isAnswered(index: index) ? Color.warmWhite : Color.warmWhite.opacity(0.09))
                            .frame(width: 13, height: 13)
                            .overlay {
                                if index == todayIndex {
                                    Circle()
                                        .stroke(Color.dawn.opacity(0.35), lineWidth: 3)
                                        .frame(width: 20, height: 20)
                                }
                            }
                    } else {
                        // 未来日はまだ粒を置かない (本番グリッドは今日で終わる)
                        Color.clear.frame(width: 13, height: 13)
                    }
                }
            }
            .padding(.vertical, 28)

            Spacer()

            VStack(spacing: 6) {
                // ja: 答えた朝 %lld
                Text("\((0...todayIndex).filter { isAnswered(index: $0) }.count) mornings answered")
                    .font(.system(size: 12))
                    .tracking(1.2)
                    .foregroundStyle(Color.warmWhite.opacity(0.55))
                // ja: 空白は、空白のまま。
                Text("Blank stays blank.")
                    .font(.system(size: 11))
                    .tracking(0.88)
                    .foregroundStyle(Color.warmWhite.opacity(0.32))
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }

    /// index のセルを回答済みにするかどうか。
    /// 序盤は歯抜け・後半ほど埋まる分布を固定パターンで作り、「続くほど墨が濃くなる」蓄積を表現する
    private func isAnswered(index: Int) -> Bool {
        // 初週より前は空白から始める
        if index < 2 { return false }
        // 序盤 (〜5週) は 3 日に 1 日ほど空白を入れる
        if index < 35 { return index % 3 != 1 }
        // 中盤以降はほぼ毎日。7 の倍数近辺にだけ空白を残す
        return index % 11 != 4
    }
}
