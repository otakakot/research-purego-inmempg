# PostgreSQL アーキテクチャ詳解

本ドキュメントは、PostgreSQL ソースコード（version 19devel）に基づき、コアアーキテクチャを解説する。
Pure-Go でインメモリ PostgreSQL を実装するにあたり、再現すべき内部構造の全体像を把握することを目的とする。

---

## 全体アーキテクチャ概観

```
┌─────────────────────────────────────────────────────────────────────┐
│                         クライアント                                 │
│                   (psql, libpq, JDBC, etc.)                        │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ TCP / Unix Socket
                           │ Wire Protocol v3
┌──────────────────────────▼──────────────────────────────────────────┐
│                        Postmaster                                   │
│                  (接続受付・プロセス管理)                              │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ fork()
┌──────────────────────────▼──────────────────────────────────────────┐
│                     Backend Process                                  │
│                                                                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────┐  ┌─────────┐ │
│  │ Parser   │→│ Rewriter │→│ Planner   │→│Executor│→│ Results │ │
│  └──────────┘  └──────────┘  └───────────┘  └──────┘  └─────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Storage Engine (Buffer Manager, Heap, Index, WAL, MVCC)       │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ System Catalogs (pg_class, pg_type, pg_attribute, ...)        │ │
│  └────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. クエリ処理パイプライン

PostgreSQL は SQL テキストを以下のパイプラインで処理する:

```
SQL Text
  │
  ▼
┌──────────┐
│  Parser  │  raw_parser() → flex/bison
└────┬─────┘
     │ Raw Parse Tree (SelectStmt, InsertStmt, ...)
     ▼
┌──────────┐
│ Analyzer │  parse_analyze() → semantic analysis
└────┬─────┘
     │ Query Tree (Query node)
     ▼
┌──────────┐
│ Rewriter │  QueryRewrite() → ビュー展開・ルール適用
└────┬─────┘
     │ Rewritten Query Tree(s)
     ▼
┌──────────┐
│ Planner  │  planner() → コストベース最適化
└────┬─────┘
     │ Plan Tree (SeqScan, IndexScan, NestLoop, ...)
     ▼
┌──────────┐
│ Executor │  ExecutorRun() → demand-pull パイプライン
└────┬─────┘
     │ Result Tuples
     ▼
  クライアントへ送信
```

### 1.1 パーサー (Parser)

パーサーは SQL テキストを構造化された内部表現に変換する。2 つのフェーズで構成される。

#### フェーズ 1: 字句解析 + 構文解析 → Raw Parse Tree

エントリポイントは `parser.c` の `raw_parser()` である。

```c
// src/backend/parser/parser.c
List *
raw_parser(const char *str, RawParseMode mode)
```

- **字句解析器 (Lexer)**: `scan.l`（約 1,421 行）は flex で記述されており、SQL テキストをトークンに分割する。キーワード、識別子、リテラル、演算子などを認識する。
- **構文解析器 (Grammar)**: `gram.y`（約 20,059 行）は bison で記述された文法定義。トークン列から Raw Parse Tree を生成する。

Raw Parse Tree は `parsenodes.h` で定義された各種 Statement ノードで構成される:

| ノード型 | 対応 SQL |
|---|---|
| `SelectStmt` | SELECT 文 |
| `InsertStmt` | INSERT 文 |
| `UpdateStmt` | UPDATE 文 |
| `DeleteStmt` | DELETE 文 |
| `CreateStmt` | CREATE TABLE 文 |
| `IndexStmt` | CREATE INDEX 文 |
| `ViewStmt` | CREATE VIEW 文 |

#### フェーズ 2: 意味解析 (Semantic Analysis) → Query ノード

`analyze.c` の `parse_analyze()` が Raw Parse Tree を受け取り、意味解析を行って `Query` ノードを生成する。

```
Raw Parse Tree (SelectStmt)
  │
  │  parse_analyze()
  ▼
Query Node
  ├── targetList: 出力カラムリスト (TargetEntry)
  ├── rtable: FROM 句のテーブルリスト (RangeTblEntry)
  ├── jointree: WHERE 句・JOIN 条件 (FromExpr)
  ├── sortClause: ORDER BY
  ├── groupClause: GROUP BY
  ├── havingQual: HAVING 条件
  └── limitCount / limitOffset: LIMIT / OFFSET
```

意味解析で行われる処理:

| 処理 | 担当ファイル | 内容 |
|---|---|---|
| テーブル名解決 | `parse_relation.c` | テーブル名 → OID、RangeTblEntry の生成 |
| カラム名解決 | `parse_relation.c` | カラム名 → Var ノード (varno, varattno) |
| 式の解析 | `parse_expr.c` | 演算子、関数呼び出し、サブクエリの解析 |
| 関数呼び出し解決 | `parse_func.c` | 関数名 → pg_proc の OID、オーバーロード解決 |
| 型強制 | `parse_coerce.c` | 暗黙的/明示的な型変換の挿入 |
| WHERE/ORDER BY 等 | `parse_clause.c` | 各句の解析とバリデーション |

### 1.2 リライタ (Rewriter)

リライタは PostgreSQL のルールシステムを適用し、Query Tree を変換する。

```c
// src/backend/rewrite/rewriteHandler.c
List *
QueryRewrite(Query *parsetree)
```

主な役割:

- **ビュー展開**: ビューへのクエリを、ビュー定義に基づいてベーステーブルへのクエリに変換する。
  ```sql
  -- ビュー定義: CREATE VIEW active_users AS SELECT * FROM users WHERE active = true;
  -- 入力クエリ: SELECT name FROM active_users;
  -- リライト後: SELECT name FROM users WHERE active = true;
  ```
- **ルールシステム**: `CREATE RULE` で定義されたルール（`_RETURN` ルール等）を適用する。`INSTEAD` ルールや `ALSO` ルールにより、クエリの書き換えや追加クエリの生成を行う。

リライタの出力は 1 つ以上の Query ノードのリストである（ルール適用により複数クエリが生成される場合がある）。

### 1.3 プランナ/オプティマイザ (Planner/Optimizer)

プランナは Query Tree を実行可能な Plan Tree に変換する。コストベース最適化により、推定コストが最小の実行計画を選択する。

```c
// src/backend/optimizer/plan/planner.c
PlannedStmt *
planner(Query *parse, const char *query_string, int cursorOptions,
        ParamListInfo boundParams)
