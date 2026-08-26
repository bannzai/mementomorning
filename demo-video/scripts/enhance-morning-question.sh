#!/usr/bin/env bash
set -euo pipefail

# 朝の問いシーンのクリップを演出加工する (issue #94 のデモ動画レビュー対応):
# 1. カメラ画面の区間に assets/selfie*.png (Nano Banana Pro で生成した寝起きセルフィー。
#    口の開きだけ違う 4 枚を image-to-image で揃えた) を lighten 合成し、インカメラで
#    回答している実機の見た目を再現する (疑似録画モードはプレビューが墨色のままで
#    カメラ感が出ないため。白い UI 文字は lighten で必ず画像より明るく残るので可読性は保たれる)。
#    録画開始前は口を閉じた 1 枚で静止させ、録画開始後だけ口パク (短い間隔の切り替え) にする
# 2. 録画停止直後に一瞬表示される「Try saving again」(保存は成功しているのにエラー UI が
#    約 1 秒出る。2 回の収録で再現) の区間を切り落とす
#
# 使い方: record-scene.sh で morning-question を録画した直後に実行する。
#   bash demo-video/scripts/enhance-morning-question.sh
# 元の録画は clips/morning-question.raw.mp4 に退避され、2 回目以降は退避済みの raw から
# 作り直す (何度実行しても同じ出力になる冪等な加工)。
#
# 各時刻・座標は 2026-08-26 収録のクリップ (28.15s, 1206x2622) のフレーム実測値。
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

# カメラ画面の区間 (起動アニメ後〜録画停止直前)。フレーム実測: 3.5〜18.4s
# (開始は問いのテキスト初出 3.3s ではなく、画面が入り切る 3.5s。入り切る前にセルフィーを重ねると破綻するため)
CAMERA_START=3.5
CAMERA_END=18.4
# 録画開始 (録画タイマー 0:00/0:10 の出現)。フレーム実測: 7.1s。ここまでは静止、ここから口パク
TALK_START=7.1
# 「Try saving again」が映る区間 (停止〜ホーム遷移)。フレーム実測: 18.4〜19.8s
CUT_START=18.4
CUT_END=19.8

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

# --- カメラ区間にセルフィーを lighten 合成し、「Try saving again」区間をカットする ---
# 録画開始前 (CAMERA_START〜TALK_START) は口を閉じた静止画、録画開始後 (TALK_START〜CAMERA_END) は
# 口パクループを合成する
ffmpeg -y -v error \
    -i "$RAW" \
    -stream_loop -1 -i "$TALK_LOOP" \
    -loop 1 -i "$ASSETS/selfie.png" \
    -filter_complex "\
[0:v]fps=30[base];\
[2:v]scale=1206:2622,setsar=1,colorlevels=romax=0.72:gomax=0.72:bomax=0.72[still];\
[base][still]blend=all_mode=lighten:enable='between(t,${CAMERA_START},${TALK_START})':shortest=1[pre];\
[pre][1:v]blend=all_mode=lighten:enable='between(t,${TALK_START},${CAMERA_END})':shortest=1[cam];\
[cam]select='not(between(t,${CUT_START},${CUT_END}))',setpts=N/30/TB[out]" \
    -map "[out]" -an \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
    "$CLIP"

echo "--- 加工完了: $CLIP ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$CLIP")s)"
