# PostgreSQL ソースコードからのインメモリ実装への示唆

このドキュメントは、pure-Go インメモリ PostgreSQL 互換データベースを構築する観点から、PostgreSQL ソースコード (version 19devel) の何が参考になり、何が不要かを分析する。

## 1. 参考にすべきコンポーネント

### 1.1 ワイヤープロトコル（最重要）
- PostgreSQL互換を名乗るなら、ワイヤープロトコルの完全実装が必須
- src/backend/libpq/pqcomm.c, pqformat.c のメッセージフォーマットを参考に
- src/backend/tcop/postgres.c の exec_simple_query(), exec_parse_message(), exec_bind_message(), exec_execute_message() がプロトコルフロー
- Protocol version 3.0 (PG_PROTOCOL(3,0))
- Simple Query Protocol: Query → RowDescription + DataRow* + CommandComplete → ReadyForQuery
- Extended Query Protocol: Parse → Bind → Describe → Execute → Sync
- 認証: AuthenticationOk, CleartextPassword, MD5Password, SCRAM-SHA-256

### 1.2 SQL パーサー
- gram.y (20,059行) が SQL 文法の完全な定義
- Go で再実装するか、既存の Go SQL パーサーライブラリを使うか
- pg-query-go (libpg_query のGo wrapper) で PostgreSQL のパーサーをそのまま利用可能
- ただし pure-Go にこだわるなら自前 or vitess sqlparser 等の Go パーサーを拡張
- parsenodes.h のノード型定義が AST の構造を定義

### 1.3 データ型システム
- src/backend/utils/adt/ (119 files) が全データ型の実装
- 型のシリアライゼーション・デシリアライゼーション形式 (テキスト形式・バイナリ形式)
- pg_type.h が型のカタログ定義
- 型キャスト規則 (pg_cast.h)
- OID による型識別

### 1.4 システムカタログの構造
- pg_class, pg_attribute, pg_type, pg_namespace, pg_proc, pg_constraint 等
- information_schema のビュー定義
- 多くのクライアントライブラリやORMがこれらのカタログを参照する
- 最低限のカタログ互換性が必要

### 1.5 演算子・関数のセマンティクス
- 演算子の優先順位と結合規則
- NULL の扱い（三値論理）
- 型変換規則
- 各関数の正確な動作仕様

## 2. 簡略化・省略できるコンポーネント

### 2.1 ストレージ層（大幅簡略化）
- ページ構造 (8KB pages) → インメモリなのでGo のデータ構造でOK
- バッファマネージャ → 不要（全データがメモリ上）
- WAL → インメモリなので不要（永続化が必要なら別の方法）
- TOAST → 大きなデータもメモリ上なので不要
- FSM (Free Space Map) → 不要
- Visibility Map → 不要

### 2.2 プロセスモデル（完全に異なる）
- fork ベースのプロセスモデル → Go の goroutine ベースに
- 共有メモリ → Go の並行プリミティブ（チャネル、sync.Mutex等）
- postmaster → Go の net.Listener
- bgwriter, walwriter, checkpointer → 不要

### 2.3 VACUUM
- MVCC のガベージコレクション → Go の GC がある程度カバー
- ただし古いバージョンの回収は自前で実装が必要かも

### 2.4 レプリケーション・バックアップ
- 物理/論理レプリケーション → インメモリ用途では不要
- pg_basebackup → 不要
- WAL アーカイブ → 不要

### 2.5 JIT コンパイル
- 式評価の JIT → 初期段階では不要

## 3. 実装方針への示唆

### 3.1 段階的な実装
PostgreSQL のソースコードの規模を見ると、全機能の再実装は非現実的。
段階的に:
1. Phase 1 (MVP): ワイヤープロトコル + 基本SQL (SELECT/INSERT/UPDATE/DELETE/CREATE TABLE) + 基本型 + 基本演算子
2. Phase 2: Extended Query Protocol + プリペアドステートメント + トランザクション + より多くのデータ型・関数
3. Phase 3: ウィンドウ関数、CTE、パーティショニング、PL/pgSQL 等の高度な機能

### 3.2 パーサーの選択
- 自前で書く: 柔軟だが膨大な作業量 (gram.y は 20,059行)
- pg-query-go: CGO が必要だが PostgreSQL 完全互換
- cockroachdb/cockroach のパーサー: Go製、PostgreSQL 互換度が高い
- vitess sqlparser: MySQL 寄り、PostgreSQL 互換性は限定的

### 3.3 エグゼキュータの設計
- PostgreSQL のデマンドプル (Volcano) モデルは参考になる
- 各ノードが ExecInit → ExecProc → ExecEnd のインターフェース
- Go では interface で抽象化可能
- ただしインメモリなのでI/O最適化は不要、よりシンプルにできる

### 3.4 MVCC の簡略化
- PostgreSQL は tuple に xmin/xmax を埋め込む
- インメモリなら、Go の struct に transaction ID を持たせるだけで良い
- Snapshot isolation は比較的シンプルに実装可能
- デッドロック検出は wait-for グラフで実装

### 3.5 型システム
- PostgreSQL の OID ベースの型システムを踏襲する
- OID は既存のクライアントライブラリとの互換性に重要
- src/include/catalog/pg_type.dat に全型の OID が定義されている

## 4. ソースコード規模の比較

| コンポーネント | PostgreSQL (C) | インメモリ実装 (Go) で必要な規模感 |
|---|---|---|
| パーサー | gram.y 20,059行 + 関連 ~50,000行 | 既存ライブラリ利用 or 10,000-20,000行 |
| プランナ | ~60,000行 | 5,000-10,000行 (シンプルなルールベース) |
| エグゼキュータ | ~80,000行 | 10,000-20,000行 |
| データ型 (adt/) | ~120,000行 | 20,000-30,000行 |
| ストレージ | ~100,000行 | 2,000-5,000行 (メモリ管理のみ) |
| ワイヤープロトコル | ~20,000行 | 3,000-5,000行 |
| システムカタログ | ~50,000行 | 5,000-10,000行 |
| **合計** | **~480,000行** | **55,000-100,000行** |

## 5. 参考にすべき重要ファイルリスト

Priority 1 (必読):
- src/backend/tcop/postgres.c — クエリ処理メインループ
- src/backend/libpq/pqcomm.c — ワイヤープロトコル通信
- src/backend/libpq/pqformat.c — メッセージフォーマット
- src/backend/parser/gram.y — SQL 文法定義
- src/include/nodes/parsenodes.h — パースツリー構造
- src/include/catalog/pg_type.dat — 型 OID 定義

Priority 2 (推奨):
- src/backend/executor/execMain.c — エグゼキュータメインループ
- src/backend/access/transam/xact.c — トランザクション管理
- src/include/nodes/plannodes.h — プランツリー構造
- src/include/libpq/pqformat.h — メッセージフォーマット定義
- src/backend/utils/adt/ — データ型実装の参考
