import SwiftUI
import RevenueCat

/// 利用規約ページの URL (docs/ を GitHub Pages で配信している)
private let termsURL = URL(string: "https://bannzai.github.io/mementomorning/Terms-ja")!
/// プライバシーポリシーページの URL (docs/ を GitHub Pages で配信している)
private let privacyPolicyURL = URL(string: "https://bannzai.github.io/mementomorning/PrivacyPolicy-ja")!

/// ペイウォール画面 (デザイン handoff 1l / プロトタイプ paywall)。静かな課金訴求。
/// バッジ・カウントダウン等の圧は一切使わない。
/// 料金は RevenueCat の offering (lookup_key: PremiumEntitlement.offeringIdentifier) の packages から表示し、
/// 購入・復元も RevenueCat 経由で行う (商品登録は #15)
struct PaywallPage: View {
    /// RevenueCat の offering。読み込み中・取得失敗・未 configure (#15 前) の間は nil
    @State private var offering: Offering?
    /// 購入・復元の処理中かどうか。二重実行を防ぎ、ボタンを無効化する
    @State private var isPurchasing = false
    /// offering の取得に失敗したかどうか。再読み込みの導線を出す
    @State private var offeringLoadFailed = false
    /// 購入・復元の失敗をユーザーへ伝えるメッセージ。nil 以外でアラート表示する
    @State private var purchaseError: String?

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

    /// プレミアムの機能一覧 (ヘアライン区切り)。
    /// 特典の記載は現時点で実際に解放される機能 (無限追撃・全履歴) だけに絞る。
    /// 30/90/180 日の節目・問いのデッキはデザイン handoff 1l の掲載項目だが未実装のため、各機能の実装時に行を追加する (PR #30 レビュー指摘)
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

