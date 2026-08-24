# 0004. リリースビルドの開発者メニューは配布環境の実行時判定でゲートする

## Status
Accepted (2026-08-24)

## Context
検証用の状態作り込み (サンプルデータ投入・課金状態の強制・日時経過等) を行う開発者メニュー (`DebugMenuPage`) は、これまで `#if DEBUG` でリリースビルドから完全に除外していた (`.claude/rules/debug-menu-for-verification.md`)。

Shipaton 提出やベータテストでは TestFlight 配布 (Release 構成のバイナリ) を実機で検証する場面があるが、TestFlight は App Store 配布と同一の Release バイナリであり、`#if DEBUG` はコンパイル時に確定するためどちらのビルドでも開発者メニューが開けない。起動引数や環境変数で開発者メニューを解放する案は、リモート simulator (simtunnel) や実機の TestFlight 配布に渡す手段がなく、`~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md` の方針 (アプリ内 UI を第一候補にする) とも合わない。

一方で、開発者メニューにはプレミアム状態の強制 (`debugPremiumOverride`) など課金判定に影響する検証用フラグが含まれる。App Store 配布でこれを解放すると、UserDefaults を外部から書き換えられた場合に本番ユーザーの課金判定が偽装されうる。

## Decision
開発者メニューの導線と検証用フラグの効果を、StoreKit 2 の `AppTransaction.environment` によるアプリ内の実行時判定でゲートする (`DeveloperMenuGate.swift`)。

- `isDeveloperMenuUnlocked` は DEBUG ビルドで常に `true`、リリースビルドでは起動時に `AppTransaction` を取得し、`environment == .sandbox` (TestFlight 配布) の時だけ `true` になる。App Store 配布 (`.production`) では `false` のまま
- 判定結果はプロセスローカルな状態に持ち、`isDeveloperMenuUnlocked` は同期的に参照する (AppTransaction の取得は非同期のため)。UserDefaults へは永続化しない。永続化すると、TestFlight で `true` を保存したまま App Store 版へ更新した直後の起動で、非同期の再判定が完了するまで解放が残ってしまうため、プロセスごとに必ず閉じた状態 (`false`) から始める (PR #129 レビュー指摘)
- 設定画面 (`AlarmSettingPage`) のバージョン行の長押しに開発者メニューへの導線を追加し、`isDeveloperMenuUnlocked` が `false` なら反応しない
- `PremiumEntitlement.isPremium` の検証用上書き (`debugPremiumOverride`) や、疑似録画モード (`debugSimulateVideoAnswer`) の判定にも同じゲートを通す

## Consequences

**良い点:**
- TestFlight 配布のビルドでも simtunnel・実機を問わず開発者メニューから検証用の状態を作り込める
- App Store 配布では `isDeveloperMenuUnlocked` が `false` に固定されるため、検証用フラグが本番ユーザーの課金判定に影響しない
- 既存の `debug-menu-for-verification.md` の方針 (アプリ内 UI で状態を作り込む) をリリースビルドまで一貫させられる

**悪い点 / 引き受けるリスク:**
- `AppTransaction` の取得・検証に失敗した場合は解放しない側 (`false`) へ倒すため、ネットワーク不調時などに TestFlight でも一時的に開けないことがある
- 判定はアプリ起動のたびに非同期で行うため、TestFlight でも起動直後の判定完了までの一瞬は閉じた状態になる (安全側に倒した仕様)
