import SwiftUI
import RevenueCat

/// 利用規約ページの URL (docs/ を GitHub Pages で配信している)
private let termsURL = URL(string: "https://bannzai.github.io/mementomorning/Terms-ja")!
/// プライバシーポリシーページの URL (docs/ を GitHub Pages で配信している)
private let privacyPolicyURL = URL(string: "https://bannzai.github.io/mementomorning/PrivacyPolicy-ja")!

/// ペイウォール画面 (design handoff §9)。
/// 世界観を壊さない静かな課金訴求: 機能 4 行 + 年額/月額ボタン + 「今はしない」だけで、バッジ・カウントダウン等の圧は置かない。
/// 料金は RevenueCat の offering `default` の packages ($rc_annual / $rc_monthly) から表示し、購入・復元も RevenueCat 経由で行う (商品登録は #15)
struct PaywallPage: View {
    /// RevenueCat の current offering。読み込み中・取得失敗・未 configure (#15 前) の間は nil で、料金は目安価格を見本表示する
    @State private var offering: Offering?
    /// 購入・復元の処理中かどうか。二重実行を防ぎ、ボタンを無効化する
    @State private var isPurchasing = false
    /// 購入・復元の失敗をユーザーへ伝えるメッセージ。nil 以外でアラート表示する
    @State private var purchaseError: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ja: すべての朝を、残すために。
                    Text("Keep every morning.")
                        .font(.title.weight(.light))
                        .padding(.top, 48)
                        .padding(.bottom, 40)

                    featureRow(
                        // ja: 無限追撃アラーム
                        title: Text("Endless follow-up alarm"),
                        // ja: 答えるまで、鳴りやまない
                        description: Text("It won't stop ringing until you answer.")
                    )
                    Divider()
                    featureRow(
                        // ja: すべての履歴
                        title: Text("All your history"),
                        // ja: 直近 7 日を超えた、すべての回答
                        description: Text("Every answer, beyond the last 7 days.")
                    )
                    Divider()
                    featureRow(
                        // ja: 30・90・180 日の節目
                        title: Text("Milestones at 30, 90, and 180 days"),
                        // ja: 過去の自分と、再会する
                        description: Text("Meet your past self again.")
                    )
                    Divider()
                    featureRow(
                        // ja: 問いのデッキ
                        title: Text("Question decks"),
                        // ja: 朝の問いに、別の切り口を
                        description: Text("More ways to ask the morning question.")
                    )
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    Task { await purchase(package: offering?.annual) }
                } label: {
                    // ja: 年 %@(ひと月 %@)
                    Text("Yearly \(annualPriceText) (\(annualPerMonthPriceText) a month)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isPurchasing)
                .accessibilityIdentifier("paywall_purchase_yearly")

                Button {
                    Task { await purchase(package: offering?.monthly) }
                } label: {
                    // ja: 月 %@
                    Text("Monthly \(monthlyPriceText)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isPurchasing)
                .accessibilityIdentifier("paywall_purchase_monthly")

                Button {
                    dismiss()
                } label: {
                    // ja: 今はしない
                    Text("Not now")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("paywall_not_now")
                .padding(.top, 4)

                // ja: いつでも解約できます。回答はこの端末に残ります。
                Text("Cancel anytime. Your answers stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button {
                        Task { await restore() }
                    } label: {
                        // ja: 購入を復元
                        Text("Restore Purchases")
                    }
                    .disabled(isPurchasing)
                    .accessibilityIdentifier("paywall_restore")
                    // ja: 利用規約
                    Link(destination: termsURL) { Text("Terms of Use") }
                    // ja: プライバシーポリシー
                    Link(destination: privacyPolicyURL) { Text("Privacy Policy") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .task {
            await loadOffering()
        }
        .alert(purchaseError ?? "", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            // ja: OK
            Button(String(localized: "OK")) { purchaseError = nil }
        }
    }

    /// 年額の表示価格。offering 未取得の間は PROJECT.md の目安価格を見本表示する
    private var annualPriceText: String {
        offering?.annual?.storeProduct.localizedPriceString ?? "¥3,600"
    }

    /// 年額プランのひと月あたり換算の表示価格。ストア価格を 12 (ヶ月) で割り、商品の通貨フォーマッタで整形する。
    /// offering 未取得の間は PROJECT.md の目安価格 (¥3,600 / 12ヶ月 = ¥300) を見本表示する
    private var annualPerMonthPriceText: String {
        guard let storeProduct = offering?.annual?.storeProduct else { return "¥300" }
        return storeProduct.priceFormatter?.string(from: storeProduct.price / 12 as NSDecimalNumber)
            ?? storeProduct.localizedPriceString
    }

    /// 月額の表示価格。offering 未取得の間は PROJECT.md の目安価格を見本表示する
    private var monthlyPriceText: String {
        offering?.monthly?.storeProduct.localizedPriceString ?? "¥480"
    }

    /// 機能訴求の 1 行 (タイトル + 説明)
    private func featureRow(title: Text, description: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.subheadline)
            description
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// offering `default` を読み込む。未 configure (#15 前)・取得失敗時は nil のままにし、見本価格の表示に倒す
    private func loadOffering() async {
        guard Purchases.isConfigured else { return }
        offering = try? await Purchases.shared.offerings().current
    }

    /// package を購入し、entitlement premium が有効になったら閉じる
    private func purchase(package: Package?) async {
        guard !isPurchasing else { return }
        // 未 configure (#15 前)・offering 未取得の間は購入できないことを黙殺せず伝える
        guard Purchases.isConfigured, let package else {
            // ja: 購入はまだ準備できていません。しばらくしてからお試しください。
            purchaseError = String(localized: "Purchases aren't ready yet. Please try again later.")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            // キャンセルはユーザー操作の範囲なので何もしない
            if result.userCancelled {
                return
            }
            if result.customerInfo.entitlements[PremiumEntitlement.entitlementIdentifier]?.isActive == true {
                dismiss()
            } else {
                // 商品と entitlement の紐付け不備・反映遅延で、購入が成功しても premium が有効にならないケースを黙殺しない
                // ja: 購入は完了しましたが、プレミアムの反映を確認できませんでした。時間をおいて購入の復元をお試しください。
                purchaseError = String(localized: "The purchase finished, but Premium couldn't be confirmed. Please try restoring purchases later.")
            }
        } catch {
            // ja: 購入を完了できませんでした。
            purchaseError = String(localized: "The purchase couldn't be completed.") + "\n\(error.localizedDescription)"
        }
    }

    /// 過去の購入を復元し、entitlement premium が有効になったら閉じる
    private func restore() async {
        guard !isPurchasing else { return }
        guard Purchases.isConfigured else {
            // ja: 購入はまだ準備できていません。しばらくしてからお試しください。
            purchaseError = String(localized: "Purchases aren't ready yet. Please try again later.")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await Purchases.shared.restorePurchases().entitlements[PremiumEntitlement.entitlementIdentifier]?.isActive == true {
                dismiss()
            } else {
                // ja: 復元できる購入が見つかりませんでした。
                purchaseError = String(localized: "No purchases to restore were found.")
            }
        } catch {
            // ja: 購入を復元できませんでした。
            purchaseError = String(localized: "Purchases couldn't be restored.") + "\n\(error.localizedDescription)"
        }
    }
}

struct PaywallPage_Previews: PreviewProvider {
    static var previews: some View {
        PaywallPage()
    }
}
