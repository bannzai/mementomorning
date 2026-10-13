#!/bin/bash
#
# appstore_screenshot_env.sh
#
# App Storeスクリーンショット生成用の環境変数と共通関数を定義するスクリプト。
# 他のスクリプトから source して使用する。
# (取り込み元: bannzai/Focus の同名スクリプト)
#

export SCHEME="AppStoreScreenshotsUITests"
export DERIVED_DATA_PATH=artifacts/appstore_screenshots/derived_data
export VARIANT_OUTPUT_BASE_DIR="scripts/generate_screenshots/artifacts"

# シミュレータの存在確認・自動作成 (ensure_simulator_exists) とランタイムバージョン解決
# (resolve_ios_runtime_version) の共通関数。DESTINATION の組み立てで使うため先頭で読み込む
source "$(dirname "${BASH_SOURCE[0]}")/../simulator_common.sh"

# 撮影に使う iOS ランタイムの実バージョン (deployment target と同じ iOS 26 系)。
# Xcode 更新で 26.0 → 26.0.1 のように進み、固定値では xcodebuild の destination に
# 一致しなくなるため実行時に解決する (選定基準は resolve_ios_runtime_version を参照)。
# 空 (ランタイム無し) はここでは許容する。本ファイルは apply_variant.sh など撮影しない
# スクリプトからも source されるため、必須チェックは撮影を行うスクリプト側で行う
SCREENSHOT_OS_VERSION="${SCREENSHOT_OS_VERSION:-$(resolve_ios_runtime_version 26)}"
export SCREENSHOT_OS_VERSION

# iPhone Duo (duo-outer / duo-inner) の撮影に使う iOS ランタイムの実バージョン。
# iPhone Duo の simulator は iOS 27.1 以上にしか無い (appstore-screenshot-builder skill references/iphone-duo.md) ため、
# 27.1 以上で最も低いものを解決する。空 (ランタイム無し) はここでは許容し、必須チェックは撮影を行うスクリプト側で行う
SCREENSHOT_DUO_OS_VERSION="${SCREENSHOT_DUO_OS_VERSION:-$(resolve_ios_runtime_version_at_least 27.1)}"
export SCREENSHOT_DUO_OS_VERSION

# iPhone Duo の姿勢 (閉じた / 開いた) を切り替えるスクリプト。
# xcrun simctl・XCUITest には姿勢を変える手段が無く、Device Hub のウィンドウを操作する ios-simulator skill のスクリプトに任せる
# (ローカルの Mac でしか使えない。中身と STATUS はスクリプトのヘッダーコメントが正)
export DUO_POSE_SCRIPT="${DUO_POSE_SCRIPT:-$HOME/.claude/skills/ios-simulator/scripts/duo-pose.sh}"

# 撮影デバイス (App Store Connect の表示サイズ区分)。
#   69: 6.9 インチ (iPhone 17 Pro Max, 1320×2868)。ASC で必須の表示サイズ
#   65: 6.5 インチ (iPhone 13 Pro Max, 1284×2778)。任意 (未提供なら 6.9 インチの縮小が使われる)
#   duo-outer: iPhone Duo の外側ディスプレイ (閉じた姿勢, 1398×2034)。2027 年 4 月から iOS 27.1 SDK 以降のアプリで必須
#   duo-inner: iPhone Duo の内側ディスプレイ (開いた姿勢, 横 2853×2007)。同上
# SCREENSHOT_DEVICES は生成・適用の対象デバイス一覧 (カンマ区切り。generate の -d で上書き)、
# SCREENSHOT_DEVICE は現在の 1 デバイス (generate がデバイスごとに export し、子スクリプトが引き継ぐ)。
# 既定に iPhone Duo を含めないのは、撮影が iOS 27.1 ランタイムと Device Hub の姿勢切り替え (ローカル限定) を要し、
# 生成物も fastlane deliver が読めない (apply 先が別) ため、明示的に選んだ時だけ撮る
export SCREENSHOT_DEVICES="${SCREENSHOT_DEVICES:-69,65}"

# デバイス区分から出力ファイル名に使う表示サイズ名を返す関数。
# 名前は fastlane deliver の DisplayType (Spaceship::ConnectAPI::AppScreenshotSet::DisplayType) に合わせる。
# deliver は 6.9 インチ (1320×2868) を APP_IPHONE_67 として扱う (判定自体は画像の解像度で行われるが、名前も一致させて紛れをなくす)。
# iPhone Duo の 2 つは deliver に無く、App Store Connect API の表示タイプ APP_IPHONE_DUO (外側・内側で 1 つ) に
# ディスプレイの区別を足したファイル名用のラベル (同じ番号の外側と内側が衝突しないようにするためのもの)
# Usage: get_display_type <69|65|duo-outer|duo-inner>
get_display_type() {
  case "$1" in
    69) echo "APP_IPHONE_67" ;;
    65) echo "APP_IPHONE_65" ;;
    duo-outer) echo "APP_IPHONE_DUO_OUTER" ;;
    duo-inner) echo "APP_IPHONE_DUO_INNER" ;;
    *) echo "Error: 未対応の SCREENSHOT_DEVICE です: $1 (対応: 69, 65, duo-outer, duo-inner)" >&2; return 1 ;;
  esac
}

