# Go 製 RDB プロジェクトのパッケージ構造調査

## 目的

Pure Go によるインメモリ PostgreSQL 互換データベースを設計するにあたり、既存の Go 製 RDB プロジェクトのパッケージ構造を調査し、共通パターンを抽出したうえで推奨構造を提案する。

---

## 1. 各プロジェクトのパッケージ構造

### 1.1 CockroachDB (`cockroachdb/cockroach`)

**概要**: 大規模な PostgreSQL 互換分散データベース。Go 製 RDB の中で最も成熟したプロジェクト。

```
cockroach/
├── pkg/
│   ├── sql/                    # SQL レイヤー（巨大）
│   │   ├── parser/             # YACC 文法による SQL パーサー
│   │   │   ├── sql.y           # YACC 文法定義
│   │   │   ├── parse.go        # パースエントリポイント
│   │   │   ├── lexer.go        # レキサー
│   │   │   └── scanner.go      # スキャナー
│   │   ├── sem/
│   │   │   └── tree/           # AST ノード定義（数百ファイル）
│   │   │       ├── alter_table.go
│   │   │       ├── create_table.go
│   │   │       ├── select.go
│   │   │       └── ...
│   │   ├── types/              # データ型
│   │   │   ├── types.go
│   │   │   ├── oid.go
│   │   │   └── alias.go
│   │   ├── catalog/            # システムカタログ
│   │   │   ├── catalog.go
│   │   │   ├── database/
│   │   │   ├── descpb/
│   │   │   └── descs/
│   │   └── colexec/            # カラム指向実行エンジン
│   ├── storage/                # ストレージエンジン（Pebble ベース）
│   ├── kv/                     # Key-Value レイヤー
│   │   ├── kvserver/
│   │   └── kvclient/
│   ├── server/                 # サーバー（HTTP, gRPC, SQL）
│   └── cli/                    # CLI ツール
```

**アーキテクチャ**: `SQL → KV → Storage` の 3 層構造。`pkg/` 配下にすべての主要パッケージを配置。SQL レイヤーだけで数千ファイル規模。

**特徴**:
- `sem/tree/` で AST を独立パッケージとして分離
- `catalog/` でシステムカタログを明確に管理
- `types/` は `sql/` 配下に配置（SQL レイヤーに密結合）

---

### 1.2 TiDB (`pingcap/tidb`)

**概要**: MySQL 互換の分散データベース。クエリプランナの設計が特に洗練されている。

```
tidb/
├── pkg/
│   ├── parser/                 # SQL パーサー
│   │   ├── ast/                # AST 定義
│   │   ├── charset/            # 文字セット
│   │   ├── format/             # フォーマッタ
│   │   └── generate.go
│   ├── planner/                # クエリプランナー
│   │   ├── cascades/           # Cascades オプティマイザ
│   │   ├── core/               # コアプランニング
│   │   ├── memo/               # メモ化
│   │   ├── optimize.go
│   │   ├── cardinality/        # カーディナリティ推定
│   │   └── property/           # プロパティ
│   ├── executor/               # クエリエグゼキュータ
│   │   ├── aggfuncs/           # 集約関数
│   │   ├── aggregate/          # 集約処理
│   │   └── analyze.go
│   ├── expression/             # 式評価
│   ├── types/                  # データ型
│   │   ├── datum.go
│   │   ├── convert.go
│   │   ├── compare.go
│   │   └── enum.go
│   ├── ddl/                    # DDL 実行
│   ├── session/                # セッション管理
│   ├── sessionctx/             # セッションコンテキスト
│   ├── server/                 # MySQL プロトコルサーバー
│   ├── kv/                     # KV インターフェース
│   ├── store/                  # ストレージインターフェース
│   ├── statistics/             # クエリ統計
│   ├── infoschema/             # information_schema
│   ├── privilege/              # 権限管理
│   └── meta/                   # メタデータ管理
```

**アーキテクチャ**: `Parser → Planner → Executor → KV → TiKV` のパイプライン構造。

**特徴**:
- `planner/` が `cascades/`, `memo/`, `cardinality/` 等のサブパッケージを持つ洗練された設計
- `session/` と `sessionctx/` を明確に分離
- `infoschema/`, `privilege/`, `statistics/` が独立パッケージ

---

