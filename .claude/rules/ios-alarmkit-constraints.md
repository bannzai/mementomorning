---
paths:
  - "MementoMorning/**/*.swift"
---

# iOS 通知・AlarmKit 制約ルール

取り込み元: bannzai/Alarmy の `ios-notification-constraints.md`。制約の一次検証は Alarmy リポジトリと iOS 26.5 SDK の swiftinterface で実施済み(経緯: https://github.com/bannzai/ideamemo/issues/187 のコメント)。

## AlarmKit（iOS 26+）の制約（事実）

1. **iOS 26.0+ 専用。** `#available(iOS 26.0, *)` ガード必須
2. **NSAlarmKitUsageDescription が Info.plist に必須**
3. **件数上限あり**（`AlarmError.maximumLimitReached`）。バックアップアラームは 2〜3 本に抑える
4. **cancelAll は存在しない。** UUID 個別キャンセルのみ。ID の対応付けを永続化しておく
5. **AlarmMetadata 準拠型で ID 対応付けをする。** app と Widget Extension の両ターゲットに含める
6. **バックグラウンド wake しない**
7. **サイレントモード・集中モードを突破して鳴る**
8. **スワイプ消去は検知不可。** stopIntent も通らない
9. **シミュレータでは sound `.default` だと鳴らない癖がある。** 発火確認は画面表示で判定する
10. **システムのアラーム UI の停止ボタンは消せない・差し替えられない。** iOS 26.1 で `AlarmPresentation.Alert` の `stopButton` は deprecated になり、停止 UI はシステム標準描画

## Memento Morning での運用ルール（方針）

1. **「答えるまで止まらない」は stopIntent 再スケジュール方式で実現する。** `AlarmConfiguration` の `stopIntent`（LiveActivityIntent）の perform() で、未回答なら数分後のアラームを再登録する。`openAppWhenRun = true` で停止と同時に質問画面を開く。回答した時だけ全アラームをキャンセルする
2. **スワイプ消去の保険として、アラーム登録時点でバックアップアラームを 2〜3 本先に仕込む二段構えにする**（制約 3・8 への対応）
3. **再スケジュールは「全キャンセル → 全再登録」の冪等方式。** 差分更新はしない（cancelAll がないため登録済み UUID の永続化が前提）
4. **再スケジュールはリアクティブにせず手続的に明示呼び出しする。** 状態変化検知の自動実行は不意の解除・登録がアンコントローラブルになるため避ける
5. **UserNotifications（夜リマインド等）と併用する場合、主（AlarmKit）のスケジュールを妨げないよう相手側のエラーは隔離する**
6. **stopIntent の perform() 内からの `schedule()` が background でも通るかは実機未検証。** 実装着手時の最初の検証項目とし、検証結果をこのルールに追記する
   - **検証結果 (2026-08-13、issue #3、シミュレータ)**: stopIntent の perform() 自体がシミュレータ上で一度も実行されなかったため、background 云々を検証する以前の段階でブロックされた。アラーム発火中に停止操作 (スワイプ/タップ) を行うと、unified log に `Could not find an intent with identifier StopAlarmIntent, mangledTypeName: ...` が出て型解決に失敗し、perform() は未実行・openAppWhenRun によるアプリ前面化も発生しない。`struct` を `public` にする既知の workaround (Apple Developer Forums: https://developer.apple.com/forums/thread/746696 ) を適用しても解消せず、debug dylib 分離の有無 (`ENABLE_DEBUG_DYLIB`) やアプリの完全アンインストール→クリーン再インストールでも解消しなかった (計 6 パターンで再現)。Widget Extension を追加すれば解決する可能性があるが未検証 (参考: bannzai/Alarmy は `AlarmyWidget` という Widget Extension を持ち、そのコメントに「AlarmMetadata 型は両ターゲット必須」とある)。実機でも同じ現象が起きるかは未検証。stopIntent の実装自体 (LiveActivityIntent 準拠 + openAppWhenRun = true) は完了しているが、実行経路の検証は issue #2 (stopIntent の perform() 内 schedule() が background で通るか実機検証) に引き継ぐ

## UserNotifications（夜リマインド用）の制約（事実）

1. **保留中通知は最大64件。** 超過分は直近64件のみ保持される
   - ref: https://developer.apple.com/documentation/usernotifications
2. **カスタムサウンドは AIFF 系のみ。** サイレントモード突破は不可（Critical Alerts の申請が必要）
3. **件数管理は定数設計で行う。** 実行時チェックではなく「スケジュール日数 × 通知種別数が上限内に収まる」ように定数を設計する
