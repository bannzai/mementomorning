---
feature: ShareCard
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# ShareCard QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/7 (受け入れ条件)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 回答ログ / 節目画面から画像を共有できる | カードの表示 / share sheet での共有 |
| S2 | 日本語・英語どちらの回答でもレイアウトが崩れない | レイアウトの言語耐性 |

## 1. カードと共有

- [ ] **カードの表示**: ジャーナルまたは「七つの朝」の回答行をタップすると、日付と回答本文が入ったカードのプレビューが表示される
  - 自動化: manual（表示内容の目視確認）
- [ ] **share sheet での共有**: 「共有」ボタンで share sheet が開き、カードが 1 枚画像として共有できる
  - 自動化: manual（share sheet は OS UI のため目視確認）
- [ ] **レイアウトの言語耐性**: 日本語・英語どちらの回答本文でもカードのレイアウトが崩れない
  - 自動化: manual（見た目の崩れの目視確認。日英ロケールでの書き出しは MementoMorningTests/AnswerShareCardRenderTests.swift がカバー済み）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **カードの表示**: ジャーナルまたは「七つの朝」の回答行をタップすると、日付と回答本文が入ったカードのプレビューが表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **share sheet での共有**: 「共有」ボタンで share sheet が開き、カードが 1 枚画像として共有できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **レイアウトの言語耐性**: 日本語・英語どちらの回答本文でもカードのレイアウトが崩れない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---
