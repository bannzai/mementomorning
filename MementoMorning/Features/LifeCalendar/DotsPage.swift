import Combine
import SwiftUI
import SwiftData

/// 答えた朝がひと粒ずつ積もっていく「点」画面 (issue #118)。
/// 週・日付・未回答という概念は持たず、答えた朝の数だけ粒が物理で積もり、端末の傾きで転がる。
/// streak 修復は作らない (documents/PROJECT.md の課金設計参照)
struct DotsPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// 全期間の回答数 (= 積もる粒の数)。件数だけ必要なため fetchCount で取得する
    @State private var answeredCount = 0
    /// 今日の回答があるかどうか。いちばん新しい粒に夜明けのリングを付ける判定に使う
    @State private var hasTodayAnswer = false
    /// 7 日の節目「七つの朝」を見返すシートを表示中かどうか (issue #109。リンクの存廃は issue #116 で判断する)
    @State private var isSevenMorningsPagePresented = false

    var body: some View {
        VStack(spacing: 0) {
            // ja: ひと粒が、答えたひとつの朝
            Text("One dot, one answered morning.")
                .font(.system(size: 11))
                .tracking(0.66)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 40)
            MorningDotsPhysicsView(
                dotCount: answeredCount,
                dotDiameter: 13,
                dotColor: UIColor(Color.warmWhite),
                newestDotRingColor: hasTodayAnswer ? UIColor(Color.dawn.opacity(0.35)) : nil
            )
            // 粒は装飾表現のため、読み上げは件数の要約に集約する
            // ja: 答えた日数 %lld日
            .accessibilityLabel(Text("\(answeredCount) mornings answered"))
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    // ja: 答えた朝
                    Text("Mornings answered")
                        .font(.system(size: 11))
                        .tracking(2.2)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                    Text(verbatim: "\(answeredCount)")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(Color.warmWhite)
                }
                // ja: 点はいつかつながる
                Text("The dots will connect.")
                    .font(.system(size: 11))
                    .tracking(0.88)
                    .foregroundStyle(Color.warmWhite.opacity(0.32))
                // 節目に達した後はいつでもこの画面から振り返りカードを見返せるようにする (issue #109)。
                // 30 日の節目「一ヶ月の手紙」の導線は実装後 (issue #96) にここへ追加する
                if canRevisitSevenMorningsMilestone(answerCount: answeredCount) {
                    Button {
                        isSevenMorningsPagePresented = true
                    } label: {
                        // ja: 七つの朝
                        Text("Seven Mornings")
                            .underline()
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                    }
                    .font(.system(size: 13))
                    .tracking(1.3)
                    .foregroundStyle(Color.warmWhite.opacity(0.65))
                    .accessibilityIdentifier("life_calendar_seven_mornings_link")
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $isSevenMorningsPagePresented) {
            SevenMorningsPage()
        }
        .background(Color.ink.ignoresSafeArea())
        .onAppear {
            recalculate()
        }
        // この画面を開いたまま朝の問い (fullScreenCover) で回答が保存されても onAppear は再発火しないため、
        // 保存通知で粒の数と七つの朝リンクの表示条件を再計算する (HomeContent と同じパターン)
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            recalculate()
        }
        // バックグラウンドで日付が変わった後の復帰では onAppear が発火しないため、
        // アクティブに戻った時に今日の回答の有無 (= いちばん新しい粒のリング) を判定し直す
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                recalculate()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                // ja: 点
                Text("Dots")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2.1)
                    .foregroundStyle(Color.warmWhite)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 粒の数 (全期間の回答数) と、今日の回答の有無を取得し直す
    private func recalculate() {
        answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        let today = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == today })
        // 1 日 1 件のため 1 件だけ数えれば有無がわかる
        descriptor.fetchLimit = 1
        hasTodayAnswer = ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }
}

struct DotsPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 今日・3 日前・10 日前に回答した状態のサンプルデータ (回答本文はユーザーの自由入力値のためハードコード)
        let _ = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            let calendar = Calendar.current
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: .now), text: "家族と過ごす"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: .now)!), text: "海を見に行く"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -10, to: .now)!), text: "手紙を書く"))
            try! modelContext.save()
        }()
        NavigationStack {
            DotsPage()
        }
        .modelContainer(container)
    }
}
