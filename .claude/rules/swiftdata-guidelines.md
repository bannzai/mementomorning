---
paths:
  - "MementoMorning/**/*.swift"
---

# SwiftData ガイドライン

Memento Morning における SwiftData の使用方針。取り込み元: bannzai/Alarmy の同名ルール（Focus リポジトリで実証済みのノウハウが基）。
DB はローカルの SwiftData のみ（サーバー DB なし。documents/adr/0001-local-only-swiftdata-revenuecat-infra.md 参照）。

## 1. PersistenceController パターン

永続化層は `@MainActor struct PersistenceController` のシングルトンで管理する（実体: `MementoMorning/Shared/Entity/Persistence.swift`）。

- 新しいモデルを追加したら `static let types: [any PersistentModel.Type]` にも追加する（Schema はここから構築される）
- テスト / Preview 環境では `isStoredInMemoryOnly: true` でメモリ内 DB を使う
- Widget 等の Extension とデータを共有する場合は `groupContainer` で App Groups を指定する

## 2. @Model 定義の慣習

- `@Model final class` で宣言し、`@Attribute(.unique) var id: UUID` で一意な ID を持たせる
- `createdDateTime` はデフォルト値 `Date.now` で宣言する
- 更新は `private(set)` + ドメインメソッド経由で行い `updatedDateTime` を更新する（`.claude/rules/coding-rules-entity.md` が SSOT）

## 3. マイグレーション戦略

軽量マイグレーションに頼る。`VersionedSchema` / `SchemaMigrationPlan` は使わない。

- 新規プロパティは「プリミティブ型の Optional」で追加する（SwiftData の自動軽量マイグレーションが適用される）
- 独自の Codable オブジェクトをプロパティとして保存しない（マイグレーションが困難になるため）
- 非 Optional のプリミティブ型を新規追加しない（既存データが nil でクラッシュする）

## 4. クエリ

- 履歴系（回答ログ等、時間経過で蓄積するモデル）の `@Query` / `FetchDescriptor` には必ず `fetchLimit` を設定する。Extension プロセスは 6MB のメモリ制限があるため、全件取得するとクラッシュする
- ユーザーの入力に応じてクエリ内容が変わる場合は `@Query` ではなく `FetchDescriptor` を使う View ラッパーで対応する（`@Query` は初期化時に条件が固定される）

## 5. App Extension (Widget 等) 内での SwiftData

- `Task` / `async` / `await` / `container.mainContext` を使わない（`mainContext` は `@MainActor` を要求するため Extension では使えない）
- `ModelContainer` を TimelineProvider のプロパティとして保持しない
- 関数内ローカルで `ModelContext(PersistenceController.shared.container)` を作成して同期的にアクセスする（Focus リポジトリ ADR-0004 で検証済み）

## 6. Preview での SwiftData

- `#Preview` ではなく `PreviewProvider` を使い、`PersistenceController.shared.container` から作った `ModelContext` にテストデータを `insert()` → `try! save()` して、View に `.modelContainer(container)` を付ける（既存の PreviewProvider を踏襲する）
- `let _ =` で戻り値を破棄し（警告回避）、コメントでどのようなデータかを補足する
