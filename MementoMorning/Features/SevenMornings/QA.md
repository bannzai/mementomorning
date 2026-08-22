---
feature: SevenMornings
verification: mobile-mcp
last_verified_commit: 25e17c225a4716fab8723809a68a9c1cf405fa8e
last_verified_at: 2026-08-22
---

# SevenMornings QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/10 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/7 (共有カード導線)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 回答が 7 件に達した朝に一度だけ表示される (冪等) | 7 件到達で表示 / 一度だけ表示 |
| S2 | 30/90/180/365 日の節目は対象外 (MVP 後) | — (未実装のため QA 項目なし) |

## 1. 節目の表示

- [x] **7 件到達で表示**: 回答が 7 件に達すると (開発者メニューの「Delete all answers」→「Seed sample answers (10 days)」で再現)、「七つの朝」(seven_mornings_title) が sheet で表示され、最初の 7 件の回答が古い順に並ぶ
  - 自動化: manual（画面上の表示の目視確認。表示判定のロジックは MementoMorningTests/SevenMorningsMilestoneTests.swift がカバー済み）
- [x] **一度だけ表示**: 一度表示した後は、アプリを再起動しても再表示されない。開発者メニューの「Reset Seven Mornings milestone」でリセットすると再表示される
  - 自動化: manual（再起動と表示済みフラグの操作が必要）
  - 再現手順: 開発者メニューで「全回答を削除」→「七つの朝の節目をリセット」→「サンプル回答を投入 (10 日分)」の順にタップする。sheet は**開発者メニューを開いたまま**表示される (ホームへ戻る操作は不要)。「七つの朝の節目をリセット」も同じくタップした瞬間に sheet が出る
- [x] **無料枠制限を適用しない**: 8 日以上前になった回答も、無料状態のままこの画面では表示される
  - 自動化: manual（課金状態と表示の突き合わせが必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **7 件到達で表示**: 回答が 7 件に達すると (開発者メニューの「Delete all answers」→「Seed sample answers (10 days)」で再現)、「七つの朝」(seven_mornings_title) が sheet で表示され、最初の 7 件の回答が古い順に並ぶ

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/eb44e56a-973a-43ed-83bf-34b761582fd8.jpg" width="320">

(10 件投入後にホームへ戻ると自動表示。最初の 7 件 (Aug 8〜14) が日付昇順で 1 画面に並ぶ)

</details>

### **一度だけ表示**: 一度表示した後は、アプリを再起動しても再表示されない。開発者メニューの「Reset Seven Mornings milestone」でリセットすると再表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

1. 「全回答を削除」→「七つの朝の節目をリセット」→「サンプル回答を投入 (10 日分)」で「七つの朝」が sheet で表示された (最初の 7 件 = 8/13〜8/19 が日付昇順)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/400b6d71-2122-4517-8b82-7d94268fc7df.png" width="320">

2. sheet を閉じ、`xcrun simctl terminate` → `xcrun simctl launch` で再起動。ホームが表示されるだけで sheet は出ない (アクセシビリティツリーにも seven_mornings_title が無い。回答は 10 件のまま「答えた日数 10日」)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/3eba1593-b966-4a64-97c7-913b76c5619d.png" width="320">

3. 開発者メニューの「七つの朝の節目をリセット」をタップすると、その場で sheet が再表示された

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/a6f600c0-a8e0-4c61-9d82-734fea7cd742.png" width="320">

</details>

### **無料枠制限を適用しない**: 8 日以上前になった回答も、無料状態のままこの画面では表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/eb44e56a-973a-43ed-83bf-34b761582fd8.jpg" width="320">

(無料状態のまま、ジャーナルでは非表示になる Aug 8〜10 (8 日以上前) の回答もこの画面には表示されている)

</details>

</details>

---

## 2. 共有カード導線

- [x] **行タップで共有カード**: 回答行のどこをタップしても AnswerShareCardPage が sheet で開く
  - 自動化: manual（sheet 遷移の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **行タップで共有カード**: 回答行のどこをタップしても AnswerShareCardPage が sheet で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/84719a9c-5b33-45ca-8293-32feabd7b903.jpg" width="320">

</details>

</details>

---
