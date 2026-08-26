#!/usr/bin/env bash
set -euo pipefail

# people バリアント (issue #141) の登場人物セルフィー assets/person-*.png を生成する。
# base 4 枚は text-to-image、talk 3 枚は base を入力にした image-to-image
# (既存の selfie.png / selfie-talk-*.png と同じ作り方。口の開き 3 段階:
#  talk-3=わずか, talk-1=半開, talk-2=大。make-people-cuts.sh の口パク並び順に合わせる)
#
# 使い方: bash demo-video/scripts/generate-people-assets.sh <bases|talks|all> [person...]
#   person 省略時は worker student parent creator の全員
#
# 必要環境: GEMINI_API_KEY と gemini-image-generator skill (venv 済み)。
# 生成画像はコミット済みのため、人物やプロンプトを変えたい時だけ実行すればよい
#
# 冪等性: 実行のたびに対象画像を作り直す (上書き)。生成 AI の出力は毎回揺らぐため
# ピクセル一致はしないが、同じプロンプト・同じ構図の画像に置き換わる

cd "$(dirname "$0")/../.."

GEN=~/.claude/skills/gemini-image-generator/scripts/generate_image.sh
I2I_PY=~/.claude/skills/gemini-image-generator/.venv/bin/python3
I2I=demo-video/scripts/generate-talk-variant.py
ASSETS=demo-video/assets

MODE="${1:-all}"
shift || true
PERSONS=("$@")
[[ ${#PERSONS[@]} -gt 0 ]] || PERSONS=(worker student parent creator)

STYLE_COMMON="This is an entirely fictional person who does not resemble any real individual or celebrity. The face fills the center of the frame at arm's length, looking straight into the front camera with sleepy just-woken eyes and a calm, quietly determined expression, mouth fully closed, messy bed hair. The room is dim, lit only by faint morning light leaking around dark curtains behind them; bedding or a pillow is visible around the shoulders. Natural skin texture, subtle low-light sensor grain, muted colors, ordinary amateur selfie realism. No text, no watermark, no user interface elements."

person_prompt() {
    case "$1" in
        worker)  echo "Photorealistic vertical smartphone front-camera selfie, taken alone in a dark bedroom just after waking up in the early morning by a Japanese office worker man in his mid-30s with short black hair. A dark charcoal duvet is pulled up near his chin. $STYLE_COMMON" ;;
        student) echo "Photorealistic vertical smartphone front-camera selfie, taken alone in a dark bedroom just after waking up in the early morning by a Japanese female university student around 20 years old with shoulder-length dark hair, wearing a plain loose crew-neck pajama top that clearly covers her shoulders and chest. Light plain bedding and a small turned-off desk lamp are faintly visible behind her. $STYLE_COMMON" ;;
        parent)  echo "Photorealistic vertical smartphone front-camera selfie, taken alone in a dark bedroom just after waking up in the early morning by a Japanese father in his late 30s with very short hair, light stubble and a gentle tired face. A corner of a child's plush toy rests on the bed beside him, barely visible in the dark. $STYLE_COMMON" ;;
        creator) echo "Photorealistic vertical smartphone front-camera selfie, taken alone in a dark bedroom just after waking up in the early morning by a Japanese woman in her mid-20s with loosely tied hair, a few strands falling over her forehead. Far behind her in the dark, tiny faint standby lights of music equipment glow softly. $STYLE_COMMON" ;;
        *) echo "unknown person: $1" >&2; exit 1 ;;
    esac
}

talk_prompt() {
    local keep="Keep this exact photo unchanged - same person, same pose, same framing, same lighting, same background - and modify only the mouth:"
    case "$1" in
        3) echo "$keep the lips are now slightly parted, just beginning to speak. Do not change anything else." ;;
        1) echo "$keep the mouth is now half open, mid-word while speaking. Do not change anything else." ;;
        2) echo "$keep the mouth is now clearly open, as if stressing a vowel while speaking. Do not change anything else." ;;
    esac
}

# API の一時エラーに備えて 3 回まで再試行する
retry() {
    local attempt
    for attempt in 1 2 3; do
        "$@" && return 0
        echo "  attempt $attempt failed, retrying..." >&2
        sleep 5
    done
    return 1
}

for person in "${PERSONS[@]}"; do
    BASE="$ASSETS/person-$person.png"
    if [[ "$MODE" == "bases" || "$MODE" == "all" ]]; then
        echo "=== base: $person"
        retry bash "$GEN" --prompt "$(person_prompt "$person")" --output "$BASE" --aspect-ratio 9:16
    fi
    if [[ "$MODE" == "talks" || "$MODE" == "all" ]]; then
        [[ -f "$BASE" ]] || { echo "ERROR: $BASE がありません (先に bases を生成)" >&2; exit 1; }
        for t in 3 1 2; do
            echo "=== talk-$t: $person"
            retry "$I2I_PY" "$I2I" "$BASE" "$ASSETS/person-$person-talk-$t.png" "$(talk_prompt "$t")"
        done
    fi
done

echo "=== done ($MODE: ${PERSONS[*]})"