```

#### プランニングの流れ

```
Query
  │
  ▼
┌─────────────────────────────┐
│ 1. サブクエリの展開/プルアップ │
│    (subquery_planner)        │
└──────────┬──────────────────┘
           ▼
┌─────────────────────────────┐
│ 2. 各リレーションのパス生成   │  ← allpaths.c
│    (make_one_rel)            │
│                              │
│  SeqScan Path                │
│  IndexScan Path              │
│  BitmapScan Path             │
│  ...                         │
└──────────┬──────────────────┘
           ▼
┌─────────────────────────────┐
│ 3. 結合戦略の探索            │
│                              │
│  NestLoop Join               │
│  Hash Join                   │
│  Merge Join                  │
│  (各組み合わせのコスト推定)    │
└──────────┬──────────────────┘
           ▼
┌─────────────────────────────┐
│ 4. 最小コストの Path を選択   │
│ 5. Path → Plan に変換        │
│    (create_plan)             │
└──────────┬──────────────────┘
           ▼
Plan Tree
```

#### 主要な概念

| 概念 | 説明 |
|---|---|
| `RelOptInfo` | 各リレーション（テーブル or 結合結果）の最適化情報。利用可能な Path のリストを保持 |
| `Path` | 特定のアクセス方法を表す。推定コスト (startup_cost, total_cost) を持つ |
| `Plan` | 最終的な実行計画ノード。Path から変換される |
| `PathKey` | ソート順序を表す。Merge Join やソート済みの出力に必要 |
| `RestrictInfo` | WHERE 句の各条件。セレクティビティ推定値を保持 |
| `EquivalenceClass` | 等価な式のグループ (例: `a.id = b.id` → {a.id, b.id}) |

#### コスト推定

`costsize.c`（約 225KB）にコスト推定の公式が実装されている:

```
SeqScan コスト:
  startup_cost = 0
  total_cost = seq_page_cost * pages + cpu_tuple_cost * tuples

IndexScan コスト:
  startup_cost = index のリーフに到達するコスト
  total_cost = index_pages * random_page_cost
             + heap_pages * random_page_cost  (非カバリングの場合)
             + cpu_index_tuple_cost * index_tuples
             + cpu_tuple_cost * tuples
```

セレクティビティ推定（WHERE 句の条件がタプルをどの程度絞り込むか）は `clausesel.c` 等で行われる。`pg_statistic` カタログのヒストグラムや MCV (Most Common Values) を利用する。

#### GEQO (Genetic Query Optimizer)

結合するテーブルが多い場合（デフォルト 12 テーブル以上）、全探索では計算量が爆発する。PostgreSQL は遺伝的アルゴリズム（GEQO）を使用して準最適な結合順序を求める:

```
geqo_main()  // src/backend/optimizer/geqo/
  │
  ├── 初期個体群をランダム生成 (各個体 = 結合順序の順列)
  ├── 各個体のフィットネス = 実行計画のコスト
  └── 選択・交叉・突然変異を繰り返し、低コストの結合順序を探索
```

### 1.4 エグゼキュータ (Executor)

エグゼキュータは Plan Tree を実行し、結果タプルを生成する。**Demand-pull（Volcano/Iterator）モデル**を採用しており、各ノードが上位ノードからの要求に応じて 1 タプルずつ返す。

```
  ┌──────────┐
  │  Client  │ ← タプルを1つずつ受け取る
  └────┬─────┘
       │ ExecProcNode()
  ┌────▼─────┐
  │  Sort    │ ← 子ノードから全タプル取得後、ソートして1つずつ返す
  └────┬─────┘
       │ ExecProcNode()
  ┌────▼──────────┐
  │  Hash Join    │ ← 内側テーブルのハッシュテーブル構築後、
  └────┬─────┬────┘   外側から1タプルずつ取得してプローブ
       │     │
  ┌────▼───┐ ┌▼────────┐
  │SeqScan │ │IndexScan│
  │(outer) │ │(inner)  │
  └────────┘ └─────────┘
```

#### ノードのライフサイクル

```c
// 各ノードは以下の3関数で統一されたインターフェースを持つ:

PlanState *ExecInitNode(Plan *node, EState *estate, int eflags);
  // Plan Tree → PlanState Tree を構築。子ノードも再帰的に初期化。

TupleTableSlot *ExecProcNode(PlanState *node);
  // 次の結果タプルを1つ返す。NULLを返すと終了。

void ExecEndNode(PlanState *node);
  // リソースの解放。子ノードも再帰的にクリーンアップ。
```

`PlanState` ツリーは `Plan` ツリーをミラーする。各 `PlanState` は実行時の状態（現在のスキャン位置、ハッシュテーブル等）を保持する。

#### Tuple Table Slots

ノード間のタプル受け渡しには `TupleTableSlot` を使用する。これは物理的なタプルデータへの参照を抽象化したもので、ヒープタプル、仮想タプル、ミニマルタプルの 3 種類がある。

#### メインループ (postgres.c)

`postgres.c` がバックエンドプロセスのメインループを実装する:

```
PostgresMain()
  └── for (;;)
        ├── ReadCommand()           // クライアントからメッセージ読み取り
        ├── switch (firstchar)
        │   ├── 'Q': exec_simple_query(query_string)
        │   │         // Simple Query Protocol
        │   │         // パース → リライト → プラン → 実行 を一括
        │   │
        │   ├── 'P': exec_parse_message(...)
        │   │         // Extended Protocol: Parse
        │   │
        │   ├── 'B': exec_bind_message(...)
        │   │         // Extended Protocol: Bind
        │   │
        │   ├── 'D': exec_describe_message(...)
        │   │         // Extended Protocol: Describe
        │   │
        │   ├── 'E': exec_execute_message(...)
        │   │         // Extended Protocol: Execute
        │   │
        │   ├── 'C': exec_close_message(...)
        │   │         // Extended Protocol: Close
        │   │
        │   ├── 'S': // Sync
        │   │
        │   └── 'X': // Terminate
        │
        └── ReadyForQuery(DestRemote)  // 'Z' メッセージ送信
