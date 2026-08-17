---
feature: AnswerEdit
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# AnswerEdit QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/25 (受け入れ条件「文字起こし結果を編集して保存できる」)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 文字起こし結果 (回答本文) を編集して保存できる | 編集して保存 |

## 1. 編集フロー

- [ ] **ホームからの導線**: 今日の回答がある状態で、ホームの「直す」リンク (home_today_answer_edit_link) をタップすると編集画面が sheet で開く
  - 自動化: manual（sheet 遷移の確認）
- [ ] **初期値の反映**: 編集画面のテキストフィールド (answer_edit_text_field) に編集対象の回答本文が初期表示される
  - 自動化: manual（表示値の目視確認）
- [ ] **編集して保存**: 本文を書き換えて「保存」(answer_edit_save_button) をタップすると sheet が閉じ、ホームの「今朝のことば」に編集後の本文が反映される
  - 自動化: manual（テキスト入力と反映の確認）
- [ ] **空文字の保存禁止**: 本文を空 (空白・改行のみ含む) にすると保存ボタンが無効になる
  - 自動化: manual（ボタンの活性状態の目視確認）
- [ ] **保存失敗時の挙動**: 保存に失敗した場合は画面が閉じず、エラー (answer_edit_save_error) が表示され再タップで再試行できる
  - 自動化: todo

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **ホームからの導線**: 今日の回答がある状態で、ホームの「直す」リンク (home_today_answer_edit_link) をタップすると編集画面が sheet で開く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **初期値の反映**: 編集画面のテキストフィールド (answer_edit_text_field) に編集対象の回答本文が初期表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **編集して保存**: 本文を書き換えて「保存」(answer_edit_save_button) をタップすると sheet が閉じ、ホームの「今朝のことば」に編集後の本文が反映される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **空文字の保存禁止**: 本文を空 (空白・改行のみ含む) にすると保存ボタンが無効になる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **保存失敗時の挙動**: 保存に失敗した場合は画面が閉じず、エラー (answer_edit_save_error) が表示され再タップで再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---
