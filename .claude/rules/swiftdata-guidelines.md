---
paths:
  - "MementoMorning/**/*.swift"
---

# SwiftData ガイドライン

Memento Morning における SwiftData の使用方針。取り込み元: bannzai/Alarmy の同名ルール（Focus リポジトリで実証済みのノウハウが基）。
DB はローカルの SwiftData のみ（サーバー DB なし。documents/adr/0001-local-only-swiftdata-revenuecat-infra.md 参照）。

## 1. PersistenceController パターン

永続化層は `@MainActor struct PersistenceController` のシングルトンで管理する。

- `static let types: [any PersistentModel.Type]` に全モデルを列挙する。新しいモデルを追加したらここにも追加する
- `Schema(types)` でスキーマを構築する
- テスト / Preview 環境では `isStoredInMemoryOnly: true` でメモリ内 DB を使用する
- Widget 等の Extension とデータを共有する場合は `groupContainer` で App Groups を指定する

```swift
@MainActor struct PersistenceController {
  static let types: [any PersistentModel.Type] = [
    MorningAnswer.self,
    // 新しいモデルはここに追加
  ]
  static let schema = Schema(types)
  static let shared = PersistenceController()
  let container: ModelContainer
}
```

## 2. @Model 定義の慣習

- `@Model final class` で宣言する
- `@Attribute(.unique) var id: UUID` で一意な ID を持たせる
- `createdDateTime` はデフォルト値 `Date.now` で宣言する
- 外部から更新されるプロパティは `private(set)` にし、ドメインメソッド経由で更新する
- ドメインメソッド内で必ず `updatedDateTime = .now` を更新する（`.claude/rules/coding-rules-entity.md` 参照）

## 3. マイグレーション戦略

### 方針: 軽量マイグレーションに頼る

- `VersionedSchema` / `SchemaMigrationPlan` は使わない
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

- `#Preview` ではなく `PreviewProvider` を使用する
- `PersistenceController.shared.container` から container を取得し、`ModelContext(container)` で modelContext を作成する
- テストデータは `modelContext.insert()` で追加し、必ず `try! modelContext.save()` を呼ぶ
- View に `.modelContainer(container)` modifier を付ける
- `let _ =` で戻り値を破棄し（警告回避）、コメントでどのようなデータかを補足する
