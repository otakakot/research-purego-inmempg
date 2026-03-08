# psql-wire 詳細分析

[← README に戻る](../README.md)

---

psql-wire の内部アーキテクチャ、ハンドラAPI、型システム、プロトコルサポートを詳細に分析する。

---

## 目次

1. [アーキテクチャ概要](#1-アーキテクチャ概要)
2. [メインAPI](#2-メインapi)
3. [ハンドラ / フックAPI](#3-ハンドラ--フックapi)
4. [型システム](#4-型システム)
5. [Extended Query Protocol](#5-extended-query-protocol)
6. [認証](#6-認証)
7. [セッション管理](#7-セッション管理)
8. [並列パイプライニング](#8-並列パイプライニング)
9. [制限事項](#9-制限事項)
10. [最小構成サーバー実装例](#10-最小構成サーバー実装例)

---

## 1. アーキテクチャ概要

psql-wire は PostgreSQL ワイヤープロトコル（v3）の Pure Go 実装であり、**SQLパーサーや実行エンジンを含まない**。コネクション管理とプロトコルメッセージのエンコード/デコードに特化している。

### 接続ライフサイクル

```
クライアント接続
    │
    ▼
┌─────────────────────┐
│  1. TLS ネゴシエーション │
│     (オプション)       │
└──────────┬──────────┘
           │
    ▼
┌─────────────────────┐
│  2. StartupMessage   │
│     パラメータ解析    │
└──────────┬──────────┘
           │
    ▼
┌─────────────────────┐
│  3. 認証             │
│     (AuthStrategy)   │
└──────────┬──────────┘
           │
    ▼
┌─────────────────────┐
│  4. セッション初期化  │
│     (SessionHandler) │
└──────────┬──────────┘
           │
    ▼
┌─────────────────────────────┐
│  5. コマンドループ           │
│     ┌─────────────────────┐ │
│     │ Simple Query (Q)    │ │
│     │ Parse (P)           │ │
│     │ Bind (B)            │ │
│     │ Describe (D)        │ │
│     │ Execute (E)         │ │
│     │ Sync (S)            │ │
│     │ Close (C)           │ │
│     │ Terminate (X)       │ │
│     └─────────────────────┘ │
└──────────┬──────────────────┘
           │
    ▼
┌─────────────────────┐
│  6. 切断処理         │
│     (ClosedHandler)  │
└─────────────────────┘
```

### 1接続 = 1ゴルーチン

各クライアント接続は独立したゴルーチンで処理される。セッション状態は接続ごとに分離される。

---

## 2. メインAPI

### サーバー起動（シンプル）

```go
import wire "github.com/jeroenrinzema/psql-wire"

// 最もシンプルな起動方法
err := wire.ListenAndServe("127.0.0.1:5432", handler)
```

### サーバー起動（詳細設定）

```go
server, err := wire.NewServer(
    wire.Parse(parseFn),           // SQLハンドラ（必須）
    wire.Logger(slog.Default()),   // ロガー
    wire.Session(sessionFn),       // セッション初期化
    wire.Closed(closedFn),         // 切断ハンドラ
    wire.Auth(authStrategy),       // 認証
    wire.Terminate(terminateFn),   // 終了ハンドラ
    wire.CancelRequest(cancelFn),  // キャンセルハンドラ
    wire.Version("17.0"),          // サーバーバージョン
)
if err != nil {
    log.Fatal(err)
}

err = server.ListenAndServe("127.0.0.1:5432")
```

---

## 3. ハンドラ / フックAPI

psql-wire は 7 つのフック/コールバックを提供する:

### 3.1 ParseFn（メインハンドラ）

**最も重要なフック**。クライアントからのSQLクエリを受け取り、結果を返す。

```go
type ParseFn func(ctx context.Context, query string, writer ParseWriter) error
```

```go
func handler(ctx context.Context, query string, writer wire.ParseWriter) error {
    // query: クライアントから受け取ったSQL文字列
    // writer: 結果を書き戻すためのインターフェース
    
    // カラム定義
    writer.Define(wire.Columns{
        {
            Table:  0,
            Name:   "id",
            Oid:    pgtype.Int4OID,
            Width:  4,
            Format: wire.TextFormat,
        },
        {
            Table:  0,
            Name:   "name",
            Oid:    pgtype.TextOID,
            Width:  -1,
            Format: wire.TextFormat,
        },
    })

    // 行データ送信
    writer.Row([]any{int32(1), "Alice"})
    writer.Row([]any{int32(2), "Bob"})

    // 完了通知
    return writer.Complete("SELECT 2")
}
```

### 3.2 SessionHandler

接続確立後、認証成功後に呼ばれる。セッション初期化に使用。

```go
type SessionHandler func(ctx context.Context) (context.Context, error)
```

```go
func sessionHandler(ctx context.Context) (context.Context, error) {
    // パラメータ取得
    params := wire.ParamsFromContext(ctx)
    user := params["user"]
    database := params["database"]
    
    // セッション属性の設定
    wire.SetAttribute(ctx, "user", user)
    wire.SetAttribute(ctx, "database", database)
    
    return ctx, nil
}
```

### 3.3 ClosedHandler

接続が切断されたときに呼ばれる。リソースクリーンアップ用。

```go
type ClosedHandler func(ctx context.Context, err error)
```

### 3.4 AuthStrategy

認証戦略インターフェース。

```go
type AuthStrategy interface {
    AuthHandshake(ctx context.Context, reader *buffer.Reader, writer *buffer.Writer) (context.Context, error)
}
```

組み込み実装:
- `wire.ClearTextPassword(verifyFn)` — クリアテキストパスワード認証

### 3.5 CancelRequestHandler

クライアントからのクエリキャンセル要求を処理。

```go
type CancelRequestHandler func(ctx context.Context, pid int32, secret int32) error
```

### 3.6 TerminateHandler

クライアントが `Terminate` メッセージを送信したときに呼ばれる。

```go
type TerminateHandler func(ctx context.Context) error
```

### 3.7 VersionHandler

サーバーバージョン文字列を設定。`SELECT version()` の応答に影響。

```go
wire.Version("17.0")
```

### フック一覧

| フック | 型 | 必須 | 目的 |
|--------|---|------|------|
| `Parse` | `ParseFn` | ✅ | SQLクエリ処理 |
| `Session` | `SessionHandler` | ❌ | セッション初期化 |
| `Closed` | `ClosedHandler` | ❌ | 切断時クリーンアップ |
| `Auth` | `AuthStrategy` | ❌ | 認証処理 |
| `CancelRequest` | `CancelRequestHandler` | ❌ | クエリキャンセル |
| `Terminate` | `TerminateHandler` | ❌ | 正常切断 |
| `Version` | `string` | ❌ | サーバーバージョン |

---

## 4. 型システム

### pgx/v5 pgtype.Map ベース

psql-wire は `jackc/pgx/v5` の型システムを使用している。PostgreSQL の全 OID に対応。

```go
import "github.com/jackc/pgx/v5/pgtype"

// カラム定義時のOID指定
wire.Columns{
    {Name: "id",        Oid: pgtype.Int4OID},      // int4 (23)
    {Name: "name",      Oid: pgtype.TextOID},       // text (25)
    {Name: "price",     Oid: pgtype.Float8OID},     // float8 (701)
    {Name: "active",    Oid: pgtype.BoolOID},       // bool (16)
    {Name: "created",   Oid: pgtype.TimestamptzOID}, // timestamptz (1184)
    {Name: "data",      Oid: pgtype.JSONBOID},      // jsonb (3802)
    {Name: "tags",      Oid: pgtype.TextArrayOID},  // text[] (1009)
}
```

### Column 構造体

```go
type Column struct {
    Table          int32        // テーブルOID（0 = 計算列）
    Name           string       // カラム名
    AttrNo         int16        // テーブル内の属性番号
    Oid            uint32       // 型OID
    Width          int16        // 型の幅（バイト数、可変長は-1）
    TypeModifier   int32        // 型修飾子
    Format         FormatCode   // TextFormat(0) or BinaryFormat(1)
}
```

### カスタム型の登録

pgtype.Map にカスタム型を登録可能:

```go
typeMap := pgtype.NewMap()
typeMap.RegisterType(&pgtype.Type{
    Name:  "my_custom_type",
    OID:   50000,
    Codec: &MyCustomCodec{},
})
```

---

## 5. Extended Query Protocol

psql-wire は PostgreSQL の Extended Query Protocol を**完全サポート**している。

### プロトコルフロー

```
クライアント                         サーバー
    │                                  │
    │── Parse (SQL + パラメータ型) ────→│  ステートメント準備
    │←── ParseComplete ────────────────│
    │                                  │
    │── Bind (パラメータ値 + 結果形式) →│  パラメータバインド
    │←── BindComplete ─────────────────│
    │                                  │
    │── Describe (Statement or Portal)→│  メタデータ取得
    │←── ParameterDescription ─────────│
    │←── RowDescription ───────────────│
    │                                  │
    │── Execute (ポータル + 行数制限) ─→│  実行
    │←── DataRow (×N) ─────────────────│
    │←── CommandComplete ──────────────│
    │                                  │
    │── Sync ─────────────────────────→│  トランザクション同期
    │←── ReadyForQuery ────────────────│
```

### ステートメントキャッシュ

Extended Query Protocol では、Parse されたステートメントとバインドされたポータルがキャッシュされる:

```go
// 名前付きステートメント: 接続中有効
Parse(name="my_stmt", query="SELECT $1::int + $2::int", paramTypes=[int4OID, int4OID])

// 名前なしステートメント: 次のParseで上書き
Parse(name="", query="SELECT 1", paramTypes=[])
```

### Prepared Statement の動作

```go
// pgx から使用する場合（自動的にExtended Queryを使用）
conn.Query(ctx, "SELECT * FROM users WHERE id = $1", 42)
// → Parse → Bind → Execute → Sync

// 明示的なプリペアドステートメント
stmt, _ := conn.Prepare(ctx, "get_user", "SELECT * FROM users WHERE id = $1")
conn.Query(ctx, "get_user", 42)
// → Bind → Execute → Sync (2回目以降Parseなし)
```

---

## 6. 認証

### 組み込み: ClearTextPassword

```go
verify := func(ctx context.Context, username, password string) (context.Context, error) {
    if username == "admin" && password == "secret" {
        return ctx, nil
    }
    return ctx, fmt.Errorf("invalid credentials")
}

server, _ := wire.NewServer(
    wire.Parse(handler),
    wire.Auth(wire.ClearTextPassword(verify)),
)
```

### カスタム認証

```go
type MyAuthStrategy struct{}

func (a *MyAuthStrategy) AuthHandshake(
    ctx context.Context,
    reader *buffer.Reader,
    writer *buffer.Writer,
) (context.Context, error) {
    // カスタム認証ロジック
    // 例: MD5認証、SCRAM-SHA-256認証 等
    return ctx, nil
}
```

### 未サポートの認証方式

| 認証方式 | サポート |
|---------|---------|
| Trust (認証なし) | ✅ デフォルト |
| ClearTextPassword | ✅ 組み込み |
| MD5Password | ❌ カスタム実装必要 |
| SCRAM-SHA-256 | ❌ カスタム実装必要 |
| GSS/SSPI | ❌ |
| Certificate | ❌ |

---

## 7. セッション管理

### セッション属性

接続ごとに任意のキー・バリューを保存できる:

```go
// 設定
wire.SetAttribute(ctx, "current_database", "mydb")
wire.SetAttribute(ctx, "transaction_state", "idle")

// 取得
db := wire.GetAttribute(ctx, "current_database")
```

### StartupMessage パラメータ

クライアントが接続時に送信するパラメータを取得:

```go
func sessionHandler(ctx context.Context) (context.Context, error) {
    params := wire.ParamsFromContext(ctx)
    
    // 標準パラメータ
    user := params["user"]
    database := params["database"]
    appName := params["application_name"]
    clientEncoding := params["client_encoding"]
    
    return ctx, nil
}
```

---

## 8. 並列パイプライニング

2026年1月追加の新機能。バッチクエリを並列実行可能。

### 概念

```
従来（シーケンシャル）:
  Query1 → 結果1 → Query2 → 結果2 → Query3 → 結果3

パイプライニング:
  Query1 ─→ ┐
  Query2 ─→ ┤ 並列実行 → 結果1, 結果2, 結果3（順序保証）
  Query3 ─→ ┘
```

### pgx からの利用

```go
// pgx のパイプラインモード
batch := &pgx.Batch{}
batch.Queue("SELECT 1")
batch.Queue("SELECT 2")
batch.Queue("SELECT 3")

results := conn.SendBatch(ctx, batch)
defer results.Close()
```

---

## 9. 制限事項

### 未サポート機能

| 機能 | 状態 | 備考 |
|------|------|------|
| LISTEN / NOTIFY | ❌ | 非同期通知未実装 |
| COPY プロトコル | ❌ | COPY IN/OUT 未対応 |
| GSS/SASL 認証 | ❌ | ClearText のみ組み込み |
| SSL クライアント証明書 | ⚠️ | TLS はサポート |
| ストリーミングレプリケーション | ❌ | |
| Large Object API | ❌ | |
| トランザクション管理 | ❌ | ユーザー側で実装必要 |
| エラーフィールド詳細 | ⚠️ | 基本的なエラーは送信可能 |

### 意図的な非サポート

psql-wire は意図的に以下を**含まない**:
- SQLパーサー
- クエリオプティマイザ
- ストレージエンジン
- トランザクションマネージャ

これらは利用者側で実装する設計。

---

## 10. 最小構成サーバー実装例

### 基本サーバー（10行）

```go
package main

import (
    "context"
    "log"

    wire "github.com/jeroenrinzema/psql-wire"
    "github.com/jackc/pgx/v5/pgtype"
)

func main() {
    log.Fatal(wire.ListenAndServe("127.0.0.1:5432", handler))
}

func handler(ctx context.Context, query string, writer wire.ParseWriter) error {
    writer.Define(wire.Columns{
        {Name: "result", Oid: pgtype.TextOID, Width: -1, Format: wire.TextFormat},
    })
    writer.Row([]any{"Hello, PostgreSQL!"})
    return writer.Complete("SELECT 1")
}
```

### インプロセス接続パターン（net.Pipe）

```go
package main

import (
    "context"
    "net"

    "github.com/jackc/pgx/v5"
    wire "github.com/jeroenrinzema/psql-wire"
)

func connectInProcess() (*pgx.Conn, error) {
    // psql-wire サーバーを作成（Listen不要）
    server, _ := wire.NewServer(wire.Parse(handler))

    // pgx の接続設定でカスタム DialFunc を使用
    config, _ := pgx.ParseConfig("postgres://localhost/testdb")
    config.DialFunc = func(ctx context.Context, network, addr string) (net.Conn, error) {
        client, serverConn := net.Pipe()
        go server.Serve(serverConn)  // サーバー側をゴルーチンで処理
        return client, nil           // クライアント側を pgx に返す
    }

    return pgx.ConnectConfig(context.Background(), config)
}
```

> **注意**: `server.Serve(conn)` メソッドの存在は要確認。実際の実装ではカスタム `net.Listener` を使用する方法がより確実。

### カスタム Listener パターン

```go
type pipeListener struct {
    conns  chan net.Conn
    closed chan struct{}
}

func newPipeListener() *pipeListener {
    return &pipeListener{
        conns:  make(chan net.Conn),
        closed: make(chan struct{}),
    }
}

func (l *pipeListener) Accept() (net.Conn, error) {
    select {
    case conn := <-l.conns:
        return conn, nil
    case <-l.closed:
        return nil, net.ErrClosed
    }
}

func (l *pipeListener) Close() error {
    close(l.closed)
    return nil
}

func (l *pipeListener) Addr() net.Addr {
    return &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
}

// Dial はクライアント側接続を返す
func (l *pipeListener) Dial(ctx context.Context, network, addr string) (net.Conn, error) {
    client, server := net.Pipe()
    l.conns <- server
    return client, nil
}
```

---

## 利用プロジェクト

| プロジェクト | 用途 |
|------------|------|
| Shopify | 内部ツール |
| Cloudproud | データベースプロキシ |
| DoltgreSQL | ワイヤープロトコル層（参考） |

---

[← README に戻る](../README.md)
