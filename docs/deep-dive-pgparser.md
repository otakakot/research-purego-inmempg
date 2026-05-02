# pgparser 詳細分析

[← README に戻る](../README.md)

---

pgparser の内部アーキテクチャ、AST構造、パーサーAPI、ノード型を詳細に分析する。

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [パーサーAPI](#2-パーサーapi)
3. [AST ノード型（全210型）](#3-ast-ノード型全210型)
4. [主要なAST構造体](#4-主要なast構造体)
5. [式（Expression）の表現](#5-式expressionの表現)
6. [型情報](#6-型情報)
7. [ASTの走査（Tree Walking）](#7-astの走査tree-walking)
8. [シリアライゼーション](#8-シリアライゼーション)
9. [pg_query_go との比較](#9-pg_query_go-との比較)
10. [ゼロ依存の実現方法](#10-ゼロ依存の実現方法)
11. [実践的な使用例](#11-実践的な使用例)
12. [PostgreSQL 19devel ソースコードとの比較](#12-postgresql-19devel-ソースコードとの比較)

---

## 1. アーキテクチャ概要

pgparser は手書きではなく、PostgreSQL のソースコードから**体系的に変換**された Pure Go パーサーである。

### 変換プロセス

```
PostgreSQL ソースコード (REL_17_STABLE)
├── gram.y (Bison文法)     → parser/gram.y (goyacc形式に変換)
├── scan.l (字句解析)       → parser/lexer.go (手書きGo実装)
├── kwlist.h (キーワード)   → parser/keywords.go
└── parsenodes.h (ノード型) → nodes/parsenodes.go (Go構造体)
```

### キーテクノロジー: goyacc

`goyacc`（`golang.org/x/tools` に含まれる）を使用してLALR(1)パーサーを生成:

```bash
goyacc -o parser.go -p pg gram.y
# → 1.2 MB の Pure Go ファイルを生成
```

goyacc は Go ツールチェインの一部であり、外部依存を一切追加しない。

### ファイル構成

| ファイル | サイズ | 説明 |
|---------|-------|------|
| `parser/gram.y` | 393 KB | Bison文法（goyacc形式） |
| `parser/parser.go` | 1.2 MB | 生成されたLALR(1)パーサー |
| `parser/lexer.go` | 32 KB | 手書き字句解析器 |
| `parser/keywords.go` | - | PostgreSQLキーワード定義 |
| `parser/parse.go` | - | メインAPI（Parse関数） |
| `nodes/parsenodes.go` | 86 KB | 全210ノード型定義 |
| `nodes/outfuncs.go` | - | シリアライゼーション |

### go.mod

```
module github.com/pgplex/pgparser
go 1.21
// 外部依存: なし
```

---

## 2. パーサーAPI

### メイン関数

```go
package parser

// Parse はSQL文字列をパースし、AST（抽象構文木）を返す
func Parse(input string) (*nodes.List, error)
```

### 戻り値の構造

```
*nodes.List
  └── Items: []Node
       └── *nodes.RawStmt
            ├── Stmt: Node          // 実際のステートメント
            ├── StmtLocation: int   // ソース中のバイトオフセット
            └── StmtLen: int        // バイト長（0 = 残り全て）
```

### 基本使用例

```go
import (
    "github.com/pgplex/pgparser/parser"
    "github.com/pgplex/pgparser/nodes"
)

stmts, err := parser.Parse("SELECT id, name FROM users WHERE active = true")
if err != nil {
    log.Fatal(err)
}

rawStmt := stmts.Items[0].(*nodes.RawStmt)
selectStmt := rawStmt.Stmt.(*nodes.SelectStmt)

// TargetList: SELECT句の項目
// FromClause: FROM句のテーブル参照
// WhereClause: WHERE句の条件式
```

### 複数文のパース

```go
stmts, _ := parser.Parse("SELECT 1; INSERT INTO t VALUES (1); DELETE FROM t")
// stmts.Items[0] → SelectStmt
// stmts.Items[1] → InsertStmt
// stmts.Items[2] → DeleteStmt
```

### スレッドセーフ

`Parse` 関数はスレッドセーフであり、並行呼び出しが可能。

---

## 3. AST ノード型（全210型）

### ステートメントノード（75+）

#### DML

| ノード型 | SQL | 主要フィールド |
|---------|-----|--------------|
| `SelectStmt` | SELECT / VALUES | TargetList, FromClause, WhereClause, GroupClause, SortClause, LimitCount |
| `InsertStmt` | INSERT | Relation, Cols, SelectStmt, OnConflictClause, ReturningList |
| `UpdateStmt` | UPDATE | Relation, TargetList, WhereClause, FromClause, ReturningList |
| `DeleteStmt` | DELETE | Relation, UsingClause, WhereClause, ReturningList |
| `MergeStmt` | MERGE (PG17+) | Relation, SourceRelation, JoinCondition, MergeWhenClauses |

#### DDL

| ノード型 | SQL | 主要フィールド |
|---------|-----|--------------|
| `CreateStmt` | CREATE TABLE | Relation, TableElts, InhRelations, Constraints, Partbound |
| `ViewStmt` | CREATE VIEW | View, Query, Aliases, WithCheckOption |
| `IndexStmt` | CREATE INDEX | Idxname, Relation, IndexParams, WhereClause, Unique |
| `AlterTableStmt` | ALTER TABLE | Relation, Cmds (67+サブコマンド), ObjType |
| `DropStmt` | DROP | Objects, RemoveType, Behavior (CASCADE/RESTRICT) |
| `CreateRoleStmt` | CREATE ROLE/USER | Role, Options |
| `CreateFunctionStmt` | CREATE FUNCTION | Funcname, Parameters, ReturnType, Options |
| `CreateTrigStmt` | CREATE TRIGGER | Trigname, Relation, Funcname, Events, Timing |
| `CreateDomainStmt` | CREATE DOMAIN | Domainname, TypeName, Constraints |
| `CreateSeqStmt` | CREATE SEQUENCE | Sequence, Options |
| `CreateSchemaStmt` | CREATE SCHEMA | Schemaname, SchemaElts |
| `CreateExtensionStmt` | CREATE EXTENSION | Extname, Options |
| `CreateEnumStmt` | CREATE TYPE AS ENUM | TypeName, Vals |

#### DCL / その他

| ノード型 | SQL |
|---------|-----|
| `GrantStmt` | GRANT / REVOKE |
| `TransactionStmt` | BEGIN / COMMIT / ROLLBACK / SAVEPOINT |
| `ExplainStmt` | EXPLAIN |
| `CopyStmt` | COPY |
| `TruncateStmt` | TRUNCATE |
| `LockStmt` | LOCK |
| `VariableSetStmt` | SET |
| `VariableShowStmt` | SHOW |
| `PrepareStmt` | PREPARE |
| `ExecuteStmt` | EXECUTE |
| `DeallocateStmt` | DEALLOCATE |

### 式ノード（50+）

| ノード型 | 用途 | 例 |
|---------|------|---|
| `ColumnRef` | カラム参照 | `id`, `t.name`, `schema.table.*` |
| `A_Const` | リテラル値 | `42`, `3.14`, `'text'`, `NULL` |
| `A_Expr` | 演算子式 | `a + b`, `a = b`, `a BETWEEN x AND y` |
| `TypeCast` | 型キャスト | `value::TYPE`, `CAST(v AS TYPE)` |
| `FuncCall` | 関数呼び出し | `COUNT(*)`, `SUM(amt)`, `now()` |
| `BoolExpr` | 論理式 | `AND`, `OR`, `NOT` |
| `SubLink` | サブクエリ | `(SELECT ...)`, `EXISTS(...)`, `IN (SELECT ...)` |
| `CaseExpr` | CASE式 | `CASE WHEN ... THEN ... END` |
| `ArrayExpr` | 配列 | `ARRAY[1, 2, 3]` |
| `RowExpr` | 行式 | `ROW(a, b, c)` |
| `NullTest` | NULL判定 | `IS NULL`, `IS NOT NULL` |
| `CoalesceExpr` | COALESCE | `COALESCE(a, b, c)` |
| `MinMaxExpr` | GREATEST/LEAST | `GREATEST(a, b)` |
| `BooleanTest` | 真偽判定 | `IS TRUE`, `IS NOT FALSE` |
| `ParamRef` | パラメータ参照 | `$1`, `$2` |
| `A_Indirection` | 間接参照 | `arr[1]`, `(row).field` |
| `CollateClause` | 照合順序 | `name COLLATE "C"` |

### 補助ノード

| ノード型 | 用途 |
|---------|------|
| `RangeVar` | テーブル参照（スキーマ.テーブル） |
| `JoinExpr` | JOIN句 |
| `RangeSubselect` | FROM句のサブクエリ |
| `RangeFunction` | FROM句の関数 |
| `Alias` | エイリアス |
| `ResTarget` | SELECT句の結果カラム |
| `SortBy` | ORDER BY句の項目 |
| `WindowDef` | WINDOW定義 |
| `WithClause` | CTE (WITH句) |
| `CommonTableExpr` | 個々のCTE定義 |
| `OnConflictClause` | ON CONFLICT句 |
| `GroupingSet` | GROUPING SETS / CUBE / ROLLUP |
| `LockingClause` | FOR UPDATE / SHARE |
| `TypeName` | 型名 |
| `ColumnDef` | カラム定義 |
| `Constraint` | 制約定義 |

---

## 4. 主要なAST構造体

### SelectStmt

```go
type SelectStmt struct {
    DistinctClause *List        // DISTINCT ON 式のリスト (nil = 非DISTINCT)
    TargetList     *List        // SELECT項目 (ResTarget)
    FromClause     *List        // テーブル/サブクエリ (RangeVar, JoinExpr等)
    WhereClause    Node         // WHERE条件
    GroupClause    *List        // GROUP BY式
    GroupDistinct  bool         // GROUP BY DISTINCT?
    HavingClause   Node         // HAVING条件
    WindowClause   *List        // WINDOW定義
    ValuesLists    *List        // VALUES句
    SortClause     *List        // ORDER BY (SortBy)
    LimitOffset    Node         // OFFSET
    LimitCount     Node         // LIMIT
    LimitOption    LimitOption  // FETCH WITH TIES
    LockingClause  *List        // FOR UPDATE/SHARE

    // 集合演算 (UNION, INTERSECT, EXCEPT)
    Op    SetOperation  // SETOP_NONE, SETOP_UNION, SETOP_INTERSECT, SETOP_EXCEPT
    All   bool          // UNION ALL?
    Larg  *SelectStmt   // 左辺
    Rarg  *SelectStmt   // 右辺

    WithClause *WithClause // CTE
}
```

### A_Expr（演算子式）

```go
type A_Expr struct {
    Kind     A_Expr_Kind // 式の種類
    Name     *List       // 演算子名 (String ノード)
    Lexpr    Node        // 左オペランド
    Rexpr    Node        // 右オペランド
    Location ParseLoc    // ソース位置
}

// Kind の値
const (
    AEXPR_OP              // 通常演算子: +, =, <, >
    AEXPR_OP_ANY          // scalar op ANY (array)
    AEXPR_OP_ALL          // scalar op ALL (array)
    AEXPR_DISTINCT        // IS DISTINCT FROM
    AEXPR_NOT_DISTINCT    // IS NOT DISTINCT FROM
    AEXPR_NULLIF          // NULLIF(a, b)
    AEXPR_IN              // IN (list)
    AEXPR_LIKE            // LIKE
    AEXPR_ILIKE           // ILIKE
    AEXPR_SIMILAR         // SIMILAR TO
    AEXPR_BETWEEN         // BETWEEN ... AND ...
    AEXPR_NOT_BETWEEN     // NOT BETWEEN
    AEXPR_BETWEEN_SYM     // BETWEEN SYMMETRIC
    AEXPR_NOT_BETWEEN_SYM // NOT BETWEEN SYMMETRIC
)
```

### FuncCall（関数呼び出し）

```go
type FuncCall struct {
    Funcname       *List    // 関数名 (String ノード)
    Args           *List    // 引数
    AggOrder       *List    // ORDER BY (集約関数用)
    AggFilter      Node     // FILTER句
    Over           Node     // OVER句 (WindowDef)
    AggWithinGroup bool     // WITHIN GROUP?
    AggStar        bool     // COUNT(*)?
    AggDistinct    bool     // DISTINCT in aggregate?
    FuncVariadic   bool     // 可変長引数?
    FuncFormat     int      // 表示形式
    Location       ParseLoc
}
```

### RangeVar（テーブル参照）

```go
type RangeVar struct {
    Catalogname    string   // データベース名
    Schemaname     string   // スキーマ名
    Relname        string   // テーブル/ビュー名
    Inh            bool     // 継承テーブルを含む?
    Relpersistence byte     // 'p'=永続, 't'=一時, 'u'=unlogged
    Alias          *Alias   // テーブルエイリアス
    Location       ParseLoc
}
```

### JoinExpr（JOIN）

```go
type JoinExpr struct {
    Jointype    JoinType // JOIN_INNER, JOIN_LEFT, JOIN_FULL, JOIN_RIGHT, JOIN_SEMI, JOIN_ANTI
    IsNatural   bool     // NATURAL JOIN?
    Larg        Node     // 左テーブル
    Rarg        Node     // 右テーブル
    UsingClause *List    // USING (columns)
    JoinUsingAlias *Alias // USING エイリアス
    Quals       Node     // ON 条件
    Alias       *Alias
    Rtindex     int
}
```

---

## 5. 式（Expression）の表現

### 例: `price * 1.1 > 100`

```
A_Expr (AEXPR_OP, ">")
├── Lexpr: A_Expr (AEXPR_OP, "*")
│   ├── Lexpr: ColumnRef {Fields: ["price"]}
│   └── Rexpr: A_Const {Val: Float{Str: "1.1"}}
└── Rexpr: A_Const {Val: Integer{Ival: 100}}
```

### 例: `name LIKE '%john%' AND age BETWEEN 20 AND 30`

```
BoolExpr (AND_EXPR)
├── Args[0]: A_Expr (AEXPR_LIKE)
│   ├── Lexpr: ColumnRef {Fields: ["name"]}
│   └── Rexpr: A_Const {Val: String{Str: "%john%"}}
└── Args[1]: A_Expr (AEXPR_BETWEEN)
    ├── Lexpr: ColumnRef {Fields: ["age"]}
    └── Rexpr: List [A_Const{20}, A_Const{30}]
```

### 例: `COALESCE(email, 'unknown') || '@' || domain`

```
A_Expr (AEXPR_OP, "||")
├── Lexpr: A_Expr (AEXPR_OP, "||")
│   ├── Lexpr: CoalesceExpr
│   │   └── Args: [ColumnRef{"email"}, A_Const{"unknown"}]
│   └── Rexpr: A_Const {Val: String{Str: "@"}}
└── Rexpr: ColumnRef {Fields: ["domain"]}
```

---

## 6. 型情報

### AST に含まれる型情報

```go
type TypeName struct {
    Names       *List    // 型名 (String ノード)
    TypeOid     Oid      // 型OID（パーサーでは未設定）
    Setof       bool     // SETOF?
    PctType     bool     // %TYPE?
    Typmods     *List    // 型修飾子 (VARCHAR(100) → [Integer{100}])
    ArrayBounds *List    // 配列次元
    Location    ParseLoc
}
```

### 含まれるもの

- ✅ `TypeName` ノードでの型指定（`CREATE TABLE` のカラム型等）
- ✅ `TypeCast` ノードでの型キャスト（`value::TYPE`）
- ✅ 型修飾子（`VARCHAR(255)` の `255`）
- ✅ 配列次元（`INT[][]`）

### 含まれないもの

- ❌ 型OID解決（意味解析フェーズの担当）
- ❌ 関数シグネチャの解決
- ❌ 暗黙の型変換情報
- ❌ 制約検証

> **重要**: pgparser は**生のパースツリー（raw parse tree）**を生成する。型解決はクエリ計画フェーズで行う必要がある。

---

## 7. ASTの走査（Tree Walking）

### pgparser はビジターパターンを提供しない

手動でノードを走査する必要がある:

```go
func walkNode(node nodes.Node) {
    if node == nil {
        return
    }

    switch n := node.(type) {
    case *nodes.SelectStmt:
        walkList(n.TargetList)
        walkList(n.FromClause)
        walkNode(n.WhereClause)
        walkList(n.GroupClause)
        walkNode(n.HavingClause)
        walkList(n.SortClause)
        walkNode(n.LimitCount)
        walkNode(n.LimitOffset)
    case *nodes.A_Expr:
        walkNode(n.Lexpr)
        walkNode(n.Rexpr)
    case *nodes.FuncCall:
        walkList(n.Args)
        walkNode(n.Over)
        walkNode(n.AggFilter)
    case *nodes.BoolExpr:
        walkList(n.Args)
    case *nodes.SubLink:
        walkNode(n.Subselect)
        walkNode(n.Testexpr)
    case *nodes.ColumnRef:
        // リーフノード
    case *nodes.A_Const:
        // リーフノード
    // ... 全210ノード型を処理
    }
}

func walkList(list *nodes.List) {
    if list == nil {
        return
    }
    for _, item := range list.Items {
        walkNode(item)
    }
}
```

### 汎用ビジター実装パターン

```go
type Visitor func(node nodes.Node) bool // false で走査中断

func Walk(node nodes.Node, visitor Visitor) {
    if node == nil || !visitor(node) {
        return
    }
    // ノード種別ごとに子ノードを走査
    switch n := node.(type) {
    case *nodes.SelectStmt:
        WalkList(n.TargetList, visitor)
        WalkList(n.FromClause, visitor)
        Walk(n.WhereClause, visitor)
        // ...
    // ...
    }
}
```

---

## 8. シリアライゼーション

### NodeToString（組み込み）

```go
stmts, _ := parser.Parse("SELECT 1 + 2 AS result")
rawStmt := stmts.Items[0].(*nodes.RawStmt)
fmt.Println(nodes.NodeToString(rawStmt.Stmt))
```

出力（PostgreSQL内部形式）:

```
{SELECTSTMT 
  :distinctClause <> 
  :targetList (
    {RESTARGET 
      :name "result" 
      :val {A_EXPR :kind 0 :name ("+" ) 
            :lexpr {A_CONST :val {INTEGER :ival 1}} 
            :rexpr {A_CONST :val {INTEGER :ival 2}}}
    }
  )
  :fromClause <> :whereClause <> ...
}
```

### 重要な制限

`NodeToString` は PostgreSQL の**内部デバッグ形式**であり、有効なSQLは生成しない。SQLの再生成（デパーサー）が必要な場合は別途実装が必要。

---

## 9. pg_query_go との比較

| 特性 | pgparser | pg_query_go |
|------|---------|-------------|
| **実装** | Pure Go | Go + C (CGO) |
| **外部依存** | ゼロ | libpg_query |
| **正確性** | 99.6% | 100% |
| **性能** | 高速（CGOオーバーヘッドなし） | CGOコストあり |
| **デプロイ** | シングルバイナリ | .so/.dll 必要 |
| **メンテナンス** | gram.y から手動更新 | アップストリーム自動追従 |
| **スレッドセーフ** | ✅ | ✅（ロック付き） |
| **ビルド** | `go get` のみ | Cコンパイラ必要 |
| **デパーサー** | ❌ なし | ✅ あり |
| **対応PGバージョン** | 17.7 | 16 |
| **Protobuf AST** | ❌ | ✅ |

### 選択基準

- **Pure Go必須** → pgparser
- **100%互換必須** → pg_query_go
- **パフォーマンス重視** → pgparser
- **SQL再生成が必要** → pg_query_go（デパーサー付き）

---

## 10. ゼロ依存の実現方法

### go.mod

```
module github.com/pgplex/pgparser
go 1.21
// 依存なし
```

### 依存排除の手法

| 一般的な依存 | pgparser での解決方法 |
|------------|---------------------|
| Bison/flex | goyacc（Go標準ツール） |
| PostgreSQL Cライブラリ | 文法の移植 + 手書きレキサー |
| 正規表現ライブラリ | 手書きステートマシン |
| コード生成ランタイム | パーサー生成器に組み込み |
| 外部値型 | Go ネイティブ型（string, int64, bool） |

---

## 11. 実践的な使用例

### テーブル参照の抽出

```go
func findTables(sql string) ([]string, error) {
    stmts, err := parser.Parse(sql)
    if err != nil {
        return nil, err
    }

    var tables []string
    for _, item := range stmts.Items {
        rawStmt := item.(*nodes.RawStmt)
        collectTables(rawStmt.Stmt, &tables)
    }
    return tables, nil
}

func collectTables(node nodes.Node, tables *[]string) {
    if node == nil {
        return
    }
    switch n := node.(type) {
    case *nodes.RangeVar:
        if n.Relname != "" {
            name := n.Relname
            if n.Schemaname != "" {
                name = n.Schemaname + "." + name
            }
            *tables = append(*tables, name)
        }
    case *nodes.SelectStmt:
        collectTablesList(n.FromClause, tables)
        collectTables(n.WhereClause, tables)
    case *nodes.JoinExpr:
        collectTables(n.Larg, tables)
        collectTables(n.Rarg, tables)
    // ... 他のノード型
    }
}
```

### ステートメント種別の判定

```go
func classifyStatement(sql string) (string, error) {
    stmts, err := parser.Parse(sql)
    if err != nil {
        return "", err
    }
    rawStmt := stmts.Items[0].(*nodes.RawStmt)

    switch rawStmt.Stmt.(type) {
    case *nodes.SelectStmt:
        return "SELECT", nil
    case *nodes.InsertStmt:
        return "INSERT", nil
    case *nodes.UpdateStmt:
        return "UPDATE", nil
    case *nodes.DeleteStmt:
        return "DELETE", nil
    case *nodes.CreateStmt:
        return "CREATE TABLE", nil
    case *nodes.ViewStmt:
        return "CREATE VIEW", nil
    case *nodes.IndexStmt:
        return "CREATE INDEX", nil
    default:
        return fmt.Sprintf("UNKNOWN(%T)", rawStmt.Stmt), nil
    }
}
```

### パラメータ（$1, $2...）の抽出

```go
func findParams(node nodes.Node) []int {
    var params []int
    walk(node, func(n nodes.Node) {
        if p, ok := n.(*nodes.ParamRef); ok {
            params = append(params, p.Number)
        }
    })
    sort.Ints(params)
    return params
}

// "SELECT * FROM t WHERE id = $1 AND name = $2" → [1, 2]
```

---

## 12. PostgreSQL 19devel ソースコードとの比較

pgparser が基づく PostgreSQL 17.7 と、最新の 19devel ソースコードを比較し、パーサー関連の規模と差異を整理する。

### ソースコード規模の比較

| ファイル | PostgreSQL 19devel | pgparser (PG 17.7 ベース) | 備考 |
|---------|-------------------|--------------------------|------|
| `gram.y` (文法定義) | **20,059行** | 393 KB (goyacc形式) | 新しい SQL 構文が追加されている可能性あり |
| `scan.l` (字句解析) | **1,421行** | `lexer.go` (32 KB, 手書きGo) | flex → Go への手動変換 |
| `parsenodes.h` (ASTノード型) | **4,433行** | `parsenodes.go` (86 KB, 210型) | 19devel では新規ノード型が追加 |
| `primnodes.h` (式ノード型) | **2,394行** | pgparser の nodes パッケージに統合 | |
| `plannodes.h` (プランノード型) | **1,874行** | pgparser の範囲外（パーサーのみ） | |

### PostgreSQL のパーサーエントリポイント

PostgreSQL のパーサーは `parser.c` の `raw_parser()` 関数がエントリポイントとなる:

```c
// src/backend/parser/parser.c
List *
raw_parser(const char *str, RawParseMode mode)
{
    // 1. レキサーを初期化 (scan.l)
    // 2. gram.y のパーサーを実行
    // 3. 生のパースツリー (raw parse tree) を返す
    //    → List of RawStmt ノード
}
```

この `raw_parser()` が返す**生のパースツリー（raw parse tree）**は、pgparser の `parser.Parse()` が返すものと同等の構造である。PostgreSQL ではその後、`analyze.c` の `parse_analyze()` で意味解析（名前解決、型解決等）が行われ、Query ツリーに変換される。

```
PostgreSQL のパイプライン:
  raw_parser() → raw parse tree → parse_analyze() → Query tree → pg_plan_queries() → Plan tree

pgparser の範囲:
  parser.Parse() → raw parse tree（ここまで）
```

### 19devel で追加される可能性のある構文

PostgreSQL 19devel は開発中のバージョンであり、PG 17.7 の `gram.y` には存在しない新しい SQL キーワードや文法規則が含まれている可能性がある。主な差異が想定される領域:

- **新しい SQL 標準構文**: PostgreSQL は各メジャーバージョンで SQL 標準への準拠を拡大している
- **新しいユーティリティコマンド**: 管理系の DDL/DCL の拡張
- **既存構文の拡張**: 既存のステートメントへの新しいオプション追加
- **OAuth 認証関連**: 19devel で追加された新機能に関連するシステムコマンド

### pgparser の AST ノード数 vs PostgreSQL の全ノード定義

pgparser が定義する **210 AST ノード型**は `parsenodes.h` に対応するもので、パーサーが生成する構文ノードに限定される。PostgreSQL の `src/include/nodes/` ディレクトリには、より広範なノード型が定義されている:

| ヘッダファイル | 19devel 行数 | 内容 |
|-------------|-------------|------|
| `parsenodes.h` | 4,433行 | パーサー出力ノード（SELECT, INSERT等のAST） |
| `primnodes.h` | 2,394行 | プリミティブ式ノード（Var, Const, OpExpr等） |
| `plannodes.h` | 1,874行 | プランナー出力ノード（SeqScan, HashJoin等） |
| `execnodes.h` | - | エグゼキュータ状態ノード（PlanState等） |
| `pathnodes.h` | - | プランナー内部パスノード（Path, RelOptInfo等） |

pgparser はパーサーフェーズのみを扱うため、`primnodes.h` の一部（パーサー段階で使用されるもの）と `parsenodes.h` の全体が対象となる。`plannodes.h` 以降はクエリ計画・実行フェーズのノードであり、pgparser の範囲外である。

### バージョン差異への対応方針

pgparser が PG 17.7 ベースであることを踏まえ、19devel との差異は以下のように対応する:

1. **基本的な SQL 構文**: PG 17.7 で十分にカバーされている（SELECT, INSERT, UPDATE, DELETE, DDL 等）
2. **新構文が必要な場合**: pgparser の gram.y を手動更新するか、pg_query_go (CGO) への切り替えを検討
3. **テスト用途**: 大多数のユースケースでは PG 17.7 の文法で十分

---

## まとめ

pgparser は以下の特徴を持つ:

| 特徴 | 評価 |
|------|------|
| Pure Go / ゼロ依存 | ✅ 完全 |
| PostgreSQL 17.7 互換 | ✅ 99.6% |
| AST ノード型 | ✅ 210型 |
| スレッドセーフ | ✅ |
| ビジターパターン | ❌ 手動走査が必要 |
| SQL再生成（デパーサー） | ❌ 未実装 |
| 型解決（意味解析） | ❌ パーサーの範囲外 |

クエリ実行エンジンを構築する場合、pgparser の出力（raw parse tree）を受け取り、以下の処理を実装する必要がある:

1. **名前解決**: テーブル名・カラム名の解決
2. **型解決**: 式の型推論
3. **最適化**: クエリプラン生成
4. **実行**: 実際のデータ操作

---

[← README に戻る](../README.md)
