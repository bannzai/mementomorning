import Foundation

/// プレミアム課金の判定。RevenueCat 連携 (#9) が入るまでは常に無料 (false) を返すスタブ
enum PremiumEntitlement {
    /// 現在のユーザーがプレミアムかどうか。#9 で RevenueCat の CustomerInfo による判定に置き換える
    static var isPremium: Bool { false }
}
