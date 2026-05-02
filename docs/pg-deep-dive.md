[← README に戻る](../README.md)

# PostgreSQL 内部詳解（12 トピック深掘り）

本ドキュメントは Pure Go インメモリ PostgreSQL 互換エンジンを設計する上で参照価値の高い PostgreSQL 本体（master / 19devel 系）の内部構造を、**12 トピック**に分けて中粒度で解説するリファレンスである。
各トピックは以下のテンプレートに従う。

- **概要** — そのサブシステムが何を担うか、なぜ重要か
- **PostgreSQL 本体の実装** — 主要ファイル / 主要関数 / 制御フロー / 疑似コード
- **Pure Go インメモリ実装への示唆** — 何を真似るべきか、何を簡略化できるか、設計上の注意

参照リンクは原則として `https://github.com/postgres/postgres/blob/master/...` を用いる（行番号は本ドキュメント執筆時点のものであり master 追従で揺れる）。

> **注意**: 既存の [docs/deep-dive-psql-wire.md](deep-dive-psql-wire.md) はクライアント側 (psql-wire) の API 視点である。本ドキュメントの「4. ワイヤープロトコル」節は **PostgreSQL サーバ側** (`pqcomm.c`, `postgres.c`) 視点で短くまとめ、詳細は前者へ誘導する。

---

## 目次

