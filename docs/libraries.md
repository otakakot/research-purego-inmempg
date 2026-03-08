# 関連ライブラリ・リポジトリ詳細リファレンス

[← README に戻る](../README.md)

---

## ライセンス一覧

| プロジェクト | ライセンス | 商用利用 | 派生物配布 | 注意事項 |
|------------|-----------|---------|-----------|---------|
| embedded-postgres | MIT | ✅ | ✅ | 制限なし |
| DoltgreSQL | Apache-2.0 | ✅ | ✅ | 変更ファイルへの通知必要 |
| go-mysql-server | Apache-2.0 | ✅ | ✅ | 変更ファイルへの通知必要 |
| ramsql | BSD-3-Clause | ✅ | ✅ | 著作権表示必要 |
| PGlite | Apache-2.0 / PostgreSQL License（デュアル） | ✅ | ✅ | いずれかを選択可 |
| psql-wire | Apache-2.0 | ✅ | ✅ | Copyright 2025 CloudProud B.V. |
| pgplex/pgparser | MIT + PostgreSQL License | ✅ | ✅ | PG由来部分はPostgreSQL License |
| auxten/postgresql-parser | Apache-2.0 | ✅ | ✅ | CockroachDB由来コードを含む |
| pg_query_go | BSD-3-Clause | ✅ | ✅ | pganalyze著作権表示必要 |
| ebitengine/purego | Apache-2.0 | ✅ | ✅ | Go runtime由来コードはBSD-3 |
| wazero | Apache-2.0 | ✅ | ✅ | Copyright 2020-2023 wazero authors |

> **すべてのプロジェクトが商用利用可能なオープンソースライセンス**を採用しており、組み合わせて利用する際のライセンス互換性に問題はない。

---

## プロジェクト詳細

### 1. fergusstrange/embedded-postgres

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/fergusstrange/embedded-postgres |
| **ライセンス** | MIT |
| **Star数** | ⭐ 1,149 |
| **Go モジュール** | `github.com/fergusstrange/embedded-postgres` |
| **最小Go** | 1.18 |
| **作者** | Fergus Strange |
| **初回リリース** | 2019年11月 |
| **最終更新** | 2026年3月 |

**依存関係（直接）**:
- `github.com/lib/pq` — PostgreSQLドライバ
- `github.com/xi2/xz` — xz圧縮
- `github.com/stretchr/testify` — テスト