```

---

## 2. ワイヤープロトコル

PostgreSQL はクライアント-サーバ間の通信に独自のバイナリプロトコル（v3）を使用する。Pure-Go 実装において最も重要なレイヤーの 1 つである。

### 2.1 接続フェーズ

```
Client                                 Server
  │                                      │
  │──── StartupMessage ────────────────→│
  │     (version=3.0, user, database)    │
  │                                      │
  │←── AuthenticationOk (R) ────────────│  ※ または認証チャレンジ
  │                                      │
  │←── ParameterStatus (S) ×N ─────────│  server_version, client_encoding,
  │                                      │  server_encoding, DateStyle, etc.
  │                                      │
  │←── BackendKeyData (K) ─────────────│  PID + secret key (キャンセル用)
  │                                      │
  │←── ReadyForQuery (Z) ──────────────│  transaction status: 'I' (idle)
  │                                      │
```

#### プロトコルバージョン定数

```c
#define PG_PROTOCOL(m, n)    (((m) << 16) | (n))

// 通常接続
PG_PROTOCOL(3, 0)       // = 196608

// 特殊リクエスト（StartupMessage と同じ位置にバージョンとして埋め込む）
CANCEL_REQUEST_CODE      = PG_PROTOCOL(1234, 5678)   // = 80877102
NEGOTIATE_SSL_CODE       = PG_PROTOCOL(1234, 5679)   // = 80877103
```

#### StartupMessage の構造

```
┌──────────┬───────────────────────────────────────────────────┐
│ Int32    │ メッセージ長 (自身を含む)                           │
├──────────┼───────────────────────────────────────────────────┤
│ Int32    │ プロトコルバージョン (196608 = 3.0)                 │
├──────────┼───────────────────────────────────────────────────┤
│ String   │ パラメータ名 ("user")                              │
├──────────┼───────────────────────────────────────────────────┤
│ String   │ パラメータ値 ("postgres")                          │
├──────────┼───────────────────────────────────────────────────┤
│ ...      │ (キー・バリューの繰り返し)                          │
├──────────┼───────────────────────────────────────────────────┤
│ Byte1(0) │ 終端                                              │
└──────────┴───────────────────────────────────────────────────┘
```

> **注意**: StartupMessage だけはメッセージタイプバイトを持たない。

### 2.2 Simple Query Protocol

最もシンプルなクエリ実行プロトコル。SQL テキストを直接送信する。

```
Client                                 Server
  │                                      │
  │──── Query ('Q') ───────────────────→│
  │     "SELECT id, name FROM users"     │
  │                                      │
  │←── RowDescription ('T') ───────────│  カラム数、各カラムの名前・型OID等
  │                                      │
  │←── DataRow ('D') ──────────────────│  1行目のデータ
  │←── DataRow ('D') ──────────────────│  2行目のデータ
  │←── ...                               │
  │                                      │
  │←── CommandComplete ('C') ──────────│  "SELECT 2"
  │                                      │
  │←── ReadyForQuery ('Z') ────────────│  'I'
  │                                      │
```

エラーの場合:

```
Client                                 Server
  │                                      │
  │──── Query ('Q') ───────────────────→│
  │     "SELECT * FROM nonexistent"      │
  │                                      │
  │←── ErrorResponse ('E') ────────────│  SQLSTATE, メッセージ等
  │                                      │
  │←── ReadyForQuery ('Z') ────────────│  'I'
  │                                      │
```

空クエリの場合は `EmptyQueryResponse ('I')` が返される。

### 2.3 Extended Query Protocol

Prepared Statement やパラメータバインドを使用する高度なプロトコル。各ステップが分離されているため、プリペアドステートメントの再利用が可能。

```
Client                                 Server
  │                                      │
  │──── Parse ('P') ──────────────────→│  SQL + ステートメント名 + パラメータ型
  │←── ParseComplete ('1') ────────────│
  │                                      │
  │──── Bind ('B') ───────────────────→│  ステートメント名 + ポータル名 + パラメータ値
  │←── BindComplete ('2') ─────────────│
  │                                      │
  │──── Describe ('D') ───────────────→│  ポータル or ステートメントを指定
  │←── ParameterDescription ('t') ─────│  (ステートメント記述の場合)
  │←── RowDescription ('T') ───────────│
  │                                      │
  │──── Execute ('E') ────────────────→│  ポータル名 + 最大行数
  │←── DataRow ('D') ×N ──────────────│
  │←── CommandComplete ('C') ──────────│
  │                                      │
  │──── Close ('C') ──────────────────→│  ステートメント or ポータルを閉じる
  │←── CloseComplete ('3') ────────────│
  │                                      │
  │──── Sync ('S') ───────────────────→│  トランザクション境界
  │←── ReadyForQuery ('Z') ────────────│
  │                                      │
```

バックエンド側の主要関数:

| メッセージ | 関数 | 処理内容 |
|---|---|---|
| Parse ('P') | `exec_parse_message()` | SQL パース、プリペアドステートメント作成 |
| Bind ('B') | `exec_bind_message()` | パラメータバインド、ポータル作成 |
| Describe ('D') | `exec_describe_message()` | ステートメント/ポータルの記述情報返却 |
| Execute ('E') | `exec_execute_message()` | 実行計画の実行、結果送信 |
| Close ('C') | `exec_close_message()` | ステートメント/ポータルの破棄 |

### 2.4 メッセージフォーマット

#### 基本構造

StartupMessage を除く全メッセージは以下の形式:

```
┌─────────┬──────────┬──────────────────┐
│ Byte1   │ Int32    │ Payload          │
│ (type)  │ (length) │ (可変長)          │
└─────────┴──────────┴──────────────────┘