### 1.3 go-mysql-server (`dolthub/go-mysql-server`)

**概要**: インメモリ SQL エンジン。**本プロジェクトに最も近いユースケース**。

```
go-mysql-server/
├── sql/                        # コア SQL パッケージ
│   ├── analyzer/               # クエリアナライザ・オプティマイザ（50+ ルール）
│   ├── plan/                   # プランノード
│   │   ├── alter_table.go
│   │   ├── create_table.go
│   │   ├── select.go
│   │   ├── join.go
│   │   └── ...
│   ├── expression/             # 式ノード
│   │   ├── arithmetic.go       # 算術演算
│   │   ├── boolean.go          # 論理演算
│   │   ├── comparison.go       # 比較演算
│   │   └── ...
│   ├── types/                  # データ型
│   │   ├── bit.go
│   │   ├── datetime.go
│   │   ├── decimal.go
│   │   ├── enum.go
│   │   ├── geometry.go
│   │   ├── json.go
│   │   └── ...
│   ├── encodings/              # 文字エンコーディング
│   ├── fulltext/               # 全文検索
│   ├── hash/                   # ハッシュ関数
│   ├── catalog.go              # カタログ
│   ├── column.go               # カラム定義
│   ├── core.go                 # コアインターフェース
│   ├── databases.go            # データベース定義
│   ├── errors.go               # エラー定義
│   ├── functions.go            # 関数定義
│   ├── session.go              # セッション定義
│   └── auth.go                 # 認証
├── memory/                     # インメモリ DB 実装
│   ├── database.go
│   ├── table.go
│   ├── index.go
│   ├── provider.go
│   └── session.go
├── driver/                     # database/sql ドライバ
├── server/                     # MySQL プロトコルサーバー
├── enginetest/                 # エンジンテストフレームワーク
├── internal/                   # 内部ユーティリティ
│   ├── regex/
│   └── strings/
└── engine.go                   # メインエンジンエントリポイント
```

**アーキテクチャ**: `Parser (vitess) → Analyzer → Plan → Memory backend`

**特徴**:
- `sql/` パッケージにコアインターフェースを集約し、`memory/` で具象実装を提供
- `analyzer/` がプランナーとオプティマイザの役割を統合
- `driver/` で `database/sql` ドライバを提供
- `enginetest/` でテストフレームワークを独立パッケージ化

---

### 1.4 DoltgreSQL (`dolthub/doltgresql`)

**概要**: go-mysql-server 上に PostgreSQL 互換レイヤーを構築。PostgreSQL 方言への変換層の設計が参考になる。

```
doltgresql/
├── server/                     # PostgreSQL サーバーレイヤー
│   ├── ast/                    # PG AST → GMS AST 変換（数百ファイル）
│   ├── analyzer/               # PG 固有の分析
│   ├── cast/                   # 型キャスト
│   │   ├── bool.go
│   │   ├── char.go
│   │   ├── date.go
│   │   ├── float32.go
│   │   ├── float64.go
│   │   ├── int16.go
│   │   ├── int32.go
│   │   ├── int64.go
│   │   └── ...
│   ├── functions/              # PG 関数
│   │   ├── abs.go
│   │   ├── acos.go
│   │   ├── age.go
│   │   ├── array_append.go
│   │   └── ...
│   ├── expression/             # PG 式
│   ├── node/                   # PG プランノード
│   ├── auth/                   # 認証
│   ├── plpgsql/                # PL/pgSQL サポート
│   └── logrepl/                # 論理レプリケーション
├── core/                       # コアドメイン
│   ├── storage/                # ストレージ
│   ├── sequences/              # シーケンス
│   ├── functions/              # 関数
│   └── typecollection/         # 型コレクション
├── postgres/                   # PG パーサーラッパー
│   └── parser/
├── cmd/                        # CLI エントリポイント
├── testing/                    # テストフレームワーク
└── utils/                      # ユーティリティ
```

**アーキテクチャ**: `PG wire protocol → AST translation → go-mysql-server → Dolt storage`

**特徴**:
- `cast/` で型ごとにファイルを分離する設計
- `functions/` で関数ごとに 1 ファイルの粒度
- AST 変換層が独立した巨大パッケージ

---

### 1.5 ramsql (`proullon/ramsql`)

