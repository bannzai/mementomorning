#!/usr/bin/env python3
"""完成した縦動画を Gemini に映像と音声の両方から検査させ、台詞の逐語書き起こし・音の流れ・崩れの有無を日本語で書き出す。

使い方:
  <gemini-image-generator の venv の python3> demo-video/scripts/inspect-short.py <mp4> [<mp4> ...]
出力: 各 mp4 と同名の .inspection.txt (標準出力にも出す)。要 GEMINI_API_KEY
用途: 目視 (コンタクトシート) で確認できない「聞こえ方」(アラーム音 → 声 → 無音 → 一音の流れ、語尾欠け、口と声のずれ)
      を機械的に確認する。判定はこの出力を読んで人が行う
"""

import os
import sys
from pathlib import Path

from google import genai
from google.genai import types

PROMPT = (
    "添付の縦動画 (TikTok / Shorts 用) を映像と音声の両方から検査してください。期待する内容は渡しません。\n"
    "1. 聞こえる発話を逐語で書き起こし、各発話の開始秒と終了秒を示す (英語はそのまま)\n"
    "2. 音の流れを秒ごとに記述する (アラーム音・環境音・声・無音・チャイムなど、何がいつ鳴っているか)\n"
    "3. 画面に表示される文字を、表示される時間帯とともにすべて書き出す (固定テロップ、アプリ画面の文言、字幕、ブランド名)\n"
    "4. 映像の流れを秒ごとに記述する (人物の動作、アプリ画面の内容)\n"
    "5. 不具合の指摘: 音切れ、語尾欠け、異音、口の動きと声のずれ、文字同士の重なり、文字の見切れ、崩れた顔や手、意図しないロゴ\n"
    "6. この動画を初めて見た人が、最初の 3 秒でどんなアプリだと理解するかを一文で書く\n"
    "聞き取れないものは推測せず不明とし、検証した事実と主観評価を分けて日本語で答えてください。"
)


def main() -> None:
    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    for arg in sys.argv[1:]:
        path = Path(arg)
        response = client.models.generate_content(
            model="gemini-3.8-flash",
            contents=[types.Part.from_bytes(data=path.read_bytes(), mime_type="video/mp4"), PROMPT],
            config=types.GenerateContentConfig(
                temperature=0,
                automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
                thinking_config=types.ThinkingConfig(thinking_level="low"),
            ),
        )
        path.with_suffix(".inspection.txt").write_text(response.text)
        print(f"===== {path.name}\n{response.text}\n")


if __name__ == "__main__":
    main()
