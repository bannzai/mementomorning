---
feature: MorningQuestion
verification: mobile-mcp
last_verified_commit: 56abe79
last_verified_at: 2026-08-19
---

# MorningQuestion QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/4 (画面骨格・追撃ループ) / https://github.com/bannzai/mementomorning/issues/24 (動画回答) / https://github.com/bannzai/mementomorning/issues/25 (文字起こし)
- 関連: https://github.com/bannzai/mementomorning/issues/2 (stopIntent 実機検証。シミュレータでは perform() が実行されない既知事象)
- 関連: https://github.com/bannzai/mementomorning/issues/52 (DEBUG 疑似録画モード。カメラの実撮影だけをフィクスチャ動画に差し替えてシミュレータで動画回答のパイプラインを通す)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | アラーム停止 → 質問画面 → 回答 → 以降アラームが鳴らない、の一連が通る | 回答成立で全アラームキャンセル |
| S2 | 未回答で放置すると追撃アラームが再度鳴る | 追撃アラーム |
| S3 | 問いオーバーレイ状態でインカメラ録画 → 停止 → 写真アプリに動画が保存される | 疑似録画での動画回答パイプライン (保存経路) / 実カメラでの録画 (画角・プレビュー) |
| S4 | 録画完了で当日の回答が成立し、追撃アラームが止まる | 疑似録画での動画回答パイプライン |
| S5 | カメラ/マイク/写真の権限拒否時にテキスト入力へフォールバックする | テキスト入力へのフォールバック |
| S6 | 動画回答の完了後、自動で文字起こしが走り MorningAnswer.text に入る (日本語・英語) | 文字起こしの適用 (実機のみ) |
| S7 | 文字起こし結果を編集して保存できる | — (AnswerEdit の QA.md「編集して保存」が担当) |
| S8 | オンデバイス認識で動作する (ネットワーク遮断状態で確認) | 文字起こしの適用 (実機のみ) |
| S9 | 録画は 10 秒で自動停止して回答が確定し、録画中は上限までの進み具合が見える (issue #71) | 録画の上限とインジケーター |

## 1. 提示と解除

- [x] **アラーム発火後の提示**: アラームが発火した朝 (未回答・アラーム ON) にアプリを前面化すると、朝の問いが全画面 (fullScreenCover) で表示され、スワイプでは閉じられない
  - 自動化: manual（発火状態は開発者メニューの「Record alarm fired now」で再現できる。実発火の確認は 1〜2 分後アラームで行う）
  - 確認範囲: 提示は「Record alarm fired now」で確認。スワイプで閉じられないことの操作確認と実発火は未実施
- [ ] **アラーム OFF 中は提示しない**: アラームを OFF にすると、発火記録が残っていても朝の問いが提示されない (提示中でも閉じる)
  - 自動化: manual（画面上の挙動の目視確認。提示判定のロジックは MementoMorningTests/MorningQuestionGateTests.swift がカバー済み）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **アラーム発火後の提示**: アラームが発火した朝 (未回答・アラーム ON) にアプリを前面化すると、朝の問いが全画面 (fullScreenCover) で表示され、スワイプでは閉じられない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9548a201-9da8-4110-b0db-aba1245ca520.jpg" width="320">

(問いの全画面表示と同時にカメラ許可ダイアログ。説明文の位置に NSCameraUsageDescription のキー名が出ていたのは issue #50 で解消済み)

</details>

### **アラーム OFF 中は提示しない**: アラームを OFF にすると、発火記録が残っていても朝の問いが提示されない (提示中でも閉じる)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. テキスト回答

- [x] **テキスト入力へのフォールバック**: カメラ非搭載のシミュレータ (または権限拒否時) では動画回答が使えず、テキスト入力が表示される
  - 自動化: manual（画面上のフォールバックの目視確認。利用可否判定のロジックは MementoMorningTests/VideoAnswerGateTests.swift がカバー済み）
  - 確認範囲: ローカル simulator (英語ロケール) では、動画回答が使えないと判定された時点でテキスト入力へ自動で切り替わり、「The camera isn't available, so answer in text.」が表示されることを確認した。issue #50 で、権限が 1 つでも拒否された時点で残りのリクエストを待たずフォールバックし、セッション起動前は録画ボタンの代わりに「Preparing the camera」を出すよう修正済み
  - 未検証: 動画回答画面の「テキストで答える」リンク (morning_question_text_input_link) を ID 指定で引けること。この要素は動画回答のブランチにしか無く、ローカル simulator では表示に到達できない。コード上、このボタンの祖先に accessibilityIdentifier は無く (上書きしていたのはホームの VStack だけ)、初回 QA で引けなかったのは修正前の過渡状態か WDA の検索由来と見ている
  - 未検証: 「カメラ許可ダイアログで拒否 → その場でフォールバック」の実挙動。ローカル simulator ではカメラ・マイク・写真の許可ダイアログ自体が出ず (カメラ非搭載のため要求が即座に解決する)、修正前のビルドでも同じ画面になり再現できなかった。ダイアログが出る環境 (simtunnel のリモート simulator / 実機) での再確認が必要
- [ ] **昨日の回答の選択式入力**: 昨日の回答がある場合、「昨日の回答を今日やる? YES / NO」の選択式から始まり、断ると自由入力へ切り替わる
  - 自動化: manual（選択式 → 自由入力の切り替え確認）
- [x] **回答の保存**: 自由入力で本文を入れて保存すると画面が閉じ、ホームの「今朝のことば」に反映される
  - 自動化: manual（テキスト入力と反映の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **テキスト入力へのフォールバック**: カメラ非搭載のシミュレータ (または権限拒否時) では動画回答が使えず、テキスト入力が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/317e94d4-ecb1-4d82-ba1a-743e3d41ad64.jpg" width="320">

**再確認日: 2026-08-17 (issue #50 の修正後。英語ロケール・ローカル simulator)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/00079cb0-98e9-418d-aeec-34bfaeb7c358.png" width="320" />

(録画ボタンは表示されず、フォールバックの文言とテキスト入力だけになっている)

</details>

### **昨日の回答の選択式入力**: 昨日の回答がある場合、「昨日の回答を今日やる? YES / NO」の選択式から始まり、断ると自由入力へ切り替わる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **回答の保存**: 自由入力で本文を入れて保存すると画面が閉じ、ホームの「今朝のことば」に反映される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/140155d4-0c60-48be-9aba-ac1c73e4b47b.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/b18f13e0-b6f3-432f-8036-29e82705eb7d.jpg" width="320">

(「家族と海を見に行く」を入力 → 保存で全画面が閉じ、ホームの「This morning's words」に反映。フッターの件数が「1 mornings answered」になっていた単数形の不具合は issue #50 で解消済み)

**再確認日: 2026-08-17 (issue #50 の修正後。英語ロケール・ローカル simulator)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/17ca081d-d3bb-403f-a43b-a3c7f10f2a4d.png" width="320" />

(回答 1 件でフッターが「1 morning answered」)

</details>

</details>

---

## 3. アラーム連携

- [ ] **回答成立で全アラームキャンセル**: 回答が成立すると当日の残アラーム (バックアップ・追撃含む) が全キャンセルされ、以降アラームが鳴らない
  - 自動化: manual（実際に鳴らないことの確認。計画ロジックは MementoMorningTests/ChaseAlarmTests.swift / AlarmPlanEngineTests.swift がカバー済み）
- [ ] **追撃アラーム**: 未回答のまま放置すると追撃アラームが再度発火する (発火判定は画面表示)
  - 自動化: manual（シミュレータでは stopIntent の perform() が実行されない既知事象があるため、発火の実確認は実機。issue #2 参照）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **回答成立で全アラームキャンセル**: 回答が成立すると当日の残アラーム (バックアップ・追撃含む) が全キャンセルされ、以降アラームが鳴らない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **追撃アラーム**: 未回答のまま放置すると追撃アラームが再度発火する (発火判定は画面表示)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---


## 4. 動画回答

カメラの実撮影以外のパイプラインは DEBUG 疑似録画モード (issue #52) でシミュレータから検証する。
開発者メニューの「Simulate video answer」を ON にすると、`VideoAnswerCamera` が AVCapture を使わず、
録画停止でフィクスチャ動画 (`DebugVideoAnswerFixture_{en,ja}.mov`。既知の発話の音声トラック入り) を
「録画結果」として返し、以降 (写真ライブラリ保存 → 文字起こし → MorningAnswer 成立 → 当日のアラーム
キャンセル → 画面が閉じてホームに反映) は本物のコードを通る。

疑似 E2E シナリオ:

1. 開発者メニューで「Simulate video answer」を ON にし、「Record alarm fired now」を押す
2. 朝の問いが全画面で表示され、録画ボタンが表示される (権限ダイアログは写真ライブラリのみ)
3. 録画開始 → 停止で回答が確定し、画面が閉じる
4. 写真アプリのアルバム「Memento Morning」に動画が保存されている
5. 回答がホームの「今朝のことば」に反映される
6. 当日の残アラームが計画から外れ、次のアラームが翌朝になる

- [x] **疑似録画での動画回答パイプライン**: 疑似 E2E シナリオ 1〜6 が通る (シミュレータ)
  - 自動化: manual（開発者メニューのタップ操作。フィクスチャの同梱・音声トラック・一時ファイル複製は MementoMorningTests/DebugVideoAnswerFixtureTests.swift がカバー）
  - 確認範囲: 録画 → 写真ライブラリ保存 → 回答成立 → ホーム反映 まで確認。文字起こしはシミュレータで動かない (下記「文字起こしの適用 (実機のみ)」)
- [ ] **文字起こしの適用 (実機のみ)**: 動画回答の完了後にオンデバイス文字起こしが走り、仮テキスト「動画で答えました」が発話内容に置き換わる (日本語・英語)。ネットワーク遮断でも動作する
  - 自動化: manual（実機のみ。適用可否・上書き判定のロジックは MementoMorningTests/VideoAnswerTranscriberTests.swift がカバー）
  - **シミュレータでは動作しない (iOS 26.5 simulator で実測)**。`SFSpeechRecognizer.supportsOnDeviceRecognition` は **true を返す**ため `isTranscriptionAvailable` を通過して認識が走るが、実行時に `kLSRErrorDomain 300 "Failed to initialize recognizer"` (MobileAsset の `mini.json` を読めない) で失敗し、仮テキストのまま残る。言語を端末と揃えても再現する (2 回再現)。端末の言語と違う言語で要求した場合は `kLSRErrorDomain 101 "No Assistant asset for language ..."` になる
  - 実機で確認する時は、フィクスチャの言語が端末の言語と一致している必要がある (シミュレータ・実機ともに端末の言語のオンデバイス認識アセットしか無いため)。`DebugVideoAnswerFixtureLanguage.current` が `Locale.current` の言語で英語版・日本語版を選び、期待値の発話は開発者メニューの「Fixture utterance」に表示される
- [ ] **実カメラでの録画 (実機のみ)**: インカメラのプレビューに問いがオーバーレイされ、画角・向き (縦) が正しい。実マイクの音声で文字起こしの認識精度が実用に足る
  - 自動化: manual（シミュレータにカメラが無いため実機のみ。疑似録画モードではプレビューが黒のままになる）
- [ ] **保存失敗時の再試行**: 動画の保存または回答の確定に失敗した場合、「保存をやり直す」(morning_question_retry_save_button) が表示され、再録画なしで再試行できる
  - 自動化: todo（失敗を注入する手段が無いため未検証。疑似録画モードにも失敗注入は用意していない）
- [x] **録画の上限とインジケーター**: 録画中は録画ボタンの上に夜明け色の点と mono タイマー「0:03 / 0:10」(morning_question_recording_timer) が出て、録画ボタンの外リングが進捗ぶん夜明け色で埋まる。10 秒で自動停止して回答が確定し、手動停止も従来どおり動く
  - 自動化: manual（開発者メニューの疑似録画モードで simulator から確認。上限値・進捗・タイマー文字列の算出は MementoMorningTests/VideoAnswerRecordingLimitTests.swift がカバー。実カメラの maxRecordedDuration での停止は実機のみ）
  - 確認範囲: 疑似録画モード (simtunnel のリモート simulator、英語ロケール) で確認。実カメラでの上限到達 (AVFoundation の maxRecordedDuration による停止) は実機未確認

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **疑似録画での動画回答パイプライン**: 疑似 E2E シナリオ 1〜6 が通る (シミュレータ)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17** (iPhone 16 Pro / iOS 26.5 simulator、端末の言語は日本語。main 取り込み後の commit `07cc8bc` で実施)

1. 開発者メニューの「Video Answer (issue #52)」。「Simulate video answer」が ON で、端末の言語に合う日本語のフィクスチャ (`Fixture utterance: 今日は家族と海を見に行きたい`) が選ばれ、同梱されている (`Fixture bundled: true`)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/5fd461bd-00d2-4a3b-9539-eb70cd6dbba8.png" width="320" />

2. 「Record alarm fired now」の後に出る権限ダイアログは写真ライブラリのみ (実撮影をしないためカメラ・マイクは要求しない)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/7c5bd8ab-0d95-47b7-a6b0-7c158ee62eda.png" width="320" />

3. 朝の問いが全画面で表示され、録画ボタンが押せる (プレビューは黒。疑似録画モードではカメラを構成しないため)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/367e6511-08e6-4e98-8409-25d0858fe65c.png" width="320" />

4. 録画中 (停止 = 回答確定を表す夜明け色の角丸)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/d522f618-aabc-40d9-9e4a-eb8dcc9fe037.png" width="320" />

5. 停止後、写真アプリのアルバム「Memento Morning」に動画が保存されている (5 件は疑似録画を 5 回実行したぶん。フィクスチャが墨色の単色動画のためサムネイルは黒)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/b32883bf-9091-4da7-9ea7-7628796abbc9.png" width="320" />

6. 全画面が閉じてホームに戻り、「今朝のことば」に回答が反映される (文字起こしが走らないため仮テキスト「動画で答えました」のまま)。「答えた日数 1日」に増え、次のアラームは翌朝 7:00 になっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/309282e3-9fbd-4981-acd8-9fcbfd4d9f64.png" width="320" />

シナリオ 6 について: 上記スクリーンショットが示すのは「再スケジュールの計画から当日が外れ、次の発火が翌朝になった」ことまで。AlarmKit に登録済みの当日の UUID が実際にキャンセルされ「鳴らない」ことの確認は「3. アラーム連携」の項目が担当する (実機)。

</details>

### **文字起こしの適用 (実機のみ)**: 動画回答の完了後にオンデバイス文字起こしが走り、仮テキスト「動画で答えました」が発話内容に置き換わる (日本語・英語)。ネットワーク遮断でも動作する

<details><summary>動作確認スクショ</summary>

（実機未実行。シミュレータでは上記のとおり `kLSRErrorDomain 300` で失敗することを確認済みで、仮テキストのまま残る挙動だけが確認できている）

</details>

### **実カメラでの録画 (実機のみ)**: インカメラのプレビューに問いがオーバーレイされ、画角・向き (縦) が正しい。実マイクの音声で文字起こしの認識精度が実用に足る

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **保存失敗時の再試行**: 動画の保存または回答の確定に失敗した場合、「保存をやり直す」(morning_question_retry_save_button) が表示され、再録画なしで再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **録画の上限とインジケーター**: 録画中は録画ボタンの上に夜明け色の点と mono タイマー「0:03 / 0:10」(morning_question_recording_timer) が出て、録画ボタンの外リングが進捗ぶん夜明け色で埋まる。10 秒で自動停止して回答が確定し、手動停止も従来どおり動く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19** (iPhone 17 / iOS 26.5、simtunnel セッション `mementomorning-issue-71`、`--ref issue-71`、英語ロケール。commit `56abe79`)

1. 録画前: タイマー・点は出ず、録画ボタンは白丸 + 白のリングのみ

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/7111030c-2042-48b2-9020-410971712813.jpg" width="320" />

2. 録画開始から約 1.5 秒: 「0:01 / 0:10」と点が出て、外リングの上部が夜明け色になっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/4b52b915-5ed1-48e4-835b-6d9491e2b0c6.jpg" width="320" />

3. 約 6 秒: 「0:05 / 0:10」、外リングの約半分が夜明け色。点は 2. より薄く (明滅)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/23d62858-6c9d-4851-b3a9-e44f2f8a0e7b.jpg" width="320" />

4. 約 16 秒: 朝の問いの全画面はボタン操作なしで閉じ (10 秒で自動停止 → 疑似録画の結果を保存 → 回答成立)、呼び出し元の開発者メニューに戻って音声認識の許可ダイアログ (文字起こしの開始) が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/3c538cf1-bccf-41fe-93d8-86b899a65c5a.jpg" width="320" />

5. ホームに戻ると「This morning's words: Answered with a video」「1 morning answered」(自動停止で回答が成立している。文字起こしは simulator で動かないため仮テキストのまま)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/f0ca7e37-b3e0-4cc5-bd21-47865ae92631.jpg" width="320" />

6. 手動停止: 「全回答を削除」→「アラーム発火を今すぐ記録」→ 録画開始 → 約 1.7 秒後に録画ボタンをタップ → 全画面が閉じて開発者メニューに戻る (手動停止も従来どおり)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/12f654fe-15a7-4340-861a-ba94f981a3e4.jpg" width="320" />

</details>

</details>

---