# デバイス区分からシミュレータのデバイスタイプ名を返す関数
# Usage: get_device_type_name <69|65|duo-outer|duo-inner>
get_device_type_name() {
  case "$1" in
    69) echo "iPhone 17 Pro Max" ;;
    65) echo "iPhone 13 Pro Max" ;;
    duo-outer|duo-inner) echo "iPhone Duo" ;;
    *) echo "Error: 未対応の SCREENSHOT_DEVICE です: $1 (対応: 69, 65, duo-outer, duo-inner)" >&2; return 1 ;;
  esac
}

# デバイス区分から撮影に使う iOS ランタイムの実バージョンを返す関数 (空ならランタイム無し)
# Usage: get_device_os_version <69|65|duo-outer|duo-inner>
get_device_os_version() {
  case "$1" in
    duo-outer|duo-inner) echo "$SCREENSHOT_DUO_OS_VERSION" ;;
    *) echo "$SCREENSHOT_OS_VERSION" ;;
  esac
}

# デバイス区分が iPhone Duo の撮影に必要な姿勢 (duo-pose.sh の引数) を返す関数。iPhone Duo 以外は空
# Usage: get_duo_pose <69|65|duo-outer|duo-inner>
get_duo_pose() {
  case "$1" in
    duo-outer) echo "closed" ;;
    duo-inner) echo "open" ;;
    *) echo "" ;;
  esac
}

# デバイス区分の撮影を XCTAttachment ではなくホスト側の simctl で行うかを返す関数 (0 = ホスト側)。
# iPhone Duo の内側ディスプレイは XCTest の API ではストア仕様の寸法で撮れない
# (AppStoreScreenshotsUITests/XCTestCase+Snapshot.swift のコメントと capture_host_screenshots.sh を参照)。
# 外側は XCTest でも撮れるが、ホームインジケーターが消えるまで撮り直す判定 (has_home_indicator) は画像を見るホスト側でしかできず、
# 端末フレームの下端が画面内に入る iPhone Duo の比率ではインジケーターがフレームに重なって写る (本 PR の本番生成で 12 枚中 6 枚) ため、
# 外側もホスト側で撮る。6.9 / 6.5 インチは従来どおり XCTest (フレームの下端が画面外で、写っても見えない)
# Usage: is_host_capture_device <69|65|duo-outer|duo-inner>
is_host_capture_device() {
  case "$1" in
    duo-outer|duo-inner) return 0 ;;
    *) return 1 ;;
  esac
}

# 画面を撮った画像にホームインジケーターが写っているかを返す関数 (0 = 写っている)。
# simctl と XCTest のスクリーンショットはどちらもシステムのオーバーレイを含み、persistentSystemOverlays(.hidden) は
# 「自動で消えてよい」の許可に過ぎないため、撮った時点でまだ残っていることがある (本 PR の本番生成で 24 枚中 9 枚に写った実測)。
# 判定は、インジケーターが描かれる位置 (画面下端の中央。外側・内側とも下端から 25〜39px の 15px 厚の帯。本 PR の生成物の画素で実測) の
# 中央から左に 220〜100px の 120×10px の小片と、その 20px 上の同じ大きさの小片の RMSE (0〜1 の正規化値) で行う。
# 無い時は両方が同じ背景・端末フレーム・ボタンの中身になって差が 0 になる
# (実測: 無し 0、有り 0.1〜0.2。しきい値 0.01 はその中間で、ノイズの無い PNG では 0 と明確に分かれる)。
# 小片を中央の左に寄せるのは、外側の最下部にボタン (夜の振り返りの「やれた」。下端から 17〜83px、中央に文字) が来るページで
# 文字を避けてボタンの地同士を比べるため。この位置はインジケーター (外側は中央 ±250px、内側は ±370px) の中にあり、
# 内側では端末フレーム (中央 +107px から右) にかからず背景だけになる
# Usage: has_home_indicator <png>
has_home_indicator() {
  local png=$1
  local width height strip_dir
  width=$(magick identify -format "%w" "$png")
  height=$(magick identify -format "%h" "$png")
  strip_dir=$(mktemp -d)
  magick "$png" -crop "120x10+$((width / 2 - 220))+$((height - 37))" +repage "$strip_dir/bottom.png"
  magick "$png" -crop "120x10+$((width / 2 - 220))+$((height - 57))" +repage "$strip_dir/above.png"
  # compare は差があると exit 1 を返すため、終了コードではなく出力 "<絶対値> (<正規化値>)" の正規化値で判定する
  local metric
  metric=$(magick compare -metric RMSE "$strip_dir/bottom.png" "$strip_dir/above.png" null: 2>&1 || true)
  rm -rf "$strip_dir"
  metric=${metric#*(}
  metric=${metric%)*}
  awk -v metric="$metric" 'BEGIN { exit !(metric > 0.01) }'
}

