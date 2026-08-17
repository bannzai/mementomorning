---
feature: LifeCalendar
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# LifeCalendar QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/6 (受け入れ条件)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 回答した日がグリッドに反映される | 回答済みの日の粒 |
| S2 | 誕生日等の設定がなくても破綻しない (未設定時のデフォルト表示) | グリッドの表示範囲 |

## 1. グリッド表示

- [ ] **回答済みの日の粒**: 回答した日 (開発者メニューの Seed sample answers で投入) が白い粒、未回答の日が薄い粒で表示される
  - 自動化: manual（粒の配色の目視確認）
- [ ] **今日の粒のリング**: 今日の粒にだけ夜明け色のリングが付く
  - 自動化: manual（配色の目視確認）
- [ ] **グリッドの表示範囲**: 誕生日等の設定なしで、最古の回答の週から今日の週までのグリッドが破綻なく表示される (週 = 1 行 × 7 マス)
  - 自動化: manual（画面表示の目視確認。日付列の導出ロジックは MementoMorningTests/LifeCalendarDatesTests.swift がカバー済み）
- [ ] **初期スクロール位置**: 履歴が画面を超える件数でも、開いた時に今日の週 (末尾) が見えている
  - 自動化: manual（スクロール位置の目視確認）
- [ ] **答えた朝の件数**: フッターに「答えた朝 N」が全期間の回答数で表示される
  - 自動化: manual（件数表示の目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **回答済みの日の粒**: 回答した日 (開発者メニューの Seed sample answers で投入) が白い粒、未回答の日が薄い粒で表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **今日の粒のリング**: 今日の粒にだけ夜明け色のリングが付く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **グリッドの表示範囲**: 誕生日等の設定なしで、最古の回答の週から今日の週までのグリッドが破綻なく表示される (週 = 1 行 × 7 マス)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **初期スクロール位置**: 履歴が画面を超える件数でも、開いた時に今日の週 (末尾) が見えている

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **答えた朝の件数**: フッターに「答えた朝 N」が全期間の回答数で表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---