**概要**: 非常にシンプルなインメモリ SQL エンジン。小規模プロジェクトの構造設計の参考。

```
ramsql/
├── engine/                     # コアエンジン
│   ├── parser/                 # SQL パーサー
│   │   ├── lexer.go
│   │   ├── parser.go
│   │   ├── create.go
│   │   ├── select.go
│   │   ├── delete.go
│   │   ├── insert.go
│   │   └── where.go
│   ├── executor/               # クエリエグゼキュータ
│   │   ├── engine.go
│   │   ├── tx.go
│   │   └── attribute.go
│   ├── agnostic/               # ストレージ非依存データモデル
│   │   ├── engine.go
│   │   ├── relation.go
│   │   ├── tuple.go
│   │   ├── schema.go
│   │   ├── predicate.go
│   │   ├── scanner.go
│   │   ├── transaction.go
│   │   └── index.go
│   └── log/                    # ロギング
└── driver/                     # database/sql ドライバ
    ├── driver.go
    ├── conn.go
    ├── stmt.go
    ├── rows.go
    └── result.go
```

**アーキテクチャ**: `Parser → Executor → Agnostic (in-memory storage)`

**特徴**:
- `agnostic/` でリレーショナルモデル（relation, tuple, schema）を抽象化
- 3 パッケージのみで構成される最小構成
- `driver/` で `database/sql` ドライバを提供

---

### 1.6 rqlite (`rqlite/rqlite`)

**概要**: Go で構築された分散 SQLite。Raft によるレプリケーション層の設計が特徴的。

```
rqlite/
├── store/                      # Raft ベース分散ストア
├── db/                         # SQLite ラッパー
├── http/                       # HTTP API
├── cluster/                    # クラスタ管理
├── cmd/                        # CLI
├── auth/                       # 認証
├── snapshot/                   # スナップショット管理
└── queue/                      # 書き込みキュー
```

**アーキテクチャ**: `HTTP → Store (Raft) → SQLite`

**特徴**:
- SQLite 本体に依存するため SQL レイヤーが存在しない
- 分散制御とストレージに特化した構造
- `auth/` をトップレベルに配置

---

## 2. 共通パターン分析

### 2.1 ほぼ全プロジェクトに存在するパッケージ

| パッケージ | 出現率 | 説明 |
|-----------|--------|------|
| **parser** (SQL パーサー) | 5/6 | SQL テキストを AST に変換。rqlite のみ SQLite に委譲 |
| **executor** (実行エンジン) | 5/6 | クエリプランを実際に実行する |
| **types** (データ型) | 5/6 | SQL データ型の定義と操作 |
| **server** (プロトコルサーバー) | 5/6 | ワイヤープロトコル（PG/MySQL）実装 |
| **driver** (database/sql ドライバ) | 3/6 | Go 標準の `database/sql` インターフェース |

### 2.2 多くのプロジェクトに存在するパッケージ

| パッケージ | 出現率 | 説明 |
|-----------|--------|------|
| **expression** (式評価) | 4/6 | 算術演算・比較演算・論理演算などの式ノード |
| **catalog** (カタログ) | 3/6 | データベース・テーブル・カラムなどのメタデータ管理 |
| **planner/analyzer** (プランナ) | 3/6 | クエリの最適化と実行計画の生成 |
| **session** (セッション) | 3/6 | クライアント接続ごとの状態管理 |
| **auth** (認証) | 3/6 | ユーザー認証・権限管理 |
| **function** (組み込み関数) | 2/6 | 組み込み SQL 関数の実装 |
| **storage** (ストレージ) | 4/6 | データの永続化・インメモリ管理 |

### 2.3 パイプラインパターン

すべてのプロジェクトが以下のパイプライン構造を持つ:

```
クライアント
  ↓
[Server]        ワイヤープロトコル受信
  ↓
[Parser]        SQL → AST
  ↓
[Analyzer]      意味解析・名前解決・型チェック
  ↓
[Planner]       AST → 実行計画（最適化含む）
  ↓
[Executor]      実行計画 → 結果セット
  ↓
[Storage]       データの読み書き
  ↓
[Catalog]       メタデータ参照（全レイヤーから参照される）
```

### 2.4 トップレベル構造のパターン

