#!/usr/bin/env bash
set -euo pipefail

# 朝の問いシーンのクリップを演出加工する (issue #94 のデモ動画レビュー対応):
# 1. カメラ画面の区間に assets/selfie.png (Nano Banana Pro で生成した寝起きセルフィー) を
#    lighten 合成し、インカメラのプレビューに問いがオーバーレイされた実機の見た目を再現する
#    (疑似録画モードはプレビューが墨色のままでカメラ感が出ないため。白い UI 文字は
#    lighten で必ず画像より明るく残るので可読性は保たれる)
# 2. 録画停止直後に一瞬表示される「Try saving again」(保存は成功しているのにエラー UI が
#    約 1 秒出る。2 回の収録で再現) の区間を切り落とす
# 3. ホーム反映後の回答テキスト「Answered with a video」に赤い下線を出し、目線を誘導する
#
# 使い方: record-scene.sh で morning-question を録画した直後に実行する。
#   bash demo-video/scripts/enhance-morning-question.sh
# 元の録画は clips/morning-question.raw.mp4 に退避され、2 回目以降は退避済みの raw から
# 作り直す (何度実行しても同じ出力になる冪等な加工)。
#
# 各時刻・座標は 2026-08-21 収録のクリップ (22.2s, 1206x2622) のフレーム実測値。
# 再録画してタイミングが変わったら、コメントの実測手順 (fps=1 のコンタクトシート) で測り直す

cd "$(dirname "$0")/../.."

CLIP=demo-video/output/clips/morning-question.mp4
RAW=demo-video/output/clips/morning-question.raw.mp4
SELFIE=demo-video/assets/selfie.png

[[ -f "$CLIP" || -f "$RAW" ]] || { echo "ERROR: $CLIP がありません (record-scene.sh で録画してから実行)" >&2; exit 1; }
[[ -f "$SELFIE" ]] || { echo "ERROR: $SELFIE がありません" >&2; exit 1; }

# 初回だけ raw へ退避し、以降は raw を入力にする (冪等)
[[ -f "$RAW" ]] || mv "$CLIP" "$RAW"

# カメラ画面の区間 (起動アニメ後〜録画停止直前)。フレーム実測: 3.0〜15.9s
CAMERA_START=3.0
CAMERA_END=15.9
# 「Try saving again」が映る区間 (停止〜ホーム遷移)。フレーム実測: 15.9〜16.95s
CUT_START=15.9
CUT_END=16.95
# 赤下線: "Answered with a video" (原寸 x 329-874, y 1582-1630 の実測) の直下。
# カット後のタイムラインでホーム表示 (15.9s) の 1 秒後に出す
UNDERLINE_ENABLE=16.9

ffmpeg -y -v error \
    -i "$RAW" \
    -loop 1 -i "$SELFIE" \
    -filter_complex "\
[0:v]fps=30[base];\
[1:v]scale=1206:2622,setsar=1,colorlevels=romax=0.72:gomax=0.72:bomax=0.72[selfie];\
[base][selfie]blend=all_mode=lighten:enable='between(t,${CAMERA_START},${CAMERA_END})':shortest=1[cam];\
[cam]select='not(between(t,${CUT_START},${CUT_END}))',setpts=N/30/TB[cutv];\
[cutv]drawbox=x=320:y=1648:w=564:h=8:color=0xB03A2E@0.9:t=fill:enable='gte(t,${UNDERLINE_ENABLE})'[out]" \
    -map "[out]" -an \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
    "$CLIP"

echo "--- 加工完了: $CLIP ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$CLIP")s)"
