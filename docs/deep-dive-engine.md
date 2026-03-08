# go-mysql-server クエリ実行エンジン詳細分析

[← README に戻る](../README.md)

---

dolthub/go-mysql-server の内部アーキテクチャ、主要インターフェース、クエリ実行パイプラインを詳細に分析する。DoltgreSQL がこのエンジンをどのように PostgreSQL 向けに適用しているかも含む。

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [クエリ実行パイプライン](#2-クエリ実行パイプライン)
3. [主要インターフェース](#3-主要インターフェース)
4. [メモリデータベース実装](#4-メモリデータベース実装)
5. [型システム](#5-型システム)
6. [組み込み関数](#6-組み込み関数)
7. [JOIN アルゴリズム](#7-join-アルゴリズム)
8. [Analyzer（最適化）](#8-analyzer最適化)
9. [拡張ポイント](#9-拡張ポイント)
10. [DoltgreSQL との統合](#10-doltgresqlとの統合)
11. [カスタムバックエンド構築手順](#11-カスタムバックエンド構築手順)
12. [Go製SQLエンジンの他の選択肢](#12-go製sqlエンジンの他の選択肢)

---

## 1. アーキテクチャ概要

go-mysql-server は5層構造のクエリ実行エンジンである:

```
┌──────────────────────────────────────────────┐
│  Layer 5: プロトコル層                        │
│  MySQL/PostgreSQL ワイヤープロトコル           │
├──────────────────────────────────────────────┤
│  Layer 4: RowExec（実行層）                   │
│  最適化済みプラン → RowIter チェーン           │
├──────────────────────────────────────────────┤
│  Layer 3: Analyzer（分析・最適化層）           │
│  50+ の最適化ルール適用                       │
├──────────────────────────────────────────────┤
│  Layer 2: PlanBuilder（計画構築層）            │
│  AST → sql.Node ツリー                       │
├──────────────────────────────────────────────┤
│  Layer 1: Parser（パーサー層）                │
│  SQL → AST (Vitess パーサー)                  │
└──────────────────────────────────────────────┘
```

### ストレージ非依存

go-mysql-server はストレージに依存しない設計。インターフェースを実装すれば任意のデータソース（ファイル、API、メモリ等）をバックエンドとして使用可能。

---

## 2. クエリ実行パイプライン

```
SQL文字列
    │
    ▼ Parse
AST（抽象構文木）
    │
    ▼ PlanBuilder
sql.Node ツリー（初期プラン）
    │
    ▼ Analyzer（50+ ルール）
    │  ├── 名前解決 (ResolveTable, ResolveColumn)
    │  ├── 型解決 (ResolveTypes)
    │  ├── フィルタ押し下げ (PushdownFilters)
    │  ├── インデックス選択 (SelectIndexes)
    │  ├── プロジェクション最適化 (PushdownProjections)
    │  └── その他 (Subquery最適化、定数畳み込み等)
    │
最適化済み sql.Node ツリー
    │
    ▼ RowExec
RowIter チェーン → 結果行
```

### 遅延評価（Lazy Evaluation）

```go
// RowIter プロトコル: 1行ずつ遅延的に取得
type RowIter interface {
    Next(ctx *sql.Context) (sql.Row, error)
    Close(ctx *sql.Context) error
}
```

各演算子（Filter, Project, Join等）は前段の RowIter をラップし、イテレーターチェーンを形成する:

```
Project(id, name)
  └── Filter(age > 20)
      └── TableScan(users)
```

---

## 3. 主要インターフェース

### 最小構成: 3インターフェース

カスタムデータベースを構築するために最低限必要なのは3つのインターフェース:

```
DatabaseProvider → Database → Table
```

### DatabaseProvider

```go
// DatabaseProvider はデータベースのコレクションを提供
type DatabaseProvider interface {
    // Database は名前でデータベースを返す
    Database(ctx *sql.Context, name string) (sql.Database, bool, error)
    // HasDatabase はデータベースの存在を確認
    HasDatabase(ctx *sql.Context, name string) bool
    // AllDatabases は全データベースを返す
    AllDatabases(ctx *sql.Context) ([]sql.Database, error)
}
```

### Database

```go
// Database はテーブルのコレクション
type Database interface {
    // Name はデータベース名を返す
    Name() string
    // GetTableInsensitive はテーブルを大文字小文字非区別で返す
    GetTableInsensitive(ctx *sql.Context, tblName string) (sql.Table, bool, error)
    // GetTableNames は全テーブル名を返す
    GetTableNames(ctx *sql.Context) ([]string, error)
}
```

### Table

```go
// Table はデータの読み取りインターフェース
type Table interface {
    // Name はテーブル名を返す
    Name() string
    // String はデバッグ用文字列を返す
    String() string
    // Schema はカラム定義を返す
    Schema() sql.Schema
    // Collation はテーブルの照合順序を返す
    Collation() sql.CollationID
    // Partitions はテーブルのパーティションを返す
    Partitions(ctx *sql.Context) (sql.PartitionIter, error)
    // PartitionRows はパーティション内の行を返す
    PartitionRows(ctx *sql.Context, partition sql.Partition) (sql.RowIter, error)
}
```

### Schema（カラム定義）

```go
type Schema []*Column

type Column struct {
    Name           string
    Type           sql.Type
    Default        *ColumnDefaultValue
    AutoIncrement  bool
    Nullable       bool
    Source         string // テーブル名
    DatabaseSource string
    PrimaryKey     bool
    Comment        string
    Extra          string
    Generated      *ColumnDefaultValue
}
```

### Row（行データ）

```go
// Row は値のスライス
type Row []interface{}
```

### オプショナルインターフェース（最適化用）

| インターフェース | 目的 | 効果 |
|---------------|------|------|
| `InsertableTable` | INSERT サポート | データ書き込み |
| `UpdatableTable` | UPDATE サポート | データ更新 |
| `DeletableTable` | DELETE サポート | データ削除 |
| `ReplaceableTable` | REPLACE サポート | UPSERT |
| `TruncateableTable` | TRUNCATE サポート | 全行削除 |
| `AlterableTable` | ALTER TABLE サポート | スキーマ変更 |
| `IndexAddressableTable` | インデックス利用 | 高速検索 |
| `ProjectedTable` | プロジェクション push-down | 不要カラムスキップ |
| `FilteredTable` | フィルタ push-down | ストレージ層でフィルタ |
| `IndexedTable` | インデックススキャン | O(log n) 検索 |
| `StatisticsTable` | 統計情報 | オプティマイザ改善 |

### InsertableTable

```go
type InsertableTable interface {
    Table
    // Inserter は新しい行挿入器を返す
    Inserter(ctx *sql.Context) sql.RowInserter
}

type RowInserter interface {
    // Insert は行を挿入する
    Insert(ctx *sql.Context, row sql.Row) error
    // Close は挿入を確定する
    Close(ctx *sql.Context) error
    Disposable
}
```

---

## 4. メモリデータベース実装

go-mysql-server にはリファレンス実装としてメモリデータベースが含まれる。

### 使用例

```go
import (
    sqle "github.com/dolthub/go-mysql-server"
    "github.com/dolthub/go-mysql-server/memory"
    "github.com/dolthub/go-mysql-server/sql"
    "github.com/dolthub/go-mysql-server/sql/information_schema"
)

// メモリデータベース作成
db := memory.NewDatabase("testdb")

// テーブル作成
table := memory.NewTable(db, "users", sql.NewPrimaryKeySchema(sql.Schema{
    {Name: "id", Type: sql.Int64, PrimaryKey: true},
    {Name: "name", Type: sql.Text, Nullable: false},
    {Name: "email", Type: sql.Text, Nullable: true},
}), nil)

db.AddTable("users", table)

// プロバイダ作成
provider := memory.NewDBProvider(db, information_schema.NewInformationSchemaDatabase())

// エンジン作成
engine := sqle.NewDefault(provider)

// クエリ実行
ctx := sql.NewEmptyContext()
schema, iter, err := engine.Query(ctx, "SELECT * FROM users WHERE id > 10")
```

### メモリテーブルの特徴

- 全データをメモリ上の `[]sql.Row` として保持
- ハッシュインデックス、B-Treeインデックスをサポート
- パーティション分割可能
- トランザクション（リファレンスレベル）
- ビュー、トリガー対応

> **注意**: メモリ実装はリファレンス用であり、DDL/DML の同時実行はスレッドセーフではない（設計上の意図）。

---

## 5. 型システム

### 組み込み型

| Go 定数 | SQL型 | Go ランタイム型 |
|---------|-------|---------------|
| `sql.Int8` | TINYINT | int8 |
| `sql.Int16` | SMALLINT | int16 |
| `sql.Int32` | INT | int32 |
| `sql.Int64` | BIGINT | int64 |
| `sql.Uint8` | TINYINT UNSIGNED | uint8 |
| `sql.Uint16` | SMALLINT UNSIGNED | uint16 |
| `sql.Uint32` | INT UNSIGNED | uint32 |
| `sql.Uint64` | BIGINT UNSIGNED | uint64 |
| `sql.Float32` | FLOAT | float32 |
| `sql.Float64` | DOUBLE | float64 |
| `sql.Decimal` | DECIMAL | decimal.Decimal |
| `sql.Text` | TEXT | string |
| `sql.Blob` | BLOB | []byte |
| `sql.Boolean` | BOOLEAN | bool |
| `sql.Date` | DATE | time.Time |
| `sql.Datetime` | DATETIME | time.Time |
| `sql.Timestamp` | TIMESTAMP | time.Time |
| `sql.JSON` | JSON | JSONValue |
| `sql.Null` | NULL | nil |

### Type インターフェース

```go
type Type interface {
    // Compare は2つの値を比較
    Compare(a, b interface{}) (int, error)
    // Convert はGoの値をこの型に変換
    Convert(v interface{}) (interface{}, sql.ConvertInRange, error)
    // Promote は型を昇格（precision拡大）
    Promote() sql.Type
    // SQL はカラムのSQL型名を返す
    SQL(ctx *sql.Context, dest []byte, v interface{}) (sqltypes.Value, error)
    // Type はVitess型定数を返す
    Type() query.Type
    // Zero はゼロ値を返す
    Zero() interface{}
    fmt.Stringer
}
```

---

## 6. 組み込み関数

go-mysql-server は 100以上の組み込み関数を提供:

### 関数の登録パターン

```go
type Function interface {
    // NewInstance は関数の新しいインスタンスを生成
    NewInstance(args []sql.Expression) (sql.Expression, error)
}

// カスタム関数の登録
catalog.RegisterFunction(sql.FunctionN{
    Name: "my_func",
    Fn: func(args ...sql.Expression) (sql.Expression, error) {
        return NewMyFunc(args...)
    },
})
```

### 関数カテゴリ

| カテゴリ | 関数数 | 例 |
|---------|--------|---|
| 文字列関数 | 30+ | CONCAT, UPPER, LOWER, SUBSTRING, TRIM, LENGTH |
| 数学関数 | 20+ | ABS, CEIL, FLOOR, ROUND, MOD, POWER, SQRT |
| 日付関数 | 15+ | NOW, DATE, DATE_FORMAT, DATE_ADD, DATEDIFF |
| 集約関数 | 10+ | COUNT, SUM, AVG, MIN, MAX, GROUP_CONCAT |
| JSON関数 | 10+ | JSON_EXTRACT, JSON_OBJECT, JSON_ARRAY |
| 制御フロー | 5+ | IF, IFNULL, NULLIF, COALESCE, CASE |
| 型変換 | 5+ | CAST, CONVERT |
| ウィンドウ関数 | 10+ | ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD |

---

## 7. JOIN アルゴリズム

go-mysql-server は5つの JOIN アルゴリズムを実装:

| アルゴリズム | 計算量 | 用途 |
|------------|--------|------|
| **Hash Join** | O(n+m) | 等値結合（最も一般的） |
| **Merge Join** | O(n+m) | ソート済みデータの結合 |
| **Lookup Join** | O(n·log m) | インデックスのある側をプローブ |
| **Nested Loop** | O(n·m) | 小テーブルまたはフォールバック |
| **Range Heap** | O(n·log m) | 範囲条件の結合 |

### JOIN タイプ（29種類）

- INNER JOIN, LEFT JOIN, RIGHT JOIN, FULL OUTER JOIN
- CROSS JOIN, NATURAL JOIN
- SEMI JOIN, ANTI JOIN（サブクエリ最適化用）
- LATERAL JOIN

---

## 8. Analyzer（最適化）

Analyzer は50以上の最適化ルールを適用する:

### 主要な最適化ルール

| ルール | 説明 |
|--------|------|
| `ResolveTable` | テーブル名をカタログから解決 |
| `ResolveColumn` | カラム名をスキーマから解決 |
| `ResolveTypes` | 式の型を解決・推論 |
| `PushdownFilters` | WHERE条件をテーブルスキャン近くに移動 |
| `PushdownProjections` | 必要カラムのみ読み取り |
| `SelectIndexes` | 利用可能なインデックスを選択 |
| `OptimizeJoins` | JOIN順序の最適化 |
| `FoldConstants` | 定数式の事前計算 |
| `OptimizeSubqueries` | サブクエリの最適化（SEMI JOIN変換等） |
| `EraseProjection` | 不要なプロジェクションの除去 |
| `MoveJoinCondToFilter` | JOIN条件をフィルタに変換 |

### Analyzer の実行順序

```
1. Default Rules（デフォルトルール）
   ├── ResolveOrderAlways
   ├── ResolveNames
   ├── ResolveTypes
   └── ResolveFunctions

2. After Default Rules（後処理）
   ├── ValidateOperands
   ├── ValidateIndexCreation
   └── CheckConstraints

3. After All Rules（最終処理）
   ├── TrackProcess
   ├── FixFieldIndexes
   └── AssignExecIndexes

4. Optimization Rules（最適化ルール）
   ├── PushdownFilters
   ├── PushdownProjections
   ├── OptimizeJoins
   └── SelectIndexes
```

---

## 9. 拡張ポイント

### カスタムデータベース

任意のデータソースをバックエンドとして使用:

```go
type MyDatabase struct {
    name   string
    tables map[string]sql.Table
}

func (d *MyDatabase) Name() string { return d.name }
func (d *MyDatabase) GetTableInsensitive(ctx *sql.Context, name string) (sql.Table, bool, error) {
    t, ok := d.tables[strings.ToLower(name)]
    return t, ok, nil
}
func (d *MyDatabase) GetTableNames(ctx *sql.Context) ([]string, error) {
    names := make([]string, 0, len(d.tables))
    for n := range d.tables {
        names = append(names, n)
    }
    return names, nil
}
```

### カスタム関数

```go
type MyUpperFunc struct {
    expression.UnaryExpression
}

func (f *MyUpperFunc) Eval(ctx *sql.Context, row sql.Row) (interface{}, error) {
    val, err := f.Child.Eval(ctx, row)
    if err != nil || val == nil {
        return nil, err
    }
    return strings.ToUpper(val.(string)), nil
}
```

### カスタム Analyzer ルール

```go
analyzer.AddRule("my_rule", func(ctx *sql.Context, a *analyzer.Analyzer, n sql.Node, scope *plan.Scope, sel analyzer.RuleSelector) (sql.Node, transform.TreeIdentity, error) {
    // カスタム最適化ロジック
    return n, transform.SameTree, nil
})
```

---

## 10. DoltgreSQLとの統合

DoltgreSQL は go-mysql-server をベースに PostgreSQL 互換性を追加:

### 適用方法

```
┌─────────────────────────────────┐
│  PostgreSQL ワイヤープロトコル   │  ← DoltgreSQL 独自
├─────────────────────────────────┤
│  PostgreSQL パーサー             │  ← Vitess の代わりに PG パーサー
├─────────────────────────────────┤
│  PG → GMS AST 変換             │  ← DoltgreSQL のブリッジ層
├─────────────────────────────────┤
│  go-mysql-server エンジン       │  ← そのまま使用
│  (Analyzer, Optimizer, Executor) │
├─────────────────────────────────┤
│  Dolt ストレージエンジン         │  ← Git-like ストレージ
└─────────────────────────────────┘
```

### DoltgreSQL が追加しているもの

- PostgreSQL ワイヤープロトコルサーバー
- PostgreSQL 構文パーサー → go-mysql-server の内部表現への変換
- PostgreSQL 固有の型（JSONB, INTERVAL, UUID等）
- PostgreSQL 固有の関数（`string_agg`, `array_agg` 等）
- PostgreSQL 固有の演算子（`::`, `->`, `->>` 等）
- `information_schema` の PostgreSQL 互換実装

---

## 11. カスタムバックエンド構築手順

### ステップ 1: 3インターフェースの実装

```go
// Provider
type MyProvider struct {
    databases map[string]*MyDatabase
}

// Database
type MyDatabase struct {
    name   string
    tables map[string]*MyTable
}

// Table
type MyTable struct {
    name    string
    schema  sql.Schema
    data    []sql.Row
}
```

### ステップ 2: エンジン作成とクエリ実行

```go
provider := &MyProvider{databases: map[string]*MyDatabase{
    "mydb": myDatabase,
}}

engine := sqle.NewDefault(provider)

ctx := sql.NewEmptyContext()
schema, iter, err := engine.Query(ctx, "SELECT id, name FROM users WHERE age > 25")
if err != nil {
    log.Fatal(err)
}

for {
    row, err := iter.Next(ctx)
    if err == io.EOF {
        break
    }
    fmt.Println(row)
}
```

### ステップ 3: 書き込みサポート（オプション）

```go
// InsertableTable の実装
func (t *MyTable) Inserter(ctx *sql.Context) sql.RowInserter {
    return &myInserter{table: t}
}

type myInserter struct {
    table *MyTable
}

func (i *myInserter) Insert(ctx *sql.Context, row sql.Row) error {
    i.table.data = append(i.table.data, row)
    return nil
}

func (i *myInserter) Close(ctx *sql.Context) error {
    return nil
}
```

---

## 12. Go製SQLエンジンの他の選択肢

### 比較表

| プロジェクト | Star | 用途 | 特徴 |
|------------|------|------|------|
| **go-mysql-server** | 2,616 | 汎用SQLエンジン | ストレージ非依存、最も成熟 |
| **ramsql** | 927 | テスト用インメモリDB | database/sql ドライバ、簡易 |
| **rqlite** | 17,000 | 分散SQLite | SQLite + Raft、読み取り専用 |
| **immudb** | 8,900 | 改ざん防止DB | 独自SQL、暗号学的検証 |
| **CockroachDB** | 30,000+ | 分散PostgreSQL互換 | 巨大、独自エンジン |

### Apache Calcite / DataFusion の Go 等価物

**Go には Calcite や DataFusion に相当する汎用クエリフレームワークは存在しない**。

go-mysql-server が最も近い存在であり、以下の機能を提供:
- SQL パーサー
- クエリプランナー / オプティマイザ
- 実行エンジン
- プラグイン可能なストレージ

Go で SQL 実行エンジンを構築する場合、go-mysql-server をベース にするか、全て自作するかの二択となる。

---

## まとめ

| 観点 | go-mysql-server の評価 |
|------|----------------------|
| 成熟度 | ⭐⭐⭐⭐⭐ (Dolt プロダクション利用) |
| 拡張性 | ⭐⭐⭐⭐⭐ (プラグイン設計) |
| 型システム | ⭐⭐⭐⭐ (MySQL型中心、PGは DoltgreSQL で対応) |
| 最適化 | ⭐⭐⭐⭐ (50+ ルール) |
| PostgreSQL互換 | ⭐⭐⭐ (DoltgreSQL経由で91%) |
| ドキュメント | ⭐⭐⭐ (コード中心、公式ドキュメント少なめ) |

---

[← README に戻る](../README.md)
