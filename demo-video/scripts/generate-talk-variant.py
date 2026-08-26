#!/usr/bin/env python3
"""入力画像を Gemini image-to-image (Nano Banana Pro) に渡し、プロンプトの指示分だけ変えた画像を生成する。

selfie / person-* の口パクバリエーション (口の開きだけ違う画像) の生成に使う。
実行は gemini-image-generator skill の venv を使う (google-genai と Pillow が入っているため):

    ~/.claude/skills/gemini-image-generator/.venv/bin/python3 \
        demo-video/scripts/generate-talk-variant.py <入力画像> <出力画像> <プロンプト>

必要環境: GEMINI_API_KEY
"""

import os
import sys

from google import genai
from google.genai import types
from PIL import Image

api_key = os.environ.get("GEMINI_API_KEY", "")
if not api_key:
    print("GEMINI_API_KEY 未設定", file=sys.stderr)
    sys.exit(1)

input_path, output_path, prompt = sys.argv[1], sys.argv[2], sys.argv[3]

client = genai.Client(api_key=api_key)
image = Image.open(input_path)

response = client.models.generate_content(
    model="gemini-3-pro-image-preview",
    contents=[image, prompt],
    config=types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(aspect_ratio="9:16"),
    ),
)

saved = False
for part in response.parts:
    if part.text is not None:
        print(f"text: {part.text}")
    elif out := part.as_image():
        out.save(output_path)
        saved = True
        print(f"saved: {output_path}")

if not saved:
    print("画像が生成されなかった", file=sys.stderr)
    sys.exit(1)
