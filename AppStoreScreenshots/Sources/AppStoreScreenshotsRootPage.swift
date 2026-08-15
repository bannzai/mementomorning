import SwiftUI

/// AppStoreScreenshots ターゲットの起動画面。
/// 各 NavigationLink のラベル `{PreviewType}_{index}` を UITest がボタンとしてタップし、スクショページへ遷移する
/// (取り込み元: bannzai/Focus の同名ファイル)
struct AppStoreScreenshotsRootPage: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    SnapshotUITest<AppStoreScreenshot1Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot2Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot3Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot4Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot5Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot6Page_Previews>()
                }
            }
        }
    }
}

/// PreviewProvider のすべての Preview をボタン化する Wrapper。
/// UITest がボタン `{PreviewType}_{index}` をタップすることで NavigationLink 遷移し、Preview が表示される
struct SnapshotUITest<T: PreviewProvider>: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: "\(T.self)")
                .font(.title3)

            VStack(alignment: .leading) {
                ForEach(T._allPreviews.indices, id: \.self) { index in
                    let preview = T._allPreviews[index]
                    NavigationLink {
                        preview.content
                            .navigationBarBackButtonHidden()
                            .statusBarHidden()
                    } label: {
                        Text(verbatim: "\(T.self)_\(index)")
                            .accessibilityLabel(Text(verbatim: "\(T.self)_\(index)"))
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