※ length は自身の4バイトを含むが、type の1バイトは含まない
```

#### メッセージタイプ一覧

**フロントエンド (Client → Server):**

| タイプ | コード | 内容 |
|---|---|---|
| Query | 'Q' | SQL テキスト |
| Parse | 'P' | プリペアドステートメント作成 |
| Bind | 'B' | パラメータバインド |
| Describe | 'D' | 記述要求 |
| Execute | 'E' | 実行要求 |
| Close | 'C' | クローズ要求 |
| Sync | 'S' | 同期ポイント |
| Terminate | 'X' | 接続終了 |

**バックエンド (Server → Client):**

| タイプ | コード | 内容 |
|---|---|---|
| AuthenticationOk | 'R' | 認証成功 |
| ParameterStatus | 'S' | サーバパラメータ通知 |
| BackendKeyData | 'K' | PID + シークレットキー |
| ReadyForQuery | 'Z' | クエリ受付可能 |
| RowDescription | 'T' | 結果カラムの記述 |
| DataRow | 'D' | 結果行 |
| CommandComplete | 'C' | コマンド完了 |
| ErrorResponse | 'E' | エラー |
| NoticeResponse | 'N' | 通知 |
| ParseComplete | '1' | Parse 完了 |
| BindComplete | '2' | Bind 完了 |
| CloseComplete | '3' | Close 完了 |
| EmptyQueryResponse | 'I' | 空クエリ |

#### メッセージ構築 API

`pqformat.c` / `pqformat.h` がメッセージの構築・読み取りを担当する:

```c
// メッセージ構築 (送信側)
void pq_beginmessage(StringInfo buf, char msgtype);
void pq_sendstring(StringInfo buf, const char *str);
void pq_sendint32(StringInfo buf, int32 i);
void pq_sendint16(StringInfo buf, int16 i);
void pq_sendbyte(StringInfo buf, int byt);
void pq_sendbytes(StringInfo buf, const void *data, int datalen);
void pq_endmessage(StringInfo buf);

// メッセージ読み取り (受信側)
int pq_getmsgbyte(StringInfo msg);
int pq_getmsgint(StringInfo msg, int b);   // b = 2 or 4
const char *pq_getmsgstring(StringInfo msg);
const char *pq_getmsgrawstring(StringInfo msg);
```

低レベルの通信は `pqcomm.c`（約 2,088 行）が担当する。ソケットの読み書き、バッファリング、SSL 対応等を実装する。

---

## 3. ストレージ層

### 3.1 ページ構造

PostgreSQL のデータはすべて固定サイズのページ（デフォルト 8KB = `BLCKSZ`）に格納される。

```
┌───────────────────────────────────────────────────────────────┐
│                     Page (8192 bytes)                          │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │            PageHeaderData (24 bytes)                   │   │
│  │  pd_lsn        : 最終更新の WAL LSN                    │   │
│  │  pd_checksum   : ページチェックサム                     │   │
│  │  pd_flags      : フラグ                                │   │
│  │  pd_lower      : 空き領域の開始位置                     │   │
│  │  pd_upper      : 空き領域の終了位置                     │   │
│  │  pd_special    : Special space の開始位置               │   │
│  │  pd_pagesize_version : ページサイズ + バージョン        │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────┬──────┬──────┬──────┬─────────────────────────┐   │
│  │ LP 1 │ LP 2 │ LP 3 │ LP 4 │  ...  (Line Pointers)  │   │
│  │ (4B) │ (4B) │ (4B) │ (4B) │                         │   │
│  └──┬───┴──┬───┴──┬───┴──┬───┴─────────────────────────┘   │
│     │      │      │      │     ← pd_lower                   │
│     │      │      │      │                                   │
│     │      │      │      │      ═══ Free Space ═══           │
│     │      │      │      │                                   │
│     │      │      │      │     ← pd_upper                   │
│     │      │      │      └──→ ┌──────────────────────┐      │
│     │      │      └────────→ │   Tuple 3             │      │
│     │      └───────────────→ │   Tuple 2             │      │
│     └──────────────────────→ │   Tuple 1             │      │
│                               └──────────────────────┘      │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │        Special Space (インデックスページ用)              │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                     ← 8192   │
└───────────────────────────────────────────────────────────────┘
```

Line Pointer (ItemId) は 4 バイトで、タプルのオフセットと長さを格納する。タプルはページの末尾から先頭に向かって成長し、Line Pointer は先頭から末尾に向かって成長する。`pd_lower` と `pd_upper` の間が空き領域となる。

`bufpage.h` に `PageHeaderData` が定義されている。

### 3.2 ヒープテーブル

ヒープはデフォルトのテーブルアクセスメソッドであり、行の挿入・更新・削除・検索を担当する。

```c
// src/backend/access/heap/heapam.c
void heap_insert(Relation relation, HeapTuple tup, ...);
void heap_delete(Relation relation, ItemPointer tid, ...);
void heap_update(Relation relation, ItemPointer otid, HeapTuple newtup, ...);
bool heap_fetch(Relation relation, Snapshot snapshot, HeapTuple tuple, ...);
```

#### ヒープタプルの構造

```
┌────────────────────────────────────────────────────┐
│              HeapTupleHeaderData                    │
├──────────────┬─────────────────────────────────────┤
│ t_xmin       │ 挿入したトランザクションの XID       │
│ t_xmax       │ 削除/更新したトランザクションの XID   │
│ t_cid        │ コマンドID (cmin/cmax)               │
│ t_ctid       │ 現在のタプルの物理位置 (ブロック, オフセット) │
│ t_infomask   │ 各種フラグ (NULL ビットマップの有無等)  │
│ t_infomask2  │ カラム数等                            │
│ t_hoff       │ ユーザデータへのオフセット              │
├──────────────┴─────────────────────────────────────┤
│ NULL bitmap (オプション)                             │
├────────────────────────────────────────────────────┤
│ User Data (実際のカラムデータ)                       │
└────────────────────────────────────────────────────┘
```

システムカラム:

| カラム | 型 | 説明 |
|---|---|---|
| `ctid` | `tid` | 物理的な行の位置 (ページ番号, タプルインデックス) |
| `xmin` | `xid` | この行を挿入したトランザクション |
| `xmax` | `xid` | この行を削除/更新したトランザクション (0 = 未削除) |
| `cmin` | `cid` | 挿入コマンドのコマンド番号 |
| `cmax` | `cid` | 削除コマンドのコマンド番号 |
| `tableoid` | `oid` | テーブルの OID |

#### HOT (Heap-Only Tuples)

UPDATE 時にインデックス付きカラムが変更されない場合、HOT 最適化が適用される:

```
通常の UPDATE:
  旧タプル → xmax を設定
  新タプル → 新しいページに挿入
  インデックス → 新タプルへのエントリを追加  ← コスト大

