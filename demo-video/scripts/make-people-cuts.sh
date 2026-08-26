#!/usr/bin/env bash
set -euo pipefail

# people バリアント (issue #141) の人物カット 4 本を morning-question.raw.mp4 から作る。
# 疑似録画中の画面 (録画タイマー進行中・問いのオーバーレイ表示中) から人物ごとに別の
# 時間窓を切り出し、人物別の口パクループを lighten 合成する (合成手法は
# enhance-morning-question.sh と同じ: 白い UI 文字は lighten で必ず画像より明るく残り、
# 画像側は colorlevels で輝度上限を制限して問いテキストを立たせる)。
# 時間窓を人物ごとにずらすのは、録画タイマーが 0:00 → 0:02 → 0:03 → 0:05 と進んで見え、
# 「別々の人が同じ朝に答えている」連続感が出るため。
#
# 使い方: record-scene.sh で morning-question を録画した後に実行する。
#   bash demo-video/scripts/make-people-cuts.sh
# 初回実行時に clips/morning-question.mp4 を clips/morning-question.raw.mp4 へ退避し、
# 以降は raw から毎回作り直す (何度実行しても同じ出力になる冪等な加工)。
#
# REC_START は 2026-08-27 収録クリップのフレーム実測値。再録画してタイミングが変わったら
# enhance-morning-question.sh ヘッダーの実測手順 (fps=1 のコンタクトシート) で測り直す

cd "$(dirname "$0")/../.."

CLIP=demo-video/output/clips/morning-question.mp4
RAW=demo-video/output/clips/morning-question.raw.mp4
ASSETS=demo-video/assets
WORK=demo-video/output/work-people
CLIP_DIR=demo-video/output/clips

PEOPLE="worker student parent creator"

[[ -f "$CLIP" || -f "$RAW" ]] || { echo "ERROR: $CLIP がありません (record-scene.sh で録画してから実行)" >&2; exit 1; }
for person in $PEOPLE; do
    for img in "person-$person.png" "person-$person-talk-1.png" "person-$person-talk-2.png" "person-$person-talk-3.png"; do
        [[ -f "$ASSETS/$img" ]] || { echo "ERROR: $ASSETS/$img がありません" >&2; exit 1; }
    done
done

# 初回だけ raw へ退避し、以降は raw を入力にする (冪等)
[[ -f "$RAW" ]] || mv "$CLIP" "$RAW"

# 録画開始 (録画タイマー 0:00/0:10 の出現)。2026-08-27 収録クリップのフレーム実測。
# 実測は本スクリプトと同じ CFR 化経路 (fps=30 を先に通す) で行うこと: -ss での seek や
# 別の fps 値だと VFR の保持フレームの実体化位置がずれ、±1s 級の誤差が出る (実測)。
# 今回の実測: タイマー 0:00 出現 7.3s、0:10 表示 17.3s、停止遷移 (Try saving again) 17.4s
REC_START=7.3
# 1 カットの長さ (config の target_duration の最大値以上にする)
CUT_LEN=4.5
# 人物ごとの切り出しオフセット (REC_START からの秒)。録画はアプリ上限の 10 秒で
# 自動停止するため、最終窓 5.4+4.5=9.9 が停止遷移 (10.1s 後) の直前に収まる
offset_for() {
    case "$1" in
        worker) echo 0 ;;
        student) echo 2 ;;
        parent) echo 3.5 ;;
        creator) echo 5.4 ;;
    esac
}

# 人物画像は raw の実解像度に合わせて scale する (シミュレータ機種変更に追従)
read -r RAW_W RAW_H < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$RAW" | tr ',' ' ')

rm -rf "$WORK"
mkdir -p "$WORK"
ABS_ASSETS="$(cd "$ASSETS" && pwd)"

for person in $PEOPLE; do
    # 口パクループ (enhance-morning-question.sh と同じ 4 段階・不均等間隔・1 周約 1.6s)
    SEQ="$WORK/talk-$person.txt"
    cat >"$SEQ" <<EOF
file '$ABS_ASSETS/person-$person.png'
duration 0.30
file '$ABS_ASSETS/person-$person-talk-3.png'
duration 0.20
file '$ABS_ASSETS/person-$person-talk-1.png'
duration 0.24
file '$ABS_ASSETS/person-$person-talk-2.png'
duration 0.26
file '$ABS_ASSETS/person-$person-talk-1.png'
duration 0.20
file '$ABS_ASSETS/person-$person-talk-3.png'
duration 0.20
file '$ABS_ASSETS/person-$person-talk-1.png'
duration 0.22
file '$ABS_ASSETS/person-$person.png'
EOF
    LOOP="$WORK/talk-$person.mp4"
    ffmpeg -nostdin -y -v error \
        -f concat -safe 0 -i "$SEQ" \
        -vf "scale=${RAW_W}:${RAW_H},setsar=1,colorlevels=romax=0.72:gomax=0.72:bomax=0.72,fps=30" \
        -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
        "$LOOP"

    # 収録クリップは可変フレームレートのため、先に fps で CFR 化してから秒指定で trim する
    # (compose-video.sh と同じ理由)
    START=$(awk -v r="$REC_START" -v o="$(offset_for "$person")" 'BEGIN { print r + o }')
    echo "--- 人物カット: $person (raw ${START}s から ${CUT_LEN}s)"
    ffmpeg -nostdin -y -v error \
        -i "$RAW" \
        -stream_loop -1 -i "$LOOP" \
        -filter_complex "\
[0:v]fps=30,trim=start=${START}:duration=${CUT_LEN},setpts=PTS-STARTPTS[win];\
[win][1:v]blend=all_mode=lighten:shortest=1[out]" \
        -map "[out]" -an \
        -c:v libx264 -pix_fmt yuv420p -preset medium -crf 18 \
        "$CLIP_DIR/person-$person.mp4"
done

echo "--- 生成完了: $CLIP_DIR/person-{worker,student,parent,creator}.mp4"
