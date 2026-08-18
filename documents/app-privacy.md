# App Privacy 回答 (App Store Connect)

App Store Connect の「App のプライバシー」への回答内容と、その実装根拠を記録する。
ASC の回答は Web UI (または fastlane spaceship) でしか設定できないため、提出前の整理を本ドキュメントが担う。
アプリバンドル側の宣言は `MementoMorning/PrivacyInfo.xcprivacy` が担い、判断根拠は本ドキュメントを共有する。

前提 (アーキテクチャ): 回答テキスト・動画・アラーム設定はすべて端末内のみで完結し、バックエンドを持たない
([ADR 0001](adr/0001-local-only-swiftdata-revenuecat-infra.md))。端末外へデータを送信する経路は
RevenueCat SDK (課金) だけである。

## 結論サマリー

| ASC の質問 | 回答 |
|---|---|
| データを収集していますか | はい (購入履歴のみ、RevenueCat SDK 経由) |
| トラッキングに使用していますか | いいえ |

## 収集するデータ

### 購入 (Purchase History)

| 項目 | 回答 |
|---|---|
| category | 購入 > 購入履歴 (PURCHASE_HISTORY) |
| 用途 (purposes) | アプリの機能 (APP_FUNCTIONALITY)・分析 (ANALYTICS) |
| ユーザーへの紐付け | 紐付けない (DATA_NOT_LINKED_TO_YOU) |
| トラッキング | 使用しない |

- 根拠: RevenueCat SDK が購入・購読情報を RevenueCat サーバーへ送信する。SDK の初期化は
  `MementoMorning/Shared/Entitlement/PremiumEntitlement.swift` の `Purchases.configure(withAPIKey:)` のみで、
  `Purchases.logIn` によるユーザー ID 連携は行っていない (匿名 App User ID のみ) ため「ユーザーに紐付けない」
- 用途に APP_FUNCTIONALITY と ANALYTICS の両方を含めるのは、RevenueCat 公式が最低要件とする回答に合わせたもの
  (出典: RevenueCat「Apple App Privacy」ドキュメント。`~/.claude/skills/appstore-app-privacy/references/sdk_privacy_answers.md` に整理済み)
- 補足: SDK 同梱の Privacy Manifest (後述) は purposes を App Functionality のみで宣言しているが、
  ASC の回答と Privacy Manifest は別の成果物であり、ASC 側は RevenueCat の ASC 回答ガイド (より広い方) に従う

## 収集しないデータ (端末内のみで完結するもの)

