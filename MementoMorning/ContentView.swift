import SwiftUI
import SwiftData

/// 起動直後に表示するルート画面。今日の問いを表示する。
/// 回答が 7 件に達したら、7 日の節目「七つの朝」(SevenMorningsPage) を一度だけ表示する
struct ContentView: View {
    /// 7 日の節目の表示判定用。判定は件数 (7 件に達したか) だけを見るため、取得条件は SevenMorningsPage と共有する
    @Query(sevenMorningsAnswersDescriptor) private var sevenMorningsAnswers: [MorningAnswer]

    /// 7 日の節目を表示済みかどうか。初回インストール時は未表示のため false から始める
    @AppStorage(.isSevenMorningsMilestonePresented) private var isSevenMorningsMilestonePresented = false

    /// 7 日の節目画面を表示中かどうか
    @State private var isSevenMorningsPagePresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // ja: 今日死ぬとしたら、何をやりたいか
                Text(String(localized: "If today were your last day, what would you want to do?"))
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                LifeCalendarPage()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AlarmSettingPage()
                    } label: {
                        Image(systemName: "alarm")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AnswerLogPage()
                    } label: {
                        // ja: ジャーナル
                        Label("Journal", systemImage: "book.closed")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        DebugMenuPage()
                    } label: {
                        Label {
                            Text(verbatim: "Developer Menu")
                        } icon: {
                            Image(systemName: "hammer")
                        }
                    }
                    .accessibilityIdentifier("debug_menu_link")
                }
                #endif
            }
            .sheet(isPresented: $isSevenMorningsPagePresented) {
                SevenMorningsPage()
            }
            .onChange(of: sevenMorningsAnswers.count, initial: true) { _, _ in
                presentSevenMorningsIfNeeded()
            }
            // 表示済みフラグのリセット (DEBUG の開発者メニュー) 後に、再起動なしで再表示を確認できるようにする
            .onChange(of: isSevenMorningsMilestonePresented) { _, _ in
                presentSevenMorningsIfNeeded()
            }
        }
    }

    /// 回答が 7 件に達していて未表示なら、7 日の節目画面を表示する
    private func presentSevenMorningsIfNeeded() {
        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に節目画面の表示とフラグの書き込みが走らないようここで打ち切る
        if isUnitTest { return }
        if shouldPresentSevenMorningsMilestone(
            answerCount: sevenMorningsAnswers.count,
            isPresented: isSevenMorningsMilestonePresented
        ) {
            isSevenMorningsPagePresented = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(PersistenceController.shared.container)
    }
}
