---
status: launched          # evaluating | building | launched | pivoting | retiring | retired
decision_date: 2026-10-13 # 次の判定日 (YYYY-MM-DD)。判定のたびに cycle_days 後へ進める
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
- [x] 90 日目「問い直し」(1 件目と 90 件目の回答を並べて問う。プレミアム限定。issue #187)
- [ ] 180 日・365 日の節目 (`documents/PROJECT.md` 37〜38 行の設計のみ。issue は未作成)

## デザインの方向

既存アプリのため Claude Design のモックは無い。現行の画面を正とし、`documents/PROJECT.md` の世界観の制約 (炎・バッジ・紙吹雪などのゲーミフィケーションの記号を使わない、実在人物名・スピーチの引用を使わない) に従う。

## 決めたこと

| 日付 | 場面 | 決めたこと | 決めた人 |
| --- | --- | --- | --- |
| 2026-09-29 | 既存アプリへの後付け | 下書きを agent が作成。bannzai が直すか黙認する。しきい値は 2026-09-29 時点の実測 (評価 0 件、直近 14 日の ★1〜2 レビュー 0 件) を基準に「現状維持なら継続、明確に落ちたら打ち切り」で置いた | agent |
| 2026-10-10 | 既存アプリへの後付け | Shipaton 2026 には応募しない。「必要な機能」から提出の項目を外した | bannzai |

## agent に任せること

文書に無い問いはすべて。RevenueCat の課金指標 (アクティブなサブスクリプション数・MRR) は、`.envrc` の v2 API key に `metrics/overview` の読み取り権限が付いた時に agent が判定基準へ足す (2026-09-29 時点の key は `/projects` の読み取りで 403)。
