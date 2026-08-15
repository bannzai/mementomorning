import Foundation
import RevenueCat

extension String {
    /// RevenueCat の entitlement 判定結果をキャッシュする UserDefaults キー。
    /// StopAlarmIntent.perform() など View 外から同期的に参照するため、customerInfoStream の更新をここへ保存する
    static let premiumEntitlementActive = "premiumEntitlementActive"
    #if DEBUG
    /// 検証用にプレミアム状態を強制する UserDefaults キー (DEBUG 限定。DebugMenuPage から切り替える)
    static let debugPremiumOverride = "debugPremiumOverride"
    #endif
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
    /// customerInfoStream が UserDefaults へ保存した最新の entitlement 判定を返す
    /// (View 外の StopAlarmIntent からも同期参照できるよう、SDK ではなくキャッシュ経由で判定する)
    static var isPremium: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: .debugPremiumOverride) {
            return true
        }
        #endif
        return UserDefaults.standard.bool(forKey: .premiumEntitlementActive)
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
            UserDefaults.standard.set(
                customerInfo.entitlements[entitlementIdentifier]?.isActive == true,
                forKey: .premiumEntitlementActive
            )
        }
    }
}
