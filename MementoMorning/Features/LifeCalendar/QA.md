---
feature: LifeCalendar
verification: mobile-mcp
last_verified_commit: 2824d8aab92be555347c4c93a7c02b699cbb2e2e
last_verified_at: 2026-08-17
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

- [x] **回答済みの日の粒**: 回答した日 (開発者メニューの「Delete all answers」→「Seed sample answers」で投入) が白い粒、未回答の日が薄い粒で表示される
  - 自動化: manual（粒の配色の目視確認）
- [x] **今日の粒のリング**: 今日の粒にだけ夜明け色のリングが付く
  - 自動化: manual（配色の目視確認）
- [x] **グリッドの表示範囲**: 誕生日等の設定なしで、最古の回答の週から今日の週まで (回答歴が浅い場合は最低 13 週分) のグリッドが破綻なく表示される (週 = 1 行 × 7 マス。LifeCalendarDates.swift の仕様)
  - 自動化: manual（画面表示の目視確認。日付列の導出ロジックは MementoMorningTests/LifeCalendarDatesTests.swift がカバー済み）
- [ ] **初期スクロール位置**: 履歴が画面を超える件数でも、開いた時に今日の週 (末尾) が見えている
  - ⏭️ スキップ: 開発者メニューで投入できる回答は 10 日分 (13 週の最低保証グリッドに収まる) で、履歴が画面を超える状態を作る手段が現状ない。長期履歴の投入手段ができたら確認する
  - 自動化: manual（スクロール位置の目視確認）
- [x] **答えた日数**: フッターに「答えた日数 N日」が全期間の回答数で表示される。英語では 1 件のときだけ単数形 (1 morning answered) になる
  - 自動化: manual（件数表示の目視確認）
  - 確認範囲: 複数件 (10 mornings answered) を確認済み。1 件の単数形は issue #50 で対応し、ホームのフッター (同じ文言) で確認した

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **回答済みの日の粒**: 回答した日 (開発者メニューの「Delete all answers」→「Seed sample answers」で投入) が白い粒、未回答の日が薄い粒で表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/a91e72fd-c640-46ff-9e9c-7f18f4b0a5f3.jpg" width="320">

(投入した 10 日分が白い粒、未回答が暗い粒)

</details>

### **今日の粒のリング**: 今日の粒にだけ夜明け色のリングが付く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/a91e72fd-c640-46ff-9e9c-7f18f4b0a5f3.jpg" width="320">

</details>

### **グリッドの表示範囲**: 誕生日等の設定なしで、最古の回答の週から今日の週まで (回答歴が浅い場合は最低 13 週分) のグリッドが破綻なく表示される (週 = 1 行 × 7 マス。LifeCalendarDates.swift の仕様)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/a91e72fd-c640-46ff-9e9c-7f18f4b0a5f3.jpg" width="320">

(回答歴 10 日のため最低保証の 13 週分が表示され、破綻なし)

</details>

### **初期スクロール位置**: 履歴が画面を超える件数でも、開いた時に今日の週 (末尾) が見えている

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **答えた日数**: フッターに「答えた日数 N日」が全期間の回答数で表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/a91e72fd-c640-46ff-9e9c-7f18f4b0a5f3.jpg" width="320">

(全期間 10 件で「10 mornings answered」)

</details>

</details>

---
