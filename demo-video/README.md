# デモ動画の収録手順 (issue #94)

`demo-video-builder` skill (config: `config.json`) で Shipaton 提出用の 2 分デモ動画を収録・合成する。
手作業で設定済みの端末に依存せず、この手順だけで再収録できることを目的とする。

## 前提

- ローカルの iOS Simulator (Maestro / `xcrun simctl` が必要なため simtunnel ではなくローカル。CLAUDE.md「検証方法」)
- `brew install ffmpeg jq`
- Maestro CLI: `brew install mobile-dev-inc/tap/maestro` (素の `brew install maestro` は同名の別製品
  (Electron 製 GUI アプリ) の cask を掴むため、必ず tap 付きの formula 名で入れる。
  ref: https://docs.maestro.dev/maestro-cli/how-to-install-maestro-cli )
- Debug ビルド (RevenueCat は Test Store キーが既定。Config.xcconfig)

## 収録環境の初期化

```sh
# 1. プロジェクト固有シミュレータを起動し UDID を控える
sim-boot   # 最終行の DEVICE_UDID= を使う
export DEVICE_UDID=<UDID>

# 2. アプリの表示言語を英語に固定する (収録 flow は英語のローカライズ済み文言で要素を特定するため必須。
#    日本語環境のままだと journal.yaml 等の英語文言待ちがタイムアウトする)
xcrun simctl spawn $DEVICE_UDID defaults write .GlobalPreferences AppleLanguages -array en-US
xcrun simctl spawn $DEVICE_UDID defaults write .GlobalPreferences AppleLocale -string en_US
xcrun simctl shutdown $DEVICE_UDID && xcrun simctl boot $DEVICE_UDID

# 3. ビルドとインストール
make build
xcrun simctl install $DEVICE_UDID tmp/DerivedData/Build/Products/Debug-iphonesimulator/MementoMorning.app

# 4. 初回起動前の状態作り込み (オンボーディングのスキップ・写真ライブラリ許可・ステータスバー 9:41)
xcrun simctl spawn $DEVICE_UDID defaults write com.bannzai.MementoMorning hasCompletedOnboarding -bool true
xcrun simctl privacy $DEVICE_UDID grant photos com.bannzai.MementoMorning
xcrun simctl status_bar $DEVICE_UDID override --time "9:41"
```

課金状態の前提: **未購入 (isPremium = false)** で収録する。Test Store で購入済みのシミュレータや
「プレミアムを強制 (上書き)」トグルが ON のままだと、ジャーナルのロック行 (`journal_paywall_link`) が
生成されず `paywall.yaml` が失敗する。購入済みならアプリを uninstall して入れ直し、
開発者メニューでプレミアム強制トグルが OFF であることを確認してから収録する。

## 収録と合成

```sh
SKILL=~/.claude/skills/demo-video-builder/scripts

# 共通の初期状態 (サンプル回答 10 件・アラーム 7:00・AlarmKit 許可)
maestro --device $DEVICE_UDID test demo-video/flows/prep/setup.yaml

# シーン録画 (prep が必要なシーンは直前に実行する)
bash $SKILL/record-scene.sh demo-video/config.json journal
bash $SKILL/record-scene.sh demo-video/config.json seven-mornings
bash $SKILL/record-scene.sh demo-video/config.json share-card
bash $SKILL/record-scene.sh demo-video/config.json paywall
bash $SKILL/record-scene.sh demo-video/config.json calendar

maestro --device $DEVICE_UDID test demo-video/flows/prep/night.yaml
bash $SKILL/record-scene.sh demo-video/config.json night-banner   # バナー到着 (登録の約 60 秒後) まで映し続ける
bash $SKILL/record-scene.sh demo-video/config.json night-reflection

maestro --device $DEVICE_UDID test demo-video/flows/prep/morning-question.yaml
bash $SKILL/record-scene.sh demo-video/config.json morning-question
# 録画後にクリップを演出加工する (人物セルフィーの口パク合成・保存リトライ表示のカット。
# 詳細と実測値の測り直し方はスクリプトのヘッダーコメントを参照)
bash demo-video/scripts/enhance-morning-question.sh
# people バリアント用の人物カット 4 本は、同じ morning-question の録画 (raw) から生成する
bash demo-video/scripts/make-people-cuts.sh

maestro --device $DEVICE_UDID test demo-video/flows/prep/alarm.yaml
bash $SKILL/record-scene.sh demo-video/config.json alarm

# 訴求カット (黒背景テキストカード) のクリップを生成する (Maestro 収録ではなく ffmpeg 生成。
# flows/why-*.yaml は validate-config.sh を通すためのプレースホルダで record-scene.sh 不要)
bash demo-video/scripts/generate-appeal-cards.sh

# ナレーション (Gemini TTS。要 GEMINI_API_KEY) と BGM のミックスを生成し、合成・機械検証する。
# ミックスの出力先は config によらず共通のため、必ず config ごとに「ナレーション → 合成」の順で実行する
bash demo-video/scripts/generate-narration.sh demo-video/config.json
bash $SKILL/compose-video.sh demo-video/config.json
bash $SKILL/verify-output.sh demo-video/config.json
```

出力: `demo-video/output/memento-morning-demo-founder.mp4` (gitignore 対象。動画バイナリはコミットしない)

## バリアント

比較用の config が 4 つある。founder / jobs / no-person はフックシーンのカード文言・ナレーションと
出力ファイル名のみの差分 (実名を出すかは App Store 審査・パブリシティ権のリスク判断が絡むため、
documents/PROJECT.md の決定と合わせて選ぶ)。upbeat はトーン違い (明るい声・明るい BGM・短い尺):

| config | 内容 | 出力 |
| --- | --- | --- |
| `config.json` | フック: ぼかし表現 (A famous founder) | `memento-morning-demo-founder.mp4` |
| `config.variant-jobs.json` | フック: 実名 (Steve Jobs) | `memento-morning-demo-jobs.mp4` |
| `config.variant-no-person.json` | フック: 人物に触れない (目覚め方の効用) | `memento-morning-demo-no-person.mp4` |
| `config.variant-upbeat.json` | 元気トーン (jobs フック + Puck ボイス + Maple Leaf Rag + 各シーン短縮)。フィードバック第 6 弾の文言エモ化とワンクッションカット (why-jobs-legacy) を先行適用 | `memento-morning-demo-upbeat.mp4` |
| `config.variant-upbeat-ja.json` | upbeat の日本語版 (字幕・ナレーション・訴求カードを日本語化。クリップは英語 UI のまま共用) | `memento-morning-demo-upbeat-ja.mp4` |
| `config.variant-upbeat-founder.json` | upbeat の安全版 (フックを実名 → A famous founder に置き換え、肖像イラストも外す。Devpost の第三者素材ルール・パブリシティ権対策) | `memento-morning-demo-upbeat-founder.mp4` |
| `config.variant-people.json` | 登場人物 4 人 (会社員・学生・親・クリエイター) が録画 UI で各自の目標を声に出す構成 (issue #141。Shipaton 提出用の英語版。冒頭は「やりたいことを先送りする人」への訴求カード → アラームの説明 → 問いカード → 人物カット 4 連 (字幕なし・声だけ) → 夜リマインド → journal → calendar → paywall → ブランドカード。人物別 TTS ボイス・Sulafat ナレーター・Vivaldi マンドリン) | `memento-morning-demo-people.mp4` |

声・話し方・BGM は config の `narration_mix` (voice / style_prompt / bgm / bgm_gain) で
上書きできる (省略時はしっとり版の既定値。generate-narration.sh のヘッダーコメント参照)。
シーン単位では `scenes[].narration_voice` / `scenes[].narration_style_prompt` でさらに上書きできる
(登場人物ごとに別の声で話させる people バリアント用。未指定シーンは narration_mix へフォールバック)。
バリアントを作る時は config を差し替えて「generate-narration.sh → compose-video.sh → verify-output.sh」を繰り返す。

## アセット

- `assets/selfie.png` / `assets/selfie-talk-{1,2,3}.png`: Nano Banana Pro (gemini-3-pro-image-preview) で
  生成した寝起きセルフィー。talk 系は selfie.png を入力にした image-to-image で口の開きだけ変えたもので、
  enhance-morning-question.sh が切り替えて口パクにする
- `assets/person-{worker,student,parent,creator}.png` / 同 `-talk-{1,2,3}.png`: people バリアントの
  登場人物 4 人 (会社員・学生・親・クリエイター) の寝起きセルフィー。selfie.png と同じ作り方
  (base は Nano Banana Pro の text-to-image、talk 系は base を入力にした image-to-image で口の開きだけ
  変えたもの) で、make-people-cuts.sh が切り替えて口パクにする。全員が実在人物に似せない生成架空人物
  (肖像リスクの判断は PR #95 と同じ)。プロンプト定義込みの生成スクリプトは
  `scripts/generate-people-assets.sh` (image-to-image の実体は `scripts/generate-talk-variant.py`)
- `assets/founder-portrait.png`: Nano Banana Pro (gemini-3-pro-image-preview) で生成した創業者の
  線画イラスト (黒背景・白線画)。フックカード (why-founder / why-jobs / why-jobs-legacy) に載せる。実写・報道写真は
  使わない (肖像の権利リスクを生成イラストに留める判断。経緯は PR #95 のフィードバック第 4 弾コメント)
- `assets/bgm.m4a`: Erik Satie - Gymnopédie No.1 (Robin Alciatore 演奏、パブリックドメイン、帰属表記不要)。
  出典: https://commons.wikimedia.org/wiki/File:Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg
- `assets/bgm-upbeat.m4a`: Scott Joplin - Maple Leaf Rag (Joplin 本人の 1916 年ピアノロール演奏、
  パブリックドメイン、帰属表記不要)。upbeat バリアントの BGM。
  出典: https://commons.wikimedia.org/wiki/File:Maple_leaf_rag_-_played_by_Scott_Joplin_1916_V2.ogg
- `assets/bgm-mandolin.m4a`: Antonio Vivaldi - マンドリン協奏曲 ハ長調 RV 425 (The Milan Baroque Soloists 演奏、
  Musopen 提供、Creative Commons Public Domain Mark 1.0、帰属表記不要)。people バリアントの BGM。
  出典: https://commons.wikimedia.org/wiki/File:Antonio_Vivaldi,_Mandolin_Concerto_in_C_major,_RV_425.ogg

## 注意 (シミュレータで撮れないもの)

- AlarmKit の発火 UI はシミュレータでは中身が描画されない (空の黒ピルになることを実測)。
  発火 UI の実映像・実カメラのプレビュー・文字起こしの反映は実機収録カット (PR #95 の一覧参照)
- 夜リマインドのバナーはシステム UI のため Maestro の要素検出に乗らない。`night-banner.yaml` は
  アサートせず固定時間ホームを映して到着を録画に収め、到着はフレーム抽出で確認する
- `xcrun simctl status_bar` の `--time` は HH:mm 形式 (ISO 日時文字列は Invalid argument で失敗する)

## 16 秒の縦動画 3 案 × 英日 (issue #167)

macOS の Python 3、Pillow (`python3 -m pip install Pillow==12.3.0`)、ffmpeg / ffprobe を使う。
`config.shorts.json` に固定テロップ・回答訳・人物の切り出し位置と原動画の URL / SHA-256 を置く。

```sh
mkdir -p tmp
python3 demo-video/scripts/generate-shorts.py > tmp/shorts-build.log 2>&1
```

初回は公開済み people 版を取得し、以降はキャッシュをハッシュ照合して使う。
手元の同じ原動画を使う場合は `--source /絶対パス/memento-morning-demo-people.mp4` を付ける。
違う版は失敗として扱う。原動画の再制作・API キー・シミュレータは不要。
再実行はこの生成物だけを同名で作り直す。

出力は `output/shorts/{last-day,one-question,someday}-{en,ja}.mp4`、
対応する 1 秒ごとのコンタクトシート `.png`、規格検査結果 `verification.json`。
動画・中間素材は既存の `output/` の gitignore 対象のまま。
英日で映像の順序と音声は共通、編集テキストのみ差し替える。回答音声は英語のまま。

冒頭の架空人物 → アラーム設定画面 → 問い → 録画 UI で回答 → 無音に近い余韻 →
夜の振り返りを表す編集カード → 最後の 1 秒のブランド名、の順。
夜のカードはアプリ UI・OS 通知の再現ではなく、その人が語った回答を使う編集表現。
旧カレンダー画面や別の回答が入った通知は使わない。
アラーム音は合成した演出音、人物・口パクと声は既存デモの生成素材であり、実機の連続操作記録ではない。
BGM の権利表記は上の `bgm-mandolin.m4a` の項目を参照。

固定テロップは x=60〜940、y=240〜490 に全編表示し、
Issue 指定の上 12%・下 20%・右 12% の除外範囲を避ける。
プレミアム機能の注記も下 20% より上に表示する。
生成時に ffprobe の規格確認と全 480 フレームの見出し照合を行う。
公開前にはコンタクトシートと最終フレームを目視し、音声のデコード・音量も検査する。
`puts` への公開は生成スクリプトに含めず、検査した出力だけをアップロードする。