| パターン | プロジェクト | 説明 |
|---------|------------|------|
| `pkg/` 配下集約 | CockroachDB, TiDB | 大規模プロジェクト向け。Go の慣例的な `pkg/` レイアウト |
| フラット構造 | go-mysql-server, ramsql | 中小規模向け。`sql/`, `memory/`, `server/` 等をトップレベルに配置 |
| ドメイン分割 | DoltgreSQL | 変換層を `server/` に集約、ドメインを `core/` に分離 |

---

## 3. パッケージ構造の比較表

### 3.1 機能別パッケージマッピング

| 機能 | CockroachDB | TiDB | go-mysql-server | DoltgreSQL | ramsql | rqlite |
|------|------------|------|-----------------|------------|--------|--------|
| **SQL パーサー** | `pkg/sql/parser/` | `pkg/parser/` | 外部(vitess) | `postgres/parser/` | `engine/parser/` | ─ (SQLite) |
| **AST 定義** | `pkg/sql/sem/tree/` | `pkg/parser/ast/` | `sql/plan/` | `server/ast/` | `engine/parser/` | ─ |
| **データ型** | `pkg/sql/types/` | `pkg/types/` | `sql/types/` | `server/cast/` | ─ | ─ |
| **式評価** | `pkg/sql/sem/tree/` | `pkg/expression/` | `sql/expression/` | `server/expression/` | ─ | ─ |
| **プランナ/アナライザ** | `pkg/sql/` (統合) | `pkg/planner/` | `sql/analyzer/` | `server/analyzer/` | ─ | ─ |
| **エグゼキュータ** | `pkg/sql/colexec/` | `pkg/executor/` | `sql/` (統合) | ─ (GMS委譲) | `engine/executor/` | ─ |
| **カタログ** | `pkg/sql/catalog/` | `pkg/infoschema/` | `sql/catalog.go` | `core/` | `engine/agnostic/` | ─ |
| **ストレージ** | `pkg/storage/` | `pkg/store/` | `memory/` | `core/storage/` | `engine/agnostic/` | `store/`, `db/` |
| **サーバー** | `pkg/server/` | `pkg/server/` | `server/` | `server/` | ─ | `http/` |
| **セッション** | `pkg/sql/` (統合) | `pkg/session/` | `sql/session.go` | ─ | ─ | ─ |
| **認証** | `pkg/server/` (統合) | `pkg/privilege/` | `sql/auth.go` | `server/auth/` | ─ | `auth/` |
| **組み込み関数** | `pkg/sql/sem/builtins/` | `pkg/expression/` | `sql/functions.go` | `server/functions/` | ─ | ─ |
| **ドライバ** | ─ | ─ | `driver/` | ─ | `driver/` | ─ |
| **CLI** | `pkg/cli/` | ─ | ─ | `cmd/` | ─ | `cmd/` |
| **トランザクション** | `pkg/kv/` (統合) | `pkg/kv/` | ─ | ─ | `engine/executor/tx.go` | `store/` (Raft) |
| **エラー** | `pkg/sql/pgwire/pgerror/` | `pkg/errno/` | `sql/errors.go` | ─ | ─ | ─ |

### 3.2 プロジェクト規模とパッケージ数

| プロジェクト | 規模 | トップレベルパッケージ数 | SQL レイヤーの深さ |
|------------|------|----------------------|------------------|
| CockroachDB | 超大規模 | ~20 | 非常に深い（3-4 階層） |
| TiDB | 大規模 | ~25 | 深い（2-3 階層） |
| go-mysql-server | 中規模 | ~8 | 中程度（1-2 階層） |
| DoltgreSQL | 中規模 | ~6 | 中程度（1-2 階層） |
| ramsql | 小規模 | ~2 | 浅い（1 階層） |
| rqlite | 中規模 | ~8 | なし（SQLite 委譲） |

---

## 4. 推奨パッケージ構造

### 4.1 設計方針

以下の方針に基づいて構造を設計する:

1. **go-mysql-server を主要な参考モデルとする** — インメモリ実装として最も近いユースケース
2. **CockroachDB/TiDB の分離粒度を参考にする** — パーサー、プランナー、エグゼキュータを明確に分離
3. **DoltgreSQL の PostgreSQL 固有設計を取り入れる** — 型キャスト、PG 関数、pg_catalog
4. **ramsql のシンプルさを意識する** — 不要な抽象化を避け、段階的に拡張可能な構造
5. **`pkg/` レイアウトを採用する** — 将来的な拡張性を考慮

