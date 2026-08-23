---
feature: LifeCalendar
verification: mobile-mcp
last_verified_commit: 38c26408b7964ab166d1853bf2918484e1cc1bfd
last_verified_at: 2026-08-24
---

# LifeCalendar QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/6 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/116 (七つの朝を後から見返す導線 issue #109 は、コンセプト見直しで撤去)

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
- [x] **答えた日数**: フッターに「答えた日数 N日」(英語では N mornings answered) が全期間の回答数で表示される。英語では 1 件のときだけ単数形 (1 morning answered) になる
  - 自動化: manual（件数表示の目視確認）
  - 確認範囲: 複数件 (答えた日数 10日) を確認済み。1 件の単数形は issue #50 で対応し、ホームのフッター (同じ文言) で確認した

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

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/d7ea0919-b9a4-416d-952c-086ddc276c0b.jpg" width="320">

(全期間 10 件で「答えた日数 10日」。日本語設定の simtunnel で確認)

</details>

</details>

---

## 2. 七つの朝への導線の不在 (issue #116)

issue #109 で追加した「七つの朝」再訪リンクは、コンセプト見直し (issue #116) で撤去した。七つの朝は 7 件到達時に一度だけ自動表示される画面に戻っている。

- [x] **リンクを出さない**: 回答件数に関わらず、フッターに「七つの朝」リンク (life_calendar_seven_mornings_link) が表示されない
  - 自動化: manual（表示可否とアクセシビリティツリーの確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **リンクを出さない**: 回答件数に関わらず、フッターに「七つの朝」リンク (life_calendar_seven_mornings_link) が表示されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (iPhone / iOS 26.2 ローカル simulator、英語ロケール、サンプル回答 10 件投入後)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/26188bc8-9cc3-4b87-aa93-597e97825f24.png" width="320">

(節目到達済みの 10 件でもフッターは「10 mornings answered / The dots will connect.」のみ。アクセシビリティツリーにも life_calendar_seven_mornings_link は 0 件)

</details>

</details>

---
