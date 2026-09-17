# TikTok / YouTube Shorts の運用案 (Shipaton 2026 Most Viral App 向け)

作成日: 2026-09-16。締切 2026-10-01 15:45 JST までの 2 週間で回す前提。

## 根拠にした事実

- Most Viral App (Noise) の公式基準は Virality (話題化したか) / Scalability (同じ形式を繰り返せるか) / Conversion relevance (発信が製品価値を伝え DL につながったか) の 3 つ ( https://revenuecat-shipaton-2026.devpost.com/rules )
- 2025 の同賞 1 位 ReadHim は Instagram のミーム垢 (520 万再生) と 230 万フォロワーの TikTok インフルエンサー起用、3 位 MemoLune は 100 日間の公開制作と PyCon JP 基調講演でのライブ公開。#BuildInPublic 1 位 Gurwi はほぼ毎日投稿し、Figma の試作を見せた最初の動画が 25 万再生、提出直前まで待って最新の数字を添えた ( https://www.revenuecat.com/blog/company/shipaton-2025-winners , https://www.revenuecat.com/blog/company/gurwi-build-in-public-shipaton )
- YouTube Shorts は 3 分以内・縦 9:16 なら自動で Shorts 扱い。ライセンス音源は 60 秒まで ( https://www.descript.com/blog/article/how-long-can-youtube-shorts-be )。デモ動画の BGM は Musopen 提供のパブリックドメイン音源 (Vivaldi RV 425) なので制限にかからない
- TikTok の投稿 API は未審査クライアントだと非公開投稿しかできない ( https://developers.tiktok.com/docs/en/content-sharing-guidelines )。投稿は手動で行い、agent は素材・台本・キャプションを用意する
- App Store Connect のキャンペーンリンク (`?pt=&ct=&mt=8`) で流入元ごとの DL 数を App Analytics > Sources > Campaigns に出せる。リンクは ASC の Web UI で作る。集計は 24 時間以内の DL を計上し、5 件未満の指標は表示されない ( https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links/ )

## 方針

1. **同じ縦動画を TikTok / YouTube Shorts / Instagram Reels / X に横展開する**。1 本作って 4 か所に出す。編集の手間を増やさず投稿数を稼ぐ
2. **1 日 1 本を 14 日間**。Gurwi の「ほぼ毎日」と同じ密度。伸びた形式を翌日以降に繰り返す (Scalability の根拠になる)
3. **最初の 1〜2 秒に問いを置く**。完走率が再生数より配信に効くため、15〜30 秒に収める。60 秒のデモ動画は Shorts にそのまま出せるが、TikTok / Reels では冒頭の「Someday」カードを削って問いから始める
4. **コメント欄で答えてもらう**。「今日死ぬとしたら、何をやりたいか」は視聴者が自分の答えを書きたくなる問い。コメントへの動画返信で次の投稿を作る (UGC の種)
5. **流入元ごとにキャンペーンリンクを分ける**。`ct=tiktok` / `ct=shorts` / `ct=reels` / `ct=x` の 4 本。TikTok はキャプションのリンクが押せないためプロフィール欄に置き、動画内で「プロフィールのリンクから」と言う
6. **英語を主、日本語を従にする**。審査員は米国。字幕は英語、キャプションは英日併記。日本語版は同じ素材で字幕だけ差し替える

## 動画の形式 (素材はすべて既存のデモ動画の要素で作れる)

| # | 形式 | 尺 | 狙い | 素材 |
| --- | --- | --- | --- | --- |
| A | 止まらない目覚まし | 15 秒 | フック。アラーム → 停止 → 問いが出る → 答える → 止まる | demo の alarm (6s) + why-question (6s) + person 1 人 (4s) |
| B | 4 人の答え | 16 秒 | 感情。「定時で帰って妻と話す」「避けてた友達に謝る」など | person-worker / student / parent / creator の 4 カット |
| C | 今朝の答え (毎日) | 10〜20 秒 | 継続形式。作者本人が実際に朝答えた動画 (実顔・実寝室) + 共有カード。最も本物で最も繰り返せる | 毎朝の回答動画 (写真アプリのアルバム) |
| D | 問いだけ | 8 秒 | コメント誘発。黒画面に問いだけ。「あなたの答えをコメントで」 | why-question カード |
| E | 人生カレンダー | 12 秒 | 蓄積の可視化。粒が増えて 7 日目に「七つの朝」 | calendar クリップ + 七つの朝 |
| F | 作った理由・作り方 | 30〜60 秒 | #BuildInPublic。AlarmKit の停止ボタンを消せない制約と stopIntent 再登録の話、Claude Code での開発 | 画面収録 + 顔出しまたは声 |

冒頭の一文 (英語):

- A: `There's only one way to stop this alarm.`
- B: `Four people. One question. "If today were your last day, what would you want to do?"`
- C: `Day N. If today were my last day, what would I want to do?`
- D: `If today were your last day, what would you want to do? Answer in the comments.`
- E: `Every morning you answer becomes one dot.`
- F: `I built an alarm you can't stop until you answer one question.`

## 14 日の並び (9/17〜9/30)

| 日 | 形式 | 備考 |
| --- | --- | --- |
| 9/17 | A | リリース告知と同日。X はリリース投稿に 62 秒版を添付 |
| 9/18 | D | コメント欄を育てる |
| 9/19 | C (Day 1) | 以後、C は毎日ではなく週 3 本 |
| 9/20 | B | |
| 9/21 | F | 開発の話。#BuildInPublic 用 |
| 9/22 | C | |
| 9/23 | E | |
| 9/24 | C | |
| 9/25 | A の別カット (person を変える) | 伸びた形式の反復 |
| 9/26 | D へのコメント返信動画 | |
| 9/27 | C | |
| 9/28 | F の続き (数字の途中経過を含めてよい) | |
| 9/29 | 伸びた形式の再投稿 | |
| 9/30 | 締めの投稿 + 全投稿の数字を記録 | 提出は 10/1 15:45 JST まで |

## 計測と Devpost への転記

各投稿について次を `announcement-posts.md` の記録欄に残す。提出文の Most Viral セクションはこの表から書く。

- 投稿日時・URL・形式 (A〜F)
- 再生数・完走率 (TikTok / YouTube の Analytics)・いいね・コメント数
- キャンペーンリンク経由の DL 数 (App Store Connect > Analytics > Sources > Campaigns)
- トライアル開始数・購入数 (RevenueCat)
- 反応を受けて変えたこと (形式の反復・コメント返信・アプリの改善)

## 役割分担

agent が行う:

- A / B / D / E の切り出しと字幕焼き込み (ffmpeg。`demo-video/output/clips/` の収録済みクリップと人物カットを使う)
- 英日のキャプション・ハッシュタグ案
- F の台本
- 提出前日の数字の取得 (App Store Connect / RevenueCat)

ユーザーが行う (#163 に記録):

- App Store Connect でキャンペーンリンクを 4 本作る (Web UI のみ)
- TikTok / YouTube / Instagram / X への投稿と、プロフィール欄へのリンク設置
- C (毎朝の実回答) の撮影は日々の利用そのもの。公開してよい回答だけを選ぶ

## 16 秒の候補 3 案 (issue #167)

英語を主、日本語を従とし、同じ人物・音声・順序で編集テキストを差し替える。
固定テロップの正は `demo-video/config.shorts.json`、生成手順は `demo-video/README.md`。
最終採用と投稿はユーザーが行う。投稿先での実際の UI の被り・反応は未計測。

### 止める条件から入る案 (last-day)

英語キャプション:

> If today were your last day, what would you do? Say it before the day gets away from you. Memento Morning asks you every morning. Endless follow-up alarms are a Premium feature. What would your answer be?

日本語キャプション:

> 今日が最後の日なら、何をしたいですか。いつもの一日が始まる前に、声に出してみる。Memento Morning は毎朝その問いを届ける目覚ましです。回答するまで繰り返し鳴るアラームはプレミアム機能。あなたなら何と答えますか。

### 毎朝の問いから入る案 (one-question)

英語キャプション:

> One question before the notifications and the to-do list. If today were your last day, what would you want to do? Mine might be one conversation I've been putting off. What's yours?

日本語キャプション:

> 通知やタスクを見る前に、一つだけ。もし今日が最後の日なら、何をしたいですか。ずっと避けていた人と話す。それだけでもいい。あなたの答えも聞かせてください。

### 先送りから入る案 (someday)

英語キャプション:

> That unfinished song. That conversation. That thing you keep saving for someday. Memento Morning is an alarm that asks what matters today. Say one thing out loud. Endless follow-up alarms require Premium.

日本語キャプション:

> 作りかけの曲も、避けていた会話も、いつかやるつもりだったことも。Memento Morning は、今日何をしたいかを問いかける目覚ましです。一つだけ声に出して、今日の約束に。回答するまで繰り返し鳴るアラームはプレミアム機能です。

各投稿の末尾に、映像の由来を明示する文を付ける:

- 英語: `Illustrative demo with AI-generated fictional people and voices`
- 日本語: `架空の人物と音声をAIで生成したデモ映像です`

一般ハッシュタグ案:

- 英語: `#MementoMorning #MementoMori #MorningRoutine #IntentionalLiving`
- 日本語: `#MementoMorning #朝の習慣 #今日を大切に #目覚まし`

イベント用 `#Shipaton2026` は **仮置き・公式ハッシュタグ未確認**。
#163 で確認するまでは公式タグとして扱わず、投稿時の必須タグ欄へ転記しない。

## セッション再開

```sh
cd /Users/bannzai/ghq/github.com/bannzai/mementomorning
claude --resume 7a892c6e-f0f6-400e-b187-3936c50b4682
```
