---
feature: NightReflection
verification: mobile-mcp
last_verified_commit: f07f0fd
last_verified_at: 2026-08-19
---

# NightReflection QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/8 (受け入れ条件) / https://github.com/bannzai/mementomorning/issues/26 (パーソナライズ)
- 関連: https://github.com/bannzai/mementomorning/issues/80 (動画の見返し)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 指定時刻に通知が届き、タップで振り返り画面が開く | 通知からの起動 |
| S2 | やれた / やれていない が MorningAnswer に記録される | やれた / やれていない の記録 |
| S3 | 当日回答がある日の夜リマインドに回答テキストが含まれる | 通知のパーソナライズ |
| S4 | 回答がない日は従来の文言で届く | 通知のパーソナライズ |
| S5 | 長文回答が通知で破綻しない (切り詰め確認) | 通知のパーソナライズ |
| S6 | 動画で答えた朝は今朝の動画を見返せる (issue #80) | 動画の見返し導線 |

## 1. 通知

- [x] **通知からの起動**: 夜リマインド通知 (開発者メニューの「Schedule night reminder in 1 minute」で 1 分後に発火) をタップすると、振り返り画面が sheet で開く
  - 自動化: maestro（ローカル simulator で `xcrun simctl push` に category `NIGHT_REMINDER` の payload を渡し、Maestro の repeat で画面上部中央 (50%,8%) をバナーが消える前に blind tap する。2026-08-19 にこの手順で確認）
  - 確認範囲: 開発者メニューの 1 分後登録ではなく simctl push で配信した通知で確認した (通知タップのルーティングは categoryIdentifier で判定するため同じ経路)。リモート simulator (simtunnel) では通知バナーを捕捉できない (発火 70 秒後の 1 フレーム撮影ではバナーが消えた後かを判別できず、WDA からは通知センターも開けなかった)
- [ ] **通知のパーソナライズ**: 当日回答がある日は通知本文に回答テキストが含まれ、回答がない日は汎用文言で届く。長文回答でも通知が破綻しない
  - 自動化: manual（通知の実表示の目視確認。本文組み立てのロジックは MementoMorningTests/NightReminderTests.swift がカバー済み）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **通知からの起動**: 夜リマインド通知 (開発者メニューの「Schedule night reminder in 1 minute」で 1 分後に発火) をタップすると、振り返り画面が sheet で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/3ecb9031-8dd8-4264-a23d-f7e07ba4f1a2.png" width="320" />

(simctl push した夜リマインドのバナーをタップして振り返り画面が sheet で開いた状態)

</details>

### **通知のパーソナライズ**: 当日回答がある日は通知本文に回答テキストが含まれ、回答がない日は汎用文言で届く。長文回答でも通知が破綻しない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 振り返り

- [ ] **今朝の回答の表示**: 今朝の回答がある状態で開くと「守れてますか?」の見出しと回答本文 (night_reflection_answer_text) が表示される
  - 自動化: manual（表示内容の目視確認）
- [ ] **やれた / やれていない の記録**: 「やれた」(night_reflection_fulfilled_button) または「やれていない」(night_reflection_not_fulfilled_button) をタップすると記録されて画面が閉じ、ジャーナルの該当行の右端に結果が反映される
  - 自動化: manual（記録と反映の確認）
- [ ] **記録済みの表示**: 記録済みの回答で再度開くと「記録済み: ...」が表示される
  - 自動化: manual（表示内容の目視確認）
- [ ] **回答がない日の表示**: 今朝の回答がない状態で開くと「今朝の回答はまだありません」と閉じるボタンが表示される
  - 自動化: manual（表示内容の目視確認）
- [ ] **保存失敗時の挙動**: 記録の保存に失敗した場合は画面が閉じず、エラー (night_reflection_save_error) が表示され再タップで再試行できる
  - 自動化: todo

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **今朝の回答の表示**: 今朝の回答がある状態で開くと「守れてますか?」の見出しと回答本文 (night_reflection_answer_text) が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **やれた / やれていない の記録**: 「やれた」(night_reflection_fulfilled_button) または「やれていない」(night_reflection_not_fulfilled_button) をタップすると記録されて画面が閉じ、ジャーナルの該当行の右端に結果が反映される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **記録済みの表示**: 記録済みの回答で再度開くと「記録済み: ...」が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **回答がない日の表示**: 今朝の回答がない状態で開くと「今朝の回答はまだありません」と閉じるボタンが表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **保存失敗時の挙動**: 記録の保存に失敗した場合は画面が閉じず、エラー (night_reflection_save_error) が表示され再タップで再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 3. 動画の見返し

- [x] **動画の見返し導線**: 動画で答えた朝は回答本文の下に「今朝 H:mm のあなた · 動画を見返す」(night_reflection_video_replay_link) が表示され、タップすると再生画面 (answer_video_player) が sheet で開く。テキスト回答の朝には表示されない
  - 自動化: maestro（動画回答の作り込みは AnswerLog QA.md「動画の見返し」の flow と同じ。通知からの起動は本 QA.md「通知からの起動」の手順）
  - 確認範囲: ローカル simulator (日本語ロケール) で、疑似録画で答えた朝の振り返り画面に「今朝 12:38 のあなた · 動画を見返す」が出て、タップで再生画面が開くことを確認した。表示する時刻は回答の作成時刻 (MorningAnswer.createdDateTime)。テキスト回答の朝に出ないことは未確認 (videoAssetIdentifier == nil で非表示にする実装)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **動画の見返し導線**: 動画で答えた朝は回答本文の下に「今朝 H:mm のあなた · 動画を見返す」(night_reflection_video_replay_link) が表示され、タップすると再生画面 (answer_video_player) が sheet で開く。テキスト回答の朝には表示されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/3ecb9031-8dd8-4264-a23d-f7e07ba4f1a2.png" width="320" />

(回答本文「動画で答えました」(文字起こしは simulator の音声認識アセット不足で仮テキストのまま) の下に「今朝 12:38 のあなた · 動画を見返す」。タップで再生画面が開くことは Maestro の assert (answer_video_player の出現) で確認)

</details>

</details>

---
