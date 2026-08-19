import SwiftUI

/// 共有カード画面。カードのプレビューを表示し、1 枚画像として share sheet で共有する
struct AnswerShareCardPage: View {
    let answer: MorningAnswer

    /// 書き出し済みのカード画像。表示時にレンダリングし、本文が変わったら作り直す
    @State private var cardImage: UIImage?

    var body: some View {
        VStack(spacing: 32) {
            AnswerShareCardView(answeredDate: answer.answeredDate, text: answer.text)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let cardImage {
                ShareLink(
                    item: Image(uiImage: cardImage),
                    preview: SharePreview(Text(verbatim: "Memento Morning"), image: Image(uiImage: cardImage))
                ) {
                    // ja: 共有
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            cardImage = renderAnswerShareCardImage(answeredDate: answer.answeredDate, text: answer.text)
        }
        // 動画回答の文字起こしは画面を開いた後にも完了し得るため、本文が置き換わったら共有画像も作り直す
        // (開いた時点の本文で書き出した画像を共有し続けない)
        .onChange(of: answer.text) { _, _ in
            cardImage = renderAnswerShareCardImage(answeredDate: answer.answeredDate, text: answer.text)
        }
    }
}

/// 共有カードを 1 枚画像に書き出す。locale はテストで日英両方のレイアウトを検証するために注入できるようにしている
@MainActor
func renderAnswerShareCardImage(answeredDate: Date, text: String, locale: Locale = .current) -> UIImage? {
    let renderer = ImageRenderer(
        content: AnswerShareCardView(answeredDate: answeredDate, text: text)
            .environment(\.locale, locale)
    )
    // カード 360pt 四方を 1080px 四方で書き出すため (AnswerShareCardView.sideLength のコメント参照)
    renderer.scale = 3
    return renderer.uiImage
}