### 4.2 推奨ディレクトリ構造

```
inmempg/
├── cmd/                         # CLI エントリポイント
│   └── inmempg/
│       └── main.go
├── pkg/
│   ├── server/                  # ワイヤープロトコルサーバー
│   │   ├── server.go            # TCP/Unix socket リスナー
│   │   ├── connection.go        # コネクションハンドラ
│   │   ├── protocol.go          # PG ワイヤープロトコル実装
│   │   ├── auth.go              # 認証
│   │   └── session.go           # セッション管理
│   ├── parser/                  # SQL パーサー
│   │   ├── parser.go            # パーサーエントリポイント
│   │   ├── lexer.go             # レキサー
│   │   └── ast/                 # AST ノード定義
│   ├── analyzer/                # 意味解析・クエリ最適化
│   │   ├── analyzer.go          # メインアナライザ
│   │   ├── resolve.go           # 名前解決
│   │   ├── typecheck.go         # 型チェック
│   │   └── optimize.go          # 最適化ルール
│   ├── planner/                 # クエリプランナ
│   │   ├── planner.go           # プラン生成
│   │   └── cost.go              # コスト推定
│   ├── executor/                # クエリエグゼキュータ
│   │   ├── executor.go          # メインエグゼキュータ
│   │   ├── scan.go              # テーブルスキャン
│   │   ├── join.go              # JOIN 実行
│   │   ├── aggregate.go         # 集約実行
│   │   ├── sort.go              # ソート
│   │   ├── limit.go             # LIMIT/OFFSET
│   │   ├── modify.go            # INSERT/UPDATE/DELETE
│   │   └── window.go            # ウィンドウ関数
│   ├── catalog/                 # システムカタログ
│   │   ├── catalog.go           # カタログマネージャ
│   │   ├── database.go          # データベース定義
│   │   ├── schema.go            # スキーマ定義
│   │   ├── table.go             # テーブル定義
│   │   ├── column.go            # カラム定義
│   │   ├── index.go             # インデックス定義
│   │   ├── constraint.go        # 制約定義
│   │   ├── sequence.go          # シーケンス定義
│   │   └── pg_catalog.go        # pg_catalog 仮想テーブル
│   ├── storage/                 # インメモリストレージ
│   │   ├── engine.go            # ストレージエンジン
│   │   ├── heap.go              # ヒープテーブル
│   │   ├── btree.go             # B-tree インデックス
│   │   ├── hash.go              # ハッシュインデックス
│   │   ├── tuple.go             # タプル表現
│   │   └── mvcc.go              # MVCC 実装
│   ├── types/                   # データ型
│   │   ├── types.go             # 型定義・OID
│   │   ├── numeric.go           # 数値型
│   │   ├── string.go            # 文字列型
│   │   ├── datetime.go          # 日付・時刻型
│   │   ├── json.go              # JSON/JSONB 型
│   │   ├── array.go             # 配列型
│   │   ├── uuid.go              # UUID 型
│   │   ├── bool.go              # 真偽値型
│   │   ├── cast.go              # 型変換
│   │   └── oid.go               # OID 定義
│   ├── expression/              # 式評価
│   │   ├── expression.go        # 式インターフェース
│   │   ├── arithmetic.go        # 算術演算
│   │   ├── comparison.go        # 比較演算
│   │   ├── logical.go           # 論理演算
│   │   ├── function.go          # 関数呼び出し
│   │   └── cast.go              # キャスト式
│   ├── function/                # 組み込み関数
│   │   ├── registry.go          # 関数レジストリ
│   │   ├── math.go              # 数学関数
│   │   ├── string.go            # 文字列関数
│   │   ├── datetime.go          # 日付・時刻関数
│   │   ├── aggregate.go         # 集約関数
│   │   ├── json.go              # JSON 関数
│   │   ├── array.go             # 配列関数
│   │   ├── system.go            # システム情報関数
│   │   └── window.go            # ウィンドウ関数
│   ├── transaction/             # トランザクション管理
│   │   ├── manager.go           # トランザクションマネージャ
│   │   ├── snapshot.go          # スナップショット分離
│   │   ├── lock.go              # ロック管理
│   │   └── deadlock.go          # デッドロック検出
│   └── errors/                  # エラーコード
│       ├── codes.go             # PostgreSQL エラーコード
│       └── errors.go            # エラーハンドリング
├── driver/                      # database/sql ドライバ
│   └── driver.go
├── internal/                    # 内部ユーティリティ
│   ├── encoding/                # エンコーディング
│   └── testutil/                # テストユーティリティ
├── go.mod
├── go.sum
└── README.md
```