Apple の「収集」の定義は「端末外へ送信し、開発者や第三者がアクセスできる状態にすること」
( https://developer.apple.com/app-store/app-privacy-details/ )。以下は端末外へ送信しないため「収集」に該当しない。

| データ | 実装 | 根拠 |
|---|---|---|
| 毎朝の回答テキスト | SwiftData でローカル保存。Widget へは App Groups 共有ストア経由 (端末内) | `MementoMorning/Shared/` の SwiftData モデル、[ADR 0001](adr/0001-local-only-swiftdata-revenuecat-infra.md) |
| 回答動画 (カメラ・マイク) | インカメラで録画し、一時ディレクトリ経由で写真アプリのアルバム「Memento Morning」へ保存 (端末内のみ) | `MementoMorning/Features/MorningQuestion/VideoAnswerCamera.swift`、`VideoAnswerPhotoLibrary.swift` |
| 音声の文字起こし | `SFSpeechRecognizer` に `requiresOnDeviceRecognition = true` を指定し、端末内でのみ認識 | `MementoMorning/Features/MorningQuestion/VideoAnswerTranscriber.swift:74` |
| 写真ライブラリ | 保存 (書き込み) のみで読み取りなし | `MementoMorning/Features/MorningQuestion/VideoAnswerPhotoLibrary.swift`、`MementoMorning/Info.plist` の `NSPhotoLibraryUsageDescription` |
| アラーム設定・オンボーディング状態等 | UserDefaults / SwiftData でローカル保存 | `MementoMorning/MementoMorningApp.swift` ほか |

分析 SDK (Firebase 等)・広告 SDK・IDFA は使用していない (依存は RevenueCat のみ。
`MementoMorning.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` 参照)。

## トラッキング

なし。ATT (App Tracking Transparency) の対象となるデータ結合・広告目的の共有は行わない。
`PrivacyInfo.xcprivacy` の `NSPrivacyTracking` も `false`。

## Privacy Manifest (PrivacyInfo.xcprivacy)

### アプリ本体 (`MementoMorning/PrivacyInfo.xcprivacy`)

| キー | 宣言 | 根拠 |
|---|---|---|
| NSPrivacyTracking | false | トラッキングなし (上記) |
| NSPrivacyCollectedDataTypes | 空 | アプリ自身のコードは端末外へデータを送信しない。RevenueCat SDK の収集は SDK 同梱の manifest が宣言する (下記) |
| NSPrivacyAccessedAPITypes | UserDefaults / CA92.1 | 自アプリの `@AppStorage`・`UserDefaults.standard` 使用 (オンボーディング完了フラグ・entitlement キャッシュ・最終アラーム発火時刻等。`MementoMorning/MementoMorningApp.swift`、`MementoMorning/Shared/Entitlement/PremiumEntitlement.swift`) |

Required Reason API の洗い出し結果 (2026-08-18 時点、`rg` による全 Swift ソース検査):

- UserDefaults: 使用あり → CA92.1 で宣言
- ファイルタイムスタンプ API (`creationDate` / `contentModificationDate` / `attributesOfItem` 等): 使用なし
- システム起動時刻 (`systemUptime` 等)・ディスク空き容量 (`volumeAvailableCapacity` 等)・アクティブキーボード: 使用なし
- `FileManager` は `temporaryDirectory` への書き込み・`copyItem` / `removeItem` のみで、Required Reason API に該当しない

### RevenueCat SDK (purchases-ios 5.83.2)

SDK が自身の Privacy Manifest を SPM リソースとして同梱しており、アプリ側で重複宣言しない
(出典: `https://github.com/RevenueCat/purchases-ios/blob/5.83.2/Sources/PrivacyInfo.xcprivacy` )。
同梱 manifest の内容: PurchaseHistory (linked=false, tracking=false, purpose=App Functionality)、
UserDefaults / CA92.1、NSPrivacyTracking=false。

issue #66 の「RevenueCat SDK の Required Reason API (UserDefaults 等) を宣言する」は、SDK 同梱 manifest が
既に宣言しているため二重宣言が不要と判断した。自アプリも UserDefaults を直接使うため、
アプリ側 manifest の UserDefaults / CA92.1 宣言は自アプリの使用根拠で独立に必要であり、結果としてバンドル全体で要件を満たす。

### Widget Extension (MementoMorningWidget)

Privacy Manifest は追加しない。理由:

- Widget のコードは Required Reason API を直接呼んでいない (UserDefaults 使用なし。`rg` で検査済み)
- SwiftData (`ModelContainer`) は Apple 純正フレームワークであり、サードパーティ SDK に課される
  manifest 同梱義務の対象外
- データの端末外送信もない (App Groups 共有ストアの読み取りのみ。`MementoMorningWidget/TodayAnswerWidget.swift`)

Widget に UserDefaults 等の Required Reason API を将来追加する場合は、アプリ本体の manifest では extension を
カバーできないため、Widget ターゲットにも PrivacyInfo.xcprivacy を追加すること。

## ASC への適用方法

App Privacy は公開 App Store Connect API に存在しないため、Web UI で回答するか、
`/appstore-app-privacy` skill (fastlane spaceship 経由) で本ドキュメントの回答を適用する。
skill を使う場合の回答定義 (fastlane/app_privacy_details.json 相当):

```json
{
  "data_usages": [
    {
      "category": "PURCHASE_HISTORY",
      "purposes": ["ANALYTICS", "APP_FUNCTIONALITY"],
      "data_protections": ["DATA_NOT_LINKED_TO_YOU"]
    }
  ]
}
```
