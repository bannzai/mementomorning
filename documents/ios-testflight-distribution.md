# iOS の TestFlight 配布手順

`.github/workflows/ios-deploy.yml` を手動起動すると、MementoMorning (bundle `com.bannzai.MementoMorning`、
Widget `com.bannzai.MementoMorning.MementoMorningWidget`) の Release ビルドが arm64 実機向けにアーカイブされ、
TestFlight (App Store Connect、appId 6801673264) へアップロードされる。署名は手動署名 (Secrets の証明書 + profile を
CI で復元)。方式の決定理由は [ADR 0003](adr/0003-ios-testflight-distribution-github-actions.md) (Xcode Cloud からの移行)。

workflow は castle の ios-deploy-actions skill (`~/.claude/skills/ios-deploy-actions/SKILL.md`) が生成・管理する
(1 行目に管理マーカー)。RevenueCat キーの生成 step だけ skill 生成後に追記してある (再生成時は同 step を復元すること)。

## 前提 (初回のみ / 更新時)

1. App Store Connect のアプリレコード (appId 6801673264) は作成済み
2. App Store Connect API Key。アップロード認証 (altool) と profile の API 発行に使う。Admin ロール不要
3. 配布証明書と provisioning profile。profile は発行済み
   (`MementoMorning.AppStore` / `MementoMorning.MementoMorningWidget.AppStore`。
   チーム共有の配布証明書 `68L9PY6PX2` と `W5B62YWX68` の両方を含み、期限は **2027-06-10**)。
   再発行は ios-deploy-actions skill の `signing-assets.sh` で行う
4. GitHub Secrets (Settings > Secrets and variables > Actions) に次の 8 つを登録する。
   登録は ios-deploy-actions skill の `register-secrets.sh` (非空検証つき一括登録) を使う

   | Secret | 内容 |
   | --- | --- |
   | `ASC_API_KEY_ID` | API Key の Key ID |
   | `ASC_API_KEY_ISSUER_ID` | Issuer ID (UUID) |
   | `ASC_API_KEY_P8_BASE64` | `AuthKey_<KEY_ID>.p8` の base64 |
   | `IOS_P12_CERTIFICATE_BASE64` | 配布証明書 .p12 の base64 (チーム共有の CI 用) |
   | `IOS_P12_PASSWORD` | p12 のパスワード |
   | `IOS_PROVISIONING_PROFILE_BASE64` | `MementoMorning.AppStore` profile の base64 |
   | `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` | `MementoMorning.MementoMorningWidget.AppStore` profile の base64 |
   | `REVENUECAT_API_KEY` | RevenueCat の App Store 用 public API key (`appl_` で始まる)。`ci_scripts/ci_post_clone.sh` が `Config.local.xcconfig` を生成するのに使う (Xcode Cloud 時代と同じ仕組み) |

秘密の実値はリポジトリに置かない。

## 配布する

```sh
gh workflow run ios-deploy.yml --ref main
gh run list --workflow ios-deploy.yml --limit 3
gh run watch <今起動した run の ID>
```

- ビルド番号は `github.run_number + BUILD_NUMBER_OFFSET`。**現在の offset は 15** (Xcode Cloud がビルド 14 まで採番済みのため)。
  run_number が巻き戻る事態では offset を既存の最大ビルド番号を超える値に上げる
- 配布は同時に 1 本だけ。先行 run が未完了だと最初の step (Reject concurrent dispatch) で失敗する
- 失敗した run は Re-run せず新しく dispatch する (同じビルド番号の再アップロードは拒否されるため)
- public リポジトリのため macOS runner は無料
- Archive は Release 構成のため `Config.local.xcconfig` の appl_ キーが必須 (preBuild 検査が Secret の設定漏れを検出する)

## TestFlight で処理完了になったことを確認する

```sh
bash ~/.claude/skills/ios-deploy-actions/scripts/asc-api.sh GET \
  "/v1/builds?filter[app]=6801673264&sort=-uploadedDate&limit=5&fields[builds]=version,processingState,uploadedDate" \
  | jq '.data[] | {version: .attributes.version, processingState: .attributes.processingState, uploadedDate: .attributes.uploadedDate}'
```

`processingState` が `PROCESSING` → `VALID` になれば TestFlight にビルドが並ぶ。
`Info.plist` の `ITSAppUsesNonExemptEncryption = false` 設定済みのため輸出コンプライアンスの毎回回答は不要。

## うまくいかない時

- 「Release の REVENUECAT_API_KEY が App Store 用の実キー (appl_...) ではありません」で Archive が失敗する:
  Secret `REVENUECAT_API_KEY` が未登録か値が不正。登録し直して新しく dispatch する
- `No signing certificate` / `No profiles ... were found`: Secrets の .p12 / .mobileprovision と、
  `project.pbxproj` の `PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]` の profile 名一致を確認する
- 証明書か profile の期限切れ (2027-06-10): ios-deploy-actions skill で再発行し Secrets を更新する
- `The bundle version must be higher than the previously uploaded version`: `BUILD_NUMBER_OFFSET` を上げる
