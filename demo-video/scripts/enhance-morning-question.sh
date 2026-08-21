#!/usr/bin/env bash
set -euo pipefail

# 朝の問いシーンのクリップを演出加工する (issue #94 のデモ動画レビュー対応):
# 1. カメラ画面の区間に assets/selfie*.png (Nano Banana Pro で生成した寝起きセルフィー。
#    口の開きだけ違う 4 枚を image-to-image で揃えた) を短い間隔で切り替えながら
#    lighten 合成し、インカメラで喋りながら回答している実機の見た目を再現する
#    (疑似録画モードはプレビューが墨色のままでカメラ感が出ないため。白い UI 文字は
#    lighten で必ず画像より明るく残るので可読性は保たれる)
# 2. 録画停止直後に一瞬表示される「Try saving again」(保存は成功しているのにエラー UI が
#    約 1 秒出る。2 回の収録で再現) の区間を切り落とす
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
ASSETS=demo-video/assets
WORK=demo-video/output/work-enhance

[[ -f "$CLIP" || -f "$RAW" ]] || { echo "ERROR: $CLIP がありません (record-scene.sh で録画してから実行)" >&2; exit 1; }
for img in selfie.png selfie-talk-1.png selfie-talk-2.png selfie-talk-3.png; do
    [[ -f "$ASSETS/$img" ]] || { echo "ERROR: $ASSETS/$img がありません" >&2; exit 1; }
done

# 初回だけ raw へ退避し、以降は raw を入力にする (冪等)
[[ -f "$RAW" ]] || mv "$CLIP" "$RAW"

# カメラ画面の区間 (起動アニメ後〜録画停止直前)。フレーム実測: 3.0〜15.9s
CAMERA_START=3.0
CAMERA_END=15.9
# 「Try saving again」が映る区間 (停止〜ホーム遷移)。フレーム実測: 15.9〜16.95s
CUT_START=15.9
CUT_END=16.95

rm -rf "$WORK"
mkdir -p "$WORK"

# --- 口パクループ動画を作る ---
# 口の開き: selfie.png (閉) → talk-3 (わずか) → talk-1 (半開) → talk-2 (大) の 4 段階を
# 不均等な間隔で往復させ、機械的な点滅に見えないようにする (1 周 約 1.6s)
ABS_ASSETS="$(cd "$ASSETS" && pwd)"
SEQ="$WORK/talk-sequence.txt"
cat >"$SEQ" <<EOF
file '$ABS_ASSETS/selfie.png'
duration 0.30
file '$ABS_ASSETS/selfie-talk-3.png'
duration 0.20
file '$ABS_ASSETS/selfie-talk-1.png'
duration 0.24
file '$ABS_ASSETS/selfie-talk-2.png'
duration 0.26
file '$ABS_ASSETS/selfie-talk-1.png'
duration 0.20
file '$ABS_ASSETS/selfie-talk-3.png'
duration 0.20
file '$ABS_ASSETS/selfie-talk-1.png'
duration 0.22
file '$ABS_ASSETS/selfie.png'
EOF

TALK_LOOP="$WORK/talk-loop.mp4"
ffmpeg -y -v error \
    -f concat -safe 0 -i "$SEQ" \
    -vf "scale=1206:2622,setsar=1,colorlevels=romax=0.72:gomax=0.72:bomax=0.72,fps=30" \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
    "$TALK_LOOP"

# --- カメラ区間に口パクループを lighten 合成し、「Try saving again」区間をカットする ---
ffmpeg -y -v error \
    -i "$RAW" \
    -stream_loop -1 -i "$TALK_LOOP" \
    -filter_complex "\
[0:v]fps=30[base];\
[base][1:v]blend=all_mode=lighten:enable='between(t,${CAMERA_START},${CAMERA_END})':shortest=1[cam];\
[cam]select='not(between(t,${CUT_START},${CUT_END}))',setpts=N/30/TB[out]" \
    -map "[out]" -an \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
    "$CLIP"

echo "--- 加工完了: $CLIP ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$CLIP")s)"