    /// 購入ボタンと注釈・復元・法務リンク
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // Storefront と異なる固定の円価格を見せないため、offering 取得までは購入ボタンを出さない (PR #30 レビュー指摘)。
            // 未 configure (#15 前の開発ビルド・Preview) だけは目安価格の見本表示に倒す
            if Purchases.isConfigured && offering == nil {
                if offeringLoadFailed {
                    Button {
                        Task { await loadOffering() }
                    } label: {
                        // ja: 料金を再読み込み
                        Text("Reload prices")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier("paywall_reload_offering")
                } else {
                    ProgressView()
                        .tint(Color.warmWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            } else {
                if shouldShowPlan(package: offering?.annual) {
                    Button {
                        Task { await purchase(package: offering?.annual) }
                    } label: {
                        VStack(spacing: 2) {
                            if let annualFreeTrialPeriodText {
                                // ja: %@無料
                                Text("\(annualFreeTrialPeriodText) free")
                                    .font(.system(size: 11))
                                    .tracking(0.5)
                                    .accessibilityIdentifier("paywall_yearly_free_trial")
                            }
                            // ja: 年 %@
                            Text("\(annualPriceText) / year")
                                .font(.system(size: 15))
                                .tracking(1.2)
                            // ja: ひと月 %@
                            Text("\(annualPerMonthPriceText) a month")
                                .font(.system(size: 10))
                                .tracking(0.5)
                                .opacity(0.6)
                        }
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .disabled(isPurchasing)
                    .accessibilityIdentifier("paywall_yearly_button")
                }

                if shouldShowPlan(package: offering?.monthly) {
                    Button {
                        Task { await purchase(package: offering?.monthly) }
                    } label: {
                        // ja: 月 %@
                        Text("\(monthlyPriceText) / month")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .disabled(isPurchasing)
                    .accessibilityIdentifier("paywall_monthly_button")
                }

                if shouldShowPlan(package: offering?.lifetime) {
                    Button {
                        Task { await purchase(package: offering?.lifetime) }
                    } label: {
                        // ja: 一生 %@ (一度だけ)
                        Text("\(lifetimePriceText) for life (one-time)")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .disabled(isPurchasing)
                    .accessibilityIdentifier("paywall_lifetime_button")
                }
            }

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
            .font(.system(size: 10))
            .tracking(0.5)
            .foregroundStyle(Color.warmWhite.opacity(0.4))
            .tint(Color.warmWhite.opacity(0.4))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    /// そのプランのボタンを描画してよいか。
    /// configure 済みなら package が実在する時だけ描画する。offering は取得できても個別の package が
    /// StoreKit から解決できないこと (商品の反映待ち等) があり、その時に見本価格を代わりに出すと
    /// Storefront によっては実際と異なる価格を見せてしまうため (実測: US storefront のシミュレータで
    /// 年額・月額が未解決のまま円の見本価格が表示された)。
    /// 未 configure (キーを持たない開発ビルド・Preview) では、デザイン確認のため見本価格で描画する
    private func shouldShowPlan(package: Package?) -> Bool {
        !Purchases.isConfigured || package != nil
    }

    /// 年額の表示価格。offering 未取得の間 (未 configure のみ到達) は PROJECT.md で確定した価格 (¥6,000/年) を見本表示する
    private var annualPriceText: String {
        offering?.annual?.storeProduct.localizedPriceString ?? "¥6,000"
    }

    /// 年額プランのひと月あたり換算の表示価格。ストア価格を 12 (ヶ月) で割り、商品の通貨フォーマッタで整形する。
    /// offering 未取得の間 (未 configure のみ到達) は PROJECT.md で確定した価格 (¥6,000 / 12ヶ月 = ¥500) を見本表示する
    private var annualPerMonthPriceText: String {
        guard let storeProduct = offering?.annual?.storeProduct else { return "¥500" }
        return storeProduct.priceFormatter?.string(from: storeProduct.price / 12 as NSDecimalNumber)
            ?? storeProduct.localizedPriceString
    }

    /// 年額プランの無料トライアル期間の表示文字列 (例: 1 week)。
    /// introductory offer が無料トライアルの時だけ返し、それ以外 (offer 無し・有料の導入価格・offering 未取得) は nil。
    /// PROJECT.md の課金設計では「年額のみ 7 日間無料トライアル」だが、固定文言で書くとストア側の設定と
    /// 食い違った時に実際と異なる無料期間を見せてしまうため、必ず取得できた offer の期間から組み立てる
    /// (見本価格を出さない PR #30 の方針と同じ)
    private var annualFreeTrialPeriodText: String? {
        guard let introductoryDiscount = offering?.annual?.storeProduct.introductoryDiscount,
              introductoryDiscount.paymentMode == .freeTrial else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day]
        return formatter.string(from: dateComponents(subscriptionPeriod: introductoryDiscount.subscriptionPeriod))
    }

    /// 月額の表示価格。offering 未取得の間 (未 configure のみ到達) は PROJECT.md で確定した価格 (¥800/月) を見本表示する
    private var monthlyPriceText: String {
        offering?.monthly?.storeProduct.localizedPriceString ?? "¥800"
    }

    /// 一生プランの表示価格。offering 未取得の間 (未 configure のみ到達) は PROJECT.md で確定した価格 (¥9,800) を見本表示する
    private var lifetimePriceText: String {
        offering?.lifetime?.storeProduct.localizedPriceString ?? "¥9,800"
    }

    /// offering を読み込む。未 configure (キーを持たない開発ビルド・Preview) では何もしない (見本価格の表示に倒す)。
    /// lookup_key (PremiumEntitlement.offeringIdentifier) の識別子だけで取得する。`.current` へのフォールバックは
    /// Dashboard の Current 指定次第で別キャンペーン用 offering の商品を売ってしまうため使わない (PR #30 レビュー指摘)。
    /// offering は取得できても全 package が未解決 (商品の反映待ち等) なら購入手段が無いため、読み込み失敗として再読み込み導線に倒す (PR #30 レビュー指摘)
    private func loadOffering() async {
        guard Purchases.isConfigured else { return }
        offeringLoadFailed = false
        do {
            let resolved = try await Purchases.shared.offerings().offering(identifier: PremiumEntitlement.offeringIdentifier)
            if let resolved, resolved.annual != nil || resolved.monthly != nil || resolved.lifetime != nil {
                offering = resolved
            } else {
                offering = nil
                offeringLoadFailed = true
            }
        } catch {
            offeringLoadFailed = true
        }
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
                // customerInfoStream 経由のキャッシュ更新は非同期で、dismiss 直後のゲート画面の描画に
                // 間に合わないことがあるため、確定した CustomerInfo を先にキャッシュへ反映する (PR #30 レビュー指摘)
                PremiumEntitlement.cacheEntitlement(customerInfo: result.customerInfo)
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
            let customerInfo = try await Purchases.shared.restorePurchases()
            if customerInfo.entitlements[PremiumEntitlement.entitlementIdentifier]?.isActive == true {
                // customerInfoStream 経由のキャッシュ更新は非同期で、dismiss 直後のゲート画面の描画に
                // 間に合わないことがあるため、確定した CustomerInfo を先にキャッシュへ反映する (PR #30 レビュー指摘)
                PremiumEntitlement.cacheEntitlement(customerInfo: customerInfo)
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

/// RevenueCat の購読期間を DateComponentsFormatter へ渡せる DateComponents に変換する。
/// 週は DateComponents に week が無いため weekOfMonth を使う (DateComponentsFormatter の .weekOfMonth に対応する)
func dateComponents(subscriptionPeriod: SubscriptionPeriod) -> DateComponents {
    switch subscriptionPeriod.unit {
    case .day:
        return DateComponents(day: subscriptionPeriod.value)
    case .week:
        return DateComponents(weekOfMonth: subscriptionPeriod.value)
    case .month:
        return DateComponents(month: subscriptionPeriod.value)
    case .year:
        return DateComponents(year: subscriptionPeriod.value)
    }
}

struct PaywallPage_Previews: PreviewProvider {
    static var previews: some View {
        PaywallPage()
    }
}
