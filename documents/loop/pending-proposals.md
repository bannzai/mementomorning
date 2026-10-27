# 週次の承認を待つ方向性の文書への変更提案

- [P-2026-10-27-1] 判定基準の行の追加: 指標「直近14日の新規顧客数」、計測元 `bash ~/.agents/skills/product-loop/scripts/read-dashboard-metric.sh --repo bannzai/mementomorning --metric new_customers --field new_customers --days 14 --agg sum`、継続のしきい値 `>= 1`、打ち切り条件 `< 1 x2` / 背景: 公開から 6 週間、ストアの評価・レビューが 0 件のままで、今の判定基準 (低評価レビュー数) は悪化していないことしか示せない。bannzai/dashboard が RevenueCat の指標を日次で集めるようになり、直近 14 日にも新規顧客が入っていることが読めた (有料の購読はまだ無い)。新規の利用者が途絶えたかを判定に使うため、現状維持なら継続・2 回続けて途絶えたら打ち切りの行を足す