### 4.3 各パッケージの設計根拠

#### `cmd/inmempg/` — CLI エントリポイント

**参考**: CockroachDB の `pkg/cli/`、DoltgreSQL の `cmd/`、rqlite の `cmd/`

Go の標準的な `cmd/` レイアウト。サーバー起動やマイグレーション等のサブコマンドを配置する。

#### `pkg/server/` — ワイヤープロトコルサーバー

**参考**: CockroachDB `pkg/server/`、TiDB `pkg/server/`、go-mysql-server `server/`、DoltgreSQL `server/`

PostgreSQL ワイヤープロトコル (v3) を実装する。PostgreSQL 本体の `src/backend/libpq/` に相当する。セッション管理と認証をこのパッケージに含めるのは、go-mysql-server で `sql/session.go` と `sql/auth.go` がサーバーと密結合している実態を踏まえたもの。

#### `pkg/parser/` — SQL パーサー

**参考**: CockroachDB `pkg/sql/parser/`、TiDB `pkg/parser/`、ramsql `engine/parser/`

SQL テキストを AST に変換する。PostgreSQL 本体の `src/backend/parser/` に相当する。CockroachDB は YACC ベース、ramsql は手書き再帰下降パーサーを使用している。サブパッケージ `ast/` に AST ノード定義を分離するのは CockroachDB (`sem/tree/`) と TiDB (`parser/ast/`) の設計に倣う。

#### `pkg/analyzer/` — 意味解析・クエリ最適化

**参考**: go-mysql-server `sql/analyzer/`、DoltgreSQL `server/analyzer/`

名前解決、型チェック、最適化ルールの適用を行う。go-mysql-server ではアナライザが 50 以上のルールを持つ中心的なパッケージとなっており、この設計パターンを採用する。PostgreSQL 本体の `src/backend/optimizer/` と `src/backend/parser/analyze.c` に相当する。

#### `pkg/planner/` — クエリプランナ

**参考**: TiDB `pkg/planner/`（`cascades/`, `core/`, `memo/`）

AST から実行計画を生成する。TiDB の洗練されたプランナー設計を参考にしつつ、初期段階では最小限の構成にする。PostgreSQL 本体の `src/backend/optimizer/plan/` に相当する。

#### `pkg/executor/` — クエリエグゼキュータ

**参考**: TiDB `pkg/executor/`、ramsql `engine/executor/`

実行計画をイテレータモデルで実行する。ファイル分割は操作種別ごと（scan, join, aggregate 等）に行う。これは TiDB のエグゼキュータ構造と PostgreSQL 本体の `src/backend/executor/` のファイル構成（`nodeSeqscan.c`, `nodeHashjoin.c` 等）に倣う。

#### `pkg/catalog/` — システムカタログ

**参考**: CockroachDB `pkg/sql/catalog/`、go-mysql-server `sql/catalog.go`、TiDB `pkg/infoschema/`

データベース、スキーマ、テーブル、カラム等のメタデータを管理する。PostgreSQL 本体の `src/backend/catalog/` と `pg_catalog` システムテーブルに相当する。`pg_catalog.go` で PostgreSQL のシステムカタログ仮想テーブルを実装するのは DoltgreSQL が `core/` で行っている設計を参考にしている。

#### `pkg/storage/` — インメモリストレージ

**参考**: go-mysql-server `memory/`、ramsql `engine/agnostic/`、CockroachDB `pkg/storage/`

インメモリでのデータ格納と取得を担当する。go-mysql-server の `memory/` パッケージが直接の参考だが、PostgreSQL 本体の `src/backend/storage/` や `src/backend/access/` の概念（heap, btree, hash）を反映した内部構造にする。`mvcc.go` はトランザクション分離レベルの実装に必要で、PostgreSQL のスナップショット分離モデルに対応する。