HOT UPDATE:
  旧タプル → xmax を設定 + ctid で新タプルを指す
  新タプル → 同一ページに挿入 (HEAP_ONLY_TUPLE フラグ)
  インデックス → 更新不要!  ← コスト削減
```

HOT チェーンにより、インデックスは旧タプルの位置を指したままで、ヒープ内のチェーンをたどって最新タプルに到達できる。

### 3.3 バッファマネージャ

バッファマネージャはディスク上のページを共有メモリ上にキャッシュする。

```
┌────────────────────────────────────────────────────────┐
│                   Shared Buffers                        │
│              (デフォルト 128MB = 16,384 ページ)           │
│                                                        │
│  ┌────────┐ ┌────────┐ ┌────────┐     ┌────────┐    │
│  │Buffer 1│ │Buffer 2│ │Buffer 3│ ... │Buffer N│    │
│  │ 8KB    │ │ 8KB    │ │ 8KB    │     │ 8KB    │    │
│  │        │ │        │ │        │     │        │    │
│  │pin:0   │ │pin:2   │ │pin:0   │     │pin:1   │    │
│  │dirty:N │ │dirty:Y │ │dirty:N │     │dirty:Y │    │
│  └────────┘ └────────┘ └────────┘     └────────┘    │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │      Buffer Hash Table                            │  │
│  │  (tag: RelFileNode + ForkNumber + BlockNumber)    │  │
│  │  → Buffer ID                                      │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

主要な API (`bufmgr.c`):

```c
Buffer ReadBuffer(Relation reln, BlockNumber blockNum);
  // 指定ページをバッファに読み込み、pin して返す

void ReleaseBuffer(Buffer buffer);
  // pin を解除

void MarkBufferDirty(Buffer buffer);
  // ダーティフラグを設定 (変更があったことをマーク)
```

#### Pin/Unpin モデル

- **Pin**: バッファを使用中であることを示す。pin されたバッファは追い出されない。
- **Unpin**: 使用完了を示す。pin カウントが 0 のバッファは追い出し候補となる。
- バッファの内容にアクセスする前に必ず pin し、アクセス完了後に unpin する。

#### Clock Sweep アルゴリズム

バッファの追い出し（置換）には Clock Sweep アルゴリズムを使用する:

```
全バッファを時計回りにスキャン:
  ├── pin count > 0 → スキップ (使用中)
  ├── usage count > 0 → usage count-- してスキップ (最近使用された)
  └── usage count == 0 → このバッファを追い出し対象に選択
```

### 3.4 WAL (Write-Ahead Log)

WAL (Write-Ahead Logging) はデータの永続性とクラッシュリカバリを保証する仕組みである。

```
                     変更操作
                        │
                        ▼
              ┌──────────────────┐
              │  WAL バッファ     │  ← まず WAL レコードを書く
              └────────┬─────────┘
                       │ flush (fsync)
                       ▼
              ┌──────────────────┐
              │  WAL ファイル     │  ← ディスクに永続化
              │  (16MB セグメント) │
              └──────────────────┘

              ※ データページのディスク書き込みは後でよい
                (チェックポイント時にまとめて書く)
```

- **`xlog.c`**: WAL の中核実装（約 315KB、`transam/` 内で最大のファイル）
- **LSN (Log Sequence Number)**: WAL レコードの位置を示す 64 ビット整数。全 WAL レコードに順序を与える
- **原則**: データページをディスクに書く前に、対応する WAL レコードが必ずディスクに書かれていなければならない

WAL により以下が実現される:
1. **クラッシュリカバリ**: サーバ異常終了後、WAL を再生してデータを一貫した状態に復元
2. **ポイントインタイムリカバリ (PITR)**: 特定の時点までの WAL を再生して復元
3. **レプリケーション**: WAL をスタンバイサーバに送信して複製

---

## 4. MVCC (Multi-Version Concurrency Control)

PostgreSQL は MVCC を使用して、ロックなしの読み取り一貫性を提供する。各行の複数のバージョン（タプル）が同時に存在し、各トランザクションはスナップショットに基づいて可視なバージョンを選択する。

### 4.1 基本原理

```
時間軸 →

Transaction 100: INSERT INTO t VALUES (1, 'Alice');
  ┌─────────────────────────────────────────────────┐
  │ Tuple A:  xmin=100, xmax=0                      │  ← 有効
  └─────────────────────────────────────────────────┘

Transaction 200: UPDATE t SET name='Bob' WHERE id=1;
  ┌─────────────────────────────────────────────────┐
  │ Tuple A:  xmin=100, xmax=200                    │  ← 200 が削除マーク
  └─────────────────────────────────────────────────┘
  ┌─────────────────────────────────────────────────┐
  │ Tuple B:  xmin=200, xmax=0                      │  ← 200 が作成した新版
  └─────────────────────────────────────────────────┘

Transaction 150 (READ COMMITTED, 200 コミット前に開始):
  → Tuple A が見える (xmin=100 はコミット済み、xmax=200 は未コミット)

Transaction 250 (200 コミット後に開始):
  → Tuple B が見える (xmin=200 はコミット済み、xmax=0 = 削除されていない)
```

