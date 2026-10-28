---
status: launched          # evaluating | building | launched | pivoting | retiring | retired
decision_date: 2026-11-10 # 次の判定日 (YYYY-MM-DD)。判定のたびに cycle_days 後へ進める
cycle_days: 14            # 判定の周期 (7 または 14)
veto_wait_hours: 12       # 公開後の無人ループの拒否権の待ち時間 (既定 12)
daily_issue_cap: 3        # 1 日に生成してよい改善 issue の上限 (意味の門。既定 3)
launched_at: 2026-09-15   # 公開日 (YYYY-MM-DD)。App Store の初回公開日
---

# 方向性: Memento Morning

## 仮説

朝起きられない人・内省を習慣にしたい人が、毎朝アラームを止める時に「今日死ぬとしたら何をやりたいか」にインカメラの動画かテキストで答える。アラームは獲得の入口で、売る物は毎朝の回答がたまった人生ジャーナル (プレミアム: 月額 ¥800 / 年額 ¥6,000 / 買い切り ¥9,800、RevenueCat) (出典: `documents/PROJECT.md` 3・10〜14 行、`fastlane/metadata/ja/description.txt`)。

## 判定基準

| 指標 | 計測元 (skill / コマンド) | 継続のしきい値 | 打ち切り条件 | 転換の条件 |
| --- | --- | --- | --- | --- |
| 直近14日の★1〜2レビュー数 | appstore-research skill: `bash ~/.agents/skills/appstore-research/scripts/fetch-reviews.sh 6801673264 --country jp --pages 1` の出力で `date` が直近 14 日かつ `rating` が 2 以下の行数 | <= 1 | >= 3 x2 | 低評価の内容がアラーム (止められない・鳴らない) に集中していたら、ジャーナルより先にアラームの信頼性を改善 issue の最優先にする |

平均評価は 2026-09-29 時点で 0 件のため判定基準に入れない。10 件を超えたら agent が `>= 4.0` / `< 3.5 x2` の行を足す。Crashlytics は `documents/adr/0001` で入れないと決めているため、クラッシュの指標は置かない。

## 必要な機能

- [x] AlarmKit のアラーム、答えるまで鳴り続ける追撃アラームとスヌーズ制限
- [x] 朝の問いへの回答 (インカメラ動画の録画と文字起こし、テキスト入力)
- [x] 夜の振り返りとリマインド、回答ログと編集、動画の再生
- [x] 人生カレンダー、7 日目「七つの朝」、30 日目「一ヶ月の手紙」、共有カード
- [x] オンボーディング、ペイウォール (RevenueCat)、ウィジェットと Live Activity
- [x] 90 日目「問い直し」(1 件目と 90 件目の回答を並べて問う。プレミアム限定。issue #187 / PR #189。最初のユーザーが 90 件に達する最短は 2026-12-13。App Store 版への反映は次のリリースで)
- [ ] 180 日の節目「まだ、やれていないこと」(`documents/PROJECT.md` 37 行の設計のみ。到達の最短は 2027-03-13 のため issue は未作成)
- [ ] 365 日の節目「365 の朝」(`documents/PROJECT.md` 38 行の設計のみ。書き出しアドオン (買い切り IAP) の商品設計が bannzai の判断として残る。到達の最短は 2027-09-14)

## デザインの方向

既存アプリのため Claude Design のモックは無い。現行の画面を正とし、`documents/PROJECT.md` の世界観の制約 (炎・バッジ・紙吹雪などのゲーミフィケーションの記号を使わない、実在人物名・スピーチの引用を使わない) に従う。

## 決めたこと

| 日付 | 場面 | 決めたこと | 決めた人 |
| --- | --- | --- | --- |
| 2026-09-29 | 既存アプリへの後付け | 下書きを agent が作成。bannzai が直すか黙認する。しきい値は 2026-09-29 時点の実測 (評価 0 件、直近 14 日の ★1〜2 レビュー 0 件) を基準に「現状維持なら継続、明確に落ちたら打ち切り」で置いた | agent |
| 2026-10-10 | 既存アプリへの後付け | Shipaton 2026 には応募しない。「必要な機能」から提出の項目を外した | bannzai |
| 2026-10-10 | 無人ループ | 節目の到達は 7 日・30 日と同じく回答件数で数える (90 日の節目は 90 件目の回答で表示し、公開日や初回回答日からの日数では数えない)。節目の issue は到達の最短日が近い順に 1 つずつ起票し、180 日・365 日は到達が 2027 年のため 2026-10-10 時点では起票しない | agent |
| 2026-10-13 | 判定日 | 継続。直近 14 日の ★1〜2 レビュー数は 0 (計測元 `fetch-reviews.sh 6801673264 --country jp --pages 1` が `No reviews found`。iTunes Lookup の評価件数も 0) で、継続のしきい値 `<= 1` を満たし打ち切り条件 `>= 3 x2` に当たらない。次の判定日は 2026-10-27。公開から 28 日で評価・レビューが 0 件のため、現在の判定基準は「悪化していない」ことしか示せず、課金指標 (RevenueCat) が取れるまで判定の材料が無い状態が続く | agent |
| 2026-10-27 | 判定日 | 継続。直近 14 日の ★1〜2 レビュー数は 0 (計測元 `fetch-reviews.sh 6801673264 --country jp --pages 1` が `No reviews found`。iTunes Lookup の評価件数も 0) で、継続のしきい値 `<= 1` を満たし打ち切り条件 `>= 3 x2` に当たらない。次の判定日は 2026-11-10。RevenueCat の指標は bannzai/dashboard の日次データから `read-dashboard-metric.sh` で読めるようになり、有料の購読はまだ無い。利用の行 (直近 14 日の新規顧客数) を判定基準に足す案を `documents/loop/pending-proposals.md` に積んだ | agent |

## agent に任せること

文書に無い問いはすべて。RevenueCat の課金指標 (アクティブなサブスクリプション数・MRR・新規顧客数等) は、bannzai/dashboard が日次で集めたデータを `bash ~/.agents/skills/product-loop/scripts/read-dashboard-metric.sh --repo bannzai/mementomorning --metric <指標> --field <列>` で読む (2026-10-27 に `mrr`・`active_subscriptions`・`new_customers` が `STATUS=ok` で読めた。v2 API key は 2026-10-27 に `.envrc` から 1Password の `.env.1password` の `REVENUECAT_PROJECT_CONFIGURATION_API_KEY_V2` へ移った (commit 2581444)。移る前の key は 2026-10-26 の無人ループで `project_configuration:projects:read` が無く 403。移った後の権限は未確認で、2026-10-29 の無人ループの `op run --env-file .env.1password -- rc_api.sh GET /projects` は 1Password の `authorization timeout` で止まった)。判定基準に足す行は週次の承認を経て反映する。