1. [MVCC と可視性判定](#1-mvcc-と可視性判定)
2. [システムカタログ](#2-システムカタログ)
3. [型システム](#3-型システム)
4. [ワイヤープロトコル（サーバ側）](#4-ワイヤープロトコルサーバ側)
5. [MemoryContext](#5-memorycontext)
6. [プランナ／オプティマイザ](#6-プランナオプティマイザ)
7. [エグゼキュータ](#7-エグゼキュータ)
8. [ロックマネージャ](#8-ロックマネージャ)
9. [インデックス AM (Access Method)](#9-インデックス-am-access-method)
10. [関数呼び出し規約 (fmgr)](#10-関数呼び出し規約-fmgr)
11. [エラーハンドリングと ereport](#11-エラーハンドリングと-ereport)
12. [Extended Query Protocol (Parse/Bind/Execute)](#12-extended-query-protocol-parsebindexecute)

---

## 1. MVCC と可視性判定

### 概要

PostgreSQL の同時実行制御は **MVCC (Multi-Version Concurrency Control)** に基づき、書き込みが読み取りをブロックせず、読み取りも書き込みをブロックしない。
タプルは更新時に「物理的に上書き」されず **新しいバージョンを heap に追記**し、古いバージョンは `xmin/xmax` というシステム列で寿命管理される。
スナップショット (`xmin, xmax, xip[]`) と各タプルの `(xmin, xmax, cmin/cmax, infomask)` を突き合わせて **そのトランザクションから見えるか** を判定するのが「可視性判定」であり、PostgreSQL のトランザクション意味論の核である。

### PostgreSQL 本体の実装

主要ファイル:

- `src/backend/access/heap/heapam_visibility.c` (約 1753 行)
- `src/backend/utils/time/snapmgr.c` (約 1971 行)
- `src/include/access/htup_details.h`（タプルヘッダ HEAP_XMIN_COMMITTED 等のフラグ定義）
- `src/backend/access/transam/clog.c`（コミットログ）

可視性判定関数群（`heapam_visibility.c`）:

| 関数 | 行 | 用途 |
|------|----|------|
| `HeapTupleSatisfiesSelf` | ~297 | 自トランザクション内の見え方（dirty read 相当だが自身のみ） |
| `HeapTupleSatisfiesUpdate` | ~511 | UPDATE/DELETE の競合検出（HeapTupleMayBeUpdated 等を返す） |
| `HeapTupleSatisfiesDirty` | ~759 | 未コミット含めて見る（外部キー検査などに利用） |
| `HeapTupleSatisfiesMVCC` | ~939 | 通常の SELECT。スナップショットと付き合わせる |
| `HeapTupleSatisfiesVacuum` | ~1113 | VACUUM 用（HEAPTUPLE_DEAD/RECENTLY_DEAD/LIVE/INSERT_IN_PROGRESS/DELETE_IN_PROGRESS） |
| `HeapTupleSatisfiesVacuumHorizon` | ~1147 | グローバル xmin に基づく削除可否 |
| `HeapTupleSatisfiesHistoricMVCC` | ~1504 | 論理デコード（過去スナップショット）用 |

`HeapTupleSatisfiesMVCC` の制御フロー（疑似コード）:

```c
bool HeapTupleSatisfiesMVCC(HeapTuple htup, Snapshot snap, Buffer buf) {
    HeapTupleHeader t = htup->t_data;

    /* xmin の有効性を確かめる */
    if (!HeapTupleHeaderXminCommitted(t)) {
        if (HeapTupleHeaderXminInvalid(t)) return false;
        if (TransactionIdIsCurrentTransactionId(t->t_xmin)) {
            /* 自分が挿入: cmin と比較 */
            if (HeapTupleHeaderGetCmin(t) >= snap->curcid) return false;
            /* xmax の判定へ */
        } else if (XidInMVCCSnapshot(t->t_xmin, snap)) {
            return false;     /* 自スナップショットには未コミット扱い */
        } else if (TransactionIdDidCommit(t->t_xmin)) {
            SetHintBits(t, buf, HEAP_XMIN_COMMITTED, t->t_xmin);
        } else {
            SetHintBits(t, buf, HEAP_XMIN_INVALID, InvalidTransactionId);
            return false;
        }
    }

    /* ここまで来ると xmin はスナップショットから見て「コミット済み」 */
    if (t->t_infomask & HEAP_XMAX_INVALID) return true;
    if (HEAP_XMAX_IS_LOCKED_ONLY(t->t_infomask)) return true;

    /* xmax の有効性を確かめて、削除済みなら不可視 */
    if (!(t->t_infomask & HEAP_XMAX_COMMITTED)) {
        if (TransactionIdIsCurrentTransactionId(t->t_xmax)) {
            if (HeapTupleHeaderGetCmax(t) >= snap->curcid) return true;
            return false;
        }
        if (XidInMVCCSnapshot(t->t_xmax, snap)) return true;
        if (!TransactionIdDidCommit(t->t_xmax)) {
            SetHintBits(t, buf, HEAP_XMAX_INVALID, InvalidTransactionId);
            return true;
        }
        SetHintBits(t, buf, HEAP_XMAX_COMMITTED, t->t_xmax);
    }
    if (t->t_xmax >= snap->xmax || XidInMVCCSnapshot(t->t_xmax, snap))
        return true;  /* 削除はスナップショット時点ではまだ */
    return false;
}
```

スナップショット取得は `GetTransactionSnapshot()` が `GetSnapshotData()` を呼び、共有メモリの `ProcArray`（全アクティブバックエンドの xid 一覧）を走査して `xmin / xmax / xip[]` を切り出す。
**Hint Bits**（`HEAP_XMIN_COMMITTED` 等）は CLOG 参照を毎回行わなくて済むようタプルに「以前のチェック結果」をキャッシュする工夫であり、ストレージ書き込みを伴うが WAL は出さない（楽観的キャッシュ）。

### Pure Go インメモリ実装への示唆

- 「タプルにバージョン列 `xmin / xmax` を持たせ、新規バージョンは追記、不可視判定は MVCC スナップショット」は **Go でもそのまま写経できる**最良の出発点。
- インメモリなら CLOG 相当は `map[xid]CommitState` で十分（永続化不要）。Hint Bits も「実装簡素化のため省略」して常に CLOG を見る選択でよい（パフォーマンスは十分）。
- `ProcArray` 相当は `sync.Mutex` 保護下の `[]activeXid` で OK。スナップショット作成のコストはトランザクション数に比例で、想定接続数が小さい用途では問題にならない。
- バージョンチェイン (`t_ctid`) を素直に持つと VACUUM 相当を後回しにでき、PoC では「ガベージコレクトしない」運用も可能（メモリ消費と引き換え）。
- `HeapTupleSatisfiesMVCC` の if 木は **Go の switch ＋ 早期 return** に書き換えると見通しが良い。テストは PG 本体の isolation テストを真似て「読み手 / 書き手」を goroutine で並走させるのが鉄板。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/access/heap/heapam_visibility.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/time/snapmgr.c>
- <https://github.com/postgres/postgres/blob/master/src/include/access/htup_details.h>

---

## 2. システムカタログ

### 概要

PostgreSQL は **「カタログ自身も通常のテーブル」** という設計（self-hosted catalog）を取る。データベース・テーブル・列・型・関数・インデックス・制約などのメタデータはすべて `pg_class`, `pg_attribute`, `pg_type`, `pg_proc`, `pg_namespace`, ... という **実体テーブル** に格納され、SQL からも `SELECT * FROM pg_class` のように参照できる。
DDL は内部的に **これらカタログテーブルへの INSERT/UPDATE/DELETE** に帰着する。

### PostgreSQL 本体の実装

主要ヘッダ（`src/include/catalog/`）:

| ヘッダ | 役割 |
|--------|------|
| `pg_class.h` | リレーション (テーブル/インデックス/ビュー) の定義。`relkind`, `relnatts`, `reltuples`, `relpages`, `relam` 等 |
| `pg_attribute.h` | 列の定義。`attname, atttypid, attnum, attnotnull, atttypmod` 等 |
| `pg_type.h` | 型。`typname, typlen, typbyval, typtype, typcategory, typinput, typoutput` 等 |
| `pg_namespace.h` | スキーマ |
| `pg_proc.h` | 関数定義（C/SQL/PL/pgSQL すべて） |
| `pg_constraint.h` | 制約 (PK/FK/UNIQUE/CHECK) |
| `pg_index.h` | インデックスの構造（`indkey`, `indclass`, `indoption`） |
| `pg_database.h` | データベース |
| `pg_operator.h, pg_opclass.h, pg_amop.h, pg_amproc.h` | 演算子族・演算子クラス（インデックスで使う比較関数等） |

これらはビルド時に `genbki.pl` が `.dat` ファイルから初期データを読み bootstrap カタログを生成する。
SQL 側からのアクセスは `src/backend/catalog/` 配下（例: `heap.c`, `index.c`, `pg_class.c`）の各種 `Form_pg_xxx` 構造体経由で行われる。SearchSysCache（`syscache.c`）は OID をキーとした **共有メモリ LRU キャッシュ**で、カタログへの数兆回のアクセスを実用速度に保つ要石。

DDL 例: `CREATE TABLE foo(a int)` の流れ:

1. パース (`gram.y` → `CreateStmt`)
2. `DefineRelation` (`commands/tablecmds.c`) が `heap_create_with_catalog` を呼ぶ
3. `heap_create_with_catalog` (`catalog/heap.c`) が
   - `pg_class` に行を INSERT
   - 各列につき `pg_attribute` に INSERT
   - `pg_type` にこのテーブル用の合成型を INSERT
   - 必要なら `pg_depend, pg_shdepend` に依存関係を INSERT
4. ファイル実体 (relfilenode) を生成

### Pure Go インメモリ実装への示唆

- 「カタログ自身がテーブル」を素朴に実装すると相互依存（chicken-and-egg）が複雑になる。**Pure Go では Phase 1 ではカタログを Go の構造体 (`map[OID]*Relation` 等) で持ち、SQL から見える `pg_class` は読み取り専用ビューで合成**するのが現実的。
- 具体的に必要な最小カタログ:
  - `pg_namespace` (`oid, nspname`)
  - `pg_class` (`oid, relname, relnamespace, relkind, relnatts`)
  - `pg_attribute` (`attrelid, attname, attnum, atttypid, attnotnull`)
  - `pg_type` (`oid, typname, typlen, typbyval, typcategory`)
  - `pg_proc` (`oid, proname, prorettype, proargtypes`)
  - `pg_index`, `pg_constraint` は Phase 2
- `pg_catalog` への SELECT 互換は **psql の `\d` や ORM の introspection** が依存するので最重要（特に `pg_class`, `pg_attribute`, `pg_type`, `pg_namespace`, `pg_description`）。
- OID は内部的に 1 から振る uint32 で十分。**OID 1〜9999 は組み込み型 / システム関数用**として PG と互換にしておくと、ライブラリ（pgx, lib/pq）が型を解釈しやすい（`int4 = 23, text = 25, varchar = 1043, ...`）。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_class.h>
- <https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h>
- <https://github.com/postgres/postgres/blob/master/src/backend/catalog/heap.c>

---

## 3. 型システム

### 概要

PostgreSQL の型システムは「**カタログ駆動型**」であり、組み込み型と拡張型を完全に同じ枠組みで扱う。
各型は `pg_type` の 1 行で表現され、入出力関数 (`typinput, typoutput`)、バイナリ送受信関数 (`typsend, typreceive`)、長さ (`typlen`)、値渡し可否 (`typbyval`)、整列 (`typalign`)、カテゴリ (`typcategory`)、要素型 (`typelem`) などをメタデータとして持つ。
SQL レベルの `CAST`, `IN`/`OUT` 関数、`COERCE`, 自動キャスト、演算子解決はすべてこの定義をたどる。

### PostgreSQL 本体の実装

主要ファイル:

- `src/include/catalog/pg_type.h` — `Form_pg_type` 構造体定義
- `src/include/catalog/pg_type.dat` — 組み込み型の初期データ（bool, int2, int4, int8, float4, float8, numeric, text, varchar, bytea, date, time, timestamp, timestamptz, interval, uuid, json, jsonb, xml, oid, name, ...）
- `src/backend/utils/adt/` — 型ごとの実装（例: `int.c, numeric.c, varchar.c, timestamp.c, jsonb.c`）
- `src/backend/parser/parse_coerce.c` — 型強制 (coercion) ロジック
- `src/backend/parser/parse_oper.c` — 演算子解決
- `src/backend/parser/parse_func.c` — 関数解決

入出力関数の例（`int.c`）:

```c
Datum int4in(PG_FUNCTION_ARGS) {
    char *s = PG_GETARG_CSTRING(0);
    int32 result = pg_strtoint32_safe(s, fcinfo);
    PG_RETURN_INT32(result);
}

Datum int4out(PG_FUNCTION_ARGS) {
    int32 v = PG_GETARG_INT32(0);
    char *result = palloc(12);
    pg_ltoa(v, result);
    PG_RETURN_CSTRING(result);
}
```

型カテゴリ (`typcategory`) は `'B'(boolean), 'D'(datetime), 'N'(numeric), 'S'(string), 'U'(user), 'A'(array), 'C'(composite), 'E'(enum), 'R'(range), ...` で、暗黙キャストの優先順位 (`typispreferred`) と合わせて「型の昇格 (promotion)」のルールを駆動する（例: `int + numeric → numeric`）。

### Pure Go インメモリ実装への示唆

- Phase 1 で実装すべき型は **本当に少ない**: `bool, int2, int4, int8, float4, float8, numeric, text, varchar, bytea, date, timestamp, timestamptz, uuid, jsonb, oid` の 16 種類で多数のアプリケーションが動く（`numeric` だけは Go で `math/big` 系の自前実装が必要、`shopspring/decimal` の流用も検討に値する）。
- 各型は Go の interface で表現:
  ```go
  type PgType interface {
      OID() uint32
      Name() string
      Length() int16
      ByVal() bool
      InputText(string) (Datum, error)
      OutputText(Datum) string
      InputBinary([]byte) (Datum, error)
      OutputBinary(Datum) []byte
  }
  ```
- 内部値表現は **Go ネイティブ型 (`int32, int64, float64, string, []byte, time.Time, uuid.UUID, decimal.Decimal`) を直接使う**のが Pure Go 流。Datum を `interface{}` ないし `any` にして型 OID と 1:1 対応させる設計が読みやすい。
- 強制 (coercion) は最初は素朴にハードコード (`int4 → int8`, `int → numeric`, `int → text` 等) で十分。`pg_cast` 全互換は Phase 3 以降。
- バイナリ表現は pgx 互換性を保つため **ネットワークバイトオーダ (big-endian)** を厳守。`int4` は 4 バイト big-endian、`text` は UTF-8 そのまま、`numeric` は専用フォーマット（PG 仕様に準拠）。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h>
- <https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat>
- <https://github.com/postgres/postgres/blob/master/src/backend/parser/parse_coerce.c>

---

## 4. ワイヤープロトコル（サーバ側）

### 概要

クライアント／サーバ間の通信プロトコル v3.0 の **サーバ側の受信・送信ループ**。Simple Query / Extended Query / COPY / Function Call のメッセージ駆動状態機械として実装される。
本節は PG 本体（`pqcomm.c`, `postgres.c`）の振る舞いに絞る。プロトコル仕様の網羅および Go 側の実装パターンは [docs/deep-dive-psql-wire.md](deep-dive-psql-wire.md) を参照。

### PostgreSQL 本体の実装

主要ファイル:

- `src/backend/libpq/pqcomm.c` — 低レベル受信／送信バッファ (`pq_getbyte`, `pq_getstring`, `pq_getmessage`, `pq_putmessage`, `pq_flush`)
- `src/backend/libpq/auth.c` — 認証（trust, md5, scram-sha-256, GSSAPI, ...）
- `src/backend/tcop/postgres.c` — メインループ `PostgresMain` と各メッセージタイプのディスパッチ
- `src/backend/utils/error/elog.c` — `ErrorResponse` 等の構築
- `src/include/libpq/protocol.h` — メッセージタイプの 1 文字定数

`PostgresMain`（`postgres.c`）の擬似コード:

```c
for (;;) {
    firstchar = ReadCommand(&input_message);  /* pq_getmessage を呼ぶ */
    switch (firstchar) {
        case 'Q': exec_simple_query(query_string); break;
        case 'P': exec_parse_message(...);          break;
        case 'B': exec_bind_message(...);           break;
        case 'E': exec_execute_message(...);        break;
        case 'D': exec_describe_statement_message(.../portal_message); break;
        case 'C': exec_close_message(...);          break;
        case 'S': finish_xact_command(); send_ReadyForQuery(...); break;
        case 'X': proc_exit(0);
        case 'F': HandleFunctionRequest();          break;
        case 'd': case 'c': case 'f': /* COPY data */; break;
        ...
    }
}
```

ハンドシェイク:

1. クライアントが `StartupMessage` (プロトコル番号 196608 = 3.0)
2. サーバが `AuthenticationXxx` を送る、必要なら認証往復
3. 成功で `BackendKeyData` + 複数の `ParameterStatus` (server_version, client_encoding, ...) を送り `ReadyForQuery('I')` で待機
4. 以降はメッセージループ

エラー時は **ErrorResponse 'E'** を送り、現在のトランザクションを失敗状態に遷移。次の `Sync` まで以降のメッセージを「無視（skip）」する仕様（Extended Query における Sync の役割）。

### Pure Go インメモリ実装への示唆

- 既存の **psql-wire / pgproto3 を流用**し、自前実装は最小限に留めるのが圧倒的に効率的（[deep-dive-psql-wire.md](deep-dive-psql-wire.md) 参照）。
- インプロセス (in-process) 用途では **`net.Pipe()`** か **カスタム `net.Listener`** を使い、TCP すら経由せず goroutine 間 io.Pipe で完結させられる。これによりレイテンシをマイクロ秒単位に短縮可能。
- Phase 1 で実装すべきメッセージは: `StartupMessage, AuthenticationOk, ParameterStatus, BackendKeyData, ReadyForQuery, Query, RowDescription, DataRow, CommandComplete, ErrorResponse, Terminate` の 11 種で **Simple Query は完結**する。Extended Query (`Parse/Bind/Execute/Describe/Close/Sync`) は Phase 2。
- 認証は **trust 固定**で十分。SSL は Phase 3 以降（または無期限に省略）。
- Sync の skip セマンティクスは **必ず実装**しないと pgx の prepared statement やトランザクションエラーで挙動が壊れる。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/tcop/postgres.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/libpq/pqcomm.c>
- <https://www.postgresql.org/docs/current/protocol.html>

---

## 5. MemoryContext

### 概要

PostgreSQL は **階層化されたメモリコンテキスト**を使い、`palloc/pfree` ではなく「コンテキスト単位の一括解放 (`MemoryContextReset/Delete`)」でメモリ寿命を管理する。
これによりリーク発生確率が劇的に下がり、エラー処理時に「クエリ用コンテキストごと吹き飛ばす」というクリーンアップが可能になる。
代表的コンテキスト: `TopMemoryContext`（プロセス終了まで） → `CacheMemoryContext / TopTransactionContext / MessageContext / PortalContext / ExecutorState / ExprContext` 等が階層を成す。

### PostgreSQL 本体の実装

主要ファイル（`src/backend/utils/mmgr/`）:

| ファイル | 内容 |
|----------|------|
| `mcxt.c` | コンテキスト共通 API (`MemoryContextSwitchTo`, `palloc`, `pfree`, `MemoryContextDelete`, `repalloc`) |
| `aset.c` | AllocSet（汎用アロケータ。**最重要**） |
| `generation.c` | Generation context（FIFO 寿命に最適化、ディコーディング等） |
| `slab.c` | Slab context（固定サイズチャンク、HashJoin 等） |
| `bump.c` | Bump context（線形に詰めていくだけ。ParallelWorker 等） |
| `dsa.c` | Dynamic Shared Area（共有メモリ動的割当） |
| `portalmem.c` | Portal（カーソル）の寿命管理 |

AllocSet（`aset.c`）の構造:

- 各コンテキストに `freelist[11]`（2^3 〜 2^13 のサイズクラス）
- ブロック単位 (`AllocBlockData`) でまとめて malloc し、その中をチャンク (`AllocChunkData`) に切る
- `pfree` は `freelist` に戻すだけ（OS には返さない）
- `MemoryContextReset` は `keeper`（最初のブロック）以外を free し、`keeper` 内のチャンクは捨てる
- `MemoryContextDelete` は子コンテキストを再帰的に Delete してから自分を free

主要関数:

- `AllocSetContextCreateInternal` (`aset.c:347`) — コンテキスト生成
- `AllocSetReset` (`aset.c:546`) — 高速一括解放
- `AllocSetDelete` (`aset.c:632`) — 完全破棄
- `AllocSetAlloc` (`aset.c:1012`) — 割当
- `AllocSetFree` (`aset.c:1107`) — 解放（freelist へ）

エラー処理 (`PG_TRY/PG_CATCH`) と組み合わさり、`elog(ERROR)` が `longjmp` して `MessageContext` をリセット → 次のクエリへ、というプロセス内例外モデルが成立する。

### Pure Go インメモリ実装への示唆

- Go は GC があるため **MemoryContext を真似る必然性は低い**。素直に `make` / `new` してスコープを抜けたら GC に任せるのが Go 流。
- ただし「クエリ実行中に確保した一時メモリを高速に解放したい」「Per-statement で一括破棄したい」場合、**arena アロケータ**（`arena` パッケージは experimental だが、自前実装も難しくない）が有用。特に、ソート / ハッシュ集約のような短命大量割当ては arena 化でアロケーション数を 1〜2 桁削減できる。
- 設計上の写経ポイントは「**寿命の階層化**」という考え方。`Connection > Transaction > Statement > Expression` の階層を Go の構造体で持ち、各層で `defer cleanup()` を仕掛けることで PG の Context 階層と同等の保守性を得られる。
- エラー処理は Go では `error` 戻り値か `panic/recover` で表現。`PG_TRY` 相当を `panic` で実装するのは「特定の internal error のみ」に限定し、API 境界では必ず `error` に変換するのが Go イディオム。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/utils/mmgr/aset.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/mmgr/mcxt.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/mmgr/README>

---

## 6. プランナ／オプティマイザ

### 概要

パース＆解析後の `Query` ツリーから、コスト最小の **物理プラン** (`Plan` ツリー) を作る部分。System R 流のボトムアップ動的計画法をベースに、述語下方移動・結合順序選択・インデックス選択・GROUP BY/集約配置・ソート除去・パラレル化判断を一手に行う。
規模・難度ともに PostgreSQL ソース全体でも屈指 (`src/backend/optimizer/README` だけで 86KB)。

### PostgreSQL 本体の実装

主要ディレクトリ: `src/backend/optimizer/`

| サブディレクトリ | 役割 |
|------------------|------|
| `plan/` | 入口・全体駆動 (`planner.c`, `createplan.c`, `setrefs.c`, `subselect.c`, `initsplan.c`, `planmain.c`, `planagg.c`, `analyzejoins.c`) |
| `path/` | Path 列挙 (`allpaths.c`, `joinpath.c`, `indxpath.c`, `costsize.c`, `equivclass.c`, `pathkeys.c`) |
| `prep/` | 前処理 (`prepjointree.c`, `prepqual.c`, `preptlist.c`) |
| `util/` | ユーティリティ (`relnode.c`, `restrictinfo.c`, `tlist.c`, `var.c`) |
| `geqo/` | 遺伝的アルゴリズム（結合数が大きい時のヒューリスティック） |

中核フロー:

```
planner()                               [plan/planner.c]
 └ subquery_planner()
    ├ pull_up_subqueries()              [prep/prepjointree.c]   サブクエリのフラット化
    ├ preprocess_expression()           [prep/prepqual.c]       式の正規化
    ├ reduce_outer_joins()              [prep/prepjointree.c]   OUTER → INNER 化
    ├ remove_useless_joins()            [plan/analyzejoins.c]   不要 JOIN 除去
    ├ deconstruct_jointree()            [plan/initsplan.c]      WHERE を RestrictInfo に分解
    ├ make_one_rel()                    [path/allpaths.c]        Path 列挙のドライバ
    │   └ set_base_rel_pathlists()       テーブル単位 (Seq/Index/Bitmap/...)
    │   └ make_rel_from_joinlist()       JOIN は標準動的計画法 / GEQO
    │       └ join_search_one_level()    [path/joinrels.c]      レベル別結合
    │           └ make_join_rel() → add_paths_to_joinrel() (NestLoop/HashJoin/MergeJoin)
    ├ create_plan()                      [plan/createplan.c]    最良 Path → Plan 変換
    └ set_plan_references()              [plan/setrefs.c]       変数参照の最終解決
```

コストモデル: `costsize.c` の `cost_seqscan, cost_index, cost_nestloop, cost_hashjoin, cost_mergejoin, cost_sort, cost_agg` などが **(startup_cost, total_cost, rows, width)** を計算。GUC `seq_page_cost (=1.0), random_page_cost (=4.0), cpu_tuple_cost (=0.01), cpu_index_tuple_cost (=0.005), cpu_operator_cost (=0.0025)` がコスト係数。

統計は `pg_statistic` に格納（`ANALYZE` で収集）し、選択率推定は `selfuncs.c` が担う。

### Pure Go インメモリ実装への示唆

- 完全実装は不可能 (LOC 比で本体最大級)。**Phase 1 はルールベース最適化のみ**で割り切る:
  1. 述語下方移動 (predicate pushdown)
  2. 定数畳み込み
  3. 単純な JOIN 順序（指定順 or 行数昇順）
  4. インデックスは「等価条件があれば使う」固定ヒューリスティック
- インメモリならコストモデルの精度はほとんど問題にならない（page I/O が無いため）。ナイーブに「述語選択率 = 0.1 固定」「JOIN 結合行数 = 左右行数の積 × 0.1」程度でも実用速度になりがち。
- Phase 2 で「**JOIN 数 ≤ 8 では総当たり DP**、それ以上は Greedy」を入れると、ほぼすべての OLTP / 中規模 OLAP に対応できる。
- 参考実装として既存 Go プロダクトを真似るのが最も学習効率が高い:
  - `go-mysql-server`（rule-based + cost-based のハイブリッド、コードが平易）
  - `cockroachdb`（System R 風 DP、コスト関数が定数係数で読みやすい）

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/optimizer/README>
- <https://github.com/postgres/postgres/blob/master/src/backend/optimizer/plan/planner.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/optimizer/path/costsize.c>

---

## 7. エグゼキュータ

### 概要

プランナが作った `Plan` ツリーを **Volcano モデル** (`Init / ExecProcNode (next tuple) / End`) で実行する層。各ノードは `PlanState` ツリーとして実行時状態を持ち、親ノードが `ExecProcNode` を呼ぶたびに 1 タプルを返す pull 型。
PG 14 以降は **JIT (LLVM)** や **Just-In-Time コンパイル**された式評価（`ExecInterpExpr`）と、**Parallel Query** のための共有メモリチャネルを持つ。

### PostgreSQL 本体の実装

主要ファイル（`src/backend/executor/`）:

| ファイル | 行数目安 | 内容 |
|----------|----------|------|
| `execMain.c` | ~3268 | 入口 `ExecutorStart(124), ExecutorRun(308), ExecutorFinish(417), ExecutorEnd(477), ExecutorRewind(547)` |
| `execProcnode.c` | — | ノードタイプ→`ExecInit/Exec/End` 関数の dispatch |
| `execScan.c` | — | ScanState 共通ループ |
| `execExpr.c, execExprInterp.c` | — | 式の **EEOP 命令列**化と評価器（高速 interp） |
| `nodeSeqscan.c` | — | テーブル全件スキャン |
| `nodeIndexscan.c, nodeIndexonlyscan.c, nodeBitmapHeapscan.c` | — | インデックススキャン |
| `nodeNestloop.c, nodeHashjoin.c, nodeMergejoin.c` | — | JOIN 各種 |
| `nodeAgg.c` | — | GROUP BY / 集約 |
| `nodeSort.c, nodeUnique.c, nodeMaterial.c, nodeLimit.c` | — | 補助 |
| `nodeAppend.c, nodeMergeAppend.c` | — | パーティション統合 |
| `functions.c, spi.c` | — | SQL/PL 関数からの再帰呼び出し |

`ExecutorRun` の擬似コード:

```c
void ExecutorRun(QueryDesc *qd, ScanDirection dir, uint64 count, ...) {
    EState *est = qd->estate;
    /* メモリコンテキスト切替 / スナップショット登録 */
    MemoryContextSwitchTo(est->es_query_cxt);
    PushActiveSnapshot(est->es_snapshot);

    if (qd->operation == CMD_SELECT)
        ExecutePlan(est, qd->planstate, ..., dir, count, qd->dest);
    else  /* INSERT/UPDATE/DELETE/MERGE */
        ExecutePlan(est, qd->planstate, ..., ForwardScanDirection, count, qd->dest);

    PopActiveSnapshot();
}

static void ExecutePlan(EState *est, PlanState *ps, ..., DestReceiver *dest) {
    for (;;) {
        TupleTableSlot *slot = ExecProcNode(ps);   /* ★ ここが Volcano */
        if (TupIsNull(slot)) break;
        dest->receiveSlot(slot, dest);             /* クライアントへ送信 */
        if (++processed >= count && count > 0) break;
    }
}
```

各ノードは `ExecInitNode` で `PlanState` を作り、`ExecProcNode` 関数ポインタを設定する。例えば `SeqScanState->ss.ps.ExecProcNode = ExecSeqScan`。`ExecSeqScan` は `table_scan_getnextslot()` で TableAM 越しに 1 タプル取り、scan qual を評価して該当するものを返す。

### Pure Go インメモリ実装への示唆

- **Volcano モデルは Go の channel または interface でそのまま表現できる**:
  ```go
  type Executor interface {
      Init(ctx context.Context) error
      Next() (Row, error)   // io.EOF で終端
      Close() error
  }
  ```
- Go 流では「next 関数を返す closure」も書きやすく、`func() (Row, error)` をそのまま使う実装も見かける（例: ramsql）。
- ノード実装の必要最小セット (Phase 1):
  1. `SeqScan`（`map` か `slice` を全走査）
  2. `Filter`（WHERE 評価）
  3. `Project`（SELECT 列計算）
  4. `NestedLoopJoin`
  5. `Sort`（`sort.Slice`）
  6. `Limit`
  7. `Aggregate`（`map[key]accumulator`）
  8. `Insert / Update / Delete`
- 式評価は Phase 1 では「AST を直接 walk して `interface{}` を返す再帰 eval」で十分。Phase 2 で「式コンパイル → スタックマシン」化（PG の EEOP に相当）すると 5〜10 倍速くなる。
- 並列化 (Parallel Query) は Phase 4 以降。Go なら **`errgroup` で各 SeqScan を chunk 分割並走**させる素朴な実装で大半のワークロードに効果が出る。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/executor/execMain.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/executor/README>
- <https://github.com/postgres/postgres/blob/master/src/backend/executor/execProcnode.c>

---

## 8. ロックマネージャ

### 概要

PostgreSQL のロック層は **3 階層**で構成される:

1. **spinlock**（`s_lock.c`）— 数命令で取れる超軽量、ビジーウェイト
2. **LWLock**（`lwlock.c`）— Read/Write の共有・排他、shared memory の保護
3. **Heavyweight Lock**（`lock.c`）— SQL レベル (テーブル/タプル/アドバイザリ)、デッドロック検出を伴う

加えて **Predicate Lock** (`predicate.c`, SSI) が **Serializable Snapshot Isolation** を支える。

### PostgreSQL 本体の実装

主要ファイル（`src/backend/storage/lmgr/`）:

| ファイル | サイズ | 内容 |
|----------|--------|------|
| `lock.c` | ~149KB | Heavyweight。`LockAcquire, LockRelease, GrantLock` |
| `lwlock.c` | ~54KB | LWLock。`LWLockAcquire, LWLockRelease, LWLockConditionalAcquire` |
| `predicate.c` | ~163KB | SSI のための predicate lock |
| `lmgr.c` | — | 高レベルラッパ (`LockRelation, LockTuple`) |
| `proc.c` | — | `PGPROC` (バックエンド毎構造体) と待機キュー |
| `deadlock.c` | — | 待機グラフを巡回して循環検出 |
| `s_lock.c` | — | アーキテクチャ別 spinlock |

主要 API:

```c
LockAcquireResult LockAcquire(LOCKTAG *locktag, LOCKMODE lockmode,
                              bool sessionLock, bool dontWait);
bool LockRelease(LOCKTAG *locktag, LOCKMODE lockmode, bool sessionLock);

void LWLockAcquire(LWLock *lock, LWLockMode mode);  /* LW_SHARED or LW_EXCLUSIVE */
void LWLockRelease(LWLock *lock);
```

Heavyweight ロックは **(lockmethod, database, relation, ...)** をハッシュキーに `LockMethodLocalHash`（ローカル）と shared `LOCK / PROCLOCK` ハッシュテーブルに格納。
ロックモードは 8 種 (`AccessShareLock, RowShareLock, RowExclusiveLock, ShareUpdateExclusiveLock, ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock`) で **競合行列** (`LockConflicts[]`) で互換性が定義される。

デッドロック検出は `lock_timeout` ではなく `deadlock_timeout` (既定 1 秒) でブロックされ続けたら `DeadLockCheck` を起動し、`PGPROC` の wait-for グラフを DFS で巡回し循環があれば誰かを `ERROR: deadlock detected` で abort する。

### Pure Go インメモリ実装への示唆

- インメモリ・単一プロセスでは「shared memory 保護のための LWLock」は **`sync.RWMutex` で完全代替**できる。spinlock も同様。
- Heavyweight ロックは「**SQL 意味論を満たすための論理ロック**」なので **必須**。設計案:
  ```go
  type LockKey struct {       // (database, relation [, tuple_ctid])
      DB, Rel uint32
      Tuple   *TID            // nil ならテーブルロック
  }
  type LockManager struct {
      mu     sync.Mutex
      locks  map[LockKey]*lockEntry
  }
  type lockEntry struct {
      holders   map[txID]LockMode
      waiters   []*waiter      // chan struct{} で起床
  }
  ```
- 競合行列は PG と同じ 8 モードを Go で定数定義。実装の難所は `RowExclusiveLock` (UPDATE/DELETE) と `AccessExclusiveLock` (DROP/ALTER) の互換性。
- デッドロック検出は **タイムアウト + wait-for グラフ DFS** で写経できる。Go の `time.AfterFunc(1*time.Second, deadlockCheck)` で起動。
- Predicate Lock (SSI) は Phase 4 以降または永久に省略（Serializable は実装難度が高い。多くのアプリで Read Committed で十分）。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/storage/lmgr/README>
- <https://github.com/postgres/postgres/blob/master/src/backend/storage/lmgr/lock.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/storage/lmgr/README-SSI>

---

## 9. インデックス AM (Access Method)

### 概要

PostgreSQL は **Index Access Method API** によりインデックスの種類を抽象化している。組み込みは btree / hash / gist / spgist / gin / brin の 6 種、拡張で bloom / pg_trgm 等。
すべては `IndexAmRoutine` 構造体（関数ポインタの集合）を返す `amhandler` 関数によって SQL から `USING xxx` で選択できる。

### PostgreSQL 本体の実装

主要ファイル / 構造体:

- `src/include/access/amapi.h` — `IndexAmRoutine` 定義
- `src/backend/access/index/indexam.c` — 上位 API (`index_beginscan`, `index_getnext_tid`)
- `src/backend/access/{nbtree,hash,gist,spgist,gin,brin}/` — 各 AM の実装
- `src/include/catalog/pg_am.h, pg_am.dat` — AM の登録

`IndexAmRoutine` の主要コールバック:

| コールバック | 役割 |
|--------------|------|
| `ambuild` | 既存テーブルからインデックスを一括構築 |
| `ambuildempty` | 空インデックス作成 (UNLOGGED テーブル等) |
| `aminsert` | 1 タプル挿入 |
| `ambeginscan / amrescan` | スキャン開始・再開 |
| `amgettuple` | インデックスから次の TID を返す |
| `amgetbitmap` | Bitmap Index Scan 用 |
| `amendscan` | スキャン終了 |
| `ambulkdelete / amvacuumcleanup` | VACUUM フック |
| `amcostestimate` | プランナへコスト見積を返す |
| `amoptions` | reloption 解釈 |
| `amvalidate` | opclass 整合性検査 |
| `amcanorder, amcanunique, amcanmulticol, amcanorderbyop, amsearcharray` 等のフラグ | プランナがこの AM の能力を判定 |

例: `bthandler`（`nbtree.c`）が返す `IndexAmRoutine` は `ambuild=btbuild, aminsert=btinsert, amgettuple=btgettuple, amcostestimate=btcostestimate, amcanorder=true, amcanunique=true, ...` を設定。

`index_getnext_tid` の流れ:

```c
ItemPointer index_getnext_tid(IndexScanDesc scan, ScanDirection dir) {
    bool found = scan->indexRelation->rd_indam->amgettuple(scan, dir);
    if (!found) return NULL;
    return &scan->xs_heaptid;       /* heap TID をプランナに返す */
}
```

### Pure Go インメモリ実装への示唆

- AM 抽象化を **interface で写経**するのが拡張性 / テスト性ともに最良:
  ```go
  type IndexAM interface {
      Build(rel *Relation, tuples []Tuple) error
      Insert(tid TID, key Datum) error
      Delete(tid TID, key Datum) error
      BeginScan(quals []Qual) Scanner
  }
  type Scanner interface {
      Next() (TID, bool)
      Close() error
  }
  ```
- Phase 1 で実装すべきは **B+Tree 1 種**で十分（等価・範囲・ORDER BY をカバー）。Pure Go の代表ライブラリ:
  - `github.com/google/btree`（B-Tree、シンプル、Generics 対応版あり）
  - `github.com/tidwall/btree`（Generics、並行版あり）
  - 自前実装も 500 行程度で書ける
- Hash インデックスは Go の `map` で代用可能だが、PG 互換性の観点では「インデックス種別ごとの DDL 文 (`CREATE INDEX ... USING hash`) を受け入れて内部的には btree」とごまかすのが現実解。
- GIN / GiST / BRIN は Phase 3 以降。JSONB の `@>` 演算子に依存するアプリでは GIN が必須。
- **MVCC との接続点**: 「インデックスは TID を返すだけ → ヒープ可視性で再判定」が PG の流儀。インメモリでも同じ分離を保つと、インデックスを単純な (key → TID) の写像に保てる（インデックス自体が MVCC を意識する必要がない）。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/include/access/amapi.h>
- <https://github.com/postgres/postgres/blob/master/src/backend/access/index/indexam.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/access/nbtree/README>

---

## 10. 関数呼び出し規約 (fmgr)

### 概要

PostgreSQL のあらゆる関数（組み込み・SQL 関数・PL/pgSQL・C 拡張）は **fmgr (Function Manager)** という統一インタフェース越しに呼ばれる。引数と返り値はすべて `Datum`（事実上 `uintptr_t`）に正規化され、`PG_GETARG_XXX / PG_RETURN_XXX` マクロで型安全に取り出す。
これにより「カタログ pg_proc に登録された任意の関数」を、データ型・引数数・呼び出し元（演算子、CAST、SQL 関数本体、トリガー、インデックスのサポート関数）から統一的に呼び出せる。

### PostgreSQL 本体の実装

主要ファイル:

- `src/include/fmgr.h` — `FunctionCallInfoBaseData`, `FmgrInfo`, マクロ群
- `src/backend/utils/fmgr/fmgr.c` — `fmgr_info, FunctionCallInvoke, OidFunctionCallN`
- `src/include/utils/fmgrtab.h` — 組み込み関数テーブル（自動生成）

主要構造体:

```c
typedef struct FmgrInfo {
    PGFunction  fn_addr;        /* 関数ポインタ */
    Oid         fn_oid;
    short       fn_nargs;
    bool        fn_strict;      /* true なら引数 NULL で結果 NULL */
    bool        fn_retset;      /* SRF (set returning function) */
    /* ... */
} FmgrInfo;

typedef struct FunctionCallInfoBaseData {
    FmgrInfo   *flinfo;
    fmNodePtr   context;
    fmNodePtr   resultinfo;
    Oid         fncollation;
    bool        isnull;
    short       nargs;
    NullableDatum args[FLEXIBLE_ARRAY_MEMBER];
} FunctionCallInfoBaseData, *FunctionCallInfo;
```

呼び出し:

```c
LOCAL_FCINFO(fcinfo, 2);
InitFunctionCallInfoData(*fcinfo, &flinfo, 2, InvalidOid, NULL, NULL);
fcinfo->args[0].value = Int32GetDatum(10); fcinfo->args[0].isnull = false;
fcinfo->args[1].value = Int32GetDatum(20); fcinfo->args[1].isnull = false;
Datum result = FunctionCallInvoke(fcinfo);
```

`FunctionCallInvoke` はマクロで `(*fcinfo->flinfo->fn_addr)(fcinfo)` と展開され、`PG_FUNCTION_ARGS` シグネチャの C 関数を呼ぶ。

V1 規約 (`PG_FUNCTION_INFO_V1`): C 関数は `Datum funcname(PG_FUNCTION_ARGS)` を持ち、内部で `PG_GETARG_XXX(0/1/...)` し `PG_RETURN_XXX(...)` する。
SRF (集合返却関数) は `SRF_FIRSTCALL_INIT, SRF_PERCALL_SETUP, SRF_RETURN_NEXT, SRF_RETURN_DONE` で 1 行ずつ返すマクロ群を使う。

### Pure Go インメモリ実装への示唆

- C の `PG_FUNCTION_ARGS` 流の重い抽象を真似る必要は **ない**。Go なら `interface{}` (`any`) スライス＋戻り値で十分:
  ```go
  type PgFunc func(args []Datum) (Datum, error)
  type FuncEntry struct {
      OID         uint32
      Name        string
      ArgTypes    []uint32
      RetType     uint32
      Strict      bool
      ReturnsSet  bool
      Fn          PgFunc
  }
  ```
- 組み込み関数の登録は init() で `Register(funcEntry{...})` するだけ。型ごとの値変換は Phase 1 では `switch t := v.(type)` で済ませ、Phase 2 で型 ID ベースのテーブル駆動に拡張。
- SRF は **Go の channel か iterator pattern**（`func() (Datum, bool)`）で素直に表現できる。
- 演算子 (`+, -, =, <` 等) もすべて関数呼び出しに帰着させる PG の流儀は **Pure Go でも踏襲する価値が高い**: パーサ/プランナを単純化でき、ユーザ定義演算子の追加コストが下がる。
- C 拡張 (`.so` ロード) は Pure Go では原則サポートしない方針が現実的。代替として **Go の plugin パッケージ**は使えるが、クロスプラットフォーム面で苦しい。`go-plugin` (HashiCorp) や WASM の方が現代的。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/include/fmgr.h>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/fmgr/fmgr.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/fmgr/README>

---

## 11. エラーハンドリングと ereport

### 概要

PostgreSQL は **`ereport(level, errcode(...), errmsg(...), errdetail(...), errhint(...), ...)`** という可変引数マクロでエラーを起こす。
レベルは `DEBUG5..DEBUG1, LOG, INFO, NOTICE, WARNING, ERROR, FATAL, PANIC` で、`ERROR` 以上は内部的に `siglongjmp` でトランザクションを巻き戻し、`MemoryContext` を適切な階層までリセットする。
SQLSTATE (5 桁、英数字) によりクライアントは機械可読なエラー識別ができる（例: `23505` = unique_violation, `42P01` = undefined_table）。

### PostgreSQL 本体の実装

主要ファイル:

- `src/backend/utils/error/elog.c` — エラー生成・配信本体
- `src/include/utils/elog.h` — `ereport, errcode, errmsg, ...` マクロ
- `src/backend/utils/error/assert.c` — Assert 系
- `src/include/utils/errcodes.h` — SQLSTATE 定数（`generate_errcodes.pl` で `errcodes.txt` から生成）

擬似コード:

```c
#define ereport(elevel, ...) \
    do { if (errstart(elevel, TEXTDOMAIN)) { \
            __VA_ARGS__; errfinish(__FILE__, __LINE__, __func__); \
        } } while(0)

bool errstart(int elevel, const char *domain) {
    /* ErrorData スタックに push、メモリコンテキスト切替 */
    ...
    return shouldEmit;
}

void errfinish(const char *filename, int lineno, const char *funcname) {
    EmitErrorReport();             /* ログ書込 + クライアント送信 */
    if (elevel >= ERROR) {
        /* siglongjmp(*PG_exception_stack, 1); */
        sigsetjmp 経由で PG_TRY ブロックへ巻き戻し
    }
}
```

呼び出し例:

```c
ereport(ERROR,
        errcode(ERRCODE_UNIQUE_VIOLATION),
        errmsg("duplicate key value violates unique constraint \"%s\"", conname),
        errdetail("Key (%s)=(%s) already exists.", keys, values),
        errtableconstraint(rel, conname));
```

`PG_TRY() { ... } PG_CATCH() { ... } PG_END_TRY()` ブロックは `sigsetjmp` でリカバリポイントを登録し、`ERROR` 発生時にそこへ巻き戻す。`MessageContext` のリセットでクエリ中に確保された全メモリが一掃される。
クライアントへは Wire Protocol 上の **ErrorResponse 'E'** メッセージ（フィールド `S=Severity, C=SQLSTATE, M=Message, D=Detail, H=Hint, P=Position, F=File, L=Line, R=Routine, ...`）として送られる。

### Pure Go インメモリ実装への示唆

- Go では **`error` 戻り値**で表現するのが本道。SQLSTATE と message を持つカスタム型を導入:
  ```go
  type PgError struct {
      Severity string   // "ERROR" 等
      Code     string   // SQLSTATE "23505"
      Message  string
      Detail   string
      Hint     string
      Position int
      // 元の error をラップ
      Wrapped error
  }
  func (e *PgError) Error() string { return e.Message }
  func (e *PgError) Unwrap() error { return e.Wrapped }
  ```
- Wire 層では PgError を ErrorResponse メッセージへシリアライズするだけ。`pgproto3.ErrorResponse` をそのまま使える。
- `PG_TRY/CATCH` 相当は **`recover()` を限定的に**使うか、すべて `error` 返り値で書ききる。後者の方が Go 流で読みやすいが、deeply nested な計算では panic/recover の方が記述量が減る。**API 境界で必ず `error` に変換**するルールを徹底すれば併用できる。
- SQLSTATE 一覧は **PG の `errcodes.txt` を Go の定数ファイルに自動生成**するスクリプトを用意するのが現実的（手書きすると 200+ 個の定数になる）。
- メモリコンテキストの「エラー時一括解放」相当は Go の GC が代行するのでコード上の負担は無い。逆に「クエリ中の途中状態を確実にクリーンアップ」するため `defer` を多用する設計を心がける。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/utils/error/elog.c>
- <https://github.com/postgres/postgres/blob/master/src/include/utils/elog.h>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/errcodes.txt>

---

## 12. Extended Query Protocol (Parse/Bind/Execute)

### 概要

Simple Query (`'Q'`) は 1 メッセージで「パース→計画→実行→結果送信→ReadyForQuery」までを一気にやる方式だが、
**Extended Query** は **Parse / Bind / Describe / Execute / Close / Sync** のメッセージ列で、
- **Prepared Statement (再利用可能なパース＆計画結果)**
- **パラメータ付き実行**（SQL インジェクション完全防御）
- **バイナリフォーマット送受信**
- **複数 Execute の Pipelining**
を可能にする。pgx / JDBC / psycopg3 など現代のドライバはほぼすべてこちらを使う。

### PostgreSQL 本体の実装

主要ファイル:

- `src/backend/tcop/postgres.c` — `exec_parse_message`, `exec_bind_message`, `exec_execute_message`, `exec_describe_statement_message`, `exec_describe_portal_message`
- `src/backend/utils/cache/plancache.c` — `CachedPlanSource` 周り（プラン再利用）
- `src/backend/commands/portalcmds.c, src/backend/utils/mmgr/portalmem.c` — Portal (実行ハンドル) のライフサイクル

メッセージ列の典型:

```
C: Parse(name="stmt1", query="SELECT * FROM t WHERE id = $1", paramTypes=[INT4])
C: Bind(portal="", stmt="stmt1", paramFormats=[1], paramValues=[bytes(42)], resultFormats=[1])
C: Describe('P', "")             ← Portal を describe
C: Execute("", maxRows=0)
C: Sync
S: ParseComplete
S: BindComplete
S: RowDescription [...]
S: DataRow [...]
...
S: CommandComplete "SELECT 1"
S: ReadyForQuery 'I'
```

`exec_parse_message` は raw SQL をパースし、`CachedPlanSource` を作成 → 名前付き prepared statement に登録。
`exec_bind_message` は Plan を必要なら生成（`GetCachedPlan`）し、`Portal` を作成・パラメータをセット。
`exec_execute_message` は `PortalRun` → `ExecutorRun` を呼び、`maxRows` まで結果を返す。途中で打ち切られた場合は `PortalSuspended` 'S' を返し、次の `Execute` で続きを返す（カーソル動作）。
`Sync` で **トランザクション境界をクライアントに公開**し、`ReadyForQuery` を返す。エラーが起きると、次の `Sync` までのメッセージを **スキップ**するセマンティクスにより、ドライバが安全にエラー回復できる。

`CachedPlan` は **Generic Plan vs Custom Plan** を `choose_custom_plan` (`plancache.c`) が判定し、5 回程度実行してコスト比較→以降は generic 化、というヒューリスティックで切り替わる。これが「prepared statement の N 回目以降が速くなる」理由。

### Pure Go インメモリ実装への示唆

- **Phase 2 必須機能**。pgx を使ったアプリは prepared statement なしには動かない。
- 設計:
  ```go
  type Server struct {
      stmts   map[string]*PreparedStmt   // セッション毎
      portals map[string]*Portal
  }
  type PreparedStmt struct {
      SQL          string
      Parsed       *AST
      ParamTypes   []OID
      Plan         *PhysicalPlan         // lazy or eager
  }
  type Portal struct {
      Stmt        *PreparedStmt
      ParamValues []Datum
      Cursor      Executor                // resumable
      ResultFmts  []FormatCode
      Done        bool
  }
  ```
- **Sync スキップ**は必ず実装する。実装ミスで pgx の transaction batch がフリーズする事故が起きやすい。状態フラグ `inFailedTx bool` を持ち、Sync 受信まで他メッセージを無視。
- **バイナリフォーマット**は型ごとに encode/decode を実装。pgx 互換のバイナリ表現を厳守 (int は big-endian、numeric は専用形式、timestamp は post-2000 マイクロ秒、uuid は 16 バイトそのまま、jsonb は先頭 1 バイトのバージョン `\x01` + JSON テキスト)。
- **Describe** は statement 用 (`'S'`) と portal 用 (`'P'`) の 2 種。前者は `ParameterDescription` + `RowDescription`、後者は `RowDescription` のみ（または `NoData`）を返す。
- maxRows 0 = 無制限。Portal を介した cursor 動作は最初は最小限実装でも実害は少ないが、`SELECT ... LIMIT` を多用するアプリには無視できない。

### 参考リンク

- <https://github.com/postgres/postgres/blob/master/src/backend/tcop/postgres.c>
- <https://github.com/postgres/postgres/blob/master/src/backend/utils/cache/plancache.c>
- <https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-EXT-QUERY>

---

## まとめ

| トピック | 主要 PG ファイル | Phase 1 で必須? |
|----------|------------------|----------------|
| 1. MVCC 可視性 | `heapam_visibility.c`, `snapmgr.c` | ◎ |
| 2. システムカタログ | `catalog/heap.c`, `pg_class.h` 他 | ◎（最小カタログ） |
| 3. 型システム | `pg_type.h/.dat`, `utils/adt/*` | ◎（16 型） |
| 4. ワイヤープロトコル | `pqcomm.c`, `postgres.c` | ◎（Simple Query） |
| 5. MemoryContext | `mmgr/aset.c, mcxt.c` | △（GC で代替） |
| 6. プランナ | `optimizer/plan/planner.c` 他 | △（ルールベースのみ） |
| 7. エグゼキュータ | `executor/execMain.c` 他 | ◎（Volcano） |
| 8. ロック | `lmgr/lock.c, lwlock.c` | ○（テーブル/行ロック） |
| 9. インデックス AM | `access/amapi.h`, `nbtree/*` | ○（B+Tree のみ） |
| 10. fmgr | `fmgr/fmgr.c` | ◎（Go interface 化） |
| 11. ereport | `error/elog.c` | ◎（PgError 型） |
| 12. Extended Query | `postgres.c`, `plancache.c` | △→◎ Phase 2 で必須 |

Pure Go インメモリ実装の現実的なロードマップとしては、

- **Phase 1 (PoC)**: 4 + 7 + 3 + 2(最小) + 11 + 10 で「`psql` から SELECT/INSERT が通る」
- **Phase 2 (実用)**: 1 + 12 + 8 + 9 を加えて「pgx + アプリで OLTP が動く」
- **Phase 3 (拡張)**: 6 をルールベース→簡易コストベースに昇格、5 を arena 化、9 を hash/gin 拡張
- **Phase 4 (本格)**: 並列実行、SSI、論理レプリケーション

という順序が、PG 本体の依存構造とも整合する。

> 各トピックの主要ファイル行番号は執筆時点 (master 最新コミット 20efbdffeb6418afa13d6c8457054735d11c7e3a 周辺) のもの。リンク先の行番号は変動するため `grep` で関数名から再特定することを推奨する。

---

[← README に戻る](../README.md)
