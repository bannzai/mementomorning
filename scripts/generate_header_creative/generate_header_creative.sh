#!/bin/bash
# App Store creative assets (product page header / search results) を生成する。
# SwiftUI (HeaderCreativeGenerator.swift) を swiftc でコンパイルし、ja / en-US の 4 枚を
# fastlane/creative_assets/ へ PNG 出力する。再実行しても同じ結果になる (冪等)。
#
# usage: bash scripts/generate_header_creative/generate_header_creative.sh [--safe-area-guide]
#   --safe-area-guide: Art Safe Area の赤枠を重ねた検証用画像を ./tmp/creative_assets_guide/ に出力する
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
build_dir="$repo_root/tmp/generate_header_creative"
mkdir -p "$build_dir"

# 配色トークン (DesignTokens.swift) はスクショ基盤と共有し、三重定義を避ける
swiftc -O -parse-as-library \
  "$repo_root/AppStoreScreenshots/Sources/DesignTokens.swift" \
  "$script_dir/HeaderCreativeGenerator.swift" \
  -o "$build_dir/generate_header_creative"

if [[ "${1:-}" == "--safe-area-guide" ]]; then
  "$build_dir/generate_header_creative" "$repo_root/tmp/creative_assets_guide" --safe-area-guide
else
  "$build_dir/generate_header_creative" "$repo_root/fastlane/creative_assets"
fi
