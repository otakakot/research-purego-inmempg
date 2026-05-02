# PostgreSQL互換性テスト手法と関連技術

[← README に戻る](../README.md)

---

Go製インメモリPostgreSQLの互換性をどのように検証するか、既存のテストフレームワーク・手法・ツールを調査し整理する。

> **注記**: PostgreSQL のソースコードは https://github.com/postgres/postgres から参照可能です。PostgreSQL 19devel では PG 17.7 に比べ回帰テストが追加・更新されている可能性があるため、最新のテストスイートを基準にすることを推奨します。

---

## 目次

1. [互換性テストの全体像](#1-互換性テストの全体像)
2. [PostgreSQL公式回帰テスト](#2-postgresql公式回帰テスト)
3. [SQLLogicTest](#3-sqllogictest)
4. [DoltgreSQLのテスト戦略](#4-doltgresqlのテスト戦略)
5. [pgparserの互換性テスト](#5-pgparserの互換性テスト)
6. [pgTAP](#6-pgtap)
7. [差分テスト（Differential Testing）](#7-差分テストdifferential-testing)
8. [Goにおけるテスト実装手法](#8-goにおけるテスト実装手法)
9. [推奨テスト戦略](#9-推奨テスト戦略)
10. [関連ツール・リポジトリ](#10-関連ツールリポジトリ)

---

## 1. 互換性テストの全体像

PostgreSQL互換データベースの互換性テストは、以下の層で行う必要がある:

```
┌──────────────────────────────────────────────────────┐
│  Layer 5: ORM/アプリケーション互換性テスト            │
│  (GORM, sqlc, sqlx, ent 等が正しく動作するか)        │
├──────────────────────────────────────────────────────┤
│  Layer 4: PostgreSQL固有機能テスト                    │
│  (型キャスト、JSONB演算子、配列操作、CTE、ウィンドウ)  │
├──────────────────────────────────────────────────────┤
│  Layer 3: SQL標準準拠テスト                          │
│  (SQLLogicTest, 回帰テスト)                          │
├──────────────────────────────────────────────────────┤
│  Layer 2: パーサー互換性テスト                       │
│  (PostgreSQL回帰テストSQLのパース成功率)              │
├──────────────────────────────────────────────────────┤
│  Layer 1: ワイヤープロトコル互換性テスト              │
│  (pgx, lib/pq, psql等のクライアントとの接続確認)      │
└──────────────────────────────────────────────────────┘
```

---

## 2. PostgreSQL公式回帰テスト

### 概要

PostgreSQL本体に付属する回帰テストスイートは、SQLの正確性を検証するための包括的なテスト群である。

| 項目 | 内容 |
|------|------|
| **場所** | `src/test/regress/` (PostgreSQLソースツリー) |
| **テスト数** | 213テスト（コア） + 追加テストスイート |
| **SQL文数** | 約45,000文 |
| **方式** | SQLスクリプトを実行し、期待出力と `diff` 比較 |
| **ツール** | `pg_regress`（テストランナー） |
| **タイムゾーン** | `America/Los_Angeles` を前提 |
| **ロケール** | C ロケール推奨 |

### ディレクトリ構成

```
src/test/regress/
├── sql/                    # テスト用SQLファイル
│   ├── select.sql
│   ├── insert.sql
│   ├── join.sql
│   ├── aggregates.sql
│   ├── window.sql
│   └── ...
├── expected/               # 期待出力ファイル
│   ├── select.out
│   ├── insert.out
│   └── ...
├── results/                # 実行結果出力
└── regression.diffs        # 差分ファイル
```

### テストの実行方式

```bash
# 一時インストールでのテスト実行
make check

# 既存インストールに対してテスト実行
make installcheck

# 全テストスイート（contrib含む）
make check-world
```

### Goからの活用方法

PostgreSQL回帰テストのSQLファイルを直接利用することが可能:

1. `sql/` ディレクトリからテスト用SQLファイルを取得
2. 各SQLを自作エンジンとPostgreSQL本体の両方で実行
3. 結果を比較（行順の差異は `ORDER BY` がない場合無視）

**注意点**:
- 一部のテストは出力フォーマットに依存（浮動小数点精度、マイナスゼロ表記等）
- タイムゾーン依存のテストがある
- `ORDER BY` なしの場合は行順が不定
- PostgreSQL固有の関数（`pg_*`系）を使用するテストは選別が必要

### 追加テストスイート

| テストスイート | 場所 | 内容 |
|-------------|------|------|
| コア回帰テスト | `src/test/regress/` | 基本的なSQL機能（213テスト、約45,000 SQL文） |
| 分離レベルテスト | `src/test/isolation/` | 同時実行・ロック・トランザクション分離挙動 |
| リカバリテスト | `src/test/recovery/` | クラッシュリカバリ・WALリプレイ |
| 認証テスト | `src/test/authentication/` | 各種認証方式（password, scram, cert 等） |
| サブスクリプションテスト | `src/test/subscription/` | 論理レプリケーション |
| モジュールテスト | `src/test/modules/` | モジュール固有のテスト |
| ロケールテスト | `src/test/locale/` | ロケール処理 |
| マルチバイトテスト | `src/test/mb/` | マルチバイト文字（UTF-8、EUC-JP 等） |
| SSL テスト | `src/test/ssl/` | SSL/TLS 接続 |
| Kerberos テスト | `src/test/kerberos/` | Kerberos 認証 |
| LDAP テスト | `src/test/ldap/` | LDAP 認証 |
| PL/pgSQL テスト | `src/pl/plpgsql/src/sql/` | 手続き言語 |
| contrib テスト | `contrib/*/sql/` | 拡張機能 |

### `src/test/` ディレクトリ構造の詳細（PostgreSQL 19devel）

PostgreSQL ソースツリーの `src/test/` 以下には、機能別に分離された複数のテストスイートが存在する:

```
src/test/
├── regress/           # コア SQL 回帰テスト（213テスト、~45,000 SQL文）
│   ├── sql/           #   テスト用 SQL ファイル
│   └── expected/      #   期待出力ファイル（.out）
├── isolation/         # 分離レベル・同時実行テスト
├── authentication/    # 認証方式テスト
├── recovery/          # クラッシュリカバリテスト
├── subscription/      # 論理レプリケーションテスト
├── modules/           # モジュール固有テスト
├── locale/            # ロケール処理テスト
├── mb/                # マルチバイト文字テスト
├── ssl/               # SSL/TLS テスト
├── kerberos/          # Kerberos 認証テスト
└── ldap/              # LDAP 認証テスト
```

### 回帰テストの実行方法

PostgreSQL をソースからビルドしてテストを実行する方法:

```bash
# PostgreSQL ソースの取得（https://github.com/postgres/postgres を参照）
cd postgres

# Autoconf ベースのビルド・テスト
./configure
make -j$(nproc)
make check                # 一時インストールでの回帰テスト
make installcheck         # 既存インストールに対するテスト
make check-world          # 全テストスイート（contrib含む）

# Meson ベースのビルド・テスト（PG 16 以降推奨）
meson setup build
cd build
meson compile
meson test                # 全テスト実行
meson test --suite regress  # 回帰テストのみ
```

### インメモリエンジンへのテスト活用

回帰テストの SQL ファイル（`src/test/regress/sql/`）と期待出力（`src/test/regress/expected/`）は、インメモリエンジンのテストに直接活用できる:

1. `sql/` 内の各テストファイルを自作エンジンに対して実行
2. 出力を `expected/` の `.out` ファイルと比較
3. 差分が発生した箇所を未実装機能として特定

> **PG 19devel に関する注意**: PostgreSQL 19devel では PG 17.7 に比べて新規テストが追加されている場合がある。最新のソースツリーを使用し、テストカバレッジの変更点を確認すること。テストスケジュールは `src/test/regress/parallel_schedule` で管理されている。

---

## 3. SQLLogicTest

### 概要

SQLLogicTestは、SQLite プロジェクトが開発した**データベースエンジン中立**のSQL正確性テストフレームワーク。異なるデータベースエンジン間で同一クエリの結果を比較することで正確性を検証する。

| 項目 | 内容 |
|------|------|
| **開発元** | SQLite (D. Richard Hipp) |
| **テストケース数** | 数百万（自動生成含む） |
| **方式** | テストスクリプト形式、結果比較 |
| **対応DB** | SQLite, PostgreSQL, MySQL, CockroachDB 等 |
| **テストデータ** | https://www.sqlite.org/sqllogictest/ |

### テストスクリプトフォーマット

```
# ステートメント（結果を返さないSQL）
statement ok
CREATE TABLE t1(a INTEGER, b TEXT, c REAL)

# ステートメント（エラー期待）
statement error
INSERT INTO nonexistent_table VALUES (1)

# クエリ（結果を検証）
query III rowsort
SELECT a, b, c FROM t1 ORDER BY a
----
1    hello    3.14
2    world    2.72

# データ型指定: I=整数, T=テキスト, R=浮動小数点
# ソートモード: nosort, rowsort, valuesort
```

### skipif / onlyif によるDB固有対応

```
# PostgreSQLのみ実行
onlyif postgresql
query I rowsort label-test1
SELECT a FROM t1 WHERE a::text = '1'

# PostgreSQL以外で実行
skipif postgresql
query I rowsort label-test1
SELECT CAST(a AS CHAR) FROM t1 WHERE a = 1
```

`label` を使って異なる構文で同一結果を期待できる。

### Go向け実装

#### alkemir/sqllogictest (Go)

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/alkemir/sqllogictest |
| **言語** | Go |
| **インターフェース** | `database/sql` 互換 |
| **ライセンス** | 不明（要確認） |

```go
import "github.com/alkemir/sqllogictest"

db, _ := sql.Open("your-driver", "your-dsn")
fp, _ := os.Open("test.slt")
testScript, _ := sqllogictest.ParseTestScript(fp)
res := testScript.Run(db, "postgresql", true, log.Default())
fmt.Printf("Pass rate: %d%%\n", 100*res.Success()/(res.Success()+res.Failure()))
```

#### DoltgreSQL の SQLLogicTest 活用

DoltgreSQL は `testing/logictest/` にSQLLogicTestハーネスを内蔵:

```
testing/logictest/
├── harness/     # テスト実行ハーネス
└── main.go      # エントリーポイント
```

DoltGreSQLはSQLLogicTestを使って自身のPostgreSQL互換性を定量的に計測している。

#### CockroachDB の LogicTest

CockroachDB も独自のLogicTestフレームワーク（`pkg/sql/logictest/`）を持ち、数万のテストケースでPostgreSQL互換性を検証している。CockroachDBのテストケースはPostgreSQL構文の広範なカバレッジを持つため、参考になる。

---

## 4. DoltgreSQLのテスト戦略

DoltgreSQL は複数のテスト手法を組み合わせている:

### テストディレクトリ構成

```
testing/
├── go/                      # Goユニットテスト
│   ├── adaptive_encoding_test.go
│   ├── connection_test.go
│   ├── create_table_test.go
│   ├── insert_test.go
│   ├── select_test.go
│   ├── type_test.go
│   ├── json_test.go
│   ├── regression/          # PG回帰テスト
│   │   └── tests/
│   │       └── alter_table.sql
│   └── ...
├── logictest/               # SQLLogicTest
│   ├── harness/
│   └── main.go
├── bats/                    # Bashベースの統合テスト (BATS)
├── postgres-client-tests/   # PostgreSQLクライアント互換テスト
├── dataloader/              # データロードテスト
├── dumps/                   # pg_dump互換テスト
└── generation/              # テスト生成スクリプト
```

### テストレイヤー

| レイヤー | ツール/手法 | 目的 |
|---------|-----------|------|
| ユニットテスト | `go test` (testing/go/) | 個別SQL機能の正確性 |
| 回帰テスト | PG回帰テストSQL | PostgreSQL互換性の定量評価 |
| ロジックテスト | SQLLogicTest | クエリ結果の正確性 |
| 統合テスト | BATS | CLI・サーバー動作 |
| クライアントテスト | pgx, lib/pq 等 | プロトコル互換性 |
| ダンプテスト | pg_dump | スキーマ互換性 |

---

## 5. pgparserの互換性テスト

pgplex/pgparser は、PostgreSQL公式回帰テストスイートを利用してパーサーの互換性を定量的に測定している。

### テスト方法

```bash
# PostgreSQL回帰テスト互換性チェック
go test ./parser/pgregress -run TestPGRegressStats -v
```

### テスト結果

| 指標 | 値 |
|------|---|
| テスト対象SQL文 | 約45,000 |
| パース成功率 | **99.6%** |
| パースに使用したPGバージョン | 17.7 (REL_17_STABLE) |

### 手法の意義

パーサーの互換性テストは**最も定量化しやすい**テストであり、以下の基準を提供する:
- パーサーが対象SQLを受理できるかの通過率
- PostgreSQLバージョンごとの構文サポート状況

ただしパーサーテストは「構文が受理されるか」のみを検証し、「正しい結果が返るか」は検証しない。

---

## 6. pgTAP

### 概要

pgTAP は PostgreSQL のための単体テストフレームワーク。TAP (Test Anything Protocol) に準拠。

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/theory/pgtap |
| **Star数** | ⭐ 1,120 |
| **ライセンス** | PostgreSQL License |
| **テスト数** | 数百のアサーション関数 |

### 特徴

pgTAP はPostgreSQL内部で動作するテストフレームワークであり、以下のようなアサーションを提供する:

```sql
-- テーブルの存在確認
SELECT has_table('users');

-- カラムの型確認
SELECT col_type_is('users', 'id', 'integer');

-- 外部キーの確認
SELECT has_fk('orders');

-- クエリ結果の検証
SELECT results_eq(
    'SELECT 1 + 1',
    'SELECT 2'
);

-- 行数の確認
SELECT row_eq(
    'SELECT * FROM users WHERE id = 1',
    ROW(1, 'Alice', 'alice@example.com')::users
);
```

### Go製PostgreSQLへの適用

pgTAP自体はPostgreSQLのPL/pgSQL拡張として動作するため、Go製エンジンでPL/pgSQLをサポートしない限り直接利用は困難。ただし、pgTAPのテストパターン（アサーション設計）はGoテストの参考になる。

---

## 7. 差分テスト（Differential Testing）

### 概要

差分テストは、同一のSQLを**本物のPostgreSQL**と**自作エンジン**の両方で実行し、結果を比較する手法。最も信頼性の高い互換性検証方法。

### アーキテクチャ

```
┌──────────────────────┐
│   テストケース生成    │
│   (ランダム/手動)     │
└──────────┬───────────┘
           │ SQL
    ┌──────┴──────┐
    ▼             ▼
┌─────────┐ ┌──────────────┐
│ 本物の   │ │ Go製         │
│PostgreSQL│ │ エンジン      │
└────┬────┘ └──────┬───────┘
     │ 結果         │ 結果
     └──────┬───────┘
            ▼
    ┌───────────────┐
    │  結果比較      │
    │  (diff/assert) │
    └───────────────┘
```

### Goでの実装パターン

```go
func TestCompatibility(t *testing.T) {
    // 本物のPostgreSQL（embedded-postgres or Docker）
    realPG := startRealPostgres(t)
    defer realPG.Stop()

    // 自作エンジン
    myEngine := startMyEngine(t)
    defer myEngine.Stop()

    for _, tc := range testCases {
        t.Run(tc.Name, func(t *testing.T) {
            // 両方で実行
            realResult := execOnReal(realPG, tc.SQL)
            myResult := execOnMine(myEngine, tc.SQL)

            // 結果比較
            compareResults(t, realResult, myResult, tc.Options)
        })
    }
}
```

### テストケース生成

| 手法 | 説明 | 適用場面 |
|------|------|---------|
| 手動作成 | 重要な機能ごとにテストケースを記述 | 基本機能・エッジケース |
| PG回帰テストからの抽出 | `sql/*.sql` ファイルを利用 | 広範な標準機能 |
| SQLLogicTest | 既存テストデータベース | 数学的・論理的正確性 |
| ランダム生成 | SQLSmith等のツールでSQL自動生成 | ファジング・エッジケース |
| ORM生成SQL | GORM, sqlc等が発行するSQL | 実アプリケーション互換性 |

### SQLSmith

SQLSmith はランダムなSQL文を自動生成するツール。PostgreSQLのスキーマ情報を読み取り、文法的に正しいが意味的に複雑なSQLを大量生成する。CockroachDB、DuckDB等が互換性テストに使用している。

---

## 8. Goにおけるテスト実装手法

### 8.1 embedded-postgres を使った差分テスト

```go
import embeddedpostgres "github.com/fergusstrange/embedded-postgres"

func setupRealPostgres(t *testing.T) *sql.DB {
    pg := embeddedpostgres.NewDatabase(
        embeddedpostgres.DefaultConfig().
            Port(15432).
            Version(embeddedpostgres.V17),
    )
    require.NoError(t, pg.Start())
    t.Cleanup(func() { pg.Stop() })

    db, err := sql.Open("postgres", "host=localhost port=15432 ...")
    require.NoError(t, err)
    return db
}
```

### 8.2 テーブル駆動テスト

```go
type CompatTest struct {
    Name     string
    Setup    []string   // DDL文
    Query    string     // テスト対象SQL
    SortRows bool       // 行順を無視するか
    Skip     string     // スキップ理由（未実装機能等）
}

var compatTests = []CompatTest{
    {
        Name:  "basic_select",
        Setup: []string{"CREATE TABLE t1 (a INT, b TEXT)"},
        Query: "SELECT a, b FROM t1 ORDER BY a",
    },
    {
        Name:  "aggregate_count",
        Setup: []string{
            "CREATE TABLE t2 (x INT)",
            "INSERT INTO t2 VALUES (1), (2), (3)",
        },
        Query: "SELECT count(*), sum(x), avg(x) FROM t2",
    },
    {
        Name:  "json_operations",
        Setup: []string{
            "CREATE TABLE t3 (data JSONB)",
            `INSERT INTO t3 VALUES ('{"a": 1, "b": [1,2,3]}')`,
        },
        Query: "SELECT data->>'a', jsonb_array_length(data->'b') FROM t3",
    },
}
```

### 8.3 結果比較ユーティリティ

```go
type QueryResult struct {
    Columns []string
    Rows    [][]interface{}
    Error   error
}

func compareResults(t *testing.T, expected, actual QueryResult, sortRows bool) {
    t.Helper()

    // エラー発生の一致確認
    if (expected.Error != nil) != (actual.Error != nil) {
        t.Errorf("error mismatch: expected=%v, actual=%v",
            expected.Error, actual.Error)
        return
    }

    // カラム名の一致
    assert.Equal(t, expected.Columns, actual.Columns)

    // 行データの比較（ソートオプション付き）
    expectedRows := expected.Rows
    actualRows := actual.Rows
    if sortRows {
        sort.Slice(expectedRows, rowSorter(expectedRows))
        sort.Slice(actualRows, rowSorter(actualRows))
    }

    assert.Equal(t, len(expectedRows), len(actualRows))
    for i := range expectedRows {
        for j := range expectedRows[i] {
            compareValues(t, expectedRows[i][j], actualRows[i][j])
        }
    }
}
```

### 8.4 互換性スコアの計測

```go
type CompatScore struct {
    Total    int
    Passed   int
    Failed   int
    Skipped  int
    Errors   []CompatError
}

type CompatError struct {
    TestName string
    SQL      string
    Expected string
    Actual   string
    Category string // "parse_error", "wrong_result", "unsupported", etc.
}

func (s CompatScore) Percentage() float64 {
    if s.Total == 0 {
        return 0
    }
    return float64(s.Passed) / float64(s.Total-s.Skipped) * 100
}
```

---

## 9. 推奨テスト戦略

### Phase 1: パーサー互換性（最初に実施）

| テスト | ツール | 目標 |
|--------|-------|------|
| SQL文パース成功率 | PG回帰テストSQL + pgparser | 99%+ パース成功 |

pgparser（99.6%通過率）を使用している場合はこのフェーズは自動的にクリアされる。

### Phase 2: ワイヤープロトコル互換性

| テスト | ツール | 目標 |
|--------|-------|------|
| pgx 接続テスト | pgx + psql-wire | 接続/クエリ/切断 |
| lib/pq 接続テスト | lib/pq + psql-wire | 接続/クエリ/切断 |
| psql 接続テスト | psql CLI | 対話的クエリ |
| Extended Query Protocol | pgx (prepared stmt) | Parse/Bind/Execute |

### Phase 3: SQL実行互換性（メイン）

| テスト | ツール | 目標 |
|--------|-------|------|
| 基本SQL | 手動テスト + embedded-postgres 差分 | DDL/DML正確性 |
| SQLLogicTest | alkemir/sqllogictest or 独自ハーネス | クエリ結果正確性 |
| PG回帰テスト | PG回帰SQL + diff | 広範なSQL機能 |
| ランダムSQL | SQLSmith相当の生成器 | エッジケース |

### Phase 4: アプリケーション互換性

| テスト | ツール | 目標 |
|--------|-------|------|
| GORM互換 | GORM + PostgreSQLドライバ | ORM操作 |
| sqlc互換 | sqlc生成コード | 型安全クエリ |
| マイグレーション | golang-migrate | スキーマ変更 |
| information_schema | 手動テスト | メタデータクエリ |

### 互換性スコアの公開

DoltgreSQL のように互換性スコアを定量的に公開することが推奨される:

```
PostgreSQL互換性レポート
========================
パーサー互換性:     99.6% (44,820 / 45,000 SQL文)
DDL互換性:         87.3% (131 / 150 コマンド)
DML互換性:         82.1% (234 / 285 テストケース)
型互換性:          75.0% (30 / 40 データ型)
関数互換性:        45.2% (113 / 250 組み込み関数)
ウィンドウ関数:    70.0% (7 / 10 関数)
JSON操作:          60.0% (12 / 20 演算子/関数)
=====================================
総合互換性スコア:  68.4%
```

---

## 10. 関連ツール・リポジトリ

| ツール/プロジェクト | 用途 | URL |
|-------------------|------|-----|
| PostgreSQL回帰テスト | 公式テストスイート | https://www.postgresql.org/docs/17/regress.html |
| SQLLogicTest (本家) | DB中立テストフレームワーク | https://www.sqlite.org/sqllogictest/ |
| sqllogictest-rs | Rust製SQLLogicTestランナー | https://github.com/risinglightdb/sqllogictest-rs |
| alkemir/sqllogictest | Go製SQLLogicTestハーネス | https://github.com/alkemir/sqllogictest |
| gregrahn/sqllogictest | テストデータミラー | https://github.com/gregrahn/sqllogictest |
| pgTAP | PostgreSQL単体テスト | https://github.com/theory/pgtap |
| embedded-postgres | テスト用PGサーバー | https://github.com/fergusstrange/embedded-postgres |
| DoltgreSQL testing/ | 互換性テスト実装例 | https://github.com/dolthub/doltgresql/tree/main/testing |
| CockroachDB logictest | PG互換ロジックテスト | `cockroachdb/cockroach` の `pkg/sql/logictest/` |
| SQLSmith | ランダムSQL生成 | https://github.com/anse1/sqlsmith |

---

[← README に戻る](../README.md)
