# 実装すべきPostgreSQL機能の網羅的一覧

[← README に戻る](../README.md)

---

本ドキュメントは、Go製インメモリPostgreSQLを実装する際に必要となるPostgreSQLの機能を網羅的に分類・整理したものである。PostgreSQL 17 を基準とする。

> **注記**: 本ドキュメントは PostgreSQL 19devel (2026) のソースコード調査結果を反映しています。ソースコード参照については[末尾のセクション](#postgresql-ソースコード参照)を参照してください。

> **凡例**
> - 🔴 必須（基本的なSQL操作に不可欠）
> - 🟡 重要（実用的なアプリケーション開発に必要）
> - 🟢 拡張（高度な用途で必要）
> - ⚪ 低優先（特殊用途向け）

---

## 目次

1. [SQL コマンド（DDL / DML / DCL / TCL）](#1-sql-コマンド)
2. [データ型](#2-データ型)
3. [演算子](#3-演算子)
4. [組み込み関数](#4-組み込み関数)
5. [クエリ構文・機能](#5-クエリ構文機能)
6. [インデックス](#6-インデックス)
7. [制約](#7-制約)
8. [トランザクション・同時実行制御](#8-トランザクション同時実行制御)
9. [システムカタログ・情報スキーマ](#9-システムカタログ情報スキーマ)
10. [ワイヤープロトコル](#10-ワイヤープロトコル)
11. [その他の機能](#11-その他の機能)
12. [実装優先度マトリクス](#12-実装優先度マトリクス)

---

## 1. SQL コマンド

### 1.1 データ定義言語 (DDL)

| コマンド | 優先度 | 説明 |
|---------|--------|------|
| `CREATE TABLE` | 🔴 | テーブル作成（カラム定義、制約、デフォルト値） |
| `ALTER TABLE` | 🔴 | テーブル変更（カラム追加/削除/変更、制約追加/削除） |
| `DROP TABLE` | 🔴 | テーブル削除 |
| `CREATE INDEX` | 🟡 | インデックス作成 |
| `DROP INDEX` | 🟡 | インデックス削除 |
| `CREATE SCHEMA` | 🟡 | スキーマ作成 |
| `DROP SCHEMA` | 🟡 | スキーマ削除 |
| `CREATE VIEW` | 🟡 | ビュー作成 |
| `DROP VIEW` | 🟡 | ビュー削除 |
| `CREATE SEQUENCE` | 🟡 | シーケンス作成（SERIAL/BIGSERIAL の基盤） |
| `ALTER SEQUENCE` | 🟡 | シーケンス変更 |
| `DROP SEQUENCE` | 🟡 | シーケンス削除 |
| `CREATE TYPE` | 🟢 | カスタム型作成（ENUM、複合型） |
| `DROP TYPE` | 🟢 | カスタム型削除 |
| `CREATE DOMAIN` | 🟢 | ドメイン作成 |
| `CREATE FUNCTION` | 🟢 | ユーザ定義関数 |
| `DROP FUNCTION` | 🟢 | 関数削除 |
| `CREATE TRIGGER` | 🟢 | トリガー作成 |
| `DROP TRIGGER` | 🟢 | トリガー削除 |
| `CREATE EXTENSION` | 🟢 | 拡張機能読み込み |
| `TRUNCATE` | 🟡 | テーブルデータ全削除（高速DELETE） |
| `COMMENT ON` | ⚪ | オブジェクトへのコメント付与 |
| `CREATE MATERIALIZED VIEW` | 🟢 | マテリアライズドビュー |
| `REFRESH MATERIALIZED VIEW` | 🟢 | マテリアライズドビュー更新 |
| `CREATE TEMPORARY TABLE` | 🟡 | 一時テーブル作成 |
| `CREATE TABLE ... PARTITION BY` | 🟢 | パーティションテーブル |
| `CREATE TABLE ... LIKE` | 🟡 | 既存テーブル構造のコピー |
| `CREATE TABLE ... AS` | 🟡 | SELECT結果からテーブル作成 |

### 1.2 データ操作言語 (DML)

| コマンド | 優先度 | 説明 |
|---------|--------|------|
| `SELECT` | 🔴 | データ検索（基本） |
| `INSERT` | 🔴 | データ挿入 |
| `UPDATE` | 🔴 | データ更新 |
| `DELETE` | 🔴 | データ削除 |
| `INSERT ... ON CONFLICT` | 🟡 | UPSERT（競合時の動作指定） |
| `INSERT ... RETURNING` | 🟡 | 挿入結果の返却 |
| `UPDATE ... RETURNING` | 🟡 | 更新結果の返却 |
| `DELETE ... RETURNING` | 🟡 | 削除結果の返却 |
| `MERGE` | 🟢 | SQL標準のMERGE文（PG 15+） |
| `COPY` | 🟡 | バルクデータ入出力 |
| `SELECT INTO` | 🟡 | SELECT結果からテーブル作成 |

### 1.3 トランザクション制御言語 (TCL)

| コマンド | 優先度 | 説明 |
|---------|--------|------|
| `BEGIN` / `START TRANSACTION` | 🔴 | トランザクション開始 |
| `COMMIT` | 🔴 | トランザクション確定 |
| `ROLLBACK` | 🔴 | トランザクション取消 |
| `SAVEPOINT` | 🟡 | セーブポイント作成 |
| `ROLLBACK TO SAVEPOINT` | 🟡 | セーブポイントへのロールバック |
| `RELEASE SAVEPOINT` | 🟡 | セーブポイント解放 |
| `SET TRANSACTION` | 🟡 | トランザクション特性設定 |

### 1.4 データ制御言語 (DCL)

| コマンド | 優先度 | 説明 |
|---------|--------|------|
| `GRANT` | 🟢 | 権限付与 |
| `REVOKE` | 🟢 | 権限取消 |
| `CREATE ROLE` / `CREATE USER` | 🟢 | ロール/ユーザ作成 |
| `DROP ROLE` | 🟢 | ロール削除 |
| `ALTER ROLE` | 🟢 | ロール変更 |
| `SET ROLE` | 🟢 | 現在のロール切替 |

### 1.5 その他のコマンド

| コマンド | 優先度 | 説明 |
|---------|--------|------|
| `EXPLAIN` | 🟡 | クエリ実行計画の表示 |
| `EXPLAIN ANALYZE` | 🟡 | 実行計画＋実測結果 |
| `PREPARE` / `EXECUTE` | 🟡 | プリペアドステートメント |
| `DEALLOCATE` | 🟡 | プリペアド解放 |
| `SET` | 🟡 | パラメータ設定（search_path等） |
| `SHOW` | 🟡 | パラメータ値表示 |
| `RESET` | 🟡 | パラメータリセット |
| `LISTEN` / `NOTIFY` | 🟢 | 非同期通知 |
| `LOCK` | 🟢 | テーブルロック |
| `VACUUM` | ⚪ | テーブルの保守（インメモリでは不要の可能性） |
| `ANALYZE` | 🟢 | 統計情報更新 |
| `CLUSTER` | ⚪ | テーブルの物理的再編成 |
| `REINDEX` | ⚪ | インデックス再構築 |
| `DO` | 🟢 | 匿名コードブロック実行 |

---

## 2. データ型

### 2.1 数値型

| 型 | エイリアス | 優先度 | サイズ | 説明 |
|----|----------|--------|--------|------|
| `smallint` | `int2` | 🔴 | 2 bytes | -32768 〜 32767 |
| `integer` | `int`, `int4` | 🔴 | 4 bytes | -2147483648 〜 2147483647 |
| `bigint` | `int8` | 🔴 | 8 bytes | -9223372036854775808 〜 9223372036854775807 |
| `numeric(p,s)` | `decimal` | 🟡 | 可変 | 任意精度数値 |
| `real` | `float4` | 🔴 | 4 bytes | 単精度浮動小数点 |
| `double precision` | `float8`, `float` | 🔴 | 8 bytes | 倍精度浮動小数点 |
| `smallserial` | `serial2` | 🟡 | 2 bytes | 自動増分 smallint |
| `serial` | `serial4` | 🔴 | 4 bytes | 自動増分 integer |
| `bigserial` | `serial8` | 🔴 | 8 bytes | 自動増分 bigint |
| `money` | - | ⚪ | 8 bytes | 通貨型 |

### 2.2 文字列型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `text` | 🔴 | 可変長文字列（無制限） |
| `varchar(n)` / `character varying(n)` | 🔴 | 可変長文字列（最大長指定） |
| `char(n)` / `character(n)` | 🟡 | 固定長文字列 |
| `name` | 🟡 | 内部識別子型（63バイト） |

### 2.3 バイナリ型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `bytea` | 🟡 | バイナリデータ |

### 2.4 日付・時刻型

| 型 | エイリアス | 優先度 | 説明 |
|----|----------|--------|------|
| `date` | - | 🔴 | 日付（年月日） |
| `time` | - | 🟡 | 時刻（タイムゾーンなし） |
| `time with time zone` | `timetz` | 🟡 | 時刻（タイムゾーンあり） |
| `timestamp` | - | 🔴 | タイムスタンプ（タイムゾーンなし） |
| `timestamp with time zone` | `timestamptz` | 🔴 | タイムスタンプ（タイムゾーンあり） |
| `interval` | - | 🟡 | 時間間隔 |

### 2.5 真偽値型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `boolean` | 🔴 | true/false/null |

### 2.6 JSON型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `json` | 🟡 | テキスト形式JSON |
| `jsonb` | 🟡 | バイナリ形式JSON（インデックス対応） |
| `jsonpath` | 🟢 | JSONパスクエリ |

### 2.7 UUID型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `uuid` | 🟡 | UUID (128-bit) |

### 2.8 配列型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `anytype[]` | 🟡 | 任意の型の配列（`integer[]`, `text[]` 等） |

### 2.9 ネットワーク型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `inet` | 🟢 | IPv4/IPv6 アドレス |
| `cidr` | 🟢 | IPv4/IPv6 ネットワーク |
| `macaddr` | ⚪ | MACアドレス |
| `macaddr8` | ⚪ | MACアドレス (EUI-64) |

### 2.10 幾何型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `point` | ⚪ | 二次元座標 |
| `line` | ⚪ | 無限直線 |
| `lseg` | ⚪ | 線分 |
| `box` | ⚪ | 矩形 |
| `path` | ⚪ | パス |
| `polygon` | ⚪ | 多角形 |
| `circle` | ⚪ | 円 |

### 2.11 ビット文字列型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `bit(n)` | ⚪ | 固定長ビット列 |
| `bit varying(n)` / `varbit` | ⚪ | 可変長ビット列 |

### 2.12 全文検索型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `tsvector` | 🟢 | 全文検索ドキュメント |
| `tsquery` | 🟢 | 全文検索クエリ |

### 2.13 範囲型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `int4range` | 🟢 | integer の範囲 |
| `int8range` | 🟢 | bigint の範囲 |
| `numrange` | 🟢 | numeric の範囲 |
| `tsrange` | 🟢 | timestamp の範囲 |
| `tstzrange` | 🟢 | timestamptz の範囲 |
| `daterange` | 🟢 | date の範囲 |

### 2.14 その他の型

| 型 | 優先度 | 説明 |
|----|--------|------|
| `xml` | ⚪ | XML データ |
| `pg_lsn` | ⚪ | ログシーケンス番号 |
| `pg_snapshot` | ⚪ | トランザクションID スナップショット |
| `oid` | 🟡 | オブジェクト識別子 |
| `regclass` | 🟡 | テーブル/インデックスOID |
| `regtype` | 🟡 | 型OID |
| `regproc` | ⚪ | 関数OID |
| `void` | 🟡 | 戻り値なし |
| `record` | 🟡 | 匿名複合型 |
| `ENUM` | 🟡 | 列挙型（CREATE TYPE ... AS ENUM） |

---

## 3. 演算子

### 3.1 比較演算子

| 演算子 | 優先度 | 説明 |
|--------|--------|------|
| `=` | 🔴 | 等価 |
| `<>` / `!=` | 🔴 | 不等価 |
| `<` | 🔴 | 未満 |
| `>` | 🔴 | 超過 |
| `<=` | 🔴 | 以下 |
| `>=` | 🔴 | 以上 |
| `BETWEEN ... AND ...` | 🔴 | 範囲内判定 |
| `NOT BETWEEN` | 🔴 | 範囲外判定 |
| `IS NULL` / `IS NOT NULL` | 🔴 | NULL 判定 |
| `IS DISTINCT FROM` | 🟡 | NULL安全な比較 |
| `IS NOT DISTINCT FROM` | 🟡 | NULL安全な等価 |
| `IS TRUE` / `IS FALSE` / `IS UNKNOWN` | 🟡 | 真偽値判定 |

### 3.2 論理演算子

| 演算子 | 優先度 | 説明 |
|--------|--------|------|
| `AND` | 🔴 | 論理積 |
| `OR` | 🔴 | 論理和 |
| `NOT` | 🔴 | 論理否定 |

### 3.3 算術演算子

| 演算子 | 優先度 | 説明 |
|--------|--------|------|
| `+` | 🔴 | 加算 |
| `-` | 🔴 | 減算 |
| `*` | 🔴 | 乗算 |
| `/` | 🔴 | 除算 |
| `%` | 🔴 | 剰余 |
| `^` | 🟡 | 冪乗 |
| `\|/` | ⚪ | 平方根 |
| `\|\|/` | ⚪ | 立方根 |
| `!` | ⚪ | 階乗 |
| `@` | ⚪ | 絶対値 |
| `&` | 🟡 | ビット積 |
| `\|` | 🟡 | ビット和 |
| `#` | 🟡 | ビット排他的論理和 |
| `~` | 🟡 | ビット否定 |
| `<<` | 🟡 | ビット左シフト |
| `>>` | 🟡 | ビット右シフト |

### 3.4 文字列演算子

| 演算子 | 優先度 | 説明 |
|--------|--------|------|
| `\|\|` | 🔴 | 文字列連結 |
| `LIKE` / `ILIKE` | 🔴 | パターンマッチ |
| `NOT LIKE` / `NOT ILIKE` | 🔴 | パターン不一致 |
| `SIMILAR TO` | 🟡 | SQL正規表現マッチ |
| `~` / `~*` / `!~` / `!~*` | 🟡 | POSIX正規表現 |
| `^@` | 🟡 | 先頭一致（starts_with） |

### 3.5 JSON演算子

| 演算子 | 優先度 | 説明 |
|--------|--------|------|
| `->` | 🟡 | JSONオブジェクト/配列要素取得（JSON型） |
| `->>` | 🟡 | JSONオブジェクト/配列要素取得（text型） |
| `#>` | 🟡 | パスによるJSON要素取得 |
| `#>>` | 🟡 | パスによるJSON要素取得（text型） |
| `@>` | 🟡 | JSONB包含判定 |
| `<@` | 🟡 | JSONB被包含判定 |
| `?` | 🟡 | JSONBキー存在判定 |
| `?\|` | 🟢 | JSONBいずれかのキー存在 |
| `?&` | 🟢 | JSONBすべてのキー存在 |
| `@?` | 🟢 | JSONパス存在判定 |
| `@@` | 🟢 | JSONパス述語判定 |
| `#-` | 🟢 | JSONBからパスで要素削除 |

### 3.6 配列演算子

| 演算子 | 優先度 | 説明 |
|--------|--------|------|
| `@>` | 🟡 | 配列包含 |
| `<@` | 🟡 | 配列被包含 |
| `&&` | 🟡 | 配列共通要素あり |
| `\|\|` | 🟡 | 配列連結 |
| `ANY(array)` / `SOME(array)` | 🟡 | 配列要素のいずれかと比較 |
| `ALL(array)` | 🟡 | 配列全要素と比較 |

---

## 4. 組み込み関数

### 4.1 数学関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `abs(x)` | 🔴 | 絶対値 |
| `ceil(x)` / `ceiling(x)` | 🔴 | 切り上げ |
| `floor(x)` | 🔴 | 切り捨て |
| `round(x)` / `round(x, s)` | 🔴 | 四捨五入 |
| `trunc(x)` / `trunc(x, s)` | 🟡 | 小数部切り捨て |
| `mod(x, y)` | 🟡 | 剰余 |
| `power(a, b)` | 🟡 | 冪乗 |
| `sqrt(x)` | 🟡 | 平方根 |
| `log(x)` / `log10(x)` | 🟡 | 対数 |
| `ln(x)` | 🟡 | 自然対数 |
| `exp(x)` | 🟡 | 指数 |
| `sign(x)` | 🟡 | 符号 |
| `pi()` | 🟡 | 円周率 |
| `random()` | 🟡 | 乱数 (0.0 〜 1.0) |
| `setseed(x)` | 🟡 | 乱数シード設定 |
| `greatest(...)` / `least(...)` | 🔴 | 最大値/最小値 |
| `div(x, y)` | 🟡 | 整数除算 |
| `gcd(a, b)` / `lcm(a, b)` | ⚪ | 最大公約数/最小公倍数 |
| `sin/cos/tan/asin/acos/atan/atan2` | ⚪ | 三角関数 |

### 4.2 文字列関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `length(s)` / `char_length(s)` | 🔴 | 文字数 |
| `octet_length(s)` | 🟡 | バイト数 |
| `lower(s)` / `upper(s)` | 🔴 | 大文字/小文字変換 |
| `trim(s)` / `ltrim(s)` / `rtrim(s)` | 🔴 | 空白除去 |
| `substring(s, start, len)` | 🔴 | 部分文字列 |
| `position(sub IN s)` | 🔴 | 文字列位置検索 |
| `replace(s, from, to)` | 🔴 | 文字列置換 |
| `concat(...)` / `concat_ws(sep, ...)` | 🔴 | 文字列連結 |
| `split_part(s, delim, n)` | 🟡 | 分割取得 |
| `left(s, n)` / `right(s, n)` | 🟡 | 左/右から取得 |
| `repeat(s, n)` | 🟡 | 文字列繰返し |
| `reverse(s)` | 🟡 | 文字列反転 |
| `lpad(s, len, fill)` / `rpad(s, len, fill)` | 🟡 | パディング |
| `initcap(s)` | 🟡 | 単語先頭大文字化 |
| `starts_with(s, prefix)` | 🟡 | 先頭一致判定 |
| `string_to_array(s, delim)` | 🟡 | 文字列を配列に分割 |
| `array_to_string(arr, delim)` | 🟡 | 配列を文字列に結合 |
| `regexp_match(s, pattern)` | 🟡 | 正規表現マッチ |
| `regexp_matches(s, pattern, flags)` | 🟡 | 正規表現全マッチ |
| `regexp_replace(s, pattern, repl)` | 🟡 | 正規表現置換 |
| `regexp_split_to_array(s, pattern)` | 🟡 | 正規表現分割 |
| `regexp_split_to_table(s, pattern)` | 🟢 | 正規表現分割（テーブル返却） |
| `format(fmt, ...)` | 🟡 | printf形式フォーマット |
| `md5(s)` | 🟡 | MD5ハッシュ |
| `encode(data, format)` / `decode(s, format)` | 🟡 | base64等エンコード |
| `quote_ident(s)` / `quote_literal(s)` | 🟡 | SQL識別子/リテラルのクオート |
| `chr(n)` / `ascii(s)` | 🟡 | 文字コード変換 |
| `strpos(s, sub)` | 🟡 | 文字列位置検索（関数版） |
| `translate(s, from, to)` | 🟡 | 文字変換 |
| `to_hex(n)` | 🟡 | 16進数文字列変換 |

### 4.3 日付・時刻関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `now()` / `current_timestamp` | 🔴 | 現在日時 |
| `current_date` | 🔴 | 現在日付 |
| `current_time` | 🟡 | 現在時刻 |
| `extract(field FROM source)` | 🔴 | 日時フィールド抽出 |
| `date_part(field, source)` | 🔴 | 日時フィールド抽出（関数版） |
| `date_trunc(field, source)` | 🔴 | 日時切り捨て |
| `age(ts1, ts2)` | 🟡 | 日時差分 |
| `make_date(y, m, d)` | 🟡 | 日付作成 |
| `make_timestamp(...)` | 🟡 | タイムスタンプ作成 |
| `make_timestamptz(...)` | 🟡 | タイムスタンプTZ作成 |
| `make_interval(...)` | 🟡 | インターバル作成 |
| `to_timestamp(epoch)` | 🟡 | Unixエポックからタイムスタンプ |
| `to_char(ts, format)` | 🟡 | 日時フォーマット |
| `to_date(s, format)` | 🟡 | 文字列から日付変換 |
| `to_timestamp(s, format)` | 🟡 | 文字列からタイムスタンプ変換 |
| `clock_timestamp()` | 🟡 | 実時刻（文実行中に変化） |
| `statement_timestamp()` | 🟡 | 文開始時刻 |
| `transaction_timestamp()` | 🟡 | トランザクション開始時刻 |
| `date_bin(interval, ts, origin)` | 🟢 | タイムスタンプのビン化 |
| `isfinite(ts/date/interval)` | 🟢 | 有限判定 |
| `justify_days/hours/interval` | ⚪ | インターバル正規化 |
| `OVERLAPS` | 🟢 | 期間重複判定 |

### 4.4 集約関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `count(*)` / `count(expr)` | 🔴 | 件数 |
| `sum(expr)` | 🔴 | 合計 |
| `avg(expr)` | 🔴 | 平均 |
| `min(expr)` / `max(expr)` | 🔴 | 最小/最大 |
| `bool_and(expr)` / `bool_or(expr)` | 🟡 | 論理集約 |
| `every(expr)` | 🟡 | SQL標準のbool_and |
| `array_agg(expr)` | 🟡 | 配列集約 |
| `string_agg(expr, delim)` | 🟡 | 文字列連結集約 |
| `json_agg(expr)` / `jsonb_agg(expr)` | 🟡 | JSON配列集約 |
| `json_object_agg(k, v)` / `jsonb_object_agg(k, v)` | 🟡 | JSONオブジェクト集約 |
| `bit_and(expr)` / `bit_or(expr)` / `bit_xor(expr)` | 🟢 | ビット演算集約 |
| `any_value(expr)` | 🟢 | 任意の値（PG 16+） |

#### 統計集約関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `stddev(x)` / `stddev_pop(x)` / `stddev_samp(x)` | 🟢 | 標準偏差 |
| `variance(x)` / `var_pop(x)` / `var_samp(x)` | 🟢 | 分散 |
| `corr(Y, X)` | ⚪ | 相関係数 |
| `covar_pop(Y, X)` / `covar_samp(Y, X)` | ⚪ | 共分散 |
| `regr_*` (slope, intercept, r2 等) | ⚪ | 回帰分析関数群 |

#### 順序集合集約関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `mode() WITHIN GROUP (ORDER BY ...)` | 🟢 | 最頻値 |
| `percentile_cont(frac) WITHIN GROUP (ORDER BY ...)` | 🟢 | 連続百分位数 |
| `percentile_disc(frac) WITHIN GROUP (ORDER BY ...)` | 🟢 | 離散百分位数 |

### 4.5 ウィンドウ関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `row_number()` | 🟡 | 行番号 |
| `rank()` | 🟡 | ランク（ギャップあり） |
| `dense_rank()` | 🟡 | ランク（ギャップなし） |
| `percent_rank()` | 🟢 | 相対ランク |
| `cume_dist()` | 🟢 | 累積分布 |
| `ntile(n)` | 🟡 | n分割 |
| `lag(value, offset, default)` | 🟡 | 前行参照 |
| `lead(value, offset, default)` | 🟡 | 後行参照 |
| `first_value(value)` | 🟡 | フレーム最初の値 |
| `last_value(value)` | 🟡 | フレーム最後の値 |
| `nth_value(value, n)` | 🟡 | フレームのn番目の値 |

### 4.6 条件式関数

| 関数/構文 | 優先度 | 説明 |
|-----------|--------|------|
| `CASE WHEN ... THEN ... ELSE ... END` | 🔴 | 条件分岐 |
| `COALESCE(v1, v2, ...)` | 🔴 | 最初の非NULL値 |
| `NULLIF(v1, v2)` | 🔴 | 等しければNULL |
| `GREATEST(v1, v2, ...)` | 🔴 | 最大値 |
| `LEAST(v1, v2, ...)` | 🔴 | 最小値 |

### 4.7 型変換関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `CAST(expr AS type)` | 🔴 | 型変換（SQL標準） |
| `expr::type` | 🔴 | 型変換（PostgreSQL構文） |
| `to_char(n/ts, format)` | 🟡 | 数値/日時→文字列 |
| `to_number(s, format)` | 🟡 | 文字列→数値 |
| `to_date(s, format)` | 🟡 | 文字列→日付 |
| `to_timestamp(s, format)` | 🟡 | 文字列→タイムスタンプ |

### 4.8 JSON関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `to_json(val)` / `to_jsonb(val)` | 🟡 | JSON変換 |
| `json_build_object(...)` / `jsonb_build_object(...)` | 🟡 | JSONオブジェクト構築 |
| `json_build_array(...)` / `jsonb_build_array(...)` | 🟡 | JSON配列構築 |
| `json_typeof(json)` | 🟡 | JSON型判定 |
| `json_array_length(json)` | 🟡 | JSON配列長 |
| `json_array_elements(json)` | 🟡 | JSON配列展開 |
| `json_each(json)` / `json_each_text(json)` | 🟡 | JSONオブジェクト展開 |
| `json_object_keys(json)` | 🟡 | JSONキー一覧 |
| `json_extract_path(json, ...)` | 🟡 | パス指定で値取得 |
| `json_populate_record(base, json)` | 🟢 | JSONをレコードに展開 |
| `json_to_record(json)` | 🟢 | JSONをレコードに変換 |
| `jsonb_set(target, path, new_value)` | 🟡 | JSONB値設定 |
| `jsonb_insert(target, path, new_value)` | 🟡 | JSONB値挿入 |
| `jsonb_strip_nulls(jsonb)` | 🟡 | JSONBからnull除去 |
| `jsonb_path_exists(target, path)` | 🟢 | JSONパス存在判定 |
| `jsonb_path_query(target, path)` | 🟢 | JSONパスクエリ |
| `jsonb_pretty(jsonb)` | 🟢 | JSONB整形出力 |
| `row_to_json(record)` | 🟡 | レコードをJSONに変換 |

### 4.9 配列関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `array_length(arr, dim)` | 🟡 | 配列長 |
| `array_dims(arr)` | 🟡 | 配列次元 |
| `array_lower(arr, dim)` / `array_upper(arr, dim)` | 🟡 | 配列添字範囲 |
| `array_append(arr, elem)` | 🟡 | 配列末尾追加 |
| `array_prepend(elem, arr)` | 🟡 | 配列先頭追加 |
| `array_cat(arr1, arr2)` | 🟡 | 配列連結 |
| `array_remove(arr, elem)` | 🟡 | 配列要素削除 |
| `array_replace(arr, from, to)` | 🟡 | 配列要素置換 |
| `array_position(arr, elem)` | 🟡 | 配列要素位置 |
| `array_positions(arr, elem)` | 🟡 | 配列要素全位置 |
| `unnest(arr)` | 🟡 | 配列を行に展開 |
| `cardinality(arr)` | 🟡 | 配列要素総数 |

### 4.10 システム情報関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `current_database()` | 🔴 | 現在のデータベース名 |
| `current_schema()` | 🔴 | 現在のスキーマ名 |
| `current_schemas(include_implicit)` | 🟡 | 検索パスのスキーマ一覧 |
| `current_user` / `session_user` | 🔴 | 現在のユーザ |
| `version()` | 🟡 | バージョン文字列 |
| `pg_typeof(expr)` | 🟡 | 式の型名 |
| `has_table_privilege(...)` | 🟢 | テーブル権限判定 |
| `has_schema_privilege(...)` | 🟢 | スキーマ権限判定 |
| `pg_table_size(regclass)` | ⚪ | テーブルサイズ |
| `pg_total_relation_size(regclass)` | ⚪ | テーブル＋インデックス合計サイズ |
| `pg_column_size(expr)` | ⚪ | 値のストレージサイズ |
| `txid_current()` | 🟢 | 現在のトランザクションID |
| `pg_backend_pid()` | 🟡 | バックエンドプロセスID |

### 4.11 シーケンス関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `nextval(regclass)` | 🔴 | 次のシーケンス値 |
| `currval(regclass)` | 🟡 | 現在のシーケンス値 |
| `setval(regclass, bigint)` | 🟡 | シーケンス値設定 |
| `lastval()` | 🟡 | 最後に取得したシーケンス値 |

### 4.12 集合返却関数

| 関数 | 優先度 | 説明 |
|------|--------|------|
| `generate_series(start, stop, step)` | 🟡 | 連番生成（整数/タイムスタンプ） |
| `generate_subscripts(arr, dim)` | 🟢 | 配列添字生成 |

---

## 5. クエリ構文・機能

### 5.1 SELECT の構成要素

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `SELECT *` / `SELECT expr` | 🔴 | 基本的なカラム選択 |
| `SELECT DISTINCT` | 🔴 | 重複排除 |
| `SELECT DISTINCT ON (expr)` | 🟡 | PostgreSQL拡張の重複排除 |
| `FROM` | 🔴 | テーブル指定 |
| `WHERE` | 🔴 | 条件指定 |
| `GROUP BY` | 🔴 | グループ化 |
| `GROUP BY GROUPING SETS` | 🟢 | グルーピングセット |
| `GROUP BY ROLLUP` | 🟢 | ロールアップ集計 |
| `GROUP BY CUBE` | 🟢 | キューブ集計 |
| `HAVING` | 🔴 | グループ条件 |
| `ORDER BY` | 🔴 | ソート |
| `ORDER BY ... NULLS FIRST/LAST` | 🟡 | NULLのソート順指定 |
| `LIMIT` / `FETCH FIRST n ROWS` | 🔴 | 行数制限 |
| `OFFSET` | 🔴 | オフセット |
| テーブルエイリアス (`AS`) | 🔴 | テーブル/カラム別名 |

### 5.2 JOIN

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `INNER JOIN ... ON` | 🔴 | 内部結合 |
| `LEFT [OUTER] JOIN ... ON` | 🔴 | 左外部結合 |
| `RIGHT [OUTER] JOIN ... ON` | 🔴 | 右外部結合 |
| `FULL [OUTER] JOIN ... ON` | 🟡 | 完全外部結合 |
| `CROSS JOIN` | 🔴 | 直積 |
| `NATURAL JOIN` | 🟡 | 自然結合 |
| `JOIN ... USING (col)` | 🟡 | USING句による結合 |
| `LATERAL JOIN` | 🟢 | ラテラル結合 |
| 自己結合 | 🔴 | テーブルの自己参照結合 |

### 5.3 サブクエリ

| 機能 | 優先度 | 説明 |
|------|--------|------|
| スカラーサブクエリ | 🔴 | 単一値を返すサブクエリ |
| `IN (subquery)` | 🔴 | サブクエリ内存在判定 |
| `NOT IN (subquery)` | 🔴 | サブクエリ内非存在判定 |
| `EXISTS (subquery)` | 🔴 | サブクエリ結果存在判定 |
| `NOT EXISTS (subquery)` | 🔴 | サブクエリ結果非存在判定 |
| `ANY/SOME (subquery)` | 🟡 | サブクエリとの比較（いずれか） |
| `ALL (subquery)` | 🟡 | サブクエリとの比較（すべて） |
| 相関サブクエリ | 🟡 | 外部クエリ参照サブクエリ |
| FROM句のサブクエリ（派生テーブル） | 🔴 | インラインビュー |

### 5.4 集合演算

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `UNION` | 🔴 | 和集合（重複排除） |
| `UNION ALL` | 🔴 | 和集合（重複含む） |
| `INTERSECT` | 🟡 | 積集合 |
| `INTERSECT ALL` | 🟢 | 積集合（重複含む） |
| `EXCEPT` | 🟡 | 差集合 |
| `EXCEPT ALL` | 🟢 | 差集合（重複含む） |

### 5.5 CTE (Common Table Expressions)

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `WITH ... AS (SELECT ...)` | 🟡 | 基本CTE |
| `WITH RECURSIVE ...` | 🟡 | 再帰CTE |
| `WITH ... AS MATERIALIZED` | 🟢 | マテリアライズCTE |
| `WITH ... AS NOT MATERIALIZED` | 🟢 | 非マテリアライズCTE |
| CTE内のDML (`INSERT/UPDATE/DELETE`) | 🟢 | 書き込みCTE |
| `SEARCH DEPTH/BREADTH FIRST` | 🟢 | 再帰探索順序 |
| `CYCLE ... SET ... USING ...` | 🟢 | サイクル検出 |

### 5.6 ウィンドウ関数構文

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `OVER (PARTITION BY ... ORDER BY ...)` | 🟡 | 基本ウィンドウ指定 |
| `OVER (ORDER BY ...)` | 🟡 | パーティションなしウィンドウ |
| `ROWS BETWEEN ... AND ...` | 🟡 | 行ベースフレーム |
| `RANGE BETWEEN ... AND ...` | 🟢 | 値ベースフレーム |
| `GROUPS BETWEEN ... AND ...` | 🟢 | グループベースフレーム |
| `WINDOW w AS (...)` | 🟢 | 名前付きウィンドウ定義 |
| `EXCLUDE CURRENT ROW / GROUP / TIES / NO OTHERS` | ⚪ | フレーム排除指定 |

### 5.7 その他のクエリ機能

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `VALUES (...)` | 🟡 | 値リスト |
| `TABLE tablename` | 🟡 | `SELECT * FROM tablename` の省略形 |
| `FOR UPDATE` / `FOR SHARE` | 🟡 | 行ロック |
| `FOR NO KEY UPDATE` / `FOR KEY SHARE` | 🟢 | 行ロック（キー考慮） |
| 型キャスト (`::`) | 🔴 | PostgreSQL形式型変換 |
| `IN (value_list)` | 🔴 | 値リスト内存在判定 |
| `BETWEEN a AND b` | 🔴 | 範囲判定 |
| `LIKE` / `ILIKE` パターン | 🔴 | ワイルドカード検索 |
| `SIMILAR TO` パターン | 🟡 | SQL正規表現 |
| `RETURNING *` | 🟡 | DML結果返却 |

---

## 6. インデックス

| インデックス型 | 優先度 | 説明 | 対応する演算 |
|--------------|--------|------|-------------|
| B-tree | 🔴 | デフォルト。等価・範囲検索 | `<`, `<=`, `=`, `>=`, `>`, `BETWEEN`, `IN`, `IS NULL` |
| Hash | 🟡 | 等価検索のみ | `=` |
| GiST | 🟢 | 幾何データ、全文検索、範囲型 | `<<`, `>>`, `@>`, `<@`, `&&` 等 |
| SP-GiST | ⚪ | 不均衡データ構造 | 四分木、kd木、トライ木 |
| GIN | 🟡 | 配列、JSONB、全文検索 | `@>`, `<@`, `=`, `&&`, `?`, `?&`, `?\|` |
| BRIN | 🟢 | ブロック範囲サマリ | 物理的に順序付きデータ向け |
| Bloom | ⚪ | ブルームフィルタ | 等価検索（多カラム） |

### インデックス機能

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `CREATE INDEX` | 🟡 | 基本インデックス作成 |
| `CREATE UNIQUE INDEX` | 🟡 | ユニークインデックス |
| `CREATE INDEX ... ON (expr)` | 🟢 | 式インデックス |
| `CREATE INDEX ... WHERE ...` | 🟢 | 部分インデックス |
| `CREATE INDEX CONCURRENTLY` | ⚪ | 並行インデックス作成 |
| 複合インデックス | 🟡 | 複数カラムインデックス |
| カバリングインデックス (`INCLUDE`) | 🟢 | インデックスオンリースキャン用 |

---

## 7. 制約

| 制約 | 優先度 | 説明 |
|------|--------|------|
| `NOT NULL` | 🔴 | NULL不許可 |
| `UNIQUE` | 🔴 | 一意制約 |
| `PRIMARY KEY` | 🔴 | 主キー（NOT NULL + UNIQUE） |
| `FOREIGN KEY ... REFERENCES` | 🟡 | 外部キー |
| `ON DELETE CASCADE/SET NULL/RESTRICT/NO ACTION` | 🟡 | 外部キー削除動作 |
| `ON UPDATE CASCADE/SET NULL/RESTRICT/NO ACTION` | 🟡 | 外部キー更新動作 |
| `CHECK (expr)` | 🟡 | チェック制約 |
| `DEFAULT value` | 🔴 | デフォルト値 |
| `GENERATED ALWAYS AS (expr) STORED` | 🟢 | 生成カラム |
| `GENERATED ALWAYS AS IDENTITY` | 🟡 | IDENTITY カラム |
| `EXCLUDE USING ...` | 🟢 | 排他制約 |
| `DEFERRABLE` / `INITIALLY DEFERRED` | 🟢 | 遅延制約評価 |

---

## 8. トランザクション・同時実行制御

### 8.1 トランザクション分離レベル

| 分離レベル | 優先度 | 説明 |
|-----------|--------|------|
| `READ COMMITTED` | 🔴 | デフォルト。コミット済みデータのみ読取 |
| `REPEATABLE READ` | 🟡 | トランザクション開始時のスナップショット |
| `SERIALIZABLE` | 🟢 | 直列化可能分離レベル |
| `READ UNCOMMITTED` | ⚪ | PGでは `READ COMMITTED` と同等 |

### 8.2 MVCC (Multi-Version Concurrency Control)

| 機能 | 優先度 | 説明 |
|------|--------|------|
| スナップショット分離 | 🔴 | トランザクション間のデータ可視性管理 |
| 行バージョニング | 🟡 | 同一行の複数バージョン管理 |
| デッドロック検出 | 🟡 | 循環待ちの検出と解消 |

### 8.3 ロック

| ロック種類 | 優先度 | 説明 |
|-----------|--------|------|
| 行レベルロック (`FOR UPDATE` 等) | 🟡 | SELECT時の行ロック |
| テーブルレベルロック (`LOCK TABLE`) | 🟢 | 明示的テーブルロック |
| アドバイザリーロック (`pg_advisory_lock`) | 🟢 | アプリケーション定義ロック |

---

## 9. システムカタログ・情報スキーマ

### 9.1 最低限必要なシステムカタログ

| カタログ | 優先度 | 説明 |
|---------|--------|------|
| `pg_catalog.pg_class` | 🔴 | テーブル・インデックス等の一覧 |
| `pg_catalog.pg_attribute` | 🔴 | カラム定義 |
| `pg_catalog.pg_type` | 🔴 | データ型定義 |
| `pg_catalog.pg_namespace` | 🔴 | スキーマ定義 |
| `pg_catalog.pg_index` | 🟡 | インデックス情報 |
| `pg_catalog.pg_constraint` | 🟡 | 制約情報 |
| `pg_catalog.pg_sequence` | 🟡 | シーケンス情報 |
| `pg_catalog.pg_depend` | 🟡 | オブジェクト依存関係 |
| `pg_catalog.pg_proc` | 🟢 | 関数・プロシージャ定義 |
| `pg_catalog.pg_trigger` | 🟢 | トリガー定義 |
| `pg_catalog.pg_description` | 🟡 | オブジェクトコメント |
| `pg_catalog.pg_settings` | 🟡 | サーバ設定パラメータ |
| `pg_catalog.pg_database` | 🟡 | データベース一覧 |
| `pg_catalog.pg_roles` | 🟢 | ロール一覧 |
| `pg_catalog.pg_stat_user_tables` | 🟢 | テーブル統計情報 |
| `pg_catalog.pg_stat_activity` | 🟢 | アクティブセッション |
| `pg_catalog.pg_locks` | 🟢 | ロック情報 |
| `pg_catalog.pg_enum` | 🟡 | ENUM型の値一覧 |
| `pg_catalog.pg_attrdef` | 🟡 | カラムデフォルト値 |
| `pg_catalog.pg_views` | 🟡 | ビュー一覧 |

### 9.2 情報スキーマ (information_schema)

| ビュー | 優先度 | 説明 |
|--------|--------|------|
| `information_schema.tables` | 🔴 | テーブル一覧 |
| `information_schema.columns` | 🔴 | カラム一覧 |
| `information_schema.table_constraints` | 🟡 | テーブル制約一覧 |
| `information_schema.key_column_usage` | 🟡 | キーカラム使用状況 |
| `information_schema.referential_constraints` | 🟡 | 外部キー制約 |
| `information_schema.constraint_column_usage` | 🟡 | 制約カラム使用状況 |
| `information_schema.schemata` | 🟡 | スキーマ一覧 |
| `information_schema.views` | 🟡 | ビュー一覧 |
| `information_schema.sequences` | 🟡 | シーケンス一覧 |
| `information_schema.routines` | 🟢 | 関数・プロシージャ一覧 |
| `information_schema.parameters` | 🟢 | 関数パラメータ |
| `information_schema.check_constraints` | 🟢 | チェック制約 |
| `information_schema.domains` | 🟢 | ドメイン一覧 |
| `information_schema.triggers` | 🟢 | トリガー一覧 |

---

## 10. ワイヤープロトコル

PostgreSQLクライアント（pgx, lib/pq, psql等）との通信に必要なプロトコル機能。

### 10.1 接続フェーズ

| メッセージ | 優先度 | 説明 |
|-----------|--------|------|
| StartupMessage | 🔴 | 接続開始（バージョン、パラメータ） |
| AuthenticationOk | 🔴 | 認証成功 |
| AuthenticationCleartextPassword | 🟡 | 平文パスワード認証 |
| AuthenticationMD5Password | 🟡 | MD5パスワード認証 |
| AuthenticationSASL | 🟢 | SCRAM-SHA-256認証 |
| ParameterStatus | 🔴 | サーバパラメータ通知 |
| BackendKeyData | 🟡 | バックエンドキー（キャンセル用） |
| ReadyForQuery | 🔴 | クエリ受付可能通知 |
| SSLRequest | 🟡 | SSL接続要求 |
| CancelRequest | 🟡 | クエリキャンセル要求 |

### 10.2 Simple Query Protocol

| メッセージ | 優先度 | 説明 |
|-----------|--------|------|
| Query (F) | 🔴 | SQL文送信 |
| RowDescription (B) | 🔴 | 結果カラム情報 |
| DataRow (B) | 🔴 | 結果データ行 |
| CommandComplete (B) | 🔴 | コマンド完了通知 |
| EmptyQueryResponse (B) | 🔴 | 空クエリ応答 |
| ErrorResponse (B) | 🔴 | エラー通知 |
| NoticeResponse (B) | 🟡 | 警告/通知 |

### 10.3 Extended Query Protocol

| メッセージ | 優先度 | 説明 |
|-----------|--------|------|
| Parse (F) | 🟡 | プリペアド文パース |
| ParseComplete (B) | 🟡 | パース完了 |
| Bind (F) | 🟡 | パラメータバインド |
| BindComplete (B) | 🟡 | バインド完了 |
| Describe (F) | 🟡 | ポータル/ステートメント記述要求 |
| ParameterDescription (B) | 🟡 | パラメータ型情報 |
| Execute (F) | 🟡 | 実行 |
| Close (F) | 🟡 | ポータル/ステートメント閉鎖 |
| CloseComplete (B) | 🟡 | 閉鎖完了 |
| Sync (F) | 🟡 | 同期要求 |
| Flush (F) | 🟡 | フラッシュ要求 |

### 10.4 COPY Protocol

| メッセージ | 優先度 | 説明 |
|-----------|--------|------|
| CopyInResponse (B) | 🟢 | COPYインバウンド開始 |
| CopyOutResponse (B) | 🟢 | COPYアウトバウンド開始 |
| CopyData (F/B) | 🟢 | COPYデータ |
| CopyDone (F/B) | 🟢 | COPY完了 |
| CopyFail (F) | 🟢 | COPY失敗 |

### 10.5 Notification Protocol

| メッセージ | 優先度 | 説明 |
|-----------|--------|------|
| NotificationResponse (B) | 🟢 | LISTEN/NOTIFY通知 |

---

## 11. その他の機能

### 11.1 手続き言語

| 機能 | 優先度 | 説明 |
|------|--------|------|
| PL/pgSQL | 🟢 | PostgreSQL標準手続き言語 |
| PL/Python | ⚪ | Python手続き言語 |
| PL/Perl | ⚪ | Perl手続き言語 |
| SQL関数 | 🟡 | SQL言語による関数定義 |

### 11.2 拡張機能 (Extensions)

| 拡張 | 優先度 | 説明 |
|------|--------|------|
| `pgcrypto` | 🟢 | 暗号化関数 |
| `uuid-ossp` | 🟡 | UUID生成関数（`gen_random_uuid()` はPG 13+で標準） |
| `hstore` | 🟢 | キー/値ストア型 |
| `pg_trgm` | 🟢 | トライグラム類似度検索 |
| `btree_gist` / `btree_gin` | 🟢 | B-tree演算子のGiST/GINインデックス対応 |
| `citext` | 🟢 | 大文字小文字区別なしテキスト型 |
| `tablefunc` | ⚪ | クロスタブ・ピボット |
| `unaccent` | ⚪ | アクセント除去 |
| `pgvector` | 🟢 | ベクトル型・近似最近傍検索 |

### 11.3 パーティショニング

| 機能 | 優先度 | 説明 |
|------|--------|------|
| RANGE パーティション | 🟢 | 範囲ベースパーティション |
| LIST パーティション | 🟢 | リストベースパーティション |
| HASH パーティション | 🟢 | ハッシュベースパーティション |
| デフォルトパーティション | 🟢 | 未分類行用パーティション |

### 11.4 行レベルセキュリティ (RLS)

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` | 🟢 | RLS有効化 |
| `CREATE POLICY` | 🟢 | ポリシー作成 |
| `ALTER POLICY` | 🟢 | ポリシー変更 |
| `DROP POLICY` | 🟢 | ポリシー削除 |

### 11.5 その他

| 機能 | 優先度 | 説明 |
|------|--------|------|
| `gen_random_uuid()` | 🟡 | UUIDv4 生成（PG 13+標準） |
| `GENERATED ALWAYS AS IDENTITY` | 🟡 | アイデンティティカラム |
| テーブル継承 (`INHERITS`) | ⚪ | レガシー機能 |
| `TABLESAMPLE` | ⚪ | テーブルサンプリング |
| 外部データラッパー (FDW) | ⚪ | 外部データアクセス |
| 論理レプリケーション | ⚪ | インメモリでは不要 |
| 物理レプリケーション | ⚪ | インメモリでは不要 |

---

## 12. 実装優先度マトリクス

### Phase 1: 最小限の動作（MVP）

🔴 **必須**のすべての機能。テスト用途として最低限動作するために必要。

**スコープ概要**:
- 基本SQL: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE TABLE`, `DROP TABLE`
- 基本データ型: `integer`, `bigint`, `text`, `varchar`, `boolean`, `timestamp(tz)`, `date`, `serial/bigserial`, `real`, `double precision`
- 基本演算子: 比較、論理、算術、文字列連結
- 基本関数: `count`, `sum`, `avg`, `min`, `max`, `now()`, `COALESCE`, `CASE WHEN`
- 制約: `NOT NULL`, `PRIMARY KEY`, `UNIQUE`, `DEFAULT`
- トランザクション: `BEGIN`, `COMMIT`, `ROLLBACK` (READ COMMITTED)
- JOIN: `INNER`, `LEFT`, `CROSS`
- サブクエリ: スカラー, `IN`, `EXISTS`
- 集合演算: `UNION`, `UNION ALL`
- ワイヤープロトコル: Simple Query Protocol
- システムカタログ: `pg_class`, `pg_attribute`, `pg_type`, `pg_namespace`
- 情報スキーマ: `tables`, `columns`

**推定実装コンポーネント数**: 約150〜200個

---

### Phase 2: 実用的なアプリケーション対応

🟡 **重要**の機能を追加。一般的なWebアプリケーションのテストに十分な機能。

**追加スコープ概要**:
- DDL拡張: `ALTER TABLE`, `CREATE INDEX`, `CREATE VIEW`, `CREATE SCHEMA`, シーケンス, `TRUNCATE`, 一時テーブル
- DML拡張: `UPSERT`, `RETURNING`, `COPY`
- データ型追加: `numeric`, `json/jsonb`, `uuid`, 配列, `bytea`, `interval`, `ENUM`
- JOIN拡張: `RIGHT`, `FULL`, `NATURAL`, `USING`
- CTE, ウィンドウ関数
- Extended Query Protocol
- 外部キー制約, CHECK制約
- `EXPLAIN`, プリペアドステートメント
- シーケンス関数, `generate_series`
- JSON演算子・関数群
- 配列関数群
- 文字列・日時関数の拡充
- `SAVEPOINT`, `SET TRANSACTION`
- GINインデックス（JSONB用）
- 情報スキーマ拡充

**推定追加コンポーネント数**: 約300〜400個

---

### Phase 3: 高度な機能

🟢 **拡張**の機能。エンタープライズ用途や特殊なクエリパターン対応。

**追加スコープ概要**:
- `MERGE`, 手続き言語 (PL/pgSQL)
- トリガー, カスタム型/ドメイン
- マテリアライズドビュー
- パーティショニング
- 行レベルセキュリティ
- `SERIALIZABLE` 分離レベル
- GiST/BRINインデックス
- 全文検索 (`tsvector/tsquery`)
- 範囲型
- JSONPath
- 統計集約関数
- 拡張機能基盤
- LISTEN/NOTIFY
- アドバイザリーロック
- LATERAL JOIN

**推定追加コンポーネント数**: 約200〜300個

---

### 機能数の概算

| カテゴリ | 個別機能数 (概算) |
|---------|-----------------|
| SQLコマンド | ~60 |
| データ型 | ~50 |
| 演算子 | ~80 |
| 組み込み関数 | ~250+ |
| クエリ構文機能 | ~60 |
| インデックス | ~15 |
| 制約 | ~12 |
| トランザクション機能 | ~15 |
| システムカタログ/情報スキーマ | ~35 |
| ワイヤープロトコルメッセージ | ~30 |
| その他（拡張、PL/pgSQL等） | ~30 |
| **合計** | **~640+** |

> **注意**: これは個別の「機能」の数であり、実装の「工数」ではない。一部の機能（例: `CREATE TABLE`）は多くの関連サブ機能を含み、他（例: `abs(x)` 関数）は比較的単純である。

---

## PostgreSQL ソースコード参照

> 以下は PostgreSQL 19devel ソースコードにおける各機能カテゴリの実装箇所です。
> https://github.com/postgres/postgres からソースツリーを参照できます。

| カテゴリ | ソースファイル | 行数/規模 |
|---|---|---|
| DDL コマンド | `src/backend/commands/tablecmds.c`, `indexcmds.c`, `schemacmds.c`, `view.c`, `sequence.c`, `typecmds.c`, `trigger.c`, `functioncmds.c` | 54ファイル |
| DML 実行 | `src/backend/executor/nodeModifyTable.c` (INSERT/UPDATE/DELETE, 178KB) | - |
| SQL パーサー | `src/backend/parser/gram.y` (20,059行), `scan.l` (1,421行), `analyze.c` | 21ファイル |
| クエリオプティマイザ | `src/backend/optimizer/path/costsize.c` (225KB), `allpaths.c`, `joinpath.c` | ~40ファイル |
| エグゼキュータ | `src/backend/executor/` — 65ファイル（Scan, Join, Agg, Window, Sort, Limit 等） | ~1.8M行 |
| データ型実装 | `src/backend/utils/adt/` — 119ファイル（数値, 文字列, 日付, JSON, 配列, 範囲型等） | ~120,000行 |
| トランザクション | `src/backend/access/transam/xact.c` (189KB), `xlog.c` (315KB), `clog.c`, `multixact.c` | 25ファイル |
| ワイヤープロトコル | `src/backend/libpq/pqcomm.c` (2,088行), `pqformat.c`, `auth.c` (89KB) | 17ファイル |
| システムカタログ | `src/backend/catalog/` — 34ファイル, `src/include/catalog/` — 113ヘッダ | - |
| インデックス | `src/backend/access/nbtree/` (B-tree, 13), `hash/` (10), `gin/` (15), `gist/` (11), `brin/` (10), `spgist/` (11) | 122ファイル |
| 制約 | `src/backend/catalog/pg_constraint.c`, `src/backend/commands/tablecmds.c` | - |
| ウィンドウ関数 | `src/backend/executor/nodeWindowAgg.c` (130KB) | - |
| 集約関数 | `src/backend/executor/nodeAgg.c` (153KB), `src/backend/catalog/pg_aggregate.h` | - |
| メモリ管理 | `src/backend/utils/mmgr/aset.c`, `memutils.h` | 10ファイル |
| プロセスモデル | `src/backend/postmaster/postmaster.c` (134KB), `autovacuum.c` (107KB) | 15ファイル |

---

[← README に戻る](../README.md)
