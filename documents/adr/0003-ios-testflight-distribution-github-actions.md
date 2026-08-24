# 0003. iOS の TestFlight 配布は GitHub Actions (手動署名) で行う

## Status

Accepted

## Context

TestFlight への binary アップロード経路は issue #86 以来 Xcode Cloud (main への push で自動起動、
マネージド署名) を使ってきた ([documents/xcode-cloud-setup.md](../xcode-cloud-setup.md))。
運用の中で次の不満が出た ( https://github.com/bannzai/castle/issues/658 ):

- 環境変数 (Secret `REVENUECAT_API_KEY`) の登録・変更が Xcode / App Store Connect の Web UI でしか
  できず、CLI で完結しない
- ビルドログが CLI から読みづらく、失敗時の調査をスクリプタブルに行えない

チーム方針として Swift/iOS アプリの配布環境を GitHub Actions に統一することになり、その雛形は
castle の `ios-deploy-actions` skill (bannzai/PUTS で実証済みの手動署名構成の雛形化) として整備された。
public リポジトリのため macOS runner は無料で、Xcode Cloud の無料枠を気にする必要もなくなる。

## Decision

- iOS の TestFlight 配布は GitHub Actions の `.github/workflows/ios-deploy.yml` (workflow_dispatch
  手動起動) で行う。workflow は ios-deploy-actions skill が生成・管理する (1 行目に管理マーカー)
- 署名は手動署名。Apple Distribution 証明書 (チーム共有の CI 用) と、App 本体
  (`com.bannzai.MementoMorning` → profile `MementoMorning.AppStore`)・Widget
  (`com.bannzai.MementoMorning.MementoMorningWidget` → profile `MementoMorning.MementoMorningWidget.AppStore`)
  の provisioning profile を base64 で GitHub Secrets に置き、CI 上で復元する。
  `project.pbxproj` は **Release かつ実機 SDK (`[sdk=iphoneos*]`) に限り** Manual 署名にする
  (Debug・simulator のローカル開発・テストは Automatic のまま)
- `ci_scripts/ci_post_clone.sh` (env `REVENUECAT_API_KEY` から `Config.local.xcconfig` を生成) は
  **削除せず GitHub Actions からも再利用する**。workflow の Archive 前に同スクリプトを実行し、
  GitHub Secret は正準名 `REVENUECAT_PUBLIC_API_KEY_IOS` を env 名 `REVENUECAT_API_KEY` にマップして渡す
- ビルド番号は `github.run_number + BUILD_NUMBER_OFFSET`。Xcode Cloud が採番済みのビルド番号を
  超える offset から始める
- Xcode Cloud のワークフロー (MementoMorning product の Release) は、GitHub Actions での配布が
  1 回成功したことを確認した後に App Store Connect API で削除する

## Consequences

- Secrets・workflow・実行ログのすべてを CLI (gh) で操作できる
- main へのマージごとの自動配布は失われ、リリース時の手動 dispatch に変わる
- 証明書・profile の期限管理が必要になる (更新手順は ios-deploy-actions skill)
- 手順の詳細は [documents/ios-testflight-distribution.md](../ios-testflight-distribution.md) に記録する
