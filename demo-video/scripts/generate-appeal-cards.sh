#!/usr/bin/env bash
set -euo pipefail

# デモ動画の訴求カット (黒背景 + 白文字のテキストカード) のクリップを ffmpeg で生成する
# (issue #94 フィードバック第 4 弾:「なぜこのアプリを使うと良いのか」の訴求要素)。
#
# Maestro で収録するアプリ画面ではないため record-scene.sh は使わず、本スクリプトが
# output/clips/<id>.mp4 を直接生成して compose-video.sh の通常シーンとして扱わせる
# (flows/why-*.yaml は validate-config.sh のシーン検証を通すためのプレースホルダ)。
#
# フック文言 3 パターン (実名を出すかの比較用。config.json / config.variant-*.json が各 1 つを参照):
#   why-founder   ぼかし表現 (A famous founder)
#   why-jobs      実名 (Steve Jobs)
#   why-no-person 人物に触れない (朝の目覚め方の効用)
# 価値説明 1 枚 (全パターン共通):
#   why-value     朝に目標を確認する効用 (有意義なスタート・二度寝防止)
# フックと alarm の間のワンクッション (issue #94 フィードバック第 6 弾。習慣の効用を語る):
#   why-jobs-legacy  その習慣が毎日を意味あるものにした
# 日本語版 (config.variant-upbeat-ja.json が参照する -ja サフィックスの 3 枚):
#   why-jobs-ja / why-jobs-legacy-ja / why-value-ja
# 安全版 (config.variant-upbeat-founder.json が参照。実名・肖像を使わない Shipaton 提出用の保険。
# 肖像も外すのは、パブリシティ権が氏名だけでなく肖像にも及び、線画でも人物が特定できるため):
#   why-founder-safe / why-founder-legacy
#
# 使い方 (compose-video.sh の前に実行する):
#   bash demo-video/scripts/generate-appeal-cards.sh
#
# 冪等性: 実行のたびに全カードを同じ内容で作り直す (出力は上書き)

cd "$(dirname "$0")/../.."

command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg が必要です" >&2; exit 1; }

CLIP_DIR=demo-video/output/clips
mkdir -p "$CLIP_DIR"

# compose-video.sh のプロファイル (demo-portrait) と揃える
WIDTH=1080
HEIGHT=1920
FPS=30
# クリップ尺。config の target_duration より長ければよい (compose が切り詰める)
DURATION=8

FONT=""
for candidate in \
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" \
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"; do
    [[ -f "$candidate" ]] && { FONT="$candidate"; break; }
done
[[ -n "$FONT" ]] || { echo "ERROR: drawtext 用フォントが見つかりません" >&2; exit 1; }

# フックカードに載せる肖像イラスト (assets/founder-portrait.png)。実写・実名画像ではなく
# Nano Banana Pro で生成した線画で「わかる程度」に留める (採用判断の経緯は PR #95 コメント参照)
PORTRAIT=demo-video/assets/founder-portrait.png

# id|1 行目|2 行目|肖像を載せるか (portrait / 空)
CARDS='why-founder|A famous founder asked himself|one question, every morning.|portrait
why-jobs|Steve Jobs asked himself|one question, every morning.|portrait
why-jobs-legacy|That one habit|made every day count.|portrait
why-no-person|How you wake|decides how you live the day.|
why-value|Wake to a goal.|A reason to rise, not to snooze.|
why-jobs-ja|スティーブ・ジョブズは毎朝、|自分にひとつの質問をしていた。|portrait
why-jobs-legacy-ja|そのひとつの習慣が、|毎日を意味あるものにした。|portrait
why-value-ja|目標とともに、目覚める。|二度寝ではなく、起きる理由を。|
why-founder-safe|A famous founder asked himself|one question, every morning.|
why-founder-legacy|That one habit|made every day count.|'

