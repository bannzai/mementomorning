---
feature: ShareCard
verification: mobile-mcp
last_verified_commit: b15c23b53893c3146fd207c21c48e2963f38f8c1
last_verified_at: 2026-08-22
---

# ShareCard QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/7 (受け入れ条件)、 https://github.com/bannzai/mementomorning/issues/74 (ホームからの共有・共有を促すダイアログ)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 回答ログ / 節目画面から画像を共有できる | カードの表示 / share sheet での共有 |
| S2 | 日本語・英語どちらの回答でもレイアウトが崩れない | レイアウトの言語耐性 |
| S3 | 今日の回答があるホームから共有カードを開ける | ホームの「共有」リンク |
| S4 | 初回の回答の朝に共有を促すダイアログが出て、以降は 2 週間おきに出る | 共有を促すダイアログの初回表示 / ダイアログからの共有 / 「今はしない」後は同じ 2 週間の中で再表示しない / 2 週間後の再表示 |

## 1. カードと共有

- [x] **カードの表示**: ジャーナルまたは「七つの朝」の回答行をタップすると、日付と回答本文が入ったカードのプレビューが表示される
  - 自動化: manual（表示内容の目視確認）
- [x] **share sheet での共有**: 「共有」ボタンで share sheet が開き、カードが 1 枚画像として共有できる
  - 自動化: manual（share sheet は OS UI のため目視確認）
  - 確認範囲: ローカル simulator で share sheet を開くところまで。実際の送信先アプリ (メッセージ・メール等) への引き渡しは未確認
- [x] **レイアウトの言語耐性**: 日本語・英語どちらの回答本文でもカードのレイアウトが崩れない
  - 自動化: manual（見た目の崩れの目視確認。日英ロケールでの書き出しは MementoMorningTests/AnswerShareCardRenderTests.swift がカバー済み）
  - 確認範囲: 日本語の回答本文は 2026-08-19 (issue #74、リモート simulator)、英語の回答本文は 2026-08-22 (ローカル simulator) に目視確認した

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **カードの表示**: ジャーナルまたは「七つの朝」の回答行をタップすると、日付と回答本文が入ったカードのプレビューが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/84719a9c-5b33-45ca-8293-32feabd7b903.jpg" width="320">

(問い・回答本文・日付・「Memento Morning」のウォードマークと Share ボタン。share sheet を開くまでは未確認)

</details>

### **share sheet での共有**: 「共有」ボタンで share sheet が開き、カードが 1 枚画像として共有できる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/36f03c16-ee08-4f8e-8391-8931e11ffe25.png" width="320">

共有カードのプレビューで「共有」をタップすると share sheet が開いた。共有対象が画像 1 枚であることは、ヘッダーにカードのサムネイルが 1 つだけ (タイトル「Memento Morning」) 並ぶことと、アクション行に画像専用の項目 (「画像を保存」「連絡先に割り当てる」「プレビュー」) が出ていることで判定した。share sheet は下方向のスワイプで閉じる。

</details>

### **レイアウトの言語耐性**: 日本語・英語どちらの回答本文でもカードのレイアウトが崩れない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (英語本文。iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/718f44a4-4c83-4e40-a33a-dc9c9bd2c895.png" width="320">

ホームの「直す」で本文を「Go see the sea with my family and watch the sunrise」(50 文字) に書き換えてから共有カードを開いた。本文がカード内で 3 行に折り返され、上の問い・下の日付・「Memento Morning」のウォードマークのいずれもカードの外にはみ出さず、文字の切れも無かった。日本語本文でのレイアウトは 2026-08-19 の「カードの表示」で確認済み。

</details>

</details>

---

## 2. ホームからの共有と共有を促すダイアログ (issue #74)

- [x] **ホームの「共有」リンク**: 今日の回答があるホームの「今朝のことば」の下に「直す」と並んで「共有」リンクが出て、タップすると共有カードのプレビューが開く
  - 自動化: manual（表示内容の目視確認）
- [x] **共有を促すダイアログの初回表示**: 一度もダイアログを出していない状態で今日の回答が現れると、ホームに「Share this morning's words?」のダイアログ (今はしない / 共有) が出る
  - 自動化: manual（ダイアログの目視確認。表示判定は MementoMorningTests/SharePromptTests.swift がカバー）
- [x] **ダイアログからの共有**: ダイアログの「共有」で今日の回答の共有カードのプレビューが開く
  - 自動化: manual（表示内容の目視確認）
- [x] **「今はしない」後は同じ 2 週間の中で再表示しない**: 「今はしない」を選んだ後、別画面へ移動してホームへ戻ってもダイアログは出ない
  - 自動化: manual（画面遷移を伴う目視確認）
- [x] **2 週間後の再表示**: 開発者メニューの「共有ダイアログの記録を 14 日前にする」でホームに戻るとダイアログが再表示される。「共有ダイアログの記録をリセット」でも再表示される
  - 自動化: manual（開発者メニュー操作を伴う目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **ホームの「共有」リンク**: 今日の回答があるホームの「今朝のことば」の下に「直す」と並んで「共有」リンクが出て、タップすると共有カードのプレビューが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/b0059e8a-517a-47a3-8ac3-56d1eda18e23.jpg" width="320">

(「Fix / Share」の 2 リンク。Share のタップで下のカードのプレビューが開いた)

</details>

### **共有を促すダイアログの初回表示**: 一度もダイアログを出していない状態で今日の回答が現れると、ホームに「Share this morning's words?」のダイアログ (今はしない / 共有) が出る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/b3a918e9-8182-484d-8a2e-87f7ca67bd0f.jpg" width="320">

(開発者メニューの「今日の回答を投入」→ ホームへ戻った直後)

</details>

### **ダイアログからの共有**: ダイアログの「共有」で今日の回答の共有カードのプレビューが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/ee97378a-4d98-4c2f-9bba-a7c06c1d995c.jpg" width="320">

</details>

### **「今はしない」後は同じ 2 週間の中で再表示しない**: 「今はしない」を選んだ後、別画面へ移動してホームへ戻ってもダイアログは出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/b0059e8a-517a-47a3-8ac3-56d1eda18e23.jpg" width="320">

(「今はしない」の後に開発者メニューへ移動 → ホームへ戻った状態。要素一覧に Alert が無いことも確認)

</details>

### **2 週間後の再表示**: 開発者メニューの「共有ダイアログの記録を 14 日前にする」でホームに戻るとダイアログが再表示される。「共有ダイアログの記録をリセット」でも再表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/b3a918e9-8182-484d-8a2e-87f7ca67bd0f.jpg" width="320">

(14 日前化 → ホームで再表示、「今はしない」→ リセット → ホームで再表示、の順に確認。表示されたダイアログは初回と同じ)

</details>

</details>

---
