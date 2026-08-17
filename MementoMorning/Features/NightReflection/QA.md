---
feature: NightReflection
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# NightReflection QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/8 (受け入れ条件) / https://github.com/bannzai/mementomorning/issues/26 (パーソナライズ)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 指定時刻に通知が届き、タップで振り返り画面が開く | 通知からの起動 |
| S2 | やれた / やれていない が MorningAnswer に記録される | やれた / やれていない の記録 |
| S3 | 当日回答がある日の夜リマインドに回答テキストが含まれる | 通知のパーソナライズ |
| S4 | 回答がない日は従来の文言で届く | 通知のパーソナライズ |
| S5 | 長文回答が通知で破綻しない (切り詰め確認) | 通知のパーソナライズ |

## 1. 通知

- [ ] **通知からの起動**: 夜リマインド通知 (開発者メニューの「Schedule night reminder in 1 minute」で 1 分後に発火) をタップすると、振り返り画面が sheet で開く
  - ⏭️ スキップ: リモート simulator (simtunnel) では通知バナーを捕捉できなかった (発火 70 秒後の 1 フレーム撮影ではバナーが消えた後かを判別できず、WDA からは通知センターも開けなかった)。ローカル simulator で確認する
  - 自動化: manual（通知の発火待ちとタップ操作が必要）
- [ ] **通知のパーソナライズ**: 当日回答がある日は通知本文に回答テキストが含まれ、回答がない日は汎用文言で届く。長文回答でも通知が破綻しない
  - 自動化: manual（通知の実表示の目視確認。本文組み立てのロジックは MementoMorningTests/NightReminderTests.swift がカバー済み）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **通知からの起動**: 夜リマインド通知 (開発者メニューの「Schedule night reminder in 1 minute」で 1 分後に発火) をタップすると、振り返り画面が sheet で開く

<details><summary>動作確認スクショ</summary>

（未実行）

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
