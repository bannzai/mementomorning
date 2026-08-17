---
feature: SevenMornings
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
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
- [ ] **一度だけ表示**: 一度表示した後は、アプリを再起動しても再表示されない。開発者メニューの「Reset Seven Mornings milestone」でリセットすると再表示される
  - 自動化: manual（再起動と表示済みフラグの操作が必要）
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

（未実行）

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
