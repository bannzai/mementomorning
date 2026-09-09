# App Store 製品ページヘッダー

## 訴求と根拠

「静かな問いで、自分の一日を始める」を、墨色の余白に浮かぶ小さな朝日と白紙の冊子で表現する。朝日は朝の始まり、白紙は今日の問いへの答えと、これから記録する一日を表す。

日本語・英語のストア説明（`fastlane/metadata/ja/`、`fastlane/metadata/en-US/`）にある「朝の儀式」「毎朝の回答が静かに積み重なる」という体験を根拠にした。配色は `MementoMorning/Shared/DesignSystem/DesignSystem.swift` の墨・温白・夜明けの微光に合わせた。

## 制作仕様

- 入稿ファイル: `header.jpg`（JPEG、3840 × 1646、透過なし）
- 全言語共通。画像内の文字・数字・ロゴは使用しない
- 生成プロンプト: `prompt.txt`。21:9 / 4K で生成し、中央クロップと縮小後に JPEG に変換する
- 主要な物体を中央の横帯に収め、周辺は余白と控えめな光だけにする

Apple 公式テンプレートを取得して確認した仕様（2026-09-09）:

```text
canvas: 3840 × 1646
Art Safe Area: left=1097 top=493 right=2743 bottom=1154
```

テンプレート配布元:
https://developer.apple.com/app-store/asset-best-practices/

## 検証

次のコマンドはリポジトリのルートで実行する。

```sh
bash ~/.agents/skills/appstore-header-creative/scripts/fetch_template_spec.sh --type header --cache-dir ./tmp/appstore-header-creative
bash ~/.agents/skills/appstore-header-creative/scripts/normalize_asset.sh ./tmp/header-generated.png ./tmp/header-normalized.png --type header
sips -s format jpeg -s formatOptions 95 ./tmp/header-normalized.png --out appstore/product-page-header/header.jpg
bash ~/.agents/skills/appstore-header-creative/scripts/check_header_asset.sh appstore/product-page-header/header.jpg --type header
bash ~/.agents/skills/pr-attach-screenshots/scripts/check-upload-target.sh appstore/product-page-header/header.jpg
```

2026-09-09 に各コマンドが exit 0 で完了。生成画像は 6336 × 2688 で、正規化時の拡大は発生していない。最終画像の検証結果は以下のとおり（`[OK]` 2 件、`[WARN]` 0 件、`[NG]` 0 件）。

```text
[OK] フォーマット: jpeg
[OK] サイズ: 3840x1646
[INFO] Art Safe Area (実画像換算): left=1097 top=493 right=2743 bottom=1154 — キーコンテンツ・コピーはこの範囲内に収める
```

公開前の機械検査も `mime=image/jpeg` で合格。最終画像を表示して、文字・数字・実在ロゴ・透かし・価格・受賞表現・個人情報・秘匿情報がないことを確認した。朝日と冊子の主要部分は概ね x=1290〜2550、y=555〜1100 に収まり、上記のセーフエリア内にある（目視による概算。周辺の淡い光と背景は除く）。墨色の余白と温かい微光がアプリのトーンに合うことも確認した。

生成の初回は API の混雑による 503 で失敗し、再試行で成功した。生成 SDK には自動関数呼び出し方式に関する推奨メッセージが出た。また生成器が `.png` のパスへ実体 JPEG を保存したため、正規化時に拡張子の警告と `sysctlbyname` の診断が出た。上記の JPEG 変換後は拡張子と実体が一致し、最終画像の検証は警告なしで完了した。

App Store Connect の入稿先確認・アップロード・審査での受理は未検証。今回の対象は入稿用ファイルの準備までで、入稿はユーザーが行う。アプリのコード変更を伴わないため、アプリのビルド・シミュレータ検証は実施していない。

## セッション再開

```sh
cd /Users/bannzai/worktrees/bannzai/mementomorning/appstore-header-creative
codex resume 01a08542-ba81-7383-b50a-10e420f90626
```
