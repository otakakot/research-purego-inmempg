# PostgreSQL ソースコード概要

本ドキュメントは、Pure Go によるインメモリ PostgreSQL 実装の研究プロジェクトにおいて、PostgreSQL 本体のソースコード構造を調査・整理したものである。

- **ソースリポジトリ**: https://github.com/postgres/postgres (master ブランチ = 19devel)
- **バージョン**: PostgreSQL 19devel (開発版, Copyright 2026)

---

## ソースコード構成

### トップレベル構造

主要なトップレベルファイル・ディレクトリ:

| パス | 説明 |
|------|------|
| `src/` | ソースコード本体 |
| `contrib/` | 拡張モジュール (62個) |
| `doc/` | ドキュメント |
| `config/` | ビルド設定 |
| `configure` / `configure.ac` | Autoconf 設定 |
| `meson.build` | Meson ビルド定義 |

### `src/` サブディレクトリ

| ディレクトリ | 説明 |
|-------------|------|
| `src/backend/` | バックエンドサーバー (メインコード) |
| `src/include/` | ヘッダファイル |
| `src/bin/` | コマンドラインツール |
| `src/interfaces/` | クライアントインターフェース |
| `src/pl/` | 手続き言語 |
| `src/test/` | テストスイート |
| `src/common/` | フロントエンド/バックエンド共有コード |
| `src/port/` | プラットフォーム固有コード |
| `src/fe_utils/` | フロントエンドユーティリティ |
| `src/timezone/` | タイムゾーンライブラリ |
| `src/tools/` | 開発ツール |

#### `src/bin/` — コマンドラインツール

initdb, pg_dump, psql, pgbench, pg_ctl, pg_basebackup, pg_upgrade, pg_resetwal, pg_checksums, pg_rewind, pg_waldump, pg_config, pg_controldata, pg_archivecleanup, pg_amcheck, pg_combinebackup, pg_verifybackup, pg_test_fsync, pg_test_timing, pg_walsummary, scripts, pgevent

#### `src/interfaces/` — クライアントインターフェース

- **libpq** — C クライアントライブラリ
- **libpq-oauth** — OAuth 認証ライブラリ
- **ecpg** — 組み込み SQL プリプロセッサ

#### `src/pl/` — 手続き言語

- **plpgsql** — PL/pgSQL
- **plperl** — PL/Perl
- **plpython** — PL/Python
- **tcl** — PL/Tcl

#### `src/test/` — テストスイート

regress, isolation, authentication, locale, mb, modules, perl, recovery, subscription, ssl, kerberos, ldap, icu, postmaster, examples

---

## バックエンド (`src/backend/`) の構造

- **総行数**: 約 417,688 行
- **サブディレクトリ数**: 32

### 1. `parser/` — SQL 解析・意味解析 (21 ファイル)

SQL 文字列を内部表現 (パースツリー) に変換する。構文解析と意味解析の2段階で処理される。

| ファイル | 説明 |
|---------|------|
| `parser.c` | パーサーエントリポイント |
| `gram.y` | YACC グラマー定義 (**20,059 行**) |
| `scan.l` | レキサー定義 (1,421 行) |
| `analyze.c` | 意味解析 |
| `parse_clause.c` | 句 (FROM, WHERE 等) の解析 |
| `parse_expr.c` | 式の解析 |
| `parse_func.c` | 関数呼び出しの解析 |
| `parse_relation.c` | リレーション参照の解析 |
| `parse_utilcmd.c` | ユーティリティコマンドの解析 |
| `parse_agg.c` | 集約関数の解析 |
| `parse_cte.c` | CTE (WITH 句) の解析 |
| `parse_coerce.c` | 型変換の解析 |
| `parse_collate.c` | 照合順序の解析 |
| `parse_oper.c` | 演算子の解析 |
| `parse_type.c` | 型の解析 |

### 2. `executor/` — クエリ実行エンジン (65 ファイル)

オプティマイザが生成したプランツリーを実行し、結果タプルを返す。ノード単位のイテレータモデルを採用。

**コアファイル:**

| ファイル | 説明 |
|---------|------|
| `execMain.c` | エグゼキュータメイン |
| `execExpr.c` | 式評価 |
| `execExprInterp.c` | 式インタプリタ |
| `execProcnode.c` | プランノードディスパッチ |
| `execUtils.c` | ユーティリティ |
| `execTuples.c` | タプルスロット管理 |

**スキャンノード:**