### 4.2 可視性ルール

タプルが特定のスナップショットから可視かどうかは以下のルールで判定される:

```
タプルが可視 ⟺
  xmin がコミット済み (かつスナップショットから見える)
  AND
  (xmax が無効 OR xmax が未コミット OR xmax がスナップショットから見えない)
```

具体的な判定は `tqual.c` / `heapam_visibility.c` で実装される。

### 4.3 スナップショット

スナップショットは「どのトランザクションが可視か」を定義する:

```c
typedef struct SnapshotData {
    TransactionId xmin;     // この XID より前のトランザクションはすべて完了
    TransactionId xmax;     // この XID 以降のトランザクションはすべて未開始
    TransactionId *xip;     // xmin〜xmax の間で進行中のトランザクション一覧
    uint32 xcnt;            // xip の要素数
    ...
} SnapshotData;
```

### 4.4 トランザクション管理

`xact.c`（約 189KB）がトランザクションのライフサイクル全体を管理する:

```
StartTransaction()
  │
  ├── GetNewTransactionId()     // 新しい XID を取得
  ├── GetSnapshotData()         // スナップショットを取得
  │
  ├── ... SQL 実行 ...
  │
  ├── CommitTransaction()       // コミット
  │   ├── RecordTransactionCommit()   // WAL にコミットレコード書き込み
  │   └── ProcArrayEndTransaction()   // 他トランザクションに完了を通知
  │
  └── AbortTransaction()        // アボート (エラー時)
      └── RecordTransactionAbort()
```

### 4.5 コミットログ (CLOG)

`clog.c` がトランザクションのコミット状態を管理する。各トランザクションのステータスは 2 ビットで表現される:

| ステータス | 値 | 意味 |
|---|---|---|
| `TRANSACTION_STATUS_IN_PROGRESS` | 0 | 進行中 |
| `TRANSACTION_STATUS_COMMITTED` | 1 | コミット済み |
| `TRANSACTION_STATUS_ABORTED` | 2 | アボート済み |
| `TRANSACTION_STATUS_SUB_COMMITTED` | 3 | サブトランザクションコミット済み |

### 4.6 分離レベル

| 分離レベル | 実装 | ファントムリード | 説明 |
|---|---|---|---|
| READ COMMITTED | 文ごとにスナップショット取得 | あり得る | デフォルト。各 SQL 文の実行開始時にスナップショットを取得 |
| REPEATABLE READ | トランザクション開始時にスナップショット固定 | なし | トランザクション全体で同一スナップショットを使用 |
| SERIALIZABLE | SSI (Serializable Snapshot Isolation) | なし | 直列化異常を検出してアボート。predicate lock を使用 |

---

## 5. インデックスアクセスメソッド

PostgreSQL は複数のインデックスタイプをプラグイン可能なアクセスメソッドとしてサポートする。`amapi.h` に共通インターフェース `IndexAmRoutine` が定義されている。

### 5.1 B-tree (`nbtree/`, 13 ファイル)

デフォルトのインデックスタイプ。順序付きデータに最適。

```
              ┌──────────────┐
              │   Root       │
              │  [30 | 70]   │
              └──┬───────┬───┘
          ┌──────┘       └──────┐
          ▼                     ▼
  ┌───────────────┐    ┌───────────────┐
  │  Internal     │    │  Internal     │
  │  [10 | 20]    │    │  [50 | 60]    │
  └─┬────┬────┬───┘    └─┬────┬────┬───┘
    ▼    ▼    ▼           ▼    ▼    ▼
  ┌───┐┌───┐┌───┐     ┌───┐┌───┐┌───┐
  │L1 ││L2 ││L3 │ ... │L4 ││L5 ││L6 │    ← リーフノード
  └─→─┘└─→─┘└─→─┘     └─→─┘└─→─┘└───┘      (右方向にリンク)
```

- **サポート演算子**: `=`, `<`, `>`, `<=`, `>=`, `BETWEEN`, `IN`, `IS NULL`
- **特徴**: リーフノード間が双方向リンクで接続されており、範囲スキャンが効率的
- **主要ファイル**: `nbtinsert.c` (挿入), `nbtsearch.c` (検索), `nbtsort.c` (ソートビルド)

### 5.2 Hash (`hash/`, 10 ファイル)

等価検索に特化したインデックス。

- **サポート演算子**: `=` のみ
- **特徴**: ハッシュ関数によるバケット分割。B-tree より等価検索が高速な場合がある
- **制限**: 範囲検索、ソートには使用不可

### 5.3 GiST (`gist/`, 11 ファイル)

Generalized Search Tree。バランス木を一般化したフレームワーク。

- **用途**: 空間データ (PostGIS), 範囲型, 全文検索
- **特徴**: ユーザ定義のキー分割戦略をサポート
- **演算子例**: `&&` (重なり), `@>` (包含), `<->` (距離)

### 5.4 GIN (`gin/`, 15 ファイル)

Generalized Inverted Index。転置インデックス。

```
GIN インデックスの構造:

  キー      → ポスティングリスト (該当する行のリスト)
  ─────────────────────────────────────────────
  "apple"   → {(0,1), (0,5), (1,3), ...}
  "banana"  → {(0,2), (2,1), ...}
  "cherry"  → {(1,1), (1,4), (3,2), ...}
```

- **用途**: 配列 (`@>`), JSONB (`@>`, `?`, `?|`, `?&`), 全文検索 (`@@`)
- **特徴**: 1 つのインデックスエントリが複数のキーを持つデータに最適

