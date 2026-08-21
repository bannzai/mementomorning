# デモ動画の収録手順 (issue #94)

`demo-video-builder` skill (config: `config.json`) で Shipaton 提出用の 2 分デモ動画を収録・合成する。
手作業で設定済みの端末に依存せず、この手順だけで再収録できることを目的とする。

## 前提

- ローカルの iOS Simulator (Maestro / `xcrun simctl` が必要なため simtunnel ではなくローカル。CLAUDE.md「検証方法」)
- `brew install ffmpeg maestro jq`
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
bash $SKILL/record-scene.sh demo-video/config.json life-calendar

maestro --device $DEVICE_UDID test demo-video/flows/prep/night.yaml
bash $SKILL/record-scene.sh demo-video/config.json night-banner   # バナー到着 (登録の約 60 秒後) まで映し続ける
bash $SKILL/record-scene.sh demo-video/config.json night-reflection

maestro --device $DEVICE_UDID test demo-video/flows/prep/morning-question.yaml
bash $SKILL/record-scene.sh demo-video/config.json morning-question
# 録画後にクリップを演出加工する (人物セルフィーの口パク合成・保存リトライ表示のカット。
# 詳細と実測値の測り直し方はスクリプトのヘッダーコメントを参照)
bash demo-video/scripts/enhance-morning-question.sh

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

## 訴求文言のバリアント

冒頭の訴求カット (フック) の文言違いを比較するため、config が 3 つある。差分はフックシーンの
カード文言・ナレーションと出力ファイル名のみ (実名を出すかは App Store 審査・パブリシティ権の
リスク判断が絡むため、documents/PROJECT.md の決定と合わせて選ぶ):

| config | フック | 出力 |
| --- | --- | --- |
| `config.json` | ぼかし表現 (A famous founder) | `memento-morning-demo-founder.mp4` |
| `config.variant-jobs.json` | 実名 (Steve Jobs) | `memento-morning-demo-jobs.mp4` |
| `config.variant-no-person.json` | 人物に触れない (目覚め方の効用) | `memento-morning-demo-no-person.mp4` |

バリアントを作る時は config を差し替えて「generate-narration.sh → compose-video.sh → verify-output.sh」を繰り返す。

## アセット

- `assets/selfie.png` / `assets/selfie-talk-{1,2,3}.png`: Nano Banana Pro (gemini-3-pro-image-preview) で
  生成した寝起きセルフィー。talk 系は selfie.png を入力にした image-to-image で口の開きだけ変えたもので、
  enhance-morning-question.sh が切り替えて口パクにする
- `assets/bgm.m4a`: Erik Satie - Gymnopédie No.1 (Robin Alciatore 演奏、パブリックドメイン、帰属表記不要)。
  出典: https://commons.wikimedia.org/wiki/File:Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg

## 注意 (シミュレータで撮れないもの)

- AlarmKit の発火 UI はシミュレータでは中身が描画されない (空の黒ピルになることを実測)。
  発火 UI の実映像・実カメラのプレビュー・文字起こしの反映は実機収録カット (PR #95 の一覧参照)
- 夜リマインドのバナーはシステム UI のため Maestro の要素検出に乗らない。`night-banner.yaml` は
  アサートせず固定時間ホームを映して到着を録画に収め、到着はフレーム抽出で確認する
- `xcrun simctl status_bar` の `--time` は HH:mm 形式 (ISO 日時文字列は Invalid argument で失敗する)