| ファイル | 説明 |
|---------|------|
| `nodeSeqscan.c` | シーケンシャルスキャン |
| `nodeIndexscan.c` | インデックススキャン |
| `nodeIndexonlyscan.c` | インデックスオンリースキャン |
| `nodeBitmapIndexscan.c` | ビットマップインデックススキャン |
| `nodeBitmapHeapscan.c` | ビットマップヒープスキャン |
| `nodeTidscan.c` | TID スキャン |

**ジョインノード:**

| ファイル | 説明 |
|---------|------|
| `nodeNestloop.c` | ネステッドループ結合 |
| `nodeHashjoin.c` | ハッシュ結合 |
| `nodeMergejoin.c` | マージ結合 |
| `nodeHash.c` | ハッシュテーブル構築 |

**その他の実行ノード:**

| ファイル | 説明 |
|---------|------|
| `nodeSort.c` | ソート |
| `nodeLimit.c` | LIMIT/OFFSET |
| `nodeAppend.c` | UNION ALL / パーティション |
| `nodeSubplan.c` | サブプラン |
| `nodeAgg.c` | 集約 |
| `nodeWindowAgg.c` | ウィンドウ関数 |
| `nodeModifyTable.c` | INSERT/UPDATE/DELETE |
| `nodeCtescan.c` | CTE スキャン |
| `nodeGroup.c` | グルーピング |
| `nodeSetOp.c` | 集合演算 (INTERSECT, EXCEPT) |
| `nodeResult.c` | 定数式結果 |
| `nodeFunctionscan.c` | 関数スキャン |

**パラレルクエリ:**

| ファイル | 説明 |
|---------|------|
| `execParallel.c` | パラレル実行基盤 |
| `nodeGather.c` | Gather ノード |
| `nodeGatherMerge.c` | Gather Merge ノード |

**その他:** `execPartition.c`, `execIndexing.c`, `spi.c`, `functions.c`

### 3. `optimizer/` — クエリプランナ・コスト解析

SQL のパースツリーから最適な物理実行プランを生成する。コストベースのオプティマイザを採用。

#### `path/` — パス生成・コスト計算

| ファイル | 説明 |
|---------|------|
| `allpaths.c` | 全パス列挙のエントリポイント |
| `costsize.c` | コスト・行数推定 (**225KB — 最大ファイル**) |
| `joinpath.c` | 結合パスの生成 |
| `joinrels.c` | 結合リレーションの列挙 |
| `indxpath.c` | インデックスパスの生成 |
| `equivclass.c` | 等価クラス管理 |
| `pathkeys.c` | ソート順管理 |
| `clausesel.c` | 句の選択率推定 |

#### `plan/` — プラン作成

パスからプランツリーへの変換を行う。

#### `prep/` — 前処理

| ファイル | 説明 |
|---------|------|
| `prepunion.c` | UNION クエリの前処理 |
| `prepjointree.c` | 結合ツリーの前処理 |

#### `util/` — ユーティリティ

オプティマイザ内部で使用する各種ユーティリティ関数。

#### `geqo/` — 遺伝的クエリオプティマイザ

多数のテーブルが JOIN される場合 (デフォルト12テーブル以上)、全組み合わせの探索が不可能になるため、遺伝的アルゴリズムで準最適な結合順序を求める。

### 4. `catalog/` — システムカタログ管理 (34 ファイル)

PostgreSQL のメタデータ (テーブル、カラム、型、インデックス等) を管理するシステムカタログの操作を担当。

| ファイル | 説明 |
|---------|------|
| `heap.c` | テーブル (ヒープ) カタログ操作 |
| `namespace.c` | スキーマ名前空間管理 |
| `index.c` | インデックスカタログ操作 |
| `objectaddress.c` | オブジェクトアドレッシング |
| `aclchk.c` | アクセス制御チェック |
| `dependency.c` | オブジェクト依存関係管理 |
| `pg_constraint.c` | 制約管理 |
| `pg_aggregate.c` | 集約関数定義 |
| `pg_enum.c` | 列挙型定義 |
| `pg_depend.c` | 依存関係カタログ |

### 5. `storage/` — バッファ管理・メモリ・ロック・ページ

データの物理格納とメモリ管理を担当。Pure Go 実装で最も置き換えが必要な領域。

#### `buffer/` — バッファマネージャ

| ファイル | 説明 |
|---------|------|
| `bufmgr.c` | 共有バッファ管理 |
| `freelist.c` | バッファ置換戦略 (Clock Sweep) |
| `localbuf.c` | ローカルバッファ (一時テーブル用) |

#### `lmgr/` — ロックマネージャ

