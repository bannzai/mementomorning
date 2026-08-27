import SwiftUI

#if DEBUG
// NOTE: SnapshotUITestPage は Preview を使用するので DEBUG で囲む。
// Preview はリリースビルドでは参照される場所がなくなるので最適化の過程で自然と消える (取り込み元: bannzai/Focus の同名ファイル)

/// 多言語スクリーンショット撮影 (MementoMorningSnapshotUITests) の起動画面。
/// 起動引数 isSnapshotUITest で MementoMorningApp がこの画面に分岐し、
/// UITest がボタン `{PreviewType}_{index}` をタップして本番画面の Preview を表示・撮影する
struct SnapshotUITestPage: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    SnapshotUITest<ContentView_Previews>()
                    SnapshotUITest<MorningQuestionPage_Previews>()
                    SnapshotUITest<QuestionPage_Previews>()
                    SnapshotUITest<AnswerLogPage_Previews>()
                    SnapshotUITest<MonthCalendarPage_Previews>()
                    SnapshotUITest<NightReflectionPage_Previews>()
                    SnapshotUITest<SevenMorningsPage_Previews>()
                    SnapshotUITest<AlarmSettingPage_Previews>()
                    SnapshotUITest<OnboardingPage_Previews>(previewCount: 10)
                    SnapshotUITest<PaywallPage_Previews>()
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
#endif
