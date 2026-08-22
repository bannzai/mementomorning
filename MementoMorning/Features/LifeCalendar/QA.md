---
feature: LifeCalendar
verification: mobile-mcp
last_verified_commit: 1f02d771321e3bd52b54d9d5bce25dac0c5ad57e
last_verified_at: 2026-08-23
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
- [x] **答えた日数**: フッターに「答えた日数 N日」(英語では N mornings answered) が全期間の回答数で、キャプションより強い書体 (15pt medium) で表示される (issue #110)。英語では 1 件のときだけ単数形 (1 morning answered) になる
  - 自動化: manual（件数表示の目視確認）
  - 確認範囲: 複数件 (10 mornings answered) を確認済み。1 件の単数形は issue #50 で対応し、ホームのフッター (同じ文言) で確認した
- [x] **月ラベル**: 月初 (1 日) を含む週の行頭に月名 (Jun / Jul / Aug) が表示され、グリッド最上段の週と 1 月には年が併記される (May 2026)。基準日の導出ロジックは MementoMorningTests/LifeCalendarDatesTests.swift がカバー済み (issue #110)
  - 自動化: manual（ラベル表示の目視確認）
- [x] **曜日ヘッダー**: グリッドの列と同じ並び (firstWeekday 起点) で曜日記号 (英語 S M T W T F S) がグリッド直上に表示される (issue #110)
  - 自動化: manual（ヘッダー表示の目視確認）
  - 確認範囲: 履歴が浅くグリッドが中央寄せの状態でグリッド直上に付くことを確認済み。履歴が画面を超える時のスクロール上部固定 (pinned section header) は、長期履歴の投入手段が現状ないため未検証 (「初期スクロール位置」と同じ制約)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **回答済みの日の粒**: 回答した日 (開発者メニューの「Delete all answers」→「Seed sample answers」で投入) が白い粒、未回答の日が薄い粒で表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/d7ea0919-b9a4-416d-952c-086ddc276c0b.jpg" width="320">

(投入した 10 日分が白い粒、未回答が暗い粒。グリッドはキャプションとフッターの間の中央に配置される)

</details>

### **今日の粒のリング**: 今日の粒にだけ夜明け色のリングが付く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/d7ea0919-b9a4-416d-952c-086ddc276c0b.jpg" width="320">

</details>

### **グリッドの表示範囲**: 誕生日等の設定なしで、最古の回答の週から今日の週まで (回答歴が浅い場合は最低 13 週分) のグリッドが破綻なく表示される (週 = 1 行 × 7 マス。LifeCalendarDates.swift の仕様)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/d7ea0919-b9a4-416d-952c-086ddc276c0b.jpg" width="320">

(回答歴 10 日のため最低保証の 13 週分が表示され、破綻なし)

</details>

### **初期スクロール位置**: 履歴が画面を超える件数でも、開いた時に今日の週 (末尾) が見えている

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **答えた日数**: フッターに「答えた日数 N日」(英語では N mornings answered) が全期間の回答数で表示される。英語では 1 件のときだけ単数形 (1 morning answered) になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/79d418e2-cba6-4944-be87-482e93132b35.jpg" width="320">

(全期間 10 件で「10 mornings answered」が 15pt medium の強調書体で表示される。英語設定の simtunnel で確認)

</details>

### **月ラベル**: 月初 (1 日) を含む週の行頭に月名が表示され、グリッド最上段の週と 1 月には年が併記される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/79d418e2-cba6-4944-be87-482e93132b35.jpg" width="320">

(最上段に「May 2026」(年併記)、月初を含む週に「Jun」「Jul」「Aug」。simtunnel で確認)

</details>

### **曜日ヘッダー**: グリッドの列と同じ並びで曜日記号がグリッド直上に表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/79d418e2-cba6-4944-be87-482e93132b35.jpg" width="320">

(S M T W T F S が粒の 7 列に整列してグリッド直上に表示される。スクロール時の上部固定は長期履歴の投入手段がないため未検証)

</details>

</details>

---