#### `pkg/types/` — データ型

**参考**: CockroachDB `pkg/sql/types/`、TiDB `pkg/types/`、go-mysql-server `sql/types/`、DoltgreSQL `server/cast/`

PostgreSQL のデータ型を Go で表現する。全プロジェクトが独立した型パッケージを持つ。`oid.go` で PostgreSQL の OID 体系を実装するのは CockroachDB の設計に倣う。`cast.go` は DoltgreSQL が型ごとにキャストファイルを持つ設計を参考にしつつ、単一ファイルに統合する。

#### `pkg/expression/` — 式評価

**参考**: go-mysql-server `sql/expression/`、TiDB `pkg/expression/`、DoltgreSQL `server/expression/`

算術演算、比較演算、論理演算等の式ノードを定義する。ファイル分割は go-mysql-server の `expression/` パッケージに倣い、演算種別ごとに行う。PostgreSQL 本体の `src/backend/executor/execExpr.c` に相当する。

#### `pkg/function/` — 組み込み関数

**参考**: DoltgreSQL `server/functions/`、CockroachDB `pkg/sql/sem/builtins/`

PostgreSQL の組み込み関数を実装する。DoltgreSQL が関数ごとに 1 ファイルとする粒度に対し、カテゴリごと（math, string, datetime 等）にファイルを分ける方針を採用する。PostgreSQL 本体の `src/backend/utils/adt/` に相当する。`registry.go` で関数の登録・検索機構を提供し、拡張性を確保する。

#### `pkg/transaction/` — トランザクション管理

**参考**: CockroachDB `pkg/kv/`（トランザクション統合）、ramsql `engine/executor/tx.go`

MVCC ベースのトランザクション管理、スナップショット分離、ロック管理を行う。CockroachDB や TiDB では KV レイヤーに統合されているが、インメモリ実装では独立パッケージとして分離する。PostgreSQL 本体の `src/backend/access/transam/` に相当する。

#### `pkg/errors/` — エラーコード

**参考**: CockroachDB `pkg/sql/pgwire/pgerror/`、go-mysql-server `sql/errors.go`

PostgreSQL のエラーコード体系（SQLSTATE）を実装する。PostgreSQL クライアントライブラリとの互換性のために必須。

#### `driver/` — database/sql ドライバ

**参考**: go-mysql-server `driver/`、ramsql `driver/`

Go 標準の `database/sql` インターフェースを実装する。テスト用途やアプリケーション組み込み用途で必須。`pkg/` の外に配置するのは、外部から直接 `import` されるパブリック API であるため。

#### `internal/` — 内部ユーティリティ

**参考**: go-mysql-server `internal/`

Go の慣例に従い、外部からインポートできない内部ユーティリティを配置する。エンコーディングヘルパーやテストユーティリティ等。

### 4.4 推奨構造と各プロジェクトのマッピング

| 推奨パッケージ | CockroachDB | TiDB | go-mysql-server | DoltgreSQL | ramsql | PostgreSQL 本体 |
|--------------|------------|------|-----------------|------------|--------|----------------|
| `pkg/server/` | `pkg/server/` | `pkg/server/` | `server/` | `server/` | ─ | `src/backend/libpq/` |
| `pkg/parser/` | `pkg/sql/parser/` | `pkg/parser/` | 外部(vitess) | `postgres/parser/` | `engine/parser/` | `src/backend/parser/` |
| `pkg/parser/ast/` | `pkg/sql/sem/tree/` | `pkg/parser/ast/` | `sql/plan/` | `server/ast/` | `engine/parser/` | `src/backend/nodes/` |
| `pkg/analyzer/` | `pkg/sql/` (統合) | `pkg/planner/` (部分) | `sql/analyzer/` | `server/analyzer/` | ─ | `src/backend/parser/analyze.c` |
| `pkg/planner/` | `pkg/sql/` (統合) | `pkg/planner/` | `sql/analyzer/` (統合) | ─ | ─ | `src/backend/optimizer/` |
| `pkg/executor/` | `pkg/sql/colexec/` | `pkg/executor/` | `sql/` (統合) | ─ | `engine/executor/` | `src/backend/executor/` |
| `pkg/catalog/` | `pkg/sql/catalog/` | `pkg/infoschema/` | `sql/catalog.go` | `core/` | `engine/agnostic/` | `src/backend/catalog/` |
| `pkg/storage/` | `pkg/storage/` | `pkg/store/` | `memory/` | `core/storage/` | `engine/agnostic/` | `src/backend/storage/` |
| `pkg/types/` | `pkg/sql/types/` | `pkg/types/` | `sql/types/` | `server/cast/` | ─ | `src/backend/utils/adt/` |
| `pkg/expression/` | `pkg/sql/sem/tree/` | `pkg/expression/` | `sql/expression/` | `server/expression/` | ─ | `src/backend/executor/execExpr.c` |
| `pkg/function/` | `pkg/sql/sem/builtins/` | `pkg/expression/` | `sql/functions.go` | `server/functions/` | ─ | `src/backend/utils/adt/` |
| `pkg/transaction/` | `pkg/kv/` | `pkg/kv/` | ─ | ─ | `engine/executor/tx.go` | `src/backend/access/transam/` |
| `pkg/errors/` | `pkg/sql/pgwire/pgerror/` | `pkg/errno/` | `sql/errors.go` | ─ | ─ | `src/backend/utils/errcodes.h` |
| `driver/` | ─ | ─ | `driver/` | ─ | `driver/` | ─ (libpq は C) |

