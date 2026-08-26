---
feature: LifeCalendar
verification: mobile-mcp
last_verified_commit: 75b0bf87eb1e52b1737ef435c61b32f36467f8b9
last_verified_at: 2026-08-26
---

# LifeCalendar QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/119 (カレンダー画面)。点画面 (issue #118) は issue #137 で削除した (背景に積もる粒がホームにあるため)
- デザイン: https://claude.ai/code/artifact/5888a7bf-dfb3-461e-8203-cec8ccbd6ec3
- 関連: https://github.com/bannzai/mementomorning/issues/116 (七つの朝のコンセプト見直し。issue #109 の再訪導線はこの見直しで撤去)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | カレンダー画面で「いつ答えたか」を月単位で確かめられる | カレンダー画面 |

## 1. カレンダー画面 (MonthCalendarPage)

- [x] **月グリッド**: 曜日ヘッダー付きの 7 列グリッドに今月の日付が並び、答えた日は温白の粒に墨の数字、未回答の過去日は薄い数字、未来日はさらに薄い数字で表示される
  - 自動化: manual（画面表示の目視確認。マス列の導出ロジックは MementoMorningTests/MonthCalendarDatesTests.swift がカバー済み）
- [x] **今日のリング**: 今日のマスにだけ夜明け色のリングが付く
  - 自動化: manual（配色の目視確認）
- [x] **月送り**: 前月・翌月ボタンで表示月を切り替えられる。範囲は最古の回答月〜今月で、範囲外方向のボタンは無効表示になる
  - 自動化: manual（月送り操作の確認）
- [x] **答えた朝の件数**: グリッドの下に全期間の回答数が表示される
  - 自動化: manual（件数表示の目視確認）
- [x] **日付タップで回答を開く**: 答えた日のマスをタップすると、その日の回答がジャーナルと同じ行 (AnswerLogRow) でグリッドの下に表示される (issue #130)。行のタップで共有カードが sheet で開き、別の日のタップで行が切り替わり、月送りで行は消える。無料枠 (直近 7 日) より前の答えた日はペイウォールが開き、未回答日はタップしても何も起きない
  - 自動化: manual（タップ後の表示の目視確認。日付から回答を引くロジックは MementoMorningTests/MorningAnswerTests.swift の testAnswerOfDay 系がカバー済み）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

**確認日: 2026-08-26** (simtunnel リモート simulator、英語ロケール、開発者メニューでサンプル回答 10 日分を投入。issue #137 の点画面削除 + カレンダー復活 (75b0bf8) 後の回帰確認)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/98751671-7e75-435e-8002-7a1b5993b00f.jpg" width="320" />

(ホームの Calendar リンクから遷移。August 2026 の月グリッドに答えた Aug 17〜26 が温白の粒 + 墨の数字で並び、今日 26 日にだけ夜明けのリング。下部に「Mornings answered 10」。回答が 8 月のみのため前月・翌月とも無効表示)

**確認日: 2026-08-23** (simtunnel リモート simulator、英語ロケール、開発者メニューでサンプル回答 10 日分を投入)

### カレンダー画面: 月グリッド / 今日のリング / 月送り / 答えた朝の件数

<details><summary>動作確認スクショ</summary>

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/f40377b9-cd7a-46fe-a06b-656048b76ba4.jpg" width="320" />

(August 2026 の月グリッド。答えた 14〜23 日は温白の粒に墨の数字、今日 23 日にだけ夜明けのリング、未来日は薄い数字。下部に「Mornings answered 10」)

- 月送り: 回答が 8 月のみのため範囲 (最古の回答月〜今月) が今月だけになり、前月・翌月とも無効表示になることを確認。複数月にまたがる回答データの投入手段ができたら月送り操作自体を確認する

</details>

### **日付タップで回答を開く**: 答えた日は共有カード、無料枠より前はペイウォール、未回答日は何も起きない (issue #130)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (simtunnel リモート simulator、英語ロケール・UTC。開発者メニューでサンプル回答 10 日分 = Aug 15〜24 を投入。UTC の今日は Aug 24 で、無料枠 7 日の可視範囲は Aug 18〜24)

答えた日 Aug 20 (無料枠内) のマスをタップ → その日の回答「Fix the bug that kept me up all night」の共有カードが sheet で開く:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/1da2950f-21a5-4c93-87c8-8a29367b3132.jpg" width="320" />

答えた日 Aug 15 (無料枠より前、9 日前) のマスをタップ → ペイウォールが開く (Test Store の価格表示):

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/10a4a76f-58f9-4d01-9baa-fe343fa8410e.jpg" width="320" />

未回答日 Aug 10 のマスをタップ → 何も開かずカレンダーのまま:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/05099689-526b-452c-8df4-59ba5601bc9e.jpg" width="320" />

- プレミアム状態 (答えた全日が共有カードで開ける) は未検証。判定は AnswerLogVisibility.isVisible の isPremium 分岐で、AnswerLogVisibilityTests がロジックをカバー済み

**再確認日: 2026-08-24** (PR #131 のレビュー対応 ca26175 後、simtunnel リモート simulator で回帰確認)

レビュー対応でタップのヒット領域をマス全体 (48pt 高) に広げ、回答の取得を表示と同じ辞書基準に統一した。答えた日 Aug 20 のマスの隅 (粒の円の外) をタップ → 共有カードが開く:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/34455af9-b364-49d9-9cec-17d152c7c6d8.jpg" width="320" />

- Aug 15 (無料枠より前) のタップ → ペイウォール、Aug 10 (未回答) のタップ → 無反応、カレンダーのレイアウトに変化なし、も同セッションで確認済み
- タイムゾーン変更をまたぐ実挙動 (保存後に端末 TZ を変えてタップ) は simulator では未検証。表示と取得が同一辞書になったことはコードとユニットテストで担保

**再確認日: 2026-08-25** (共有カード直開きから行表示への変更 5b3041d 後、simtunnel リモート simulator で確認。UTC の今日は Aug 25、サンプル回答は Aug 16〜25)

答えた日 Aug 20 のマスをタップ → ジャーナルと同じ行がグリッドの下に表示される:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/e021cafd-06f5-4834-920a-275708da16c4.jpg" width="320" />

その行をタップ → 共有カードが sheet で開く:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/f147fe50-acdd-445e-abad-48b1dfcd14d2.jpg" width="320" />

別の答えた日 Aug 24 をタップ → 行がその日の回答に切り替わる:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/43729bce-8019-4f76-9a7e-625f7e0d52ae.jpg" width="320" />

- Aug 16 (無料枠より前) のタップでペイウォールが開くことも同セッションで確認済み
- ジャーナル画面の行は AnswerLogRow への抽出のみで見た目・挙動は不変 (共有カード・動画導線とも既存実装の移設)
- 動画回答の行の「動画を見返す」導線はカレンダー側では未検証 (サンプル回答に動画がないため)。実装はジャーナルと同じ AnswerLogRow + AnswerVideoPlayerPage の既存パターン

</details>

</details>

---