| ファイル | 説明 |
|---------|------|
| `lock.c` | ヘビーウェイトロック |
| `deadlock.c` | デッドロック検出 |
| `lwlock.c` | ライトウェイトロック |

#### その他サブディレクトリ

| ディレクトリ | 説明 |
|-------------|------|
| `page/` | ページレイアウト (`bufpage.c`) |
| `smgr/` | ストレージマネージャ (`smgr.c`) |
| `ipc/` | プロセス間通信 (`shmem.c`, `ipci.c`, `shm_mq.c`, `pmsignal.c`) |
| `freespace/` | 空き領域マップ |
| `aio/` | 非同期 I/O |
| `file/` | ファイル管理 |
| `sync/` | 同期処理 |

### 6. `access/` — 物理データアクセス (122 ファイル)

テーブルとインデックスへの物理的なアクセスメソッドを実装する。

#### `heap/` — ヒープアクセス (10 ファイル)

| ファイル | 説明 |
|---------|------|
| `heapam.c` | ヒープアクセスメソッド本体 |
| `heapam_handler.c` | テーブル AM ハンドラ |
| `hio.c` | ヒープ I/O |
| `pruning.c` | ヒープページプルーニング |
| `vacuum.c` | VACUUM 処理 |

#### インデックスアクセスメソッド

| ディレクトリ | ファイル数 | 説明 |
|-------------|-----------|------|
| `nbtree/` | 13 | B-Tree インデックス実装 |
| `hash/` | 10 | ハッシュインデックス |
| `gin/` | 15 | GIN (全文検索、配列、JSON 対応) |
| `gist/` | 11 | GiST (空間インデックス等) |
| `spgist/` | 11 | SP-GiST (空間分割 GiST) |
| `brin/` | 10 | BRIN (ブロック範囲インデックス) |

#### `common/` — 共通アクセスメソッド (17 ファイル)

| ファイル | 説明 |
|---------|------|
| `amapi.c` | アクセスメソッド API |
| `indexam.c` | インデックスアクセスメソッド共通処理 |

#### `transam/` — トランザクション管理 (25 ファイル)

PostgreSQL の MVCC (多版型同時実行制御) とトランザクション管理の中核。

| ファイル | 説明 |
|---------|------|
| `xact.c` | トランザクション制御 (**189KB**) |
| `xlog.c` | WAL (先行書き込みログ) (**315KB — バックエンド最大ファイル**) |
| `xlogrecovery.c` | WAL リカバリ |
| `multixact.c` | マルチトランザクション ID |
| `clog.c` | コミットログ |
| `slru.c` | Simple LRU バッファ |
| `twophase.c` | 2 フェーズコミット |
| `commit_ts.c` | コミットタイムスタンプ |
| `subtrans.c` | サブトランザクション |

### 7. `commands/` — DDL/DML 実装 (54 ファイル)

CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE INDEX などの DDL コマンドと、COPY, VACUUM, EXPLAIN 等のユーティリティコマンドを実装する。

### 8. `tcop/` — トップレベルコマンド処理 (7 ファイル)

クライアントからの SQL 文を受け取り、パース → 書き換え → プランニング → 実行の一連の流れを制御する。

| ファイル | 説明 |
|---------|------|
| `postgres.c` | メインクエリ処理ループ (**5,273 行**) |
| `pquery.c` | プラン付きクエリ実行 |
| `utility.c` | ユーティリティコマンドディスパッチ |
| `backend_startup.c` | バックエンド起動処理 |
| `fastpath.c` | ファストパスインターフェース |
| `dest.c` | 出力先管理 |
| `cmdtag.c` | コマンドタグ定義 |

### 9. `postmaster/` — プロセス管理 (15 ファイル)

PostgreSQL のマルチプロセスアーキテクチャを管理する。

| ファイル | 説明 |
|---------|------|
| `postmaster.c` | マスタープロセス |
| `autovacuum.c` | 自動 VACUUM |
| `checkpointer.c` | チェックポインタ |
| `bgwriter.c` | バックグラウンドライタ |
| `walwriter.c` | WAL ライタ |
| `bgworker.c` | バックグラウンドワーカー |

### 10. `libpq/` — ワイヤープロトコル・クライアント接続 (17 ファイル)

クライアントとの通信プロトコル (PostgreSQL ワイヤープロトコル) を処理する。

| ファイル | 説明 |
|---------|------|
| `pqcomm.c` | 通信基盤 (**2,088 行**) |
| `auth.c` | 認証処理 |
| `auth-scram.c` | SCRAM 認証 |
| `hba.c` | pg_hba.conf 処理 |
| `pqformat.c` | メッセージフォーマット |
| `be-secure.c` | SSL/TLS 処理 |