### 4.5 データフロー

```
                          ┌─────────────────────────────────────────┐
                          │            pkg/catalog/                 │
                          │  (メタデータ: 全レイヤーから参照される)       │
                          └───────────────┬─────────────────────────┘
                                          │
  クライアント (psql, アプリ)               │
       │                                  │
       ▼                                  │
  ┌──────────┐                            │
  │ server/  │ PG ワイヤープロトコル v3       │
  └────┬─────┘                            │
       │ SQL テキスト                      │
       ▼                                  │
  ┌──────────┐                            │
  │ parser/  │ SQL → AST                  │
  └────┬─────┘                            │
       │ AST                              │
       ▼                                  │
  ┌──────────┐                            │
  │analyzer/ │ 名前解決・型チェック・最適化    │
  └────┬─────┘                            │
       │ 解析済み AST                      │
       ▼                                  │
  ┌──────────┐                            │
  │planner/  │ 実行計画生成                  │
  └────┬─────┘                            │
       │ 実行計画                           │
       ▼                                  │
  ┌──────────┐    ┌──────────┐            │
  │executor/ │───▶│expression│ 式評価       │
  │          │    │function/ │ 関数実行     │
  └────┬─────┘    └──────────┘            │
       │ データ読み書き要求                  │
       ▼                                  │
  ┌──────────┐    ┌──────────────┐        │
  │ storage/ │◀──▶│ transaction/ │        │
  │          │    │ (MVCC/Lock)  │        │
  └──────────┘    └──────────────┘
```

### 4.6 段階的実装の指針

推奨構造は最終形であり、初期段階では以下の順序で段階的に実装する:

| フェーズ | 実装パッケージ | 目標 |
|---------|-------------|------|
| **Phase 1** | `server/`, `parser/`, `executor/`, `storage/`, `types/`, `catalog/` | 基本的な SELECT/INSERT が動作 |
| **Phase 2** | `analyzer/`, `expression/`, `errors/` | 型チェック、式評価、エラーハンドリング |
| **Phase 3** | `function/`, `transaction/`, `planner/` | 組み込み関数、トランザクション、クエリ最適化 |
| **Phase 4** | `driver/`, `internal/` | database/sql ドライバ、ユーティリティ整備 |

---

## 参考文献

- [CockroachDB](https://github.com/cockroachdb/cockroach) — PostgreSQL 互換分散 DB
- [TiDB](https://github.com/pingcap/tidb) — MySQL 互換分散 DB
- [go-mysql-server](https://github.com/dolthub/go-mysql-server) — インメモリ SQL エンジン
- [DoltgreSQL](https://github.com/dolthub/doltgresql) — PostgreSQL 互換レイヤー
- [ramsql](https://github.com/proullon/ramsql) — シンプルなインメモリ SQL
- [rqlite](https://github.com/rqlite/rqlite) — 分散 SQLite
- [PostgreSQL ソースコード](https://github.com/postgres/postgres) — `src/backend/` 配下の構造
