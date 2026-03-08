# 既存プロジェクトの調査

[← README に戻る](../README.md)

---

## 1. fergusstrange/embedded-postgres

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/fergusstrange/embedded-postgres |
| **Star数** | ⭐ 1,149 |
| **言語** | Go |
| **方式** | PostgreSQLバイナリをダウンロードし子プロセスとして起動 |

### 概要

Maven リポジトリからプリコンパイル済みPostgreSQLバイナリをダウンロードし、ローカルで子プロセスとして起動する。Java の [zonkyio/embedded-postgres](https://github.com/zonkyio/embedded-postgres) にインスパイアされている。

### 使い方

```go
postgres := embeddedpostgres.NewDatabase()
err := postgres.Start()
// Do test logic
err = postgres.Stop()
```

カスタム設定も可能：

```go
postgres := NewDatabase(DefaultConfig().
    Username("beer").
    Password("wine").
    Database("gin").
    Version(V12).
    RuntimePath("/tmp").
    Port(9876).
    StartTimeout(45 * time.Second))
```

### デフォルト設定

| 項目 | デフォルト値 |
|------|------------|
| Username | postgres |
| Password | postgres |
| Database | postgres |
| Version | 18.0.0 |
| Port | 5432 |
| StartTimeout | 15秒 |

### メリット

- 完全なPostgreSQL互換性（実際のPostgreSQLを実行）
- Go以外の外部依存なし（バイナリは自動ダウンロード）
- セットアップが簡単
- バージョン指定が可能

### デメリット

- **インプロセスではない**（子プロセスとして起動）
- バイナリダウンロードが必要（初回起動が遅い）
- プラットフォーム依存（アーキテクチャごとのバイナリが必要）
- テスト並列化時のポート衝突リスク
- `RuntimePath` は起動ごとに削除・再作成される

---

## 2. dolthub/doltgresql (DoltgreSQL)

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/dolthub/doltgresql |
| **Star数** | ⭐ 1,668 |
| **言語** | Go |
| **方式** | PostgreSQLワイヤープロトコル互換のGo製データベース |

### 概要

Dolt（バージョン管理付きMySQLデータベース）のPostgreSQL版。[dolthub/go-mysql-server](https://github.com/dolthub/go-mysql-server)（⭐ 2,616）のSQLエンジンをベースに、PostgreSQLのワイヤープロトコルとSQL構文をサポートする。2025年4月にBeta品質に到達。

### アーキテクチャ

```
PostgreSQL クライアント (psql, pgx)
        ↓
PostgreSQL ワイヤープロトコル
        ↓
PostgreSQL AST パーサー
        ↓ (AST変換)
go-mysql-server SQLエンジン
        ↓
Dolt ストレージエンジン (Prolly Tree)
```

### パフォーマンス（Sysbench、v0.50.0）

| カテゴリ | PostgreSQL比 |
|---------|-------------|
| Read平均 | 6.3倍遅い |
| Write平均 | 3.6倍遅い |
| 総合平均 | 5.2倍遅い |

### SQL互換性（sqllogictest、v0.50.0）

| 結果 | 件数 |
|------|------|
| OK | 5,188,604 |
| NG | 411,415 |
| 未実行 | 91,270 |
| **正確性** | **91.17%** |

### メリット

- Pure Go実装
- PostgreSQLのSQLlogictest で 91.17% の正確性
- 活発に開発中（Beta品質）
- `pg_dump` / `psql` でのインポートをサポート

### デメリット

- ライブラリとしての組み込み用途には設計されていない（独立サーバーとして動作）
- Doltのバージョン管理機能と密結合
- 依存パッケージが非常に大きい
- 一部のPostgreSQL機能が未実装
- GSSAPI未サポート
- 拡張機能（Extension）未サポート

---

## 3. proullon/ramsql

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/proullon/ramsql |
| **Star数** | ⭐ 927 |
| **言語** | Go |
| **方式** | Pure Go インメモリSQLエンジン（`database/sql` ドライバ） |

### 概要

テスト用に設計されたPure Go製のインメモリSQLエンジン。`database/sql` のドライバとして動作し、PostgreSQL風のSQL構文をサポートする。DataSourceNameごとに独立したエンジンが割り当てられ、テスト間の完全な分離を実現。

### 使い方

```go
import (
    "database/sql"
    _ "github.com/proullon/ramsql/driver"
)

db, err := sql.Open("ramsql", "TestLoadUserAddresses")
defer db.Close()

_, err = db.Exec(`CREATE TABLE address (id BIGSERIAL PRIMARY KEY, street TEXT, street_number INT)`)
```

### GORM互換

```go
ramdb, _ := sql.Open("ramsql", "TestGormQuickStart")
db, _ := gorm.Open(postgres.New(postgres.Config{Conn: ramdb}), &gorm.Config{})
```

### SQL機能サポート状況

| 機能 | パース | 実装 |
|------|-------|------|
| CREATE TABLE | ✅ | ✅ |
| PRIMARY KEY | ✅ | ✅ |
| INSERT / SELECT / UPDATE / DELETE | ✅ | ✅ |
| INNER JOIN | ✅ | ✅ |
| OUTER JOIN | ✅ | ❌ |
| ORDER BY / OFFSET | ✅ | ✅ |
| COUNT / MAX | ✅ | ✅ |
| Transactions | ✅ | ✅ |
| Hash Index | ✅ | ✅ |
| FOREIGN KEY | ❌ | ❌ |
| JSON | ❌ | ❌ |
| AS | ❌ | ❌ |
| B-Tree Index | ✅ | ❌ |

### メリット

- **Pure Go**: CGo不要
- **真のインプロセス・インメモリ**: `sql.Open("ramsql", "TestName")` で即座に使用可能
- **テスト分離**: DataSourceName ごとに独立したエンジン
- **GORM互換**: PostgreSQLドライバ経由で使用可能
- 高速起動

### デメリット

- PostgreSQL互換性が低い（独自パーサー）
- サポートするSQL機能が限定的
- FOREIGN KEY 未対応
- トランザクション実装が簡略化されている（テーブルレベルロック）
- ワイヤープロトコル未対応（`database/sql` ドライバのみ）

---

## 4. electric-sql/pglite

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/electric-sql/pglite |
| **Star数** | ⭐ 14,835 |
| **言語** | TypeScript / C（WASM） |
| **方式** | PostgreSQLをWASMにコンパイル |

### 概要

PostgreSQLをEmscriptenでWASMにコンパイルし、ブラウザやNode.jsで動作させるプロジェクト。PostgreSQLの「シングルユーザーモード」を利用している。Neon の [Stas Kelvich](https://github.com/kelvich) による [postgres-wasm](https://github.com/electric-sql/postgres-wasm) をベースにしている。

### 動作原理

PostgreSQLは通常、クライアント接続ごとにプロセスをフォークするモデルで動作する。Emscriptenでコンパイルされたプログラムはプロセスフォークができないため、PostgreSQLの「シングルユーザーモード」（ブートストラップ・リカバリ用のコマンドラインモード）を活用し、JavaScript環境からの入出力パスウェイを提供している。

### 使い方（TypeScript）

```typescript
import { PGlite } from "@electric-sql/pglite";

// インメモリ
const db = new PGlite();
await db.query("select 'Hello world' as message;");

// ファイル永続化
const db = new PGlite("./path/to/pgdata");

// ブラウザ indexedDB 永続化
const db = new PGlite("idb://my-pgdata");
```

### メリット

- **本物のPostgreSQL**: WASM化されているが実際のPostgreSQLコード
- pgvector等の拡張機能もサポート
- 3MB（gzip）と軽量
- ブラウザ / Node.js / Bun / Deno で動作

### デメリット

- JavaScript/TypeScript環境向け（Go からの直接利用は不可）
- シングルユーザー/シングルコネクション制限
- Emscriptenの制約（プロセスフォーク不可）

### Go活用の可能性

Go製WASMランタイム [wazero](https://github.com/tetratelabs/wazero) でPGliteのWASMモジュールを実行する可能性があるが、EmscriptenのJavaScript相互運用レイヤーへの依存が最大の障壁となる。

---

## 5. jeroenrinzema/psql-wire

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/jeroenrinzema/psql-wire |
| **Star数** | ⭐ 219 |
| **言語** | Go |
| **方式** | PostgreSQLワイヤープロトコルのPure Go実装 |

### 概要

PostgreSQLのワイヤープロトコル（クライアント-サーバー間通信プロトコル）をPure Goで実装したライブラリ。数行のコードで独自のPostgreSQL互換サーバーを構築できる。Shopify等での採用実績がある。

### 使い方

```go
package main

import (
    "context"
    "fmt"
    wire "github.com/jeroenrinzema/psql-wire"
)

func main() {
    wire.ListenAndServe("127.0.0.1:5432", handler)
}

func handler(ctx context.Context, query string) (wire.PreparedStatements, error) {
    return wire.Prepared(wire.NewStatement(func(ctx context.Context, writer wire.DataWriter, parameters []wire.Parameter) error {
        fmt.Println(query)
        return writer.Complete("OK")
    })), nil
}
```

### メリット

- Pure Go
- `pgx` や `psql` などの標準PostgreSQLクライアントから接続可能
- カスタムハンドラーでクエリ処理をフック可能
- セッション属性のサポート
- Shopify等で採用実績あり

### デメリット

- SQLパーサー・実行エンジンは含まない（ワイヤープロトコルのみ）
- クエリの解釈と実行は利用者側で実装する必要がある

---

[← README に戻る](../README.md)
