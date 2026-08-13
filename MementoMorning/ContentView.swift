import SwiftUI

/// 起動直後に表示するルート画面。今日の問いを表示する
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // ja: 今日死ぬとしたら、何をやりたいか
                Text(String(localized: "If today were your last day, what would you want to do?"))
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .toolbar {
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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