# タイトルカード (compose-video.sh の card-main/card-sub) と同じ見た目に寄せる:
# 黒背景に白文字・中央寄せ。drawtext の複数行は左寄せになるため 1 行ずつ中央に描く。
# fontsize は最長行が画面幅 92% に収まるように縮小する (compose-video.sh の
# ラテン文字係数 62% と同じ近似。カード文言は英語のみの前提)
while IFS='|' read -r id line1 line2 with_portrait; do
    [[ -n "$id" ]] || continue
    if [[ "$with_portrait" == "portrait" && ! -f "$PORTRAIT" ]]; then
        echo "ERROR: $PORTRAIT がありません" >&2
        exit 1
    fi

    # 全角 (CJK) を含む行は等幅 100%、ラテンのみは 62% で幅を見積もる
    # (compose-video.sh の glyph_ratio と同じ近似。マルチバイト判定は bytes > chars)
    max_chars=0
    glyph_ratio=62
    for line in "$line1" "$line2"; do
        chars=$(printf '%s' "$line" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')
        bytes=$(printf '%s' "$line" | LC_ALL=C wc -c | tr -d ' ')
        (( bytes > chars )) && glyph_ratio=100
        (( chars > max_chars )) && max_chars=$chars
    done
    fontsize=$((HEIGHT / 16))
    max_width=$((WIDTH * 92 / 100))
    if (( max_chars * fontsize * glyph_ratio / 100 > max_width )); then
        fontsize=$((max_width * 100 / (max_chars * glyph_ratio)))
    fi

    # 肖像ありのカードは肖像を上寄せ中央に置き、テキストをその下に配置する。
    # 肖像なしのカードは従来どおりテキストを画面中央に置く
    if [[ "$with_portrait" == "portrait" ]]; then
        y1="1280-${fontsize}"
        y2="1280+${fontsize}"
    else
        y1="(h-text_h)/2-${fontsize}"
        y2="(h-text_h)/2+${fontsize}"
    fi
    mkdir -p demo-video/output/work
    t1=demo-video/output/work/appeal-$id-1.txt
    t2=demo-video/output/work/appeal-$id-2.txt
    printf '%s' "$line1" >"$t1"
    printf '%s' "$line2" >"$t2"

    draw="drawtext=fontfile='$FONT':textfile='$t1':expansion=none:fontsize=$fontsize:fontcolor=white:x=(w-text_w)/2:y=$y1"
    draw="$draw,drawtext=fontfile='$FONT':textfile='$t2':expansion=none:fontsize=$fontsize:fontcolor=white:x=(w-text_w)/2:y=$y2"

    echo "--- カード生成: $id (fontsize=$fontsize${with_portrait:+, portrait})"
    if [[ "$with_portrait" == "portrait" ]]; then
        # colorlevels は肖像画像の背景 (実測 RGB 約 21/255 ≒ 0.08) をカードの純黒に潰し、
        # 画像の矩形の縁が見えないようにするため
        ffmpeg -y -v error \
            -f lavfi -i "color=c=black:s=${WIDTH}x${HEIGHT}:d=${DURATION}:r=${FPS}" \
            -i "$PORTRAIT" \
            -filter_complex "[1:v]scale=640:-1,colorlevels=rimin=0.12:gimin=0.12:bimin=0.12[p];[0:v][p]overlay=x=(W-w)/2:y=330[bg];[bg]$draw" \
            -c:v libx264 -pix_fmt yuv420p -an \
            "$CLIP_DIR/$id.mp4"
    else
        ffmpeg -y -v error \
            -f lavfi -i "color=c=black:s=${WIDTH}x${HEIGHT}:d=${DURATION}:r=${FPS}" \
            -vf "$draw" \
            -c:v libx264 -pix_fmt yuv420p -an \
            "$CLIP_DIR/$id.mp4"
    fi
done <<<"$CARDS"

echo "--- 生成完了: $CLIP_DIR/why-*.mp4"
