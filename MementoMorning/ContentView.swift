import SwiftUI

/// 起動直後に表示するルート画面。今日の問いを表示する
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            // ja: 今日死ぬとしたら、何をやりたいか
            Text(String(localized: "If today were your last day, what would you want to do?"))
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
