# リリース告知と #BuildInPublic 用の投稿案

App Store 公開 (2026-09-15) の告知投稿の下書きと、投稿後の記録欄。Devpost 提出文の「Build in public timeline」はこのファイルの記録欄から転記する。

前提:

- 数字 (DL 数・売上・継続率) は計測するまで書かない
- 実在人物の名前・引用は使わない (documents/PROJECT.md の判断)
- 無料トライアルは年額プランだけ。「7 日間無料」を単独で書かず必ず「年額プランのみ」を添える
- iOS 26 以上のみ対応。投稿に必ず書く (インストールできない人からの問い合わせを防ぐ)
- 動画は `demo-video/output/memento-morning-demo-people.mp4` (62 秒) を X の投稿に直接添付する (X の動画上限は 140 秒)。YouTube リンクより再生されやすく、Most Viral App の根拠にもなる
- ハッシュタグ: Devpost の公式ページは #BuildInPublic 用のタグ・メンション先を指定していない。投稿前に RevenueCat の X アカウントか Shipaton Discord で今年の公式タグを確認して差し替える (下書きでは `#Shipaton` `#BuildInPublic` を仮置き)

## 日本語: リリース投稿

```text
Memento Morning をリリースしました

毎朝「今日死ぬとしたら、何をやりたいか」に答えないと止まらない目覚ましです
答えは動画で残り 人生カレンダーに一粒ずつ積もります

iOS 26 以上 / 無料 (年額プランのみ 7 日間無料トライアル)

https://apps.apple.com/jp/app/id6801673264
```

添付: デモ動画 (62 秒)

## 日本語: スレッド (リリース投稿への返信で続ける)

1. なぜ作ったか

```text
【要記入: 作者本人の動機。例: 自分が毎朝を惰性で始めていた実感、やりたいことを先送りしてきた経験。一般論ではなく一人称の事実で書く】
```

2. 仕組み

```text
止め方は一つだけ
インカメラに映る自分の顔の上に問いが出て 答えを話して録画を止めるとアラームが止まります
動画は写真アプリのアルバムに保存され 話した内容は端末内で文字起こしされて「今朝のことば」になります
サーバーには何も送りません
```

3. 世界観

```text
炎も バッジも 紙吹雪もありません
あるのは静かな問いと あなたの答えだけ
答えた朝は人生カレンダーに白い粒として残り 7 日目の朝に初めて 7 つの答えが一枚に並びます
```

4. 夜

```text
夜 21 時に「守れてますか?」と一度だけ聞きます
やれた日も やれなかった日も そのまま残ります
```

5. 開発について

```text
iOS 26 の AlarmKit で作りました
システムの停止ボタンは消せないので 停止時に走る stopIntent で未回答なら数分後のアラームを再登録し 回答した時だけ全部キャンセルする作りです
```

6. Shipaton

```text
RevenueCat の Shipaton 2026 に応募します
実装は Claude Code と進めました

https://bannzai.github.io/mementomorning/
#Shipaton #BuildInPublic
```

## English: launch post

```text
Memento Morning is out on the App Store

An alarm clock that won't stop until you answer one question
"If today were your last day, what would you want to do?"

iOS 26+ / Free (7-day free trial on the yearly plan only)

https://apps.apple.com/us/app/memento-morning/id6801673264
```

Attachment: demo video (62 s)

## English: thread

1. Why

```text
[TO FILL IN: the maker's first-hand motivation, in first person. No generic market talk.]
```

2. How it works

```text
There is only one way to stop it.
The question appears over your front camera. You say your answer, stop recording, and the alarm stops.
The video goes to your Photos album. The transcript becomes "this morning's words," done on device. Nothing is sent to a server.
```

3. The tone

```text
No confetti. No badges. No streaks on fire.
Just a quiet question and your answers.
Each answered morning becomes a white dot on your life calendar. On the seventh morning, your seven answers appear together for the first time.
```

4. Evening

```text
At 9 pm it asks one thing: "Did you keep today's answer?"
The days you did and the days you didn't both stay as they are.
```

5. Build notes

```text
Built on iOS 26 AlarmKit.
The system stop button can't be removed, so the stopIntent re-schedules a follow-up alarm a few minutes later if you haven't answered, and cancels everything only when you do.
```

6. Shipaton

```text
Entering RevenueCat Shipaton 2026. Built with Claude Code.

https://bannzai.github.io/mementomorning/
#Shipaton #BuildInPublic
```

## 文字数 (X の重み付き換算。上限 280。2026-09-16 計測)

CJK・全角は 2、URL は 23 で数えた値。無料アカウントでもすべて 1 投稿に収まる。

| 投稿 | 文字数 |
| --- | --- |
| 日本語: リリース投稿 | 245 |
| 日本語 1. なぜ作ったか (要記入の仮文) | 132 |
| 日本語 2. 仕組み | 231 |
| 日本語 3. 世界観 | 159 |
| 日本語 4. 夜 | 90 |
| 日本語 5. 開発について | 170 |
| 日本語 6. Shipaton | 122 |
| English: launch post | 243 |
| English 1. Why (placeholder) | 89 |
| English 2. How it works | 265 |
| English 3. The tone | 227 |
| English 4. Evening | 121 |
| English 5. Build notes | 201 |
| English 6. Shipaton | 108 |

## 投稿の記録 (Devpost の Build in public timeline に転記する)

投稿したら日時・URL・反応・反応を受けて変えたことを追記する。提出直前にまとめて作らない。

| 日時 (JST) | 投稿 URL | 内容 | 反応 (いいね・RT・コメント) | 反応を受けて変えたこと |
| --- | --- | --- | --- | --- |
| | | | | |

## セッション再開

```sh
cd /Users/bannzai/ghq/github.com/bannzai/mementomorning
claude --resume 7a892c6e-f0f6-400e-b187-3936c50b4682
```
