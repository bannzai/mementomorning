# Xcode Cloud セットアップ手順

TestFlight / App Store への binary アップロード経路は Xcode Cloud で行う (issue #86)。
このドキュメントは、リポジトリ側で整備済みの内容と、ユーザーが Xcode / App Store Connect の UI で行う設定手順を記録する。
メタデータ・スクリーンショットの入稿は従来どおり fastlane の `metadata_upload` lane (`fastlane/Fastfile`) が担い、Xcode Cloud は binary のみを扱う。

## 全体像

```
main へ push → Xcode Cloud が検知 → ci_post_clone.sh で Config.local.xcconfig を生成
→ Release アーカイブ (マネージド署名) → TestFlight 内部テストへ自動配布
→ App Store 提出時はその binary を App Store Connect で選択
```

- 署名は Xcode Cloud のマネージド署名 (cloud signing) に任せる。ローカルの provisioning profile・App Store Connect API key の管理は不要
- RevenueCat の実キー (appl_) は gitignore された `Config.local.xcconfig` に置く運用 (`Config.xcconfig` のコメント参照) のため、Xcode Cloud の checkout には存在しない。ワークフローの環境変数 (Secret) `REVENUECAT_API_KEY` から `ci_scripts/ci_post_clone.sh` が生成する

## リポジトリ側で整備済みのもの (作業不要)

| 項目 | 状態 |
|---|---|
| `ci_scripts/ci_post_clone.sh` | 環境変数 `REVENUECAT_API_KEY` から `Config.local.xcconfig` を生成する。未設定なら生成せず正常終了し、Release の欠落は下記 preBuild 検査が検出する |
| scheme の共有 | `MementoMorning` scheme は `MementoMorning.xcodeproj/xcshareddata/xcschemes/` に共有済み (Xcode Cloud は共有 scheme しか扱えない) |
| Release キーの検査 | MementoMorning ターゲットの Build Phase「Require App Store REVENUECAT_API_KEY for Release」が、Release 構成で `appl_` 以外のキーをビルドエラーにする。Secret の設定漏れはアーカイブ失敗で気づける |

補足: `ci_scripts/` は Xcode プロジェクト直下 (`.xcodeproj` と同じ階層) に置くだけでよく、Xcode プロジェクトへのファイル追加は不要。Xcode Cloud が clone 直後に `ci_post_clone.sh` を自動実行する。
参考: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts

## ユーザーが行う設定手順

### 前提

- Apple Developer Program に加入済みで、App Store Connect に MementoMorning のアプリレコード (bundle ID `com.bannzai.MementoMorning`) が作成済みであること
- Xcode に App Store Connect のアカウント (Settings > Accounts) がサインイン済みであること

### 1. ワークフローを作成する

1. Xcode で `MementoMorning.xcodeproj` を開く
2. メニュー Integrate > Create Workflow… を選ぶ (または Report navigator の Cloud タブ)
3. 対象 App として MementoMorning を選び、Grant Access でリポジトリ (github.com/bannzai/mementomorning) へのアクセスを許可する
4. 既定のワークフローが作られたら Edit Workflow… で以下のとおり設定する

### 2. ワークフローの設定内容

| 設定 | 値 |
|---|---|
| Name | Release (任意) |
| Start Conditions | Branch Changes: `main` (タグ運用にしたい場合は Tag Changes に変更) |
| Environment | 最新の macOS / Xcode。**Clean を有効**にする (アーカイブの再現性のため) |
| Environment Variables | 下記「3. Secret の登録」 |
| Actions | Archive — Platform: iOS, Scheme: `MementoMorning`, Deployment Preparation: **TestFlight (Internal Testing Only)** (App Store 提出まで見据える場合は TestFlight and App Store) |
| Post-Actions | TestFlight Internal Testing — 配布先の内部テスターグループを選択 (グループは App Store Connect の TestFlight で事前に作成する) |

- Archive アクションは Release 構成でビルドされるため、`Config.local.xcconfig` の appl_ キーが必須になる (preBuild 検査)
- テストをワークフローに含めたい場合は Test アクション (Scheme: `MementoMorning`) を追加する。テストは Debug 構成で走るため Secret なしでも動く (Test Store キー)

### 3. Secret の登録

ワークフロー編集画面の Environment > Environment Variables で次を登録する。

| Name | Value | Secret |
|---|---|---|
| `REVENUECAT_API_KEY` | RevenueCat の App Store 用 public API key (`appl_` で始まる) | **✔ (必ず Secret にする)** |

キーの取得方法は `Config.xcconfig` のコメントを参照 (RevenueCat Dashboard の Project Settings > API Keys、または `rc_get_public_api_key.sh`)。

### 4. 署名 (マネージド署名)

Xcode Cloud は既定で cloud signing (マネージド署名) を使う。初回ワークフロー作成時に自動で有効になり、証明書・provisioning profile の手動管理は不要。プロジェクト側も Automatically manage signing のままでよい。

### 5. 動作確認

1. main へ push (またはワークフロー画面から Start Build) してビルドを起動する
2. ビルドログで `ci_post_clone.sh` が「Config.local.xcconfig を生成しました」を出力していることを確認する (キーの値はログに出ない)
3. アーカイブが成功し、TestFlight の内部テストグループに配布されることを確認する
4. TestFlight 版アプリでペイウォールの価格表示が実ストアの商品 (¥800/月・¥6,000/年・¥9,800 買い切り) になっていることを確認する (Test Store キー混入の最終確認)

## トラブルシューティング

| 症状 | 原因と対処 |
|---|---|
| アーカイブが「Release の REVENUECAT_API_KEY が App Store 用の実キー (appl_...) ではありません」で失敗する | Secret `REVENUECAT_API_KEY` が未登録、または値が `appl_` で始まっていない。「3. Secret の登録」をやり直す |
| `ci_post_clone.sh` が実行されない | スクリプトの実行権限 (`chmod +x`) が落ちていないか、`ci_scripts/` がリポジトリルート (`.xcodeproj` と同じ階層) にあるかを確認する |
| scheme が選択肢に出ない | scheme が共有されているか確認する (`MementoMorning.xcodeproj/xcshareddata/xcschemes/MementoMorning.xcscheme`) |

## ローカルでの検証方法

```sh
# Config.local.xcconfig が生成されること (実キー運用中の場合は事前に退避する)
REVENUECAT_API_KEY=dummy bash ci_scripts/ci_post_clone.sh
cat Config.local.xcconfig   # → REVENUECAT_API_KEY = dummy
rm Config.local.xcconfig    # 後片付け (dummy キーを残すと Debug ビルドの課金検証が壊れる)

# 未設定なら生成されないこと
bash ci_scripts/ci_post_clone.sh
```
