# 主要コンポーネント分析

[← README に戻る](../README.md)

---

インメモリ・インプロセスPostgreSQLを構築するには、以下の5つのコンポーネントが必要となる。

## A. PostgreSQLワイヤープロトコル

クライアント（`pgx`, `psql` 等）と通信するための層。PostgreSQL Front-End/Back-End Protocol（v3）を実装する。

| ライブラリ | 特徴 | URL |
|-----------|------|-----|
| **jeroenrinzema/psql-wire** | Pure Go、高品質、Shopify採用実績あり | https://github.com/jeroenrinzema/psql-wire |

### ワイヤープロトコルの役割

```
クライアント (pgx, psql, etc.)
    │
    │  PostgreSQL Wire Protocol v3
    │  ┌─────────────────────────────┐
    │  │ Startup / Authentication    │
    │  │ Simple Query                │
    │  │ Extended Query (Parse/Bind) │
    │  │ COPY protocol               │
    │  │ Error/Notice messages       │
    │  └─────────────────────────────┘
    │
    ▼
サーバー実装
```

`psql-wire` はこの通信層を提供し、受信したSQLクエリをコールバック関数に渡す設計となっている。

---

## B. SQLパーサー

PostgreSQLのSQL文をAST（抽象構文木）に変換する。PostgreSQL互換性の基盤となる重要なコンポーネント。

### パーサー比較

| ライブラリ | Star | CGo | PGバージョン互換 | 特徴 |
|-----------|------|-----|----------------|------|
| **pgplex/pgparser** | 10 | ❌ 不要 | PG 17.7 | goyaccによるgram.y変換、99.6%回帰テスト通過 |
| **auxten/postgresql-parser** | - | ❌ 不要 | PG (CRDB v20.1.11) | CockroachDBから抽出、Atlas/Bytebase採用 |
| **pganalyze/pg_query_go** | 822 | ✅ 必要 | PG最新 | PostgreSQL本体パーサーのCラッパー |

### pgplex/pgparser（推奨）

2026年2月に公開された新しいプロジェクトで、PostgreSQL 17.7の`gram.y`をgoyaccで変換したPure Go実装。

**特徴**:
- **100% Native Go**: CGo不要、外部依存なし
- **AST互換**: PostgreSQLの内部`Node`構造体（`parsenodes.h`）と完全一致
- **高い互換性**: PostgreSQL回帰テストスイート（約45,000 SQL文）の99.6%を通過
- **スレッドセーフ**: 並行利用が安全

```go
import "github.com/pgplex/pgparser/parser"

stmts, err := parser.Parse("SELECT * FROM users WHERE id > 100")
```

### auxten/postgresql-parser

CockroachDB v20.1.11のSQLパーサーを抽出・簡略化したもの。[Atlas](https://github.com/ariga/atlas)（⭐ 1.8k）や [ByteBase](https://github.com/bytebase/bytebase)（⭐ 3.6k）で採用実績がある。

```go
import "github.com/auxten/postgresql-parser/pkg/sql/parser"

stmts, err := parser.Parse("SELECT * FROM users")
```

### pganalyze/pg_query_go

PostgreSQL本体の実際のパーサーをCGo経由で呼び出す。最も正確だがCGo依存。

---

## C. クエリ実行エンジン

パースしたASTを解釈し、データの読み書きを実行するコンポーネント。**最も実装が困難**な部分。

### 既存の実行エンジン

| ライブラリ | 特徴 | URL |
|-----------|------|-----|
| **dolthub/go-mysql-server** | 成熟したSQLエンジン（MySQL互換）、ストレージ抽象化あり | https://github.com/dolthub/go-mysql-server |
| 独自実装 | 完全な制御が可能だが開発コスト大 | - |

### go-mysql-server の機能

- クエリプランナー・オプティマイザー
- JOIN（INNER, LEFT, RIGHT, CROSS）
- サブクエリ
- 集約関数（COUNT, SUM, AVG, MAX, MIN等）
- ウィンドウ関数
- トランザクション
- インデックス
- ストレージ抽象化（カスタムバックエンド可能）

**注意**: go-mysql-server は MySQL 互換であり、PostgreSQL の AST をそのまま渡すことはできない。DoltgreSQL は PostgreSQL AST → go-mysql-server AST への変換レイヤーを持つ。

### クエリ実行エンジンに必要な機能

1. **型システム**: PostgreSQLの型（TEXT, INTEGER, BOOLEAN, TIMESTAMP, JSONB, ARRAY等）
2. **演算子**: 比較、算術、論理、文字列、パターンマッチ
3. **関数**: 組み込み関数（数百種類）
4. **暗黙の型キャスト**: PostgreSQL固有のキャストルール
5. **NULL処理**: 三値論理
6. **プランニング**: クエリ最適化
7. **トランザクション**: ACID特性、分離レベル

---

## D. ストレージエンジン（インメモリ）

データをメモリ上に保持するストレージバックエンド。

### 設計オプション

| 方式 | 特徴 | 適用場面 |
|------|------|---------|
| **HashMap ベース** | O(1)のキー検索、シンプル | 小規模テスト |
| **B-Tree ベース** | 範囲クエリ対応、ソート済みデータ | 汎用 |
| **go-mysql-server メモリバックエンド** | 既存実装を活用可能 | DoltgreSQL活用時 |
| **カスタム列指向** | 分析クエリに有利 | OLAP用途 |

### ramsql のストレージ設計（参考）

ramsql では以下の設計を採用している:

- **行ストレージ**: 連結リスト（GCフレンドリー）
- **ハッシュインデックス**: `map[string]uintptr` / `map[int64]uintptr`（GCチェック回避のためuintptrを使用）
- **テーブルレベルロック**: トランザクション用

---

## E. 接続方式

Goアプリケーションからインプロセスデータベースに接続する方法。

### オプション比較

| 方式 | ネットワーク | 互換性 | 性能 |
|------|------------|--------|------|
| **TCP (localhost)** | 必要 | ✅ 全クライアント対応 | 普通 |
| **Unix domain socket** | 必要（ファイルシステム） | ✅ 大半のクライアント対応 | TCPより高速 |
| **database/sql ドライバ** | 不要 | ⚠️ Go標準インターフェースのみ | 最速 |
| **pgx カスタムダイヤラー** | 不要 | ⚠️ pgx専用 | 最速 |
| **net.Pipe()** | 不要（インプロセス） | ✅ ワイヤープロトコル互換 | 高速 |

### 推奨: net.Pipe() を利用したインプロセス接続

`net.Pipe()` は双方向のインメモリ接続を作成でき、TCP/Unixソケットを使わずにワイヤープロトコル経由の通信が可能になる。

```go
// 概念的な実装
serverConn, clientConn := net.Pipe()

// サーバー側: psql-wire でserverConnを処理
go server.HandleConnection(serverConn)

// クライアント側: pgxのダイヤラーをオーバーライド
config, _ := pgx.ParseConfig("postgres://localhost/test")
config.DialFunc = func(ctx context.Context, network, addr string) (net.Conn, error) {
    return clientConn, nil
}
conn, _ := pgx.ConnectConfig(ctx, config)
```

---

[← README に戻る](../README.md)