### 11. `nodes/` — パースツリーノード構造 (16 ファイル)

パースツリー、プランツリー、実行状態ノードのコピー・比較・出力・読み込み等の汎用操作を実装する。

### 12. `rewrite/` — クエリ書き換え (7 ファイル)

ビュー展開やルールシステムによるクエリの書き換えを行う。パース後・プランニング前に実行される。

### 13. `utils/` — ユーティリティ関数・データ型

#### `adt/` — 抽象データ型 (119 ファイル)

PostgreSQL がサポートする全データ型の実装。

| ファイル | 説明 |
|---------|------|
| `json.c` | JSON 型 |
| `jsonb.c` | JSONB 型 |
| `array.c` / `arrayfuncs.c` | 配列型 |
| `varlena.c` | 可変長データ (text, bytea) |
| `numeric.c` | 任意精度数値 |
| `int.c` / `int8.c` | 整数型 |
| `float.c` | 浮動小数点型 |
| `date.c` / `timestamp.c` | 日付・時刻型 |
| `bool.c` | 論理型 |
| `uuid.c` | UUID 型 |
| `xml.c` | XML 型 |

#### その他サブディレクトリ

| ディレクトリ | ファイル数 | 説明 |
|-------------|-----------|------|
| `cache/` | 15 | リレーションキャッシュ (`relcache.c`), システムキャッシュ (`syscache.c`, `catcache.c`) |
| `fmgr/` | 3 | 関数マネージャ |
| `mmgr/` | 10 | メモリマネージャ (`aset.c` — メモリコンテキストの主実装) |
| `sort/` | 7 | ソート (`tuplesort.c`) |
| `misc/` | — | 各種ユーティリティ |
| `mb/` | — | マルチバイト文字エンコーディング |
| `activity/` | — | バックエンドアクティビティ追跡 |
| `error/` | — | エラーハンドリング |
| `init/` | — | バックエンド初期化 |
| `hash/` | — | ハッシュユーティリティ |
| `time/` | — | 時刻ユーティリティ |
| `resowner/` | — | リソースオーナー管理 |

### 14. その他のバックエンドディレクトリ

| ディレクトリ | ファイル数 | 説明 |
|-------------|-----------|------|
| `partitioning/` | 3 | テーブルパーティショニング |
| `statistics/` | 8 | 拡張統計情報 |
| `replication/` | 6 | レプリケーション |
| `foreign/` | 1 | 外部データラッパー基盤 |
| `jit/` | 1 | JIT コンパイル |
| `regex/` | 13 | 正規表現エンジン |
| `tsearch/` | 15 | 全文検索 |
| `bootstrap/` | 1 | ブートストラップ処理 |
| `backup/` | 14 | バックアップ |
| `snowball/` | 1 | Snowball ステマー |

---

## ヘッダファイル (`src/include/`) の構造

- **サブディレクトリ数**: 33

### 主要ヘッダファイル

| ファイル | サイズ/行数 | 説明 |
|---------|-----------|------|
| `postgres.h` | — | メインバックエンドインクルード (Datum 定義等) |
| `c.h` | 48KB | 基本 C 型・マクロ定義 |
| `fmgr.h` | 37KB | 関数マネージャインターフェース |

### ノード定義ヘッダ

| ファイル | 行数 | 説明 |
|---------|------|------|
| `nodes/parsenodes.h` | 4,433 行 | パースツリー構造定義 |
| `nodes/pathnodes.h` | 3,831 行 | オプティマイザパス構造 |
| `nodes/execnodes.h` | 2,799 行 | エグゼキュータ状態ノード |
| `nodes/primnodes.h` | 2,394 行 | プリミティブ式ノード |
| `nodes/plannodes.h` | 1,874 行 | 物理プランツリー |

### サブディレクトリ別ヘッダ

| ディレクトリ | ファイル数 | 主要ヘッダ |
|-------------|-----------|-----------|
| `catalog/` | 113 | `pg_class.h`, `pg_attribute.h`, `pg_type.h`, `pg_proc.h` 等 |
| `storage/` | 68 | `bufmgr.h`, `lock.h`, `lwlock.h`, `proc.h`, `bufpage.h` 等 |
| `access/` | 96 | `heapam.h`, `nbtree.h`, `amapi.h` 等 |
| `executor/` | 63 | `executor.h`, `execExpr.h` 等 |
| `utils/` | 101 | `rel.h`, `array.h`, `jsonb.h`, `datetime.h`, `elog.h`, `guc.h`, `memutils.h` 等 |

