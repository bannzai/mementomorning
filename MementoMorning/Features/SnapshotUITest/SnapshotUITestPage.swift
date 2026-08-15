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
                    SnapshotUITest<LifeCalendarPage_Previews>()
                    SnapshotUITest<NightReflectionPage_Previews>()
                    SnapshotUITest<SevenMorningsPage_Previews>()
                    SnapshotUITest<AlarmSettingPage_Previews>()
                    SnapshotUITest<OnboardingPage_Previews>()
                    SnapshotUITest<PaywallPage_Previews>()
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
#endif
