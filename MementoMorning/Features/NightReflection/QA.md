---
feature: NightReflection
verification: mobile-mcp
last_verified_commit: 25e17c225a4716fab8723809a68a9c1cf405fa8e
last_verified_at: 2026-08-22
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

### 再現手順 (2026-08-22 に確立。ローカル simulator / iPhone / iOS 26.5)

通知バナーはシステムの別レイヤーに描画され、`xcrun simctl io screenshot` にも mobile-mcp のアクセシビリティツリーにも一切写らない (AlarmKit のアラートと同じ。root QA.md「実行ナレッジ」)。見えないものをタップする前提で手順を組む。

- **通知本文を目視する (パーソナライズの確認)**: 開発者メニューの「夜リマインドを 1 分後に登録」→ 60 秒待つ → ホーム画面で画面上部の端 (座標 (100, 5) 付近) から下スワイプして通知センターを開く → スクリーンショットを撮る。通知センター上の本文はスクリーンショットにもツリーにも写るため、ここで初めて本文を読める
- **通知をタップして振り返り画面を開く**: **アプリをフォアグラウンドにしたまま** `xcrun simctl push <UDID> com.bannzai.MementoMorning <payload>.apns` で配信し、直後に座標 **(196, 95)** (393×852pt 換算。バナー中央) を 1 回タップする。NotificationDelegate の willPresent が `[.banner, .list, .sound]` を返すためフォアグラウンドでもバナーが出る。payload は `"category": "NIGHT_REMINDER"` を含めれば本番と同じ経路を通る
- **やってはいけないこと**: 通知センター上の通知セルのタップは WDA でも Maestro でも反応しない (何度試しても画面が開かない)。また Maestro の repeat で上部を連打すると、バナータップで開いた振り返り画面 (sheet) の外側を続けて叩いて即座に閉じてしまう。タップは 1 回だけにする
- [x] **通知のパーソナライズ**: 当日回答がある日は通知本文に回答テキストが含まれ、回答がない日は汎用文言で届く。長文回答でも通知が破綻しない
  - 自動化: manual（通知の実表示の目視確認。本文組み立てのロジックは MementoMorningTests/NightReminderTests.swift がカバー済み）
  - 確認範囲: 開発者メニューの「夜リマインドを 1 分後に登録」で実際に届いた通知 (アプリが組み立てた本文) を 3 パターン確認した。simctl push の手作り payload では確認していない
  - **通知バナーはスクリーンショットにもアクセシビリティツリーにも写らない**ため、本文の目視は通知センター (画面上部から下スワイプ) で行う。手順は下記「再現手順」を参照

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

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

1. 当日回答あり (回答本文「Go see the sea with my family」)。通知本文が「今朝のあなた『Go see the sea with my family』」になる

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/466a903a-2259-48ea-aa22-92b3650f1095.png" width="320">

2. 同じ回答をホームの「直す」で 143 文字に伸ばした状態。通知本文は「今朝のあなた『Go see the sea with my family, and then call my mother for a…』」で、回答テキストが 60 文字 + 省略記号に切り詰められ、閉じの『』も残っていて破綻しない (切り詰めは NightReminder.answerTextMaxLength = 60)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/fb46f1be-8ec0-4570-8463-dcc580b57c84.png" width="320">

3. 「全回答を削除」で当日回答がない状態。通知本文が汎用文言「今朝の回答と答え合わせしましょう」になる

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/9c90c235-0529-4713-939f-8a21ebdfed46.png" width="320">

</details>

</details>

---

## 2. 振り返り

- [x] **今朝の回答の表示**: 今朝の回答がある状態で開くと「守れてますか?」の見出しと回答本文 (night_reflection_answer_text) が表示される
  - 自動化: manual（表示内容の目視確認）
- [x] **やれた / やれていない の記録**: 「やれた」(night_reflection_fulfilled_button) または「やれていない」(night_reflection_not_fulfilled_button) をタップすると記録されて画面が閉じ、ジャーナルの該当行の右端に結果が反映される
  - 自動化: manual（記録と反映の確認）
  - 確認範囲: 両ボタンともタップで画面が閉じ、開発者メニューの「今日の回答」表示が isFulfilled: true / false に変わることを確認した。**ジャーナルへの反映は当日行では確認できない** — AnswerLogPage.swift:137 の `if !isToday, let isFulfilled` により、結果の表示は過去の行だけで、当日行には出ない仕様。過去の行での表示確認は AnswerLog QA.md「夜の結果の表示」に記載のとおり日付跨ぎが必要
- [x] **記録済みの表示**: 記録済みの回答で再度開くと「記録済み: ...」が表示される
  - 自動化: manual（表示内容の目視確認）
- [x] **回答がない日の表示**: 今朝の回答がない状態で開くと「今朝の回答はまだありません」と閉じるボタンが表示される
  - 自動化: manual（表示内容の目視確認）
  - 落とし穴: アラーム発火記録が残っていると、通知タップでアプリが前面化した時に朝の問い (fullScreenCover) が振り返り画面の上に重なって出る。回答なしの状態を作る時は「全回答を削除」に加えて「アラーム発火記録を削除」も実行する
- [ ] **保存失敗時の挙動**: 記録の保存に失敗した場合は画面が閉じず、エラー (night_reflection_save_error) が表示され再タップで再試行できる
  - 自動化: todo

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **今朝の回答の表示**: 今朝の回答がある状態で開くと「守れてますか?」の見出しと回答本文 (night_reflection_answer_text) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール、当日回答「Go see the sea with my family」あり)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/8e76f1ee-701a-4c38-8527-34c6d5f2b4f7.png" width="320">

(「守れてますか? / ARE YOU KEEPING IT?」の見出しの下に回答本文。下部に「やれた」「やれていない」)

</details>

### **やれた / やれていない の記録**: 「やれた」(night_reflection_fulfilled_button) または「やれていない」(night_reflection_not_fulfilled_button) をタップすると記録されて画面が閉じ、ジャーナルの該当行の右端に結果が反映される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (当日回答「Go see the sea with my family」で「やれた」をタップ)

画面が閉じてホームに戻り、開発者メニューの「今日の回答」が (isFulfilled: true) になった

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/80d4d62b-05b9-4500-8a52-cb3cae840a44.png" width="320">

別の回答 (本文「temp」) で「やれていない」をタップした時も同様に画面が閉じ、「今日の回答: temp (isFulfilled: false)」になることを確認した。ジャーナルへの反映は当日行には出ない仕様のため未確認 (上記チェック項目の確認範囲を参照)

</details>

### **記録済みの表示**: 記録済みの回答で再度開くと「記録済み: ...」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (「やれた」を記録した当日回答で、通知タップから再度開いた状態)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/2f1ef7b3-a4ca-4d78-b3f4-10b653854338.png" width="320">

(回答本文の下に「記録済み: やれた」)

</details>

### **回答がない日の表示**: 今朝の回答がない状態で開くと「今朝の回答はまだありません」と閉じるボタンが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (「全回答を削除」+「アラーム発火記録を削除」の後、汎用文言の夜リマインドから開いた状態)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/09f787e4-217e-49bf-ad06-79cba49c3cb7.png" width="320">

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
