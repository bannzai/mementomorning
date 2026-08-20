#!/bin/sh
# Xcode Cloud の post-clone スクリプト。
# ワークフローの環境変数 (Secret) REVENUECAT_API_KEY から、gitignore されている
# Config.local.xcconfig をリポジトリルートに生成する (手順: documents/xcode-cloud-setup.md)。
#
# - 実キーの適用は Release 構成に限定する ([config=Release])。同じワークフローに
#   Test アクションを足しても、Debug は Config.xcconfig の Test Store キーのまま動く
# - REVENUECAT_API_KEY が未設定・空の場合はファイルを生成せず正常終了する。
#   Debug ビルド (テスト) は Config.xcconfig の Test Store キーで動き、
#   Release アーカイブは preBuild 検査 (Require App Store REVENUECAT_API_KEY for Release)
#   が appl_ キーの欠落を検出してビルドエラーで止めるため、ここでは失敗にしない
# - 再実行するたびに同じ内容で上書きするため冪等
# - キーの値は秘匿情報のためログへ出力しない
set -eu

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
xcconfig_path="${repository_root}/Config.local.xcconfig"

if [ -z "${REVENUECAT_API_KEY:-}" ]; then
  echo "REVENUECAT_API_KEY が未設定のため ${xcconfig_path} を生成しません"
  exit 0
fi

printf 'REVENUECAT_API_KEY[config=Release] = %s\n' "${REVENUECAT_API_KEY}" > "${xcconfig_path}"
echo "${xcconfig_path} を生成しました"