### 5.5 BRIN (`brin/`, 10 ファイル)

Block Range Index。ブロック範囲単位でサマリ情報を保持する軽量インデックス。

```
BRIN インデックスの構造:

  ブロック範囲    min    max
  ──────────────────────────
  0 - 127        1      128
  128 - 255      129    256
  256 - 383      257    384
  ...
```

- **用途**: 自然に物理的にソートされた大規模テーブル（タイムスタンプ、シーケンシャル ID）
- **特徴**: インデックスサイズが極めて小さい。B-tree の 1/1000 以下になることもある
- **制限**: 物理的にソートされていないデータには効果が薄い

### 5.6 SP-GiST (`spgist/`, 11 ファイル)

Space-Partitioned GiST。空間分割に基づく非バランス木。

- **用途**: 電話番号のプレフィックス検索、IP アドレス範囲、幾何データ
- **特徴**: Trie、Quad-tree、k-d tree などの構造を実装可能

### 5.7 プラグイン可能なアクセスメソッド API

```c
// amapi.h - IndexAmRoutine の主要コールバック
typedef struct IndexAmRoutine {
    ...
    ambuild_function        ambuild;        // インデックス構築
    aminsert_function       aminsert;       // タプル挿入
    ambeginscan_function    ambeginscan;    // スキャン開始
    amgettuple_function     amgettuple;     // 次タプル取得
    amrescan_function       amrescan;       // スキャン再開
    amendscan_function      amendscan;      // スキャン終了
    amcostestimate_function amcostestimate; // コスト推定
    ...
} IndexAmRoutine;
```

---

## 6. システムカタログ

システムカタログは PostgreSQL のメタデータを格納する通常のテーブル群であり、`pg_catalog` スキーマに配置される。

### 6.1 主要カタログ

| カタログ | 内容 | 重要なカラム |
|---|---|---|
| `pg_class` | リレーション（テーブル、インデックス、ビュー等） | `oid`, `relname`, `relnamespace`, `relkind`, `relam` |
| `pg_attribute` | カラム定義 | `attrelid`, `attname`, `atttypid`, `attnum`, `attnotnull` |
| `pg_type` | データ型 | `oid`, `typname`, `typlen`, `typinput`, `typoutput` |
| `pg_proc` | 関数・プロシージャ | `oid`, `proname`, `proargtypes`, `prorettype`, `prosrc` |
| `pg_namespace` | スキーマ | `oid`, `nspname`, `nspowner` |
| `pg_index` | インデックスのメタデータ | `indexrelid`, `indrelid`, `indkey`, `indisunique` |
| `pg_constraint` | 制約 | `conname`, `contype`, `conrelid`, `confrelid` |
| `pg_database` | データベース | `oid`, `datname`, `datdba`, `encoding` |
| `pg_authid` | 認証情報（ロール） | `oid`, `rolname`, `rolsuper`, `rolpassword` |

### 6.2 カタログの関係

```
pg_namespace (スキーマ)
    │
    ├──→ pg_class (テーブル/ビュー/インデックス)
    │       │
    │       ├──→ pg_attribute (カラム)
    │       │       └──→ pg_type (データ型)
    │       │
    │       ├──→ pg_index (インデックスメタデータ)
    │       │
    │       └──→ pg_constraint (制約)
    │               └──→ pg_class (参照先テーブル)
    │
    └──→ pg_proc (関数)
            └──→ pg_type (引数型・戻り値型)
```

### 6.3 information_schema

SQL 標準で定義されたメタデータビュー群。内部的にはシステムカタログに対するビューとして実装されている:

- `information_schema.tables` → `pg_class` + `pg_namespace`
- `information_schema.columns` → `pg_attribute` + `pg_type`
- `information_schema.table_constraints` → `pg_constraint`

### 6.4 カタログキャッシュ

頻繁にアクセスされるカタログデータは各バックエンドプロセスのローカルメモリにキャッシュされる:

- **`catcache.c`**: カタログタプルのキャッシュ。`SearchSysCache()` でアクセス。ハッシュテーブルベース。
- **`relcache.c`**: `RelationData` 構造体のキャッシュ。テーブルやインデックスのメタデータ（カラム情報、アクセスメソッド、統計情報等）を保持。`RelationIdGetRelation()` でアクセス。

```
カタログキャッシュの階層:

  SearchSysCache1(RELOID, oid)     → catcache (タプル単位)
       │
       └── キャッシュミス時 → heap_fetch() でディスクから読み取り

  RelationIdGetRelation(oid)       → relcache (リレーション単位)
       │
       └── キャッシュミス時 → RelationBuildDesc()
              → 複数の catcache 検索を組み合わせて構築
```

キャッシュの無効化は共有メモリ上の Invalidation Message キューを通じて行われる。あるバックエンドがカタログを変更すると、他のバックエンドに無効化メッセージが送信される。

---

## 7. メモリ管理

PostgreSQL はコンテキストベースのメモリ管理システムを使用する。`malloc`/`free` ではなく、`palloc`/`pfree` を使用する。

### 7.1 MemoryContext

```
TopMemoryContext (プロセス全体の寿命)
  │
  ├── MessageContext (1 メッセージの処理中)
  │
  ├── CacheMemoryContext (カタログキャッシュ)
  │
  ├── TopTransactionContext (トランザクション全体)
  │   │
  │   ├── CurTransactionContext (現在のサブトランザクション)
  │   │
  │   └── per-portal contexts
  │       │
  │       └── per-tuple context (1 タプル処理ごとにリセット)
  │
  └── ErrorContext (エラー処理用、予約済み)
```

### 7.2 基本 API

