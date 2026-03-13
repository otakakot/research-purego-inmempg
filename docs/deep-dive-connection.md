# インプロセス接続パターン詳細分析

[← README に戻る](../README.md)

---

TCP サーバーを起動せずにインプロセスで PostgreSQL 互換接続を実現するための技術パターンを詳細に分析する。

---

## 目次

0. [PostgreSQL 本体の接続ライフサイクル（19devel ソースコード調査）](#0-postgresql-本体の接続ライフサイクル19devel-ソースコード調査)
1. [概要と目標](#1-概要と目標)
2. [net.Pipe() の仕組み](#2-netpipe-の仕組み)
3. [pgx のカスタム DialFunc](#3-pgx-のカスタム-dialfunc)
4. [カスタム net.Listener パターン](#4-カスタム-netlistener-パターン)
5. [database/sql ドライバアプローチ](#5-databasesql-ドライバアプローチ)
6. [統合パターン: psql-wire + pgx + net.Pipe()](#6-統合パターン-psql-wire--pgx--netpipe)
7. [パフォーマンス比較](#7-パフォーマンス比較)
8. [実世界の事例](#8-実世界の事例)
9. [推奨実装パターン](#9-推奨実装パターン)

---

## 0. PostgreSQL 本体の接続ライフサイクル（19devel ソースコード調査）

インプロセス実装の設計判断を正しく行うために、PostgreSQL 本体の接続処理フローを理解しておくことが重要である。

### 接続確立の全体フロー

```
クライアント (libpq)
    │
    │  TCP 接続
    ▼
postmaster (src/backend/postmaster/postmaster.c)
    │  fork() で子プロセスを生成
    ▼
backend_startup (src/backend/tcop/backend_startup.c)
    │  BackendMain() → BackendStartup()
    │  ├── StartupMessage の読み取り・パラメータ解析
    │  ├── 認証処理 (auth.c 呼び出し)
    │  └── セッション初期化
    ▼
postgres (src/backend/tcop/postgres.c)
    │  PostgresMain() → メインコマンドループ
    │  ReadCommand() でクライアントからのメッセージを待機
    │  ├── 'Q' → exec_simple_query()
    │  ├── 'P' → exec_parse_message()
    │  ├── 'B' → exec_bind_message()
    │  ├── 'E' → exec_execute_message()
    │  └── 'X' → Terminate
    ▼
切断・クリーンアップ
```

### 認証フロー（src/backend/libpq/auth.c, 約89KB）

PostgreSQL 19devel の `auth.c` は以下の認証方式をサポートしている:

| 認証方式 | 説明 | auth.c 内の処理 |
|---------|------|----------------|
| Trust | 認証なし | `AUTH_REQ_OK` を即座に返す |
| ClearTextPassword | 平文パスワード | `AUTH_REQ_PASSWORD` → パスワード照合 |
| MD5Password | MD5ハッシュ | `AUTH_REQ_MD5` → ソルト送信 → ハッシュ照合 |
| SCRAM-SHA-256 | チャレンジ・レスポンス | `AUTH_REQ_SASL` → 複数ラウンドのネゴシエーション |
| GSSAPI | Kerberos認証 | `AUTH_REQ_GSS` / `AUTH_REQ_GSS_CONT` |
| SSPI | Windows認証 | `AUTH_REQ_SSPI` |
| Certificate | SSL証明書認証 | TLS接続のクライアント証明書を検証 |
| OAuth | OAuthベアラートークン | PostgreSQL 19devel で新規追加 |

### キャンセルメカニズム

クエリキャンセルは通常の接続とは**別のTCP接続**で行われる。`src/include/libpq/pqcomm.h` で定義される特殊プロトコルコード:

```c
#define CANCEL_REQUEST_CODE PG_PROTOCOL(1234,5678)
```

`CancelRequest` メッセージは StartupMessage と同じ形式だが、プロトコルバージョンの代わりにこの特殊コードが入る。postmaster はこのコードを検出すると、対応するバックエンドプロセスに `SIGINT` を送信する。

### インプロセス実装への示唆

| PostgreSQL 本体の処理 | インプロセス実装での簡略化 |
|---------------------|------------------------|
| fork() による子プロセス生成 | ゴルーチンで代替（軽量） |
| TCP/UnixSocket 通信 | `net.Pipe()` でメモリ内通信 |
| 複雑な認証方式（SCRAM, GSS等） | Trust または ClearText で十分 |
| `pg_hba.conf` による認証制御 | 不要（テスト用途） |
| シグナルベースのキャンセル | `context.Context` のキャンセルで代替 |
| 共有メモリ・プロセス間通信 | ゴルーチン間のチャネルで代替 |

> **重要**: psql-wire の `CancelRequest` ハンドラは `pid` と `secret` を受け取るが、インプロセス実装では `context.Context` によるキャンセル伝播の方が自然であり、Go のイディオムに合致する。

---

## 1. 概要と目標

### 目標

```
テストコード:
  db, _ := sql.Open("inmempg", "")
  db.Query("SELECT * FROM users WHERE id = $1", 42)
```

これを実現するために、TCP ポートを開かず、外部プロセスを起動せず、純粋にインプロセスで PostgreSQL ワイヤープロトコル通信を行う。

### 接続パターンの選択肢

| パターン | TCP不要 | pgx対応 | database/sql対応 | 複雑度 |
|---------|--------|---------|-----------------|--------|
| net.Pipe() + DialFunc | ✅ | ✅ | ✅ | 低 |
| カスタム Listener | ✅ | ✅ | ✅ | 中 |
| database/sql ドライバ直接 | ✅ | ❌ | ✅ | 中 |
| Unix ドメインソケット | ⚠️ | ✅ | ✅ | 低 |
| TCP localhost | ❌ | ✅ | ✅ | 低 |

---

## 2. net.Pipe() の仕組み

### 基本概念

```go
client, server := net.Pipe()
```

`net.Pipe()` は2つの `net.Conn` を生成する。一方に書き込んだデータはもう一方から読み取れる:

```
client.Write("hello") → server.Read() = "hello"
server.Write("world") → client.Read() = "world"
```

### 特性

| 特性 | 値 |
|------|---|
| 型 | `net.Conn`（フルインターフェース実装） |
| バッファリング | なし（同期的）|
| アドレス | `pipe` |
| スレッドセーフ | ✅ |
| タイムアウト | `SetDeadline` サポート |
| TCP オーバーヘッド | なし（メモリコピーのみ） |
| ゴルーチン要件 | 読み書きは別ゴルーチン |

### 重要な注意点

```go
client, server := net.Pipe()

// ❌ 同一ゴルーチンでの読み書きはデッドロック
client.Write(data)  // server.Read() を待つ → ブロック
client.Read(buf)    // 到達不可能

// ✅ 別ゴルーチンで処理
go func() {
    server.Read(buf)
    server.Write(response)
}()
client.Write(data)
client.Read(buf)
```

---

## 3. pgx のカスタム DialFunc

### pgx v5 の接続設定

pgx v5 は `ConnConfig` に `DialFunc` フィールドを持ち、TCP接続をカスタム接続に差し替え可能:

```go
import "github.com/jackc/pgx/v5"

config, err := pgx.ParseConfig("postgres://user:pass@localhost/dbname")
if err != nil {
    log.Fatal(err)
}

// DialFunc をオーバーライド
config.DialFunc = func(ctx context.Context, network, addr string) (net.Conn, error) {
    client, server := net.Pipe()
    go handleServerSide(server)  // サーバー側をゴルーチンで処理
    return client, nil           // pgx にクライアント側を返す
}

conn, err := pgx.ConnectConfig(context.Background(), config)
```

### pgx が DialFunc を使う流れ

```
pgx.ConnectConfig(config)
    │
    ▼ config.DialFunc(ctx, "tcp", "localhost:5432")
    │
    ├── client, server := net.Pipe()
    ├── go handleServerSide(server)  ← ワイヤープロトコル処理
    └── return client               ← pgx が使う net.Conn
    │
    ▼ pgx: StartupMessage 送信
    │
    ▼ pgx: 認証ハンドシェイク
    │
    ▼ pgx: ReadyForQuery 受信
    │
    ▼ 接続完了！
```

### database/sql 経由

```go
import (
    "database/sql"
    "github.com/jackc/pgx/v5/stdlib"
)

// pgx を database/sql ドライバとして登録
connStr := stdlib.RegisterConnConfig(config)
db, err := sql.Open("pgx", connStr)
```

---

## 4. カスタム net.Listener パターン

psql-wire は `net.Listener` を受け入れるため、カスタム Listener を作成してインプロセス接続を実現できる。

### 実装

```go
// pipeListener は net.Pipe() ベースのカスタム Listener
type pipeListener struct {
    conns  chan net.Conn
    closed chan struct{}
    once   sync.Once
    addr   net.Addr
}

func newPipeListener() *pipeListener {
    return &pipeListener{
        conns:  make(chan net.Conn, 16),  // バッファ付き
        closed: make(chan struct{}),
        addr:   &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0},
    }
}

// Accept はサーバー側の接続を受け付ける（psql-wire が呼ぶ）
func (l *pipeListener) Accept() (net.Conn, error) {
    select {
    case conn := <-l.conns:
        return conn, nil
    case <-l.closed:
        return nil, net.ErrClosed
    }
}

func (l *pipeListener) Close() error {
    l.once.Do(func() { close(l.closed) })
    return nil
}

func (l *pipeListener) Addr() net.Addr {
    return l.addr
}

// Dial はクライアント接続を生成（pgx の DialFunc から呼ぶ）
func (l *pipeListener) Dial(ctx context.Context, network, addr string) (net.Conn, error) {
    select {
    case <-l.closed:
        return nil, net.ErrClosed
    default:
    }

    client, server := net.Pipe()

    select {
    case l.conns <- server:
        return client, nil
    case <-ctx.Done():
        client.Close()
        server.Close()
        return nil, ctx.Err()
    case <-l.closed:
        client.Close()
        server.Close()
        return nil, net.ErrClosed
    }
}
```

### psql-wire との統合

```go
listener := newPipeListener()

// サーバー起動（バックグラウンド）
server, _ := wire.NewServer(wire.Parse(handler))
go server.Serve(listener)

// pgx 接続設定
config, _ := pgx.ParseConfig("postgres://localhost/testdb")
config.DialFunc = listener.Dial

// 接続（TCP不要！）
conn, _ := pgx.ConnectConfig(ctx, config)
defer conn.Close(ctx)

// 通常通りクエリ実行
rows, _ := conn.Query(ctx, "SELECT * FROM users")
```

---

## 5. database/sql ドライバアプローチ

### ramsql スタイル: ドライバ直接登録

```go
import "database/sql"

func init() {
    sql.Register("inmempg", &Driver{})
}

type Driver struct{}

func (d *Driver) Open(name string) (driver.Conn, error) {
    return &Conn{engine: getOrCreateEngine(name)}, nil
}

type Conn struct {
    engine *Engine
}

func (c *Conn) Prepare(query string) (driver.Stmt, error) {
    return &Stmt{conn: c, query: query}, nil
}

func (c *Conn) Begin() (driver.Tx, error) {
    return &Tx{conn: c}, nil
}
```

### メリット / デメリット

| 項目 | ドライバ直接 | net.Pipe() + pgx |
|------|------------|------------------|
| API | `database/sql` のみ | `pgx` + `database/sql` |
| PG型サポート | 自前実装必要 | pgx が自動処理 |
| 実装コスト | 中 | 低 |
| 互換性 | database/sql レベル | フルPGプロトコル |
| Prepared Stmt | Simple Query のみ可能 | Extended Query 完全対応 |
| pgx固有機能 | ❌ | ✅ (CopyFrom, Batch等) |

### 推奨

**net.Pipe() + pgx アプローチを推奨**。理由:

1. pgx の型変換・エンコーディングをそのまま活用
2. Extended Query Protocol を完全サポート
3. `database/sql` 経由でも `pgx` 直接でも使用可能
4. psql-wire が多くのプロトコル処理を担当

---

## 6. 統合パターン: psql-wire + pgx + net.Pipe()

### 全体アーキテクチャ

```
テストコード / アプリケーション
    │
    ▼
┌─────────────────────────┐
│  pgx / database/sql     │
│  (PostgreSQL クライアント) │
└──────────┬──────────────┘
           │ net.Pipe() (client側)
           │
    ═══════╪════════════════  メモリ内通信（TCP不要）
           │
           │ net.Pipe() (server側)
┌──────────▼──────────────┐
│  psql-wire              │
│  (ワイヤープロトコル)    │
└──────────┬──────────────┘
           │ ParseFn コールバック
┌──────────▼──────────────┐
│  pgparser               │
│  (SQLパーサー)           │
└──────────┬──────────────┘
           │ AST
┌──────────▼──────────────┐
│  クエリ実行エンジン      │
│  (自作 or GMS ベース)    │
└──────────┬──────────────┘
           │
┌──────────▼──────────────┐
│  インメモリストレージ    │
└─────────────────────────┘
```

### 完全な実装スケルトン

```go
package inmempg

import (
    "context"
    "net"
    "sync"

    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgtype"
    "github.com/jackc/pgx/v5/stdlib"
    wire "github.com/jeroenrinzema/psql-wire"
    "github.com/pgplex/pgparser/parser"
    "github.com/pgplex/pgparser/nodes"
)

// Engine はインメモリPostgreSQLエンジン
type Engine struct {
    listener *pipeListener
    server   *wire.Server
    storage  *Storage
    mu       sync.RWMutex
}

// New はエンジンを生成して起動する
func New() (*Engine, error) {
    e := &Engine{
        listener: newPipeListener(),
        storage:  NewStorage(),
    }

    server, err := wire.NewServer(
        wire.Parse(e.handleQuery),
        wire.Session(e.handleSession),
        wire.Version("17.0"),
    )
    if err != nil {
        return nil, err
    }
    e.server = server

    go server.Serve(e.listener)
    return e, nil
}

// handleQuery は psql-wire の ParseFn コールバック
func (e *Engine) handleQuery(ctx context.Context, query string, writer wire.ParseWriter) error {
    // 1. SQLをパース
    stmts, err := parser.Parse(query)
    if err != nil {
        return err
    }

    // 2. 各ステートメントを実行
    for _, item := range stmts.Items {
        rawStmt := item.(*nodes.RawStmt)
        if err := e.executeStatement(ctx, rawStmt.Stmt, writer); err != nil {
            return err
        }
    }
    return nil
}

// executeStatement は AST ノードを実行する
func (e *Engine) executeStatement(ctx context.Context, stmt nodes.Node, writer wire.ParseWriter) error {
    switch s := stmt.(type) {
    case *nodes.SelectStmt:
        return e.executeSelect(ctx, s, writer)
    case *nodes.InsertStmt:
        return e.executeInsert(ctx, s, writer)
    case *nodes.CreateStmt:
        return e.executeCreateTable(ctx, s, writer)
    // ... 他のステートメント
    default:
        return fmt.Errorf("unsupported statement: %T", stmt)
    }
}

// ConnectPgx は pgx.Conn を返す（インプロセス接続）
func (e *Engine) ConnectPgx(ctx context.Context) (*pgx.Conn, error) {
    config, err := pgx.ParseConfig("postgres://test@localhost/testdb")
    if err != nil {
        return nil, err
    }
    config.DialFunc = e.listener.Dial
    return pgx.ConnectConfig(ctx, config)
}

// OpenDB は database/sql の *sql.DB を返す
func (e *Engine) OpenDB() (*sql.DB, error) {
    config, err := pgx.ParseConfig("postgres://test@localhost/testdb")
    if err != nil {
        return nil, err
    }
    config.DialFunc = e.listener.Dial
    connStr := stdlib.RegisterConnConfig(config)
    return sql.Open("pgx", connStr)
}

// Close はエンジンを停止する
func (e *Engine) Close() error {
    e.listener.Close()
    return nil
}
```

### テストでの使用例

```go
func TestUserRepository(t *testing.T) {
    // エンジン起動
    engine, err := inmempg.New()
    require.NoError(t, err)
    defer engine.Close()

    // database/sql で接続
    db, err := engine.OpenDB()
    require.NoError(t, err)
    defer db.Close()

    // テーブル作成
    _, err = db.Exec(`CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE
    )`)
    require.NoError(t, err)

    // データ挿入
    _, err = db.Exec("INSERT INTO users (name, email) VALUES ($1, $2)", "Alice", "alice@example.com")
    require.NoError(t, err)

    // クエリ
    var name, email string
    err = db.QueryRow("SELECT name, email FROM users WHERE id = $1", 1).Scan(&name, &email)
    require.NoError(t, err)
    assert.Equal(t, "Alice", name)
}
```

---

## 7. パフォーマンス比較

### 接続方式別のオーバーヘッド

| 方式 | 接続時間 | クエリ往復 | メモリ | ポート使用 |
|------|---------|-----------|-------|----------|
| TCP localhost | ~1ms | ~100μs | 高 | ✅ 使用 |
| Unix socket | ~0.5ms | ~50μs | 中 | ❌ |
| net.Pipe() | ~10μs | ~5μs | 低 | ❌ |
| ドライバ直接 | ~1μs | ~1μs | 最低 | ❌ |

### net.Pipe() のオーバーヘッド源

1. メモリコピー（クライアント→サーバー、サーバー→クライアント）
2. ゴルーチン間のチャネル同期
3. ワイヤープロトコルのエンコード/デコード
4. pgx の型変換処理

> TCP に比べてワイヤープロトコルのエンコード/デコードコストが支配的になる。ネットワークスタックのオーバーヘッドは排除される。

---

## 8. 実世界の事例

### CockroachDB

CockroachDB は内部テストで `net.Pipe()` 相当のインプロセス接続を使用:
- `pkg/sql/pgwire/` にワイヤープロトコル実装
- テスト用にインメモリ接続をサポート
- 本番では TCP、テストではインプロセス

### ramsql

ramsql は `database/sql` ドライバとして登録:
```go
db, _ := sql.Open("ramsql", "TestDB")
```
- ワイヤープロトコルなし
- database/sql インターフェースのみ
- pgx 非対応

### embedded-postgres（参考: 外部プロセス方式）

```go
pg := embeddedpostgres.NewDatabase()
pg.Start()
db, _ := sql.Open("postgres", "host=localhost port=5432 ...")
```
- 実際のPostgreSQLバイナリを子プロセスとして起動
- 完全なPG互換だが、インプロセスではない

---

## 9. 推奨実装パターン

### パターン A: net.Pipe() + psql-wire（推奨）

```
利点:
  ✅ pgx フル対応（Extended Query Protocol含む）
  ✅ database/sql 経由でも使用可能
  ✅ TCP ポート不要
  ✅ psql-wire がプロトコル処理を担当
  ✅ 複数同時接続可能

欠点:
  ⚠️ ワイヤープロトコルのオーバーヘッド
  ⚠️ psql-wire への依存
```

### パターン B: database/sql ドライバ直接

```
利点:
  ✅ 最小オーバーヘッド
  ✅ 依存が少ない
  ✅ 実装がシンプル

欠点:
  ❌ pgx 固有機能（CopyFrom, Batch）非対応
  ❌ PostgreSQL 型変換を自前実装
  ❌ Extended Query Protocol 非対応
```

### パターン C: ハイブリッド

```go
// テスト用途（高速）: database/sql ドライバ直接
db, _ := sql.Open("inmempg", "testdb")

// 互換性テスト用途（完全）: net.Pipe() + pgx
conn, _ := engine.ConnectPgx(ctx)
```

### 最終推奨

**パターン A（net.Pipe() + psql-wire）を推奨**。

理由:
1. PostgreSQL 互換性が目標であり、ワイヤープロトコル互換は必須
2. テスト対象コードが `pgx` や `database/sql` を使用する場合、実際のプロトコル経由でテストすべき
3. psql-wire が Extended Query Protocol を処理するため、自前実装のコストを削減
4. パフォーマンスのオーバーヘッドはテスト用途では許容範囲

---

[← README に戻る](../README.md)
