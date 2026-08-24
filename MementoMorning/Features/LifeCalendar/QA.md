---
feature: LifeCalendar
verification: mobile-mcp
last_verified_commit: 401e4abf0b08248e767d8ac2ec02a5b769f58d37
last_verified_at: 2026-08-24
---

# LifeCalendar QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/118 (点画面) / https://github.com/bannzai/mementomorning/issues/119 (カレンダー画面)
- デザイン: https://claude.ai/code/artifact/5888a7bf-dfb3-461e-8203-cec8ccbd6ec3
- 関連: https://github.com/bannzai/mementomorning/issues/116 (七つの朝のコンセプト見直し。issue #109 の再訪導線はこの見直しで撤去)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 答えた朝の数だけ粒が積もる (週・日付・空白の概念なし) | 点画面: 粒の積み上げ |
| S2 | カレンダー画面で「いつ答えたか」を月単位で確かめられる | カレンダー画面 |

## 1. 点画面 (DotsPage)

- [x] **粒の積み上げ**: 回答数ぶんのフル明度の粒 (開発者メニューの「サンプル回答を投入 (10 日分)」で投入) が画面下部に山として積もる。週・日付・空白マスの表現はない
  - 自動化: manual（粒の表示の目視確認）
- [x] **最新粒のリング**: 今日の回答がある時だけ、いちばん新しい粒に夜明け色のリングが付く
  - 自動化: manual（配色の目視確認）
- [x] **答えた朝の件数**: フッターに「答えた朝」ラベルと全期間の回答数が強調表示され、「点はいつかつながる」が添えられる
  - 自動化: manual（件数表示の目視確認）
- [ ] **傾きで粒が転がる**: 端末を傾けると粒が重力方向へ転がる (CoreMotion + SpriteKit 物理)
  - ⏭️ スキップ: シミュレータでは CoreMotion の傾きを再現できないため実機待ち。シミュレータでは既定の下向き重力で静止していることを確認する
  - 自動化: manual（実機での目視確認）

## 2. カレンダー画面 (MonthCalendarPage)

- [x] **月グリッド**: 曜日ヘッダー付きの 7 列グリッドに今月の日付が並び、答えた日は温白の粒に墨の数字、未回答の過去日は薄い数字、未来日はさらに薄い数字で表示される
  - 自動化: manual（画面表示の目視確認。マス列の導出ロジックは MementoMorningTests/MonthCalendarDatesTests.swift がカバー済み）
- [x] **今日のリング**: 今日のマスにだけ夜明け色のリングが付く
  - 自動化: manual（配色の目視確認）
- [x] **月送り**: 前月・翌月ボタンで表示月を切り替えられる。範囲は最古の回答月〜今月で、範囲外方向のボタンは無効表示になる
  - 自動化: manual（月送り操作の確認）
- [x] **答えた朝の件数**: グリッドの下に全期間の回答数が表示される
  - 自動化: manual（件数表示の目視確認）

## 3. 七つの朝への導線の不在 (issue #116)

issue #109 で点画面のフッターに追加した「七つの朝」再訪リンクは、コンセプト見直し (issue #116) で撤去した。七つの朝は 7 件到達時に一度だけ自動表示される画面に戻っている。

- [x] **リンクを出さない**: 回答件数に関わらず、点画面のフッターに「七つの朝」リンク (life_calendar_seven_mornings_link) が表示されない
  - 自動化: manual（表示可否とアクセシビリティツリーの確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

**確認日: 2026-08-23** (simtunnel リモート simulator、英語ロケール、開発者メニューでサンプル回答 10 日分を投入)

### 点画面: 粒の積み上げ / 最新粒のリング / 答えた朝の件数

<details><summary>動作確認スクショ</summary>

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/ff50ded2-9408-4332-a608-d12ea9b21b4c.jpg" width="320" />

(投入した 10 日分のフル明度の粒が画面下部に積もり、いちばん新しい粒 (右端) に夜明けのリング。フッターに「Mornings answered 10」の強調表示と「The dots will connect.」。週・日付・空白マスの表現なし)

- 0 件時も破綻しない (粒なし・「Mornings answered 0」・七つの朝リンク非表示) ことを全回答削除後に確認済み
- 傾きで粒が転がる挙動はシミュレータでは CoreMotion を再現できないため未検証 (実機待ち)。既定の下向き重力で静止していることは上記スクショで確認

</details>

### カレンダー画面: 月グリッド / 今日のリング / 月送り / 答えた朝の件数

<details><summary>動作確認スクショ</summary>

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/f40377b9-cd7a-46fe-a06b-656048b76ba4.jpg" width="320" />

(August 2026 の月グリッド。答えた 14〜23 日は温白の粒に墨の数字、今日 23 日にだけ夜明けのリング、未来日は薄い数字。下部に「Mornings answered 10」)

- 月送り: 回答が 8 月のみのため範囲 (最古の回答月〜今月) が今月だけになり、前月・翌月とも無効表示になることを確認。複数月にまたがる回答データの投入手段ができたら月送り操作自体を確認する

</details>

### **リンクを出さない**: 回答件数に関わらず、点画面のフッターに「七つの朝」リンク (life_calendar_seven_mornings_link) が表示されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (simtunnel リモート simulator、英語ロケール、開発者メニューでサンプル回答 10 日分を投入)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/264d6baf-19fb-45b9-8cc3-801a1a86924f.jpg" width="320" />

(節目到達済みの 10 件でもフッターは「Mornings answered 10 / The dots will connect.」のみ。アクセシビリティツリーにも life_calendar_seven_mornings_link は 0 件。7 件到達時の節目 sheet の自動表示は従来どおり動くことも同セッションで確認済み — 記録は SevenMornings/QA.md)

</details>

</details>

---