**特徴的な設計**:
- Maven リポジトリ（`repo1.maven.org`）からプリコンパイル済みバイナリを取得
- [zonkyio/embedded-postgres-binaries](https://github.com/zonkyio/embedded-postgres-binaries) に依存
- PostgreSQL 12〜18 をサポート
- RuntimePath は起動ごとに削除・再作成（永続データには DataPath を使用）

---

### 2. dolthub/doltgresql

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/dolthub/doltgresql |
| **ライセンス** | Apache-2.0 |
| **Star数** | ⭐ 1,668 |
| **Go モジュール** | `github.com/dolthub/doltgresql` |
| **最小Go** | 1.25.6 |
| **開発元** | DoltHub, Inc. |
| **初回リリース** | 2023年9月 |
| **最終更新** | 2026年3月（活発） |
| **ステータス** | Beta |

**主要な直接依存関係**:
- `github.com/dolthub/dolt/go` — Dolt コアエンジン
- `github.com/dolthub/go-mysql-server` — SQLエンジン
- `github.com/dolthub/vitess` — SQL パーサー（MySQL系）
- `github.com/dolthub/pg_query_go/v6` — PostgreSQL パーサー（CGo版のフォーク）
- `github.com/jackc/pgx/v5` — PostgreSQL クライアント（テスト用）
- `github.com/cockroachdb/apd/v2` — 任意精度小数
- `github.com/ebitengine/purego` — CGo不要FFI（一部使用）

**間接依存関係の規模**: 約200パッケージ（AWS SDK, GCP SDK, Azure SDK を含む重量級）

**注意点**:
- DoltGres は `ebitengine/purego` を内部で使用している
- 依存関係が非常に大きく、バイナリサイズに影響する
- Doltのリモート（S3, GCS, Azure等）機能のためのクラウドSDK依存がある

---

### 3. dolthub/go-mysql-server

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/dolthub/go-mysql-server |
| **ライセンス** | Apache-2.0 |
| **Star数** | ⭐ 2,616 |
| **Go モジュール** | `github.com/dolthub/go-mysql-server` |
| **開発元** | DoltHub, Inc. |
| **初回リリース** | 2019年6月 |

**提供する機能**:
- MySQL互換のSQLエンジン（パーサー＋プランナー＋実行エンジン）
- ストレージ抽象化レイヤー（カスタムバックエンド対応）
- インメモリストレージバックエンド内蔵
- JOIN、サブクエリ、ウィンドウ関数、CTE
- トランザクション、インデックス
- `database/sql` 経由でのアクセス

**DoltgreSQLとの関係**: DoltgreSQL は本ライブラリの上にPostgreSQL互換層を構築している

---

### 4. proullon/ramsql

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/proullon/ramsql |
| **ライセンス** | BSD-3-Clause |
| **Star数** | ⭐ 927 |
| **Go モジュール** | `github.com/proullon/ramsql` |
| **最小Go** | 1.20 |
| **初回リリース** | 2014年11月 |
| **最終更新** | 活発 |

**依存関係（直接）**:
- `gorm.io/driver/postgres` — GORM互換性テスト用
- `gorm.io/gorm` — ORM互換テスト用
- `github.com/glebarez/go-sqlite` — テスト用

**使い方**:
```go
import _ "github.com/proullon/ramsql/driver"

db, _ := sql.Open("ramsql", "TestName")
```

**内部アーキテクチャ**:
- 行ストレージ: 連結リスト（GCフレンドリー）
- ハッシュインデックス: `map[string]uintptr` （GCチェック回避）
- トランザクション: テーブルレベルロック
- パーサー: 独自実装（PostgreSQL構文の一部をサポート）

---

### 5. electric-sql/pglite

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/electric-sql/pglite |
| **ライセンス** | Apache-2.0 / PostgreSQL License（デュアルライセンス） |
| **Star数** | ⭐ 14,835 |
| **言語** | TypeScript / C (WASM) |
| **開発元** | ElectricSQL |
| **初回リリース** | 2024年2月 |
| **最終更新** | 2026年3月（非常に活発） |

**技術的背景**:
- Neon の [Stas Kelvich](https://github.com/kelvich) による [postgres-wasm](https://github.com/electric-sql/postgres-wasm) フォークがベース
- Emscripten で PostgreSQL を WASM にコンパイル
- PostgreSQLの「シングルユーザーモード」を利用
- 3MB（gzip）

**サポート環境**:
- ブラウザ（indexedDB永続化）
- Node.js / Bun / Deno（ファイル永続化）

**拡張機能サポート**:
- pgvector
- その他のPostgreSQL拡張（WASMビルド対応のもの）

**Goから利用する場合の障壁**:
- Emscripten の JavaScript 相互運用レイヤーが必須
- wazero は WASI をサポートするが、Emscripten 固有の ABI は非対応
- PGlite の入出力パスウェイが JavaScript 環境前提

---

### 6. jeroenrinzema/psql-wire

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/jeroenrinzema/psql-wire |
| **ライセンス** | Apache-2.0 (Copyright 2025 CloudProud B.V.) |
| **Star数** | ⭐ 219 |
| **Go モジュール** | `github.com/jeroenrinzema/psql-wire` |
| **最小Go** | 1.25.0 |
| **初回リリース** | 2021年9月 |
| **最終更新** | 2026年3月（活発） |

**依存関係（直接）**:
- `github.com/jackc/pgx/v5` — テスト用PostgreSQLクライアント
- `github.com/lib/pq` — テスト用PostgreSQLドライバ

**採用実績**:
- [CloudProud](https://cloudproud.nl)
- [Shopify](https://www.shopify.com)

**API設計**:
```go
// Simple Query handler
func handler(ctx context.Context, query string) (wire.PreparedStatements, error) {
    return wire.Prepared(wire.NewStatement(func(ctx context.Context, writer wire.DataWriter, parameters []wire.Parameter) error {
        return writer.Complete("OK")
    })), nil
}

// Session attributes
wire.SetAttribute(ctx, "tenant_id", "tenant-123")
tenantID, ok := wire.GetAttribute(ctx, "tenant_id")
```

**サポートするプロトコル機能**:
- Startup / Authentication
- Simple Query Protocol
- Extended Query Protocol (Parse/Bind/Describe/Execute)
- セッション属性管理

---

### 7. pgplex/pgparser

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/pgplex/pgparser |
| **ライセンス** | MIT + PostgreSQL License（PG由来部分） |
| **Star数** | ⭐ 10 |
| **Go モジュール** | `github.com/pgplex/pgparser` |
| **最小Go** | 1.21 |
| **作者** | Rebelice Yang |
| **初回リリース** | 2026年2月（非常に新しい） |
| **対応PGバージョン** | PostgreSQL 17.7 (REL_17_STABLE) |

**依存関係**: なし（外部依存ゼロ）

**実装方法**:
- PostgreSQL の `src/backend/parser/gram.y` を Go の `goyacc` で変換
- レキサー（`scan.l`）を Go で再実装
- ノード定義（`parsenodes.h`）を Go 構造体に1:1マッピング

**互換性テスト結果**:
- PostgreSQL 回帰テストスイート: 約45,000 SQL文
- **通過率: 99.6%**

**使い方**:
```go
import "github.com/pgplex/pgparser/parser"

stmts, err := parser.Parse("SELECT * FROM users WHERE id > 100")
```

**注目ポイント**:
- 外部依存ゼロで Pure Go
- スレッドセーフ
- PostgreSQL の AST と完全互換のノード構造体
- 非常に新しいプロジェクト（2026年2月公開）

---

### 8. auxten/postgresql-parser

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/auxten/postgresql-parser |
| **ライセンス** | Apache-2.0 |
| **Go モジュール** | `github.com/auxten/postgresql-parser` |
| **最小Go** | 1.15 |
| **初回リリース** | 2021年2月 |
| **ベース** | CockroachDB v20.1.11 |

**依存関係（直接）**:
- `github.com/cockroachdb/apd` — 任意精度小数
- `github.com/cockroachdb/errors` — エラーハンドリング
- `github.com/gogo/protobuf` — Protocol Buffers
- `github.com/grpc-ecosystem/grpc-gateway` — gRPC
- `github.com/lib/pq` — PostgreSQLドライバ（テスト用）
- その他 CockroachDB 由来の依存

**採用実績**:
- [Atlas](https://github.com/ariga/atlas) — データベーススキーマ管理 (⭐ 1.8k)
- [ByteBase](https://github.com/bytebase/bytebase) — データベースCI/CD (⭐ 3.6k)
- [その他の依存者](https://github.com/auxten/postgresql-parser/network/dependents)

**使い方**:
```go
import (
    "github.com/auxten/postgresql-parser/pkg/sql/parser"
    "github.com/auxten/postgresql-parser/pkg/walk"
)

stmts, err := parser.Parse(sql)
w := &walk.AstWalker{Fn: walkFunc}
w.Walk(stmts, nil)
```

**pgplex/pgparser との比較**:
| 項目 | pgplex/pgparser | auxten/postgresql-parser |
|------|----------------|------------------------|
| ベース | PostgreSQL 17.7 | CockroachDB v20.1.11 |
| 外部依存 | なし | 多い（protobuf, gRPC等） |
| Go最小バージョン | 1.21 | 1.15 |
| AST互換 | PG本体と同一 | CockroachDB独自拡張含む |
| 成熟度 | 新しい（2026年2月） | 成熟（2021年〜、実績あり） |
| メンテナンス | 活発 | 低頻度 |

---

### 9. pganalyze/pg_query_go

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/pganalyze/pg_query_go |
| **ライセンス** | BSD-3-Clause |
| **Star数** | ⭐ 822 |
| **Go モジュール** | `github.com/pganalyze/pg_query_go/v5` |
| **CGo** | ✅ 必要 |
| **著作権者** | Lukas Fittl / Duboce Labs, Inc. (pganalyze) |
| **初回リリース** | 2015年8月 |

**実装方法**:
- PostgreSQL本体のパーサーをCライブラリとしてビルド
- CGo経由でGoから呼び出し
- Protocol Buffers でAST を表現

**メリット**: PostgreSQL本体と完全に同一のパース結果を保証
**デメリット**: CGo必須のためクロスコンパイルが困難

---

### 10. ebitengine/purego

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/ebitengine/purego |
| **ライセンス** | Apache-2.0（Go runtime由来コードはBSD-3） |
| **Go モジュール** | `github.com/ebitengine/purego` |
| **最小Go** | 1.18 |
| **開発元** | Ebitengine プロジェクト |
| **ステータス** | Beta |

**依存関係**: なし（外部依存ゼロ）

**対応プラットフォーム（Tier 1）**:
- Linux: amd64, arm64
- macOS: amd64, arm64
- Windows: amd64, arm64
- Android: amd64, arm64（CGO_ENABLED=1必要）
- iOS: amd64, arm64（CGO_ENABLED=1必要）

**使い方**:
```go
libc, _ := purego.Dlopen("/usr/lib/libSystem.B.dylib", purego.RTLD_NOW|purego.RTLD_GLOBAL)
var puts func(string)
purego.RegisterLibFunc(&puts, libc, "puts")
puts("Calling C from Go without Cgo!")
```

**PostgreSQL連携の可能性と限界**:
- 理論上、`libpq` の関数を purego 経由で呼び出すことは可能
- PostgreSQLサーバーの内部関数は共有ライブラリとして公開されていないため、サーバー埋め込みには不適
- DoltgreSQL が内部で purego を使用している実績がある

---

### 11. tetratelabs/wazero

| 項目 | 内容 |
|------|------|
| **リポジトリ** | https://github.com/tetratelabs/wazero |
| **ライセンス** | Apache-2.0 |
| **Go モジュール** | `github.com/tetratelabs/wazero` |
| **開発元** | Tetrate Labs |
| **著作権者** | wazero authors (2020-2023) |

**特徴**:
- Pure Go実装のWebAssemblyランタイム（CGo不要）
- WASI (WebAssembly System Interface) サポート
- WebAssembly 1.0 (Core) および 2.0 サポート
- クロスコンパイル完全対応

**PGlite連携の技術的検討**:
- wazero は WASI 対応だが、Emscripten のランタイム環境は WASI と異なる
- PGlite の WASM モジュールは Emscripten ABI を使用しており、wazero でそのまま実行することは困難
- Emscripten の JavaScript グルーコードに相当する機能を Go で再実装する必要がある

---

## ライセンス互換性マトリクス

組み合わせて使用する場合のライセンス互換性:

| 組み合わせ | 結果ライセンス | 互換性 |
|-----------|-------------|--------|
| MIT + Apache-2.0 | Apache-2.0 | ✅ |
| MIT + BSD-3 | BSD-3 | ✅ |
| Apache-2.0 + BSD-3 | Apache-2.0 | ✅ |
| Apache-2.0 + PostgreSQL License | Apache-2.0 | ✅ |
| すべて組み合わせ | Apache-2.0 | ✅ |

**結論**: 調査対象のすべてのライブラリは permissive ライセンスを採用しており、自由に組み合わせて利用可能。商用プロジェクトへの組み込みも問題ない。

---

[← README に戻る](../README.md)