# デバイス区分の適用先ディレクトリを返す関数。
# iPhone Duo の画像は fastlane deliver が受け付けない寸法のため、deliver が読む fastlane/screenshots/ には置かず、
# 別の場所に置いて App Store Connect へは手 (Web UI) か asc で上げる (scripts/generate_screenshots/README.md)
# Usage: get_apply_destination_dir <69|65|duo-outer|duo-inner>
get_apply_destination_dir() {
  case "$1" in
    duo-outer|duo-inner) echo "appstore/iphone-duo-screenshots" ;;
    *) echo "fastlane/screenshots" ;;
  esac
}

# 現在の撮影デバイスを設定し、依存する環境変数 (表示サイズ名・デバイスタイプ・OS・DESTINATION) を更新する関数。
# シミュレータ名は DESTINATION_SIM_NAME で上書きできる。
# 複数の worktree / セッションが同時にスクショ生成すると、同名シミュレータの
# 奪い合いで UITest が互いのアプリを落とし合うため、専用名を渡して分離する
# (専用名は 1 機種分にしか付けられないため、渡す時は generate の -d で 1 機種に絞る。
# duo-outer と duo-inner は同じ機種 iPhone Duo の姿勢違いなので、一緒に指定できる)。
# Usage: configure_screenshot_device <69|65|duo-outer|duo-inner>
configure_screenshot_device() {
  export SCREENSHOT_DEVICE="$1"
  SCREENSHOT_DISPLAY_TYPE=$(get_display_type "$SCREENSHOT_DEVICE") || return 1
  export SCREENSHOT_DISPLAY_TYPE
  SCREENSHOT_DEVICE_TYPE=$(get_device_type_name "$SCREENSHOT_DEVICE") || return 1
  export SCREENSHOT_DEVICE_TYPE
  SCREENSHOT_DEVICE_OS_VERSION=$(get_device_os_version "$SCREENSHOT_DEVICE")
  export SCREENSHOT_DEVICE_OS_VERSION
  # simulator_common.sh の自動作成が使うデバイスタイプ (専用名のシミュレータでも正しい機種で作る)
  export DESTINATION_SIM_DEVICE_TYPE="$SCREENSHOT_DEVICE_TYPE"
  export DESTINATION_SIM_RESOLVED_NAME="${DESTINATION_SIM_NAME:-$SCREENSHOT_DEVICE_TYPE}"
  export DESTINATION="platform=iOS Simulator,name=${DESTINATION_SIM_RESOLVED_NAME},OS=${SCREENSHOT_DEVICE_OS_VERSION}"
}

# 既定は 6.9 インチ。generate がデバイスごとに configure_screenshot_device を呼び直し、
# 子スクリプト (run / organize) は export 済みの SCREENSHOT_DEVICE を引き継ぐ
configure_screenshot_device "${SCREENSHOT_DEVICE:-69}" || return 1

# テストファイルパスからテスト実行パスとartifactパスを取得する共通関数
# Usage: get_test_info <test_file_path>
# Returns: TEST_PATH ARTIFACT_PATH (space separated)
get_test_info() {
  local test_file=$1
  local filename=$(basename "$test_file" .swift)
  local test_path="AppStoreScreenshotsUITests/${filename}/testSnapshot"
  local artifact_path="artifacts/appstore_screenshots/${filename}/testSnapshot"
  echo "$test_path $artifact_path"
}

# BCP47言語コードをfastlane用ディレクトリ名にマッピングする関数
# fastlane/metadata/ のディレクトリ構成 (ja / en-US) と揃える
map_language_to_fastlane() {
  local lang=$1
  case "$lang" in
    "en") echo "en-US" ;;
    *) echo "$lang" ;;
  esac
}

# スクリーンショット番号からバリアント名を取得する関数
# 1-6: ink (静かな世界観そのままの墨背景)
# 7-12: washi (温白地に墨の太字見出し。ストア一覧での視認性重視)
# 13-18: dawn (墨背景 + 夜明けグラデーション強め + 太字見出し)
# 19-24: kumo (明るい雲色の地 + 左揃え太字見出し + ブランドラベル。stoic. 型)
# 25-30: kohaku (夜明け色のベタ地 + 墨の太字見出し。5 Minute Journal 型)
# 31-36: bold (墨背景 + 極太・左揃え見出し。Alarmy 型)
# 37-42: hero (1 枚目のクリエイティブ案の比較バンド。fastlane へは適用しない)
# 訴求軸のバリアントを追加する時は 6 枚単位で番号帯を割り当てる (43-48: 次のバリアント、...)
get_variant_name() {
  local num=$1
  case $(( (num - 1) / 6 )) in
    0) echo "ink" ;;
    1) echo "washi" ;;
    2) echo "dawn" ;;
    3) echo "kumo" ;;
    4) echo "kohaku" ;;
    5) echo "bold" ;;
    6) echo "hero" ;;
    *) echo "unknown" ;;
  esac
}

# スクリーンショット番号からバリアント内インデックス(0-5)を取得する関数
get_variant_index() {
  local num=$1
  echo $(( (num - 1) % 6 ))
}
