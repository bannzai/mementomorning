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
                    SnapshotUITest<AppStoreScreenshot7Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot8Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot9Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot10Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot11Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot12Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot13Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot14Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot15Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot16Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot17Page_Previews>()
                    SnapshotUITest<AppStoreScreenshot18Page_Previews>()
                }
            }
        }
    }
}

/// PreviewProvider のすべての Preview をボタン化する Wrapper。
/// UITest がボタン `{PreviewType}_{index}` をタップすることで NavigationLink 遷移し、Preview が表示される。
/// 一覧描画の時点で `_allPreviews` に触れると全 Preview の body (サンプルデータ挿入を含む) が評価され、
/// 共有 in-memory コンテナ上で互いのサンプルデータが競合するため、Preview の個数は引数で受け取り、
/// Preview 本体の評価は表示される時 (SnapshotUITestLazyPreview) まで遅延させる
struct SnapshotUITest<T: PreviewProvider>: View {
    /// T が持つ Preview の個数。テスト側の previewCount と同じ制約 (_allPreviews を型から辿れない) でハードコードする
    var previewCount = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: "\(T.self)")
                .font(.title3)

            VStack(alignment: .leading) {
                ForEach(0..<previewCount, id: \.self) { index in
                    NavigationLink {
                        SnapshotUITestLazyPreview<T>(index: index)
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

/// NavigationLink の destination は遷移前に View の値として構築されるため、
/// body が呼ばれる (実際に表示される) まで Preview の評価を遅延させるラッパー
struct SnapshotUITestLazyPreview<T: PreviewProvider>: View {
    /// 表示する Preview のインデックス
    let index: Int

    var body: some View {
        T._allPreviews[index].content
            .navigationBarBackButtonHidden()
            .statusBarHidden()
            // UITest が「遷移先の Preview が表示されてから撮影する」ための目印
            .accessibilityIdentifier("SnapshotPreview_\(T.self)_\(index)")
    }
}