```c
// memutils.h, palloc.h

// メモリ確保 (現在のコンテキストから)
void *palloc(Size size);
void *palloc0(Size size);           // ゼロ初期化

// メモリ解放
void pfree(void *pointer);

// コンテキスト操作
MemoryContext AllocSetContextCreate(MemoryContext parent, const char *name, ...);
void MemoryContextSwitchTo(MemoryContext context);
void MemoryContextReset(MemoryContext context);    // 中身を全解放 (コンテキスト自体は残る)
void MemoryContextDelete(MemoryContext context);   // コンテキスト自体も解放
```

### 7.3 AllocSet (`aset.c`)

主要なメモリアロケータ。フリーリストとチャンクベースの管理を行う:

```
AllocSet
  ├── blocks: メモリブロックのリスト
  │   ├── Block 1 (8KB)
  │   │   ├── Chunk A (64B)
  │   │   ├── Chunk B (128B)
  │   │   └── [free space]
  │   ├── Block 2 (16KB)
  │   │   └── ...
  │   └── ...
  │
  └── freelist[]: サイズ別フリーリスト
      ├── [0]: 8B チャンク
      ├── [1]: 16B チャンク
      ├── [2]: 32B チャンク
      └── ...
```

### 7.4 コンテキストベース管理の利点

1. **自動クリーンアップ**: トランザクション終了時にコンテキストを削除するだけで、個々の `pfree` 不要
2. **メモリリーク防止**: エラー発生時もコンテキスト単位で確実に解放
3. **デバッグ容易性**: コンテキスト名でメモリ使用量を追跡可能
4. **階層的管理**: 子コンテキストは親と一緒に解放される

---

## 8. プロセスモデル

PostgreSQL はマルチプロセスアーキテクチャを採用する。各クライアント接続に対して 1 つのバックエンドプロセスが `fork()` される。

### 8.1 プロセス構成

```
┌──────────────────────────────────────────────────────────────────┐
│                         Postmaster                                │
│                    (メイン管理プロセス)                              │
│                                                                    │
│  ・TCP ポートで接続を受付                                           │
│  ・子プロセスの生成と監視                                           │
│  ・シグナルハンドリング                                             │
└────────┬─────────┬─────────┬─────────┬───────────────────────────┘
         │         │         │         │
    fork()    fork()    fork()    fork() ...
         │         │         │         │
         ▼         ▼         ▼         ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────────────────┐
│Backend 1│ │Backend 2│ │Backend 3│ │ Background Workers   │
│(client) │ │(client) │ │(client) │ │                      │
│         │ │         │ │         │ │ ├── autovacuum       │
│PostgresM│ │PostgresM│ │PostgresM│ │ │   launcher/worker  │
│ain()    │ │ain()    │ │ain()    │ │ ├── checkpointer     │
└────┬────┘ └────┬────┘ └────┬────┘ │ ├── bgwriter        │
     │           │           │      │ ├── walwriter        │
     └───────────┴───────────┘      │ ├── walsummarizer   │
                 │                   │ └── stats collector  │
                 ▼                   └──────────────────────┘
    ┌─────────────────────────┐
    │    Shared Memory        │
    │                         │
    │  ├── Shared Buffers     │
    │  ├── WAL Buffers        │
    │  ├── Lock Tables        │
    │  ├── Proc Array         │
    │  ├── CLOG Buffers       │
    │  └── Sinval Queue       │
    │    (無効化メッセージ)     │
    └─────────────────────────┘
```

### 8.2 各プロセスの役割

| プロセス | 役割 |
|---|---|
| **Postmaster** | メインプロセス。接続受付、子プロセスの生成・監視・再起動 |
| **Backend** | クライアント接続ごとに 1 プロセス。SQL の処理を担当 |
| **Autovacuum Launcher** | 自動 VACUUM のスケジューリング |
| **Autovacuum Worker** | 実際の VACUUM/ANALYZE 処理 |
| **Checkpointer** | 定期的にチェックポイントを実行。ダーティバッファをディスクに書き出し |
| **Background Writer** | バックグラウンドでダーティバッファを少しずつ書き出し |
| **WAL Writer** | WAL バッファをディスクに flush |
| **WAL Summarizer** | WAL の要約情報を生成（増分バックアップ用） |
| **Stats Collector** | テーブル/インデックスのアクセス統計を収集 |

### 8.3 共有メモリによるプロセス間通信

全バックエンドプロセスは共有メモリを通じてデータを共有する:

- **Shared Buffers**: ディスクページのキャッシュ (前述)
- **WAL Buffers**: WAL レコードのバッファ
- **Lock Tables**: 行ロック、テーブルロック等の管理
- **Proc Array**: 全バックエンドのトランザクション状態。スナップショット取得時に参照
- **CLOG Buffers**: コミットログのバッファ
- **Sinval Queue**: カタログキャッシュ無効化メッセージのキュー

軽量ロック (`LWLock`) とスピンロック (`SpinLock`) が共有メモリへの並行アクセスを制御する。

---

## Pure-Go 実装への示唆

本ドキュメントで解説したアーキテクチャを Pure-Go で再現する際の主要な検討事項:

| レイヤー | PostgreSQL | Pure-Go 実装の方針 |
|---|---|---|
| ワイヤープロトコル | C 実装 | `net.Conn` で実装。既存ライブラリ（pgproto3 等）の活用を検討 |
| パーサー | flex/bison | pg_query_go（cgo）または Pure-Go パーサーの実装/採用 |
| プランナ | コストベース最適化 | 初期はルールベース、段階的にコストベースへ |
| エグゼキュータ | Volcano モデル | Go の interface で Iterator パターンを実装 |
| ストレージ | ページベース + WAL | インメモリのため大幅に簡略化可能 |
| MVCC | xmin/xmax + スナップショット | Go の `sync.RWMutex` やチャネルで実現 |
| プロセスモデル | fork() | goroutine ベースに変更 |
| 共有メモリ | POSIX shmem | Go のヒープメモリを直接共有（goroutine 間は自動的に共有） |
| メモリ管理 | MemoryContext | Go の GC に委ねる。必要に応じて `sync.Pool` で最適化 |
