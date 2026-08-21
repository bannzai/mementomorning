#!/usr/bin/env bash
set -euo pipefail

# デモ動画のナレーション (TTS) を生成し、BGM と 1 本にミックスする (issue #94 のデモ動画レビュー対応)。
#
# 1. config.json の title_card と各シーンの字幕文を Gemini TTS (gemini-2.5-flash-preview-tts) で
#    読み上げ音声にする。Gemini API が使えない場合は macOS say (英語ボイス) にフォールバックする
# 2. 各ナレーションを動画タイムライン上のシーン開始 + 0.3s の位置に配置し、
#    BGM (assets/bgm.m4a: Erik Satie - Gymnopedie No.1、Robin Alciatore 演奏、パブリックドメイン。
#    出典 https://commons.wikimedia.org/wiki/File:Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg )
#    を小音量で敷いた 1 本のオーディオ (output/narration/bgm-mix.m4a) に合成する
# 3. config.json の bgm.file がこのミックスを指しているので、続けて compose-video.sh を実行すると
#    動画に載る
#
# 使い方 (compose-video.sh の前に実行する):
#   bash demo-video/scripts/generate-narration.sh
#
# 必要環境: GEMINI_API_KEY (未設定なら say フォールバック)、ffmpeg、jq、curl
#
# 冪等性: 実行のたびに全ナレーションを再生成して同じ構成のミックスを作り直す。
# TTS の音声波形は生成のたびに揺らぐ (エンジン仕様) が、話者・文面・配置は決定的

cd "$(dirname "$0")/../.."

CONFIG=demo-video/config.json
BGM=demo-video/assets/bgm.m4a
OUT_DIR=demo-video/output/narration
MIX="$OUT_DIR/bgm-mix.m4a"

# ナレーションの音量に対する BGM のゲイン。実測 (TTS mean -21dB / BGM mean -29dB) で
# BGM がナレーションより約 17dB 下がる値
BGM_GAIN=0.35
# シーン開始からナレーション開始までの間 (秒)
LEAD_IN=0.3
VOICE=Charon
STYLE_PROMPT="Speak in a calm, quiet, contemplative tone:"

[[ -f "$CONFIG" ]] || { echo "ERROR: $CONFIG がありません" >&2; exit 1; }
[[ -f "$BGM" ]] || { echo "ERROR: $BGM がありません" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq が必要です" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg が必要です" >&2; exit 1; }

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# --- 1 文を TTS して wav にする。Gemini 失敗時は say にフォールバック ---
tts_line() {
    local text="$1" wav="$2"
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        local req="$OUT_DIR/req.json" res="$OUT_DIR/res.json"
        jq -n --arg t "$STYLE_PROMPT $text" --arg v "$VOICE" '{
            contents: [{parts: [{text: $t}]}],
            generationConfig: {
                responseModalities: ["AUDIO"],
                speechConfig: {voiceConfig: {prebuiltVoiceConfig: {voiceName: $v}}}
            }
        }' >"$req"
        if curl -sS -X POST \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent" \
            -H "x-goog-api-key: $GEMINI_API_KEY" -H "Content-Type: application/json" \
            -d @"$req" >"$res" \
            && [[ "$(jq -r '.candidates[0].content.parts[0].inlineData.data // ""' "$res")" != "" ]]; then
            jq -r '.candidates[0].content.parts[0].inlineData.data' "$res" | base64 -d >"$OUT_DIR/line.pcm"
            ffmpeg -y -v error -f s16le -ar 24000 -ac 1 -i "$OUT_DIR/line.pcm" "$wav"
            return 0
        fi
        echo "警告: Gemini TTS に失敗したため say にフォールバックします: $text" >&2
        [[ -f "$res" ]] && jq -r '.error.message // empty' "$res" >&2
    fi
    command -v say >/dev/null || { echo "ERROR: GEMINI_API_KEY も say も使えません" >&2; exit 1; }
    say -v Ava -o "$OUT_DIR/line.aiff" "$text"
    ffmpeg -y -v error -i "$OUT_DIR/line.aiff" -ar 24000 -ac 1 "$wav"
}

# --- 読み上げ対象と配置位置を config から組み立てる ---
# タイトルカードはアプリ名だけを読む (subtext まで読むと 3 秒のカードに収まらない)
TITLE_DURATION=$(jq -r '.title_card.duration // 0' "$CONFIG")
LINES_TEXT=()
LINES_START=()
LINES_BUDGET=()
if [[ "$TITLE_DURATION" != "0" ]]; then
    LINES_TEXT+=("$(jq -r '.title_card.text' "$CONFIG").")
    LINES_START+=(0)
    LINES_BUDGET+=("$TITLE_DURATION")
fi

OFFSET="$TITLE_DURATION"
SCENE_COUNT=$(jq -r '.scenes | length' "$CONFIG")
for i in $(seq 0 $((SCENE_COUNT - 1))); do
    SUBTITLE=$(jq -r ".scenes[$i].subtitle // \"\"" "$CONFIG")
    TARGET=$(jq -r ".scenes[$i].target_duration // \"\"" "$CONFIG")
    [[ -n "$TARGET" ]] || { echo "ERROR: scenes[$i] に target_duration がありません (ナレーション配置に必要)" >&2; exit 1; }
    if [[ -n "$SUBTITLE" ]]; then
        LINES_TEXT+=("$SUBTITLE")
        LINES_START+=("$OFFSET")
        LINES_BUDGET+=("$TARGET")
    fi
    OFFSET=$(awk -v a="$OFFSET" -v b="$TARGET" 'BEGIN { print a + b }')
done
TOTAL="$OFFSET"

# --- 各行を TTS し、シーン尺に収まるか確認する ---
INPUTS=(-i "$BGM")
FILTERS=""
MIX_LABELS="[bgm]"
for idx in "${!LINES_TEXT[@]}"; do
    WAV="$OUT_DIR/line-$idx.wav"
    echo "--- TTS [$((idx + 1))/${#LINES_TEXT[@]}]: ${LINES_TEXT[$idx]}"
    tts_line "${LINES_TEXT[$idx]}" "$WAV"
    DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$WAV")
    if awk -v d="$DUR" -v lead="$LEAD_IN" -v budget="${LINES_BUDGET[$idx]}" 'BEGIN { exit !(lead + d > budget) }'; then
        echo "警告: ナレーション ${idx} (${DUR}s) がシーン尺 ${LINES_BUDGET[$idx]}s に収まっていません (次のシーンへ食み出します)" >&2
    fi
    DELAY_MS=$(awk -v s="${LINES_START[$idx]}" -v lead="$LEAD_IN" 'BEGIN { printf "%d", (s + lead) * 1000 }')
    INPUTS+=(-i "$WAV")
    FILTERS="${FILTERS}[$((idx + 1)):a]adelay=${DELAY_MS}:all=1[n$idx];"
    MIX_LABELS="${MIX_LABELS}[n$idx]"
done

# --- BGM を小音量で敷いてミックスし、動画尺で打ち切る ---
echo "--- ミックス: $MIX (${TOTAL}s, BGM gain=$BGM_GAIN)"
ffmpeg -y -v error \
    "${INPUTS[@]}" \
    -filter_complex "\
[0:a]volume=${BGM_GAIN}[bgm];\
${FILTERS}\
${MIX_LABELS}amix=inputs=$((${#LINES_TEXT[@]} + 1)):duration=longest:normalize=0[mix];\
[mix]atrim=0:${TOTAL},asetpts=PTS-STARTPTS[out]" \
    -map "[out]" -c:a aac -b:a 256k \
    "$MIX"

echo "--- 生成完了: $MIX ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MIX")s)"
