import SwiftUI

/// ペイウォール画面 (デザイン handoff 1l / プロトタイプ paywall)。静かな課金訴求。
/// バッジ・カウントダウン等の圧は一切使わない。
///
/// この画面はデザイン反映 (issue #12) の範囲ではビジュアルシェルとして実装する。
/// 価格の取得と購入処理は RevenueCat 連携 (issue #9) で配線し、それまで購入ボタンは何もしない
struct PaywallPage: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            titleSection
            featureListSection
                .padding(.top, 32)
            Spacer()
            purchaseSection
        }
        .background(Color.ink.ignoresSafeArea())
    }

    /// 見出しと英語サブラベル
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ja: すべての朝を、残すために。
            Text("To keep every morning.")
                .font(.system(size: 27, weight: .light))
                .tracking(1.08)
                .lineSpacing(27 * 0.7)
                .foregroundStyle(Color.warmWhite)
            Text(verbatim: "KEEP EVERY MORNING")
                .font(.system(size: 10))
                .tracking(2.0)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 56)
        .padding(.horizontal, 36)
    }

    /// プレミアムの機能 4 行 (ヘアライン区切り)
    private var featureListSection: some View {
        VStack(spacing: 0) {
            featureRow(
                // ja: 無限追撃アラーム
                title: Text("Endless follow-up alarms"),
                // ja: 答えるまで、鳴りやまない
                detail: Text("It keeps ringing until you answer.")
            )
            featureRow(
                // ja: すべての履歴
                title: Text("All your mornings"),
                // ja: 7日を越えて、すべての朝を
                detail: Text("Every morning, beyond the last 7 days.")
            )
            featureRow(
                // ja: 30・90・180日の節目
                title: Text("Milestones at 30, 90, and 180 days"),
                // ja: 過去の自分と再会する日
                detail: Text("Days you meet your past self again.")
            )
            featureRow(
                // ja: 問いのデッキ
                title: Text("Question decks"),
                // ja: 「今日死ぬとしたら」の先へ
                detail: Text("Beyond the one question you know.")
            )
        }
        .padding(.horizontal, 36)
    }

    /// 機能 1 行 (タイトル 14pt + 説明 11pt/40%)
    private func featureRow(title: Text, detail: Text) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            title
                .font(.system(size: 14, weight: .light))
                .tracking(0.7)
                .foregroundStyle(Color.warmWhite)
            detail
                .font(.system(size: 11))
                .tracking(0.33)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            HairlineDivider()
        }
    }

    /// 購入ボタンと注釈。購入処理は issue #9 (RevenueCat 連携) で配線する
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                // RevenueCat 連携 (issue #9) までは何もしない
            } label: {
                VStack(spacing: 2) {
                    // ja: 年 ¥3,600
                    Text("¥3,600 / year")
                        .font(.system(size: 15))
                        .tracking(1.2)
                    // ja: ひと月 ¥300
                    Text("¥300 a month")
                        .font(.system(size: 10))
                        .tracking(0.5)
                        .opacity(0.6)
                }
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("paywall_yearly_button")

            Button {
                // RevenueCat 連携 (issue #9) までは何もしない
            } label: {
                // ja: 月 ¥480
                Text("¥480 / month")
                    .font(.system(size: 14))
            }
            .buttonStyle(SecondaryPillButtonStyle())
            .accessibilityIdentifier("paywall_monthly_button")

            Button {
                dismiss()
            } label: {
                // ja: 今はしない
                Text("Not now")
                    .font(.system(size: 12))
                    .tracking(1.2)
                    .foregroundStyle(Color.warmWhite.opacity(0.4))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall_not_now_button")

            // ja: いつでも解約できます。回答はこの端末に残ります。
            Text("Cancel anytime. Your answers stay on this device.")
                .font(.system(size: 10))
                .tracking(0.5)
                .foregroundStyle(Color.warmWhite.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}

struct PaywallPage_Previews: PreviewProvider {
    static var previews: some View {
        PaywallPage()
    }
}
