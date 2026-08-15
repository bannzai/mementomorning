import Foundation
import RevenueCat

extension String {
    /// RevenueCat の entitlement 判定結果をキャッシュする UserDefaults キー。
    /// StopAlarmIntent.perform() など View 外から同期的に参照するため、customerInfoStream の更新をここへ保存する
    static let premiumEntitlementActive = "premiumEntitlementActive"
    /// entitlement の失効日時 (epoch 秒) をキャッシュする UserDefaults キー。
    /// 期限付き購読はアプリ停止中に失効し得るため、premiumEntitlementActive と対で保存して参照時に同期判定する。
    /// 買い切り (失効しない) の場合はキー自体を消す
    static let premiumEntitlementExpiration = "premiumEntitlementExpiration"
    #if DEBUG
    /// 検証用にプレミアム状態を強制する UserDefaults キー (DEBUG 限定。DebugMenuPage から切り替える)
    static let debugPremiumOverride = "debugPremiumOverride"
    #endif
}

/// キャッシュした課金判定が now 時点でも有効か。
/// 失効日時が保存されている場合は同期比較する (期限切れ・返金がアプリ停止中に起きても、
/// 古い true を無期限に返さないため)。失効日時なし = 買い切りまたは未購入で、active の値をそのまま使う。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func cachedPremiumActive(active: Bool, expirationDate: Date?, now: Date) -> Bool {
    guard active else { return false }
    guard let expirationDate else { return true }
    return expirationDate > now
}

/// プレミアム課金の判定と RevenueCat SDK の初期化 (課金設計は documents/PROJECT.md 参照)
enum PremiumEntitlement {
    /// RevenueCat の entitlement 識別子。#15 で登録する entitlement の lookup_key と一致させる
    static let entitlementIdentifier = "premium"

    /// ペイウォールが表示する offering の識別子。#15 で登録する offering の lookup_key と一致させる
    static let offeringIdentifier = "default"

    /// RevenueCat の iOS 用 public API key (appl_...)。
    /// 本リポジトリは public のためソースに実値を置かず、gitignore した Config.local.xcconfig から
    /// Info.plist 経由で受け取る (手順は Config.xcconfig のコメント参照)。
    /// キーを持たない環境 (CI・コントリビューターの手元) では空文字になり configure をスキップする
    static let revenueCatAPIKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""

    /// 現在のユーザーがプレミアムかどうか。
    /// customerInfoStream が UserDefaults へ保存した最新の entitlement 判定を、失効日時と突き合わせて返す
    /// (View 外の StopAlarmIntent からも同期参照できるよう、SDK ではなくキャッシュ経由で判定する)
    static var isPremium: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: .debugPremiumOverride) {
            return true
        }
        #endif
        return cachedPremiumActive(
            active: UserDefaults.standard.bool(forKey: .premiumEntitlementActive),
            expirationDate: (UserDefaults.standard.object(forKey: .premiumEntitlementExpiration) as? Double).map(Date.init(timeIntervalSince1970:)),
            now: .now
        )
    }

    /// entitlement 判定を UserDefaults キャッシュへ保存する。
    /// customerInfoStream の監視・購入・復元の全経路で同じ形のキャッシュになるようここへ集約する
    static func cacheEntitlement(customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[entitlementIdentifier]
        UserDefaults.standard.set(entitlement?.isActive == true, forKey: .premiumEntitlementActive)
        if let expirationDate = entitlement?.expirationDate {
            UserDefaults.standard.set(expirationDate.timeIntervalSince1970, forKey: .premiumEntitlementExpiration)
        } else {
            // 買い切り (一生プラン) は expirationDate が nil = 失効しない
            UserDefaults.standard.removeObject(forKey: .premiumEntitlementExpiration)
        }
    }

    /// RevenueCat SDK を初期化する。
    /// API key 未設定 (#15 前) では何もしない。ユニットテスト・Preview ではネットワークに触れないよう configure しない。
    /// isConfigured を見て多重 configure を防ぐため冪等
    static func configureIfPossible() {
        guard !revenueCatAPIKey.isEmpty, !isUnitTest, !isPreview, !Purchases.isConfigured else { return }
        Purchases.configure(withAPIKey: revenueCatAPIKey)
    }

    /// customerInfoStream を監視して entitlement 判定のキャッシュを更新し続ける。
    /// 起動時キャッシュ → 購入・復元・期限切れ更新の順に customerInfo が流れてくるため、この 1 本で課金状態へ追従できる
    static func observeCustomerInfo() async {
        guard Purchases.isConfigured else { return }
        for await customerInfo in Purchases.shared.customerInfoStream {
            cacheEntitlement(customerInfo: customerInfo)
        }
    }
}