---

## `contrib/` 拡張モジュール (62 個)

### インデックス関連

| モジュール | 説明 |
|-----------|------|
| `bloom` | Bloom フィルタインデックス |
| `btree_gin` | B-Tree 演算子の GIN サポート |
| `btree_gist` | B-Tree 演算子の GiST サポート |

### テキスト検索

| モジュール | 説明 |
|-----------|------|
| `pg_trgm` | トライグラム類似度検索 |
| `fuzzystrmatch` | 曖昧文字列マッチング (Levenshtein, Soundex 等) |
| `unaccent` | アクセント除去テキスト検索辞書 |
| `dict_int` | 整数テキスト検索辞書 |
| `dict_xsyn` | 拡張同義語辞書 |

### データ型

| モジュール | 説明 |
|-----------|------|
| `citext` | 大文字小文字無視テキスト型 |
| `cube` | 多次元キューブ型 |
| `hstore` | キー/値ストア型 |
| `isn` | ISBN/ISSN/EAN 等の国際標準番号型 |
| `ltree` | 階層ラベルツリー型 |
| `seg` | 浮動小数点区間型 |

### セキュリティ

| モジュール | 説明 |
|-----------|------|
| `pgcrypto` | 暗号化関数 |
| `passwordcheck` | パスワード強度チェック |
| `sepgsql` | SELinux ベースアクセス制御 |
| `auth_delay` | 認証失敗時遅延 |
| `sslinfo` | SSL 証明書情報取得 |

### UUID

| モジュール | 説明 |
|-----------|------|
| `uuid-ossp` | UUID 生成関数 |

### 統計・監視

| モジュール | 説明 |
|-----------|------|
| `pg_stat_statements` | SQL 文実行統計 |
| `pgstattuple` | タプルレベル統計 |
| `pgrowlocks` | 行ロック情報 |
| `pg_buffercache` | 共有バッファキャッシュ情報 |
| `pg_freespacemap` | 空き領域マップ情報 |
| `pg_visibility` | 可視性マップ情報 |
| `pg_walinspect` | WAL 内容検査 |
| `pg_logicalinspect` | 論理レプリケーション検査 |
| `pg_overexplain` | 拡張 EXPLAIN 出力 |

### JSON/PL 連携

| モジュール | 説明 |
|-----------|------|
| `jsonb_plperl` | JSONB ↔ PL/Perl 変換 |
| `jsonb_plpython` | JSONB ↔ PL/Python 変換 |
| `hstore_plperl` | hstore ↔ PL/Perl 変換 |
| `hstore_plpython` | hstore ↔ PL/Python 変換 |
| `bool_plperl` | boolean ↔ PL/Perl 変換 |
| `ltree_plpython` | ltree ↔ PL/Python 変換 |

### FDW (外部データラッパー)

| モジュール | 説明 |
|-----------|------|
| `file_fdw` | ファイルベース外部テーブル |
| `postgres_fdw` | PostgreSQL リモートアクセス |
| `dblink` | リモートデータベース接続 |

### バックアップ

| モジュール | 説明 |
|-----------|------|
| `basebackup_to_shell` | シェルコマンドへのベースバックアップ |
| `basic_archive` | 基本 WAL アーカイブ |

### テーブル関数

| モジュール | 説明 |
|-----------|------|
| `tablefunc` | クロス集計 (crosstab) 等のテーブル関数 |

### サンプリング

| モジュール | 説明 |
|-----------|------|
| `tsm_system_rows` | 行数指定テーブルサンプリング |
| `tsm_system_time` | 時間指定テーブルサンプリング |

### その他

| モジュール | 説明 |
|-----------|------|
| `amcheck` | アクセスメソッド整合性チェック |
| `auto_explain` | 自動 EXPLAIN ロギング |
| `lo` | ラージオブジェクト管理 |
| `pageinspect` | ページ内容検査 |
| `pg_prewarm` | バッファキャッシュウォーミング |
| `pg_surgery` | ヒープタプル直接操作 (危険) |
| `spi` | SPI サンプル関数 |
| `tcn` | テーブル変更通知 |
| `test_decoding` | 論理デコーディングテストプラグイン |
| `intagg` | 整数集約 (レガシー) |
| `intarray` | 整数配列操作 |
| `oid2name` | OID → 名前変換 |
| `vacuumlo` | 孤立ラージオブジェクト削除 |
| `xml2` | XML 処理 (レガシー) |
| `earthdistance` | 地球上の距離計算 |
| `start-scripts` | 起動スクリプトサンプル |
