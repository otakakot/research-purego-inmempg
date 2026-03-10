# 実装 TODO リスト

[← README に戻る](../README.md) | [機能一覧](pg-features.md)

---

> **凡例**
> - **P1**: 必須（Phase 1: MVP）
> - **P2**: 重要（Phase 2: 実用アプリ対応）
> - **P3**: 拡張（Phase 3: 高度な機能）
> - **P4**: 低優先（Phase 3: 特殊用途）

| 優先度 | 件数 |
|--------|------|
| P1 | 125 |
| P2 | 245 |
| P3 | 119 |
| P4 | 47 |
| **合計** | **536** |

---

## 1. SQL コマンド

### 1.1 データ定義言語 (DDL)

- [ ] P1: `CREATE TABLE` — テーブル作成（カラム定義、制約、デフォルト値）
- [ ] P1: `ALTER TABLE` — テーブル変更（カラム追加/削除/変更、制約追加/削除）
- [ ] P1: `DROP TABLE` — テーブル削除
- [ ] P2: `CREATE INDEX` — インデックス作成
- [ ] P2: `DROP INDEX` — インデックス削除
- [ ] P2: `CREATE SCHEMA` — スキーマ作成
- [ ] P2: `DROP SCHEMA` — スキーマ削除
- [ ] P2: `CREATE VIEW` — ビュー作成
- [ ] P2: `DROP VIEW` — ビュー削除
- [ ] P2: `CREATE SEQUENCE` — シーケンス作成（SERIAL/BIGSERIAL の基盤）
- [ ] P2: `ALTER SEQUENCE` — シーケンス変更
- [ ] P2: `DROP SEQUENCE` — シーケンス削除
- [ ] P3: `CREATE TYPE` — カスタム型作成（ENUM、複合型）
- [ ] P3: `DROP TYPE` — カスタム型削除
- [ ] P3: `CREATE DOMAIN` — ドメイン作成
- [ ] P3: `CREATE FUNCTION` — ユーザ定義関数
- [ ] P3: `DROP FUNCTION` — 関数削除
- [ ] P3: `CREATE TRIGGER` — トリガー作成
- [ ] P3: `DROP TRIGGER` — トリガー削除
- [ ] P3: `CREATE EXTENSION` — 拡張機能読み込み
- [ ] P2: `TRUNCATE` — テーブルデータ全削除（高速DELETE）
- [ ] P4: `COMMENT ON` — オブジェクトへのコメント付与
- [ ] P3: `CREATE MATERIALIZED VIEW` — マテリアライズドビュー
- [ ] P3: `REFRESH MATERIALIZED VIEW` — マテリアライズドビュー更新
- [ ] P2: `CREATE TEMPORARY TABLE` — 一時テーブル作成
- [ ] P3: `CREATE TABLE ... PARTITION BY` — パーティションテーブル
- [ ] P2: `CREATE TABLE ... LIKE` — 既存テーブル構造のコピー
- [ ] P2: `CREATE TABLE ... AS` — SELECT結果からテーブル作成

### 1.2 データ操作言語 (DML)

- [ ] P1: `SELECT` — データ検索（基本）
- [ ] P1: `INSERT` — データ挿入
- [ ] P1: `UPDATE` — データ更新
- [ ] P1: `DELETE` — データ削除
- [ ] P2: `INSERT ... ON CONFLICT` — UPSERT（競合時の動作指定）
- [ ] P2: `INSERT ... RETURNING` — 挿入結果の返却
- [ ] P2: `UPDATE ... RETURNING` — 更新結果の返却
- [ ] P2: `DELETE ... RETURNING` — 削除結果の返却
- [ ] P3: `MERGE` — SQL標準のMERGE文（PG 15+）
- [ ] P2: `COPY` — バルクデータ入出力
- [ ] P2: `SELECT INTO` — SELECT結果からテーブル作成

### 1.3 トランザクション制御言語 (TCL)

- [ ] P1: `BEGIN` / `START TRANSACTION` — トランザクション開始
- [ ] P1: `COMMIT` — トランザクション確定
- [ ] P1: `ROLLBACK` — トランザクション取消
- [ ] P2: `SAVEPOINT` — セーブポイント作成
- [ ] P2: `ROLLBACK TO SAVEPOINT` — セーブポイントへのロールバック
- [ ] P2: `RELEASE SAVEPOINT` — セーブポイント解放
- [ ] P2: `SET TRANSACTION` — トランザクション特性設定

### 1.4 データ制御言語 (DCL)

- [ ] P3: `GRANT` — 権限付与
- [ ] P3: `REVOKE` — 権限取消
- [ ] P3: `CREATE ROLE` / `CREATE USER` — ロール/ユーザ作成
- [ ] P3: `DROP ROLE` — ロール削除
- [ ] P3: `ALTER ROLE` — ロール変更
- [ ] P3: `SET ROLE` — 現在のロール切替

### 1.5 その他のコマンド

- [ ] P2: `EXPLAIN` — クエリ実行計画の表示
- [ ] P2: `EXPLAIN ANALYZE` — 実行計画＋実測結果
- [ ] P2: `PREPARE` / `EXECUTE` — プリペアドステートメント
- [ ] P2: `DEALLOCATE` — プリペアド解放
- [ ] P2: `SET` — パラメータ設定（search_path等）
- [ ] P2: `SHOW` — パラメータ値表示
- [ ] P2: `RESET` — パラメータリセット
- [ ] P3: `LISTEN` / `NOTIFY` — 非同期通知
- [ ] P3: `LOCK` — テーブルロック
- [ ] P4: `VACUUM` — テーブルの保守（インメモリでは不要の可能性）
- [ ] P3: `ANALYZE` — 統計情報更新
- [ ] P4: `CLUSTER` — テーブルの物理的再編成
- [ ] P4: `REINDEX` — インデックス再構築
- [ ] P3: `DO` — 匿名コードブロック実行

## 2. データ型

### 2.1 数値型

- [ ] P1: `smallint` | `int2` — 2 bytes
- [ ] P1: `integer` | `int`, `int4` — 4 bytes
- [ ] P1: `bigint` | `int8` — 8 bytes
- [ ] P2: `numeric(p,s)` | `decimal` — 可変
- [ ] P1: `real` | `float4` — 4 bytes
- [ ] P1: `double precision` | `float8`, `float` — 8 bytes
- [ ] P2: `smallserial` | `serial2` — 2 bytes
- [ ] P1: `serial` | `serial4` — 4 bytes
- [ ] P1: `bigserial` | `serial8` — 8 bytes
- [ ] P4: `money` | - — 8 bytes

### 2.2 文字列型

- [ ] P1: `text` — 可変長文字列（無制限）
- [ ] P1: `varchar(n)` / `character varying(n)` — 可変長文字列（最大長指定）
- [ ] P2: `char(n)` / `character(n)` — 固定長文字列
- [ ] P2: `name` — 内部識別子型（63バイト）

### 2.3 バイナリ型

- [ ] P2: `bytea` — バイナリデータ

### 2.4 日付・時刻型

- [ ] P1: `date` | - — 日付（年月日）
- [ ] P2: `time` | - — 時刻（タイムゾーンなし）
- [ ] P2: `time with time zone` | `timetz` — 時刻（タイムゾーンあり）
- [ ] P1: `timestamp` | - — タイムスタンプ（タイムゾーンなし）
- [ ] P1: `timestamp with time zone` | `timestamptz` — タイムスタンプ（タイムゾーンあり）
- [ ] P2: `interval` | - — 時間間隔

### 2.5 真偽値型

- [ ] P1: `boolean` — true/false/null

### 2.6 JSON型

- [ ] P2: `json` — テキスト形式JSON
- [ ] P2: `jsonb` — バイナリ形式JSON（インデックス対応）
- [ ] P3: `jsonpath` — JSONパスクエリ

### 2.7 UUID型

- [ ] P2: `uuid` — UUID (128-bit)

### 2.8 配列型

- [ ] P2: `anytype[]` — 任意の型の配列（`integer[]`, `text[]` 等）

### 2.9 ネットワーク型

- [ ] P3: `inet` — IPv4/IPv6 アドレス
- [ ] P3: `cidr` — IPv4/IPv6 ネットワーク
- [ ] P4: `macaddr` — MACアドレス
- [ ] P4: `macaddr8` — MACアドレス (EUI-64)

### 2.10 幾何型

- [ ] P4: `point` — 二次元座標
- [ ] P4: `line` — 無限直線
- [ ] P4: `lseg` — 線分
- [ ] P4: `box` — 矩形
- [ ] P4: `path` — パス
- [ ] P4: `polygon` — 多角形
- [ ] P4: `circle` — 円

### 2.11 ビット文字列型

- [ ] P4: `bit(n)` — 固定長ビット列
- [ ] P4: `bit varying(n)` / `varbit` — 可変長ビット列

### 2.12 全文検索型

- [ ] P3: `tsvector` — 全文検索ドキュメント
- [ ] P3: `tsquery` — 全文検索クエリ

### 2.13 範囲型

- [ ] P3: `int4range` — integer の範囲
- [ ] P3: `int8range` — bigint の範囲
- [ ] P3: `numrange` — numeric の範囲
- [ ] P3: `tsrange` — timestamp の範囲
- [ ] P3: `tstzrange` — timestamptz の範囲
- [ ] P3: `daterange` — date の範囲

### 2.14 その他の型

- [ ] P4: `xml` — XML データ
- [ ] P4: `pg_lsn` — ログシーケンス番号
- [ ] P4: `pg_snapshot` — トランザクションID スナップショット
- [ ] P2: `oid` — オブジェクト識別子
- [ ] P2: `regclass` — テーブル/インデックスOID
- [ ] P2: `regtype` — 型OID
- [ ] P4: `regproc` — 関数OID
- [ ] P2: `void` — 戻り値なし
- [ ] P2: `record` — 匿名複合型
- [ ] P2: `ENUM` — 列挙型（CREATE TYPE ... AS ENUM）

## 3. 演算子

### 3.1 比較演算子

- [ ] P1: `=` — 等価
- [ ] P1: `<>` / `!=` — 不等価
- [ ] P1: `<` — 未満
- [ ] P1: `>` — 超過
- [ ] P1: `<=` — 以下
- [ ] P1: `>=` — 以上
- [ ] P1: `BETWEEN ... AND ...` — 範囲内判定
- [ ] P1: `NOT BETWEEN` — 範囲外判定
- [ ] P1: `IS NULL` / `IS NOT NULL` — NULL 判定
- [ ] P2: `IS DISTINCT FROM` — NULL安全な比較
- [ ] P2: `IS NOT DISTINCT FROM` — NULL安全な等価
- [ ] P2: `IS TRUE` / `IS FALSE` / `IS UNKNOWN` — 真偽値判定

### 3.2 論理演算子

- [ ] P1: `AND` — 論理積
- [ ] P1: `OR` — 論理和
- [ ] P1: `NOT` — 論理否定

### 3.3 算術演算子

- [ ] P1: `+` — 加算
- [ ] P1: `-` — 減算
- [ ] P1: `*` — 乗算
- [ ] P1: `/` — 除算
- [ ] P1: `%` — 剰余
- [ ] P2: `^` — 冪乗
- [ ] P4: `\|/` — 平方根
- [ ] P4: `\|\|/` — 立方根
- [ ] P4: `!` — 階乗
- [ ] P4: `@` — 絶対値
- [ ] P2: `&` — ビット積
- [ ] P2: `\|` — ビット和
- [ ] P2: `#` — ビット排他的論理和
- [ ] P2: `~` — ビット否定
- [ ] P2: `<<` — ビット左シフト
- [ ] P2: `>>` — ビット右シフト

### 3.4 文字列演算子

- [ ] P1: `\|\|` — 文字列連結
- [ ] P1: `LIKE` / `ILIKE` — パターンマッチ
- [ ] P1: `NOT LIKE` / `NOT ILIKE` — パターン不一致
- [ ] P2: `SIMILAR TO` — SQL正規表現マッチ
- [ ] P2: `~` / `~*` / `!~` / `!~*` — POSIX正規表現
- [ ] P2: `^@` — 先頭一致（starts_with）

### 3.5 JSON演算子

- [ ] P2: `->` — JSONオブジェクト/配列要素取得（JSON型）
- [ ] P2: `->>` — JSONオブジェクト/配列要素取得（text型）
- [ ] P2: `#>` — パスによるJSON要素取得
- [ ] P2: `#>>` — パスによるJSON要素取得（text型）
- [ ] P2: `@>` — JSONB包含判定
- [ ] P2: `<@` — JSONB被包含判定
- [ ] P2: `?` — JSONBキー存在判定
- [ ] P3: `?\|` — JSONBいずれかのキー存在
- [ ] P3: `?&` — JSONBすべてのキー存在
- [ ] P3: `@?` — JSONパス存在判定
- [ ] P3: `@@` — JSONパス述語判定
- [ ] P3: `#-` — JSONBからパスで要素削除

### 3.6 配列演算子

- [ ] P2: `@>` — 配列包含
- [ ] P2: `<@` — 配列被包含
- [ ] P2: `&&` — 配列共通要素あり
- [ ] P2: `\|\|` — 配列連結
- [ ] P2: `ANY(array)` / `SOME(array)` — 配列要素のいずれかと比較
- [ ] P2: `ALL(array)` — 配列全要素と比較

## 4. 組み込み関数

### 4.1 数学関数

- [ ] P1: `abs(x)` — 絶対値
- [ ] P1: `ceil(x)` / `ceiling(x)` — 切り上げ
- [ ] P1: `floor(x)` — 切り捨て
- [ ] P1: `round(x)` / `round(x, s)` — 四捨五入
- [ ] P2: `trunc(x)` / `trunc(x, s)` — 小数部切り捨て
- [ ] P2: `mod(x, y)` — 剰余
- [ ] P2: `power(a, b)` — 冪乗
- [ ] P2: `sqrt(x)` — 平方根
- [ ] P2: `log(x)` / `log10(x)` — 対数
- [ ] P2: `ln(x)` — 自然対数
- [ ] P2: `exp(x)` — 指数
- [ ] P2: `sign(x)` — 符号
- [ ] P2: `pi()` — 円周率
- [ ] P2: `random()` — 乱数 (0.0 〜 1.0)
- [ ] P2: `setseed(x)` — 乱数シード設定
- [ ] P1: `greatest(...)` / `least(...)` — 最大値/最小値
- [ ] P2: `div(x, y)` — 整数除算
- [ ] P4: `gcd(a, b)` / `lcm(a, b)` — 最大公約数/最小公倍数
- [ ] P4: `sin/cos/tan/asin/acos/atan/atan2` — 三角関数

### 4.2 文字列関数

- [ ] P1: `length(s)` / `char_length(s)` — 文字数
- [ ] P2: `octet_length(s)` — バイト数
- [ ] P1: `lower(s)` / `upper(s)` — 大文字/小文字変換
- [ ] P1: `trim(s)` / `ltrim(s)` / `rtrim(s)` — 空白除去
- [ ] P1: `substring(s, start, len)` — 部分文字列
- [ ] P1: `position(sub IN s)` — 文字列位置検索
- [ ] P1: `replace(s, from, to)` — 文字列置換
- [ ] P1: `concat(...)` / `concat_ws(sep, ...)` — 文字列連結
- [ ] P2: `split_part(s, delim, n)` — 分割取得
- [ ] P2: `left(s, n)` / `right(s, n)` — 左/右から取得
- [ ] P2: `repeat(s, n)` — 文字列繰返し
- [ ] P2: `reverse(s)` — 文字列反転
- [ ] P2: `lpad(s, len, fill)` / `rpad(s, len, fill)` — パディング
- [ ] P2: `initcap(s)` — 単語先頭大文字化
- [ ] P2: `starts_with(s, prefix)` — 先頭一致判定
- [ ] P2: `string_to_array(s, delim)` — 文字列を配列に分割
- [ ] P2: `array_to_string(arr, delim)` — 配列を文字列に結合
- [ ] P2: `regexp_match(s, pattern)` — 正規表現マッチ
- [ ] P2: `regexp_matches(s, pattern, flags)` — 正規表現全マッチ
- [ ] P2: `regexp_replace(s, pattern, repl)` — 正規表現置換
- [ ] P2: `regexp_split_to_array(s, pattern)` — 正規表現分割
- [ ] P3: `regexp_split_to_table(s, pattern)` — 正規表現分割（テーブル返却）
- [ ] P2: `format(fmt, ...)` — printf形式フォーマット
- [ ] P2: `md5(s)` — MD5ハッシュ
- [ ] P2: `encode(data, format)` / `decode(s, format)` — base64等エンコード
- [ ] P2: `quote_ident(s)` / `quote_literal(s)` — SQL識別子/リテラルのクオート
- [ ] P2: `chr(n)` / `ascii(s)` — 文字コード変換
- [ ] P2: `strpos(s, sub)` — 文字列位置検索（関数版）
- [ ] P2: `translate(s, from, to)` — 文字変換
- [ ] P2: `to_hex(n)` — 16進数文字列変換

### 4.3 日付・時刻関数

- [ ] P1: `now()` / `current_timestamp` — 現在日時
- [ ] P1: `current_date` — 現在日付
- [ ] P2: `current_time` — 現在時刻
- [ ] P1: `extract(field FROM source)` — 日時フィールド抽出
- [ ] P1: `date_part(field, source)` — 日時フィールド抽出（関数版）
- [ ] P1: `date_trunc(field, source)` — 日時切り捨て
- [ ] P2: `age(ts1, ts2)` — 日時差分
- [ ] P2: `make_date(y, m, d)` — 日付作成
- [ ] P2: `make_timestamp(...)` — タイムスタンプ作成
- [ ] P2: `make_timestamptz(...)` — タイムスタンプTZ作成
- [ ] P2: `make_interval(...)` — インターバル作成
- [ ] P2: `to_timestamp(epoch)` — Unixエポックからタイムスタンプ
- [ ] P2: `to_char(ts, format)` — 日時フォーマット
- [ ] P2: `to_date(s, format)` — 文字列から日付変換
- [ ] P2: `to_timestamp(s, format)` — 文字列からタイムスタンプ変換
- [ ] P2: `clock_timestamp()` — 実時刻（文実行中に変化）
- [ ] P2: `statement_timestamp()` — 文開始時刻
- [ ] P2: `transaction_timestamp()` — トランザクション開始時刻
- [ ] P3: `date_bin(interval, ts, origin)` — タイムスタンプのビン化
- [ ] P3: `isfinite(ts/date/interval)` — 有限判定
- [ ] P4: `justify_days/hours/interval` — インターバル正規化
- [ ] P3: `OVERLAPS` — 期間重複判定

### 4.4 集約関数

- [ ] P1: `count(*)` / `count(expr)` — 件数
- [ ] P1: `sum(expr)` — 合計
- [ ] P1: `avg(expr)` — 平均
- [ ] P1: `min(expr)` / `max(expr)` — 最小/最大
- [ ] P2: `bool_and(expr)` / `bool_or(expr)` — 論理集約
- [ ] P2: `every(expr)` — SQL標準のbool_and
- [ ] P2: `array_agg(expr)` — 配列集約
- [ ] P2: `string_agg(expr, delim)` — 文字列連結集約
- [ ] P2: `json_agg(expr)` / `jsonb_agg(expr)` — JSON配列集約
- [ ] P2: `json_object_agg(k, v)` / `jsonb_object_agg(k, v)` — JSONオブジェクト集約
- [ ] P3: `bit_and(expr)` / `bit_or(expr)` / `bit_xor(expr)` — ビット演算集約
- [ ] P3: `any_value(expr)` — 任意の値（PG 16+）
- [ ] P3: `stddev(x)` / `stddev_pop(x)` / `stddev_samp(x)` — 標準偏差
- [ ] P3: `variance(x)` / `var_pop(x)` / `var_samp(x)` — 分散
- [ ] P4: `corr(Y, X)` — 相関係数
- [ ] P4: `covar_pop(Y, X)` / `covar_samp(Y, X)` — 共分散
- [ ] P4: `regr_*` (slope, intercept, r2 等) — 回帰分析関数群
- [ ] P3: `mode() WITHIN GROUP (ORDER BY ...)` — 最頻値
- [ ] P3: `percentile_cont(frac) WITHIN GROUP (ORDER BY ...)` — 連続百分位数
- [ ] P3: `percentile_disc(frac) WITHIN GROUP (ORDER BY ...)` — 離散百分位数

### 4.5 ウィンドウ関数

- [ ] P2: `row_number()` — 行番号
- [ ] P2: `rank()` — ランク（ギャップあり）
- [ ] P2: `dense_rank()` — ランク（ギャップなし）
- [ ] P3: `percent_rank()` — 相対ランク
- [ ] P3: `cume_dist()` — 累積分布
- [ ] P2: `ntile(n)` — n分割
- [ ] P2: `lag(value, offset, default)` — 前行参照
- [ ] P2: `lead(value, offset, default)` — 後行参照
- [ ] P2: `first_value(value)` — フレーム最初の値
- [ ] P2: `last_value(value)` — フレーム最後の値
- [ ] P2: `nth_value(value, n)` — フレームのn番目の値

### 4.6 条件式関数

- [ ] P1: `CASE WHEN ... THEN ... ELSE ... END` — 条件分岐
- [ ] P1: `COALESCE(v1, v2, ...)` — 最初の非NULL値
- [ ] P1: `NULLIF(v1, v2)` — 等しければNULL
- [ ] P1: `GREATEST(v1, v2, ...)` — 最大値
- [ ] P1: `LEAST(v1, v2, ...)` — 最小値

### 4.7 型変換関数

- [ ] P1: `CAST(expr AS type)` — 型変換（SQL標準）
- [ ] P1: `expr::type` — 型変換（PostgreSQL構文）
- [ ] P2: `to_char(n/ts, format)` — 数値/日時→文字列
- [ ] P2: `to_number(s, format)` — 文字列→数値
- [ ] P2: `to_date(s, format)` — 文字列→日付
- [ ] P2: `to_timestamp(s, format)` — 文字列→タイムスタンプ

### 4.8 JSON関数

- [ ] P2: `to_json(val)` / `to_jsonb(val)` — JSON変換
- [ ] P2: `json_build_object(...)` / `jsonb_build_object(...)` — JSONオブジェクト構築
- [ ] P2: `json_build_array(...)` / `jsonb_build_array(...)` — JSON配列構築
- [ ] P2: `json_typeof(json)` — JSON型判定
- [ ] P2: `json_array_length(json)` — JSON配列長
- [ ] P2: `json_array_elements(json)` — JSON配列展開
- [ ] P2: `json_each(json)` / `json_each_text(json)` — JSONオブジェクト展開
- [ ] P2: `json_object_keys(json)` — JSONキー一覧
- [ ] P2: `json_extract_path(json, ...)` — パス指定で値取得
- [ ] P3: `json_populate_record(base, json)` — JSONをレコードに展開
- [ ] P3: `json_to_record(json)` — JSONをレコードに変換
- [ ] P2: `jsonb_set(target, path, new_value)` — JSONB値設定
- [ ] P2: `jsonb_insert(target, path, new_value)` — JSONB値挿入
- [ ] P2: `jsonb_strip_nulls(jsonb)` — JSONBからnull除去
- [ ] P3: `jsonb_path_exists(target, path)` — JSONパス存在判定
- [ ] P3: `jsonb_path_query(target, path)` — JSONパスクエリ
- [ ] P3: `jsonb_pretty(jsonb)` — JSONB整形出力
- [ ] P2: `row_to_json(record)` — レコードをJSONに変換

### 4.9 配列関数

- [ ] P2: `array_length(arr, dim)` — 配列長
- [ ] P2: `array_dims(arr)` — 配列次元
- [ ] P2: `array_lower(arr, dim)` / `array_upper(arr, dim)` — 配列添字範囲
- [ ] P2: `array_append(arr, elem)` — 配列末尾追加
- [ ] P2: `array_prepend(elem, arr)` — 配列先頭追加
- [ ] P2: `array_cat(arr1, arr2)` — 配列連結
- [ ] P2: `array_remove(arr, elem)` — 配列要素削除
- [ ] P2: `array_replace(arr, from, to)` — 配列要素置換
- [ ] P2: `array_position(arr, elem)` — 配列要素位置
- [ ] P2: `array_positions(arr, elem)` — 配列要素全位置
- [ ] P2: `unnest(arr)` — 配列を行に展開
- [ ] P2: `cardinality(arr)` — 配列要素総数

### 4.10 システム情報関数

- [ ] P1: `current_database()` — 現在のデータベース名
- [ ] P1: `current_schema()` — 現在のスキーマ名
- [ ] P2: `current_schemas(include_implicit)` — 検索パスのスキーマ一覧
- [ ] P1: `current_user` / `session_user` — 現在のユーザ
- [ ] P2: `version()` — バージョン文字列
- [ ] P2: `pg_typeof(expr)` — 式の型名
- [ ] P3: `has_table_privilege(...)` — テーブル権限判定
- [ ] P3: `has_schema_privilege(...)` — スキーマ権限判定
- [ ] P4: `pg_table_size(regclass)` — テーブルサイズ
- [ ] P4: `pg_total_relation_size(regclass)` — テーブル＋インデックス合計サイズ
- [ ] P4: `pg_column_size(expr)` — 値のストレージサイズ
- [ ] P3: `txid_current()` — 現在のトランザクションID
- [ ] P2: `pg_backend_pid()` — バックエンドプロセスID

### 4.11 シーケンス関数

- [ ] P1: `nextval(regclass)` — 次のシーケンス値
- [ ] P2: `currval(regclass)` — 現在のシーケンス値
- [ ] P2: `setval(regclass, bigint)` — シーケンス値設定
- [ ] P2: `lastval()` — 最後に取得したシーケンス値

### 4.12 集合返却関数

- [ ] P2: `generate_series(start, stop, step)` — 連番生成（整数/タイムスタンプ）
- [ ] P3: `generate_subscripts(arr, dim)` — 配列添字生成

## 5. クエリ構文・機能

### 5.1 SELECT の構成要素

- [ ] P1: `SELECT *` / `SELECT expr` — 基本的なカラム選択
- [ ] P1: `SELECT DISTINCT` — 重複排除
- [ ] P2: `SELECT DISTINCT ON (expr)` — PostgreSQL拡張の重複排除
- [ ] P1: `FROM` — テーブル指定
- [ ] P1: `WHERE` — 条件指定
- [ ] P1: `GROUP BY` — グループ化
- [ ] P3: `GROUP BY GROUPING SETS` — グルーピングセット
- [ ] P3: `GROUP BY ROLLUP` — ロールアップ集計
- [ ] P3: `GROUP BY CUBE` — キューブ集計
- [ ] P1: `HAVING` — グループ条件
- [ ] P1: `ORDER BY` — ソート
- [ ] P2: `ORDER BY ... NULLS FIRST/LAST` — NULLのソート順指定
- [ ] P1: `LIMIT` / `FETCH FIRST n ROWS` — 行数制限
- [ ] P1: `OFFSET` — オフセット
- [ ] P1: テーブルエイリアス (`AS`) — テーブル/カラム別名

### 5.2 JOIN

- [ ] P1: `INNER JOIN ... ON` — 内部結合
- [ ] P1: `LEFT [OUTER] JOIN ... ON` — 左外部結合
- [ ] P1: `RIGHT [OUTER] JOIN ... ON` — 右外部結合
- [ ] P2: `FULL [OUTER] JOIN ... ON` — 完全外部結合
- [ ] P1: `CROSS JOIN` — 直積
- [ ] P2: `NATURAL JOIN` — 自然結合
- [ ] P2: `JOIN ... USING (col)` — USING句による結合
- [ ] P3: `LATERAL JOIN` — ラテラル結合
- [ ] P1: 自己結合 — テーブルの自己参照結合

### 5.3 サブクエリ

- [ ] P1: スカラーサブクエリ — 単一値を返すサブクエリ
- [ ] P1: `IN (subquery)` — サブクエリ内存在判定
- [ ] P1: `NOT IN (subquery)` — サブクエリ内非存在判定
- [ ] P1: `EXISTS (subquery)` — サブクエリ結果存在判定
- [ ] P1: `NOT EXISTS (subquery)` — サブクエリ結果非存在判定
- [ ] P2: `ANY/SOME (subquery)` — サブクエリとの比較（いずれか）
- [ ] P2: `ALL (subquery)` — サブクエリとの比較（すべて）
- [ ] P2: 相関サブクエリ — 外部クエリ参照サブクエリ
- [ ] P1: FROM句のサブクエリ（派生テーブル） — インラインビュー

### 5.4 集合演算

- [ ] P1: `UNION` — 和集合（重複排除）
- [ ] P1: `UNION ALL` — 和集合（重複含む）
- [ ] P2: `INTERSECT` — 積集合
- [ ] P3: `INTERSECT ALL` — 積集合（重複含む）
- [ ] P2: `EXCEPT` — 差集合
- [ ] P3: `EXCEPT ALL` — 差集合（重複含む）

### 5.5 CTE (Common Table Expressions)

- [ ] P2: `WITH ... AS (SELECT ...)` — 基本CTE
- [ ] P2: `WITH RECURSIVE ...` — 再帰CTE
- [ ] P3: `WITH ... AS MATERIALIZED` — マテリアライズCTE
- [ ] P3: `WITH ... AS NOT MATERIALIZED` — 非マテリアライズCTE
- [ ] P3: CTE内のDML (`INSERT/UPDATE/DELETE`) — 書き込みCTE
- [ ] P3: `SEARCH DEPTH/BREADTH FIRST` — 再帰探索順序
- [ ] P3: `CYCLE ... SET ... USING ...` — サイクル検出

### 5.6 ウィンドウ関数構文

- [ ] P2: `OVER (PARTITION BY ... ORDER BY ...)` — 基本ウィンドウ指定
- [ ] P2: `OVER (ORDER BY ...)` — パーティションなしウィンドウ
- [ ] P2: `ROWS BETWEEN ... AND ...` — 行ベースフレーム
- [ ] P3: `RANGE BETWEEN ... AND ...` — 値ベースフレーム
- [ ] P3: `GROUPS BETWEEN ... AND ...` — グループベースフレーム
- [ ] P3: `WINDOW w AS (...)` — 名前付きウィンドウ定義
- [ ] P4: `EXCLUDE CURRENT ROW / GROUP / TIES / NO OTHERS` — フレーム排除指定

### 5.7 その他のクエリ機能

- [ ] P2: `VALUES (...)` — 値リスト
- [ ] P2: `TABLE tablename` — `SELECT * FROM tablename` の省略形
- [ ] P2: `FOR UPDATE` / `FOR SHARE` — 行ロック
- [ ] P3: `FOR NO KEY UPDATE` / `FOR KEY SHARE` — 行ロック（キー考慮）
- [ ] P1: 型キャスト (`::`) — PostgreSQL形式型変換
- [ ] P1: `IN (value_list)` — 値リスト内存在判定
- [ ] P1: `BETWEEN a AND b` — 範囲判定
- [ ] P1: `LIKE` / `ILIKE` パターン — ワイルドカード検索
- [ ] P2: `SIMILAR TO` パターン — SQL正規表現
- [ ] P2: `RETURNING *` — DML結果返却

## 6. インデックス

### 5.7 その他のクエリ機能

- [ ] P1: B-tree — デフォルト。等価・範囲検索
- [ ] P2: Hash — 等価検索のみ
- [ ] P3: GiST — 幾何データ、全文検索、範囲型
- [ ] P4: SP-GiST — 不均衡データ構造
- [ ] P2: GIN — 配列、JSONB、全文検索
- [ ] P3: BRIN — ブロック範囲サマリ
- [ ] P4: Bloom — ブルームフィルタ

### インデックス機能

- [ ] P2: `CREATE INDEX` — 基本インデックス作成
- [ ] P2: `CREATE UNIQUE INDEX` — ユニークインデックス
- [ ] P3: `CREATE INDEX ... ON (expr)` — 式インデックス
- [ ] P3: `CREATE INDEX ... WHERE ...` — 部分インデックス
- [ ] P4: `CREATE INDEX CONCURRENTLY` — 並行インデックス作成
- [ ] P2: 複合インデックス — 複数カラムインデックス
- [ ] P3: カバリングインデックス (`INCLUDE`) — インデックスオンリースキャン用

## 7. 制約

### インデックス機能

- [ ] P1: `NOT NULL` — NULL不許可
- [ ] P1: `UNIQUE` — 一意制約
- [ ] P1: `PRIMARY KEY` — 主キー（NOT NULL + UNIQUE）
- [ ] P2: `FOREIGN KEY ... REFERENCES` — 外部キー
- [ ] P2: `ON DELETE CASCADE/SET NULL/RESTRICT/NO ACTION` — 外部キー削除動作
- [ ] P2: `ON UPDATE CASCADE/SET NULL/RESTRICT/NO ACTION` — 外部キー更新動作
- [ ] P2: `CHECK (expr)` — チェック制約
- [ ] P1: `DEFAULT value` — デフォルト値
- [ ] P3: `GENERATED ALWAYS AS (expr) STORED` — 生成カラム
- [ ] P2: `GENERATED ALWAYS AS IDENTITY` — IDENTITY カラム
- [ ] P3: `EXCLUDE USING ...` — 排他制約
- [ ] P3: `DEFERRABLE` / `INITIALLY DEFERRED` — 遅延制約評価

## 8. トランザクション・同時実行制御

### 8.1 トランザクション分離レベル

- [ ] P1: `READ COMMITTED` — デフォルト。コミット済みデータのみ読取
- [ ] P2: `REPEATABLE READ` — トランザクション開始時のスナップショット
- [ ] P3: `SERIALIZABLE` — 直列化可能分離レベル
- [ ] P4: `READ UNCOMMITTED` — PGでは `READ COMMITTED` と同等

### 8.2 MVCC (Multi-Version Concurrency Control)

- [ ] P1: スナップショット分離 — トランザクション間のデータ可視性管理
- [ ] P2: 行バージョニング — 同一行の複数バージョン管理
- [ ] P2: デッドロック検出 — 循環待ちの検出と解消

### 8.3 ロック

- [ ] P2: 行レベルロック (`FOR UPDATE` 等) — SELECT時の行ロック
- [ ] P3: テーブルレベルロック (`LOCK TABLE`) — 明示的テーブルロック
- [ ] P3: アドバイザリーロック (`pg_advisory_lock`) — アプリケーション定義ロック

## 9. システムカタログ・情報スキーマ

### 9.1 最低限必要なシステムカタログ

- [ ] P1: `pg_catalog.pg_class` — テーブル・インデックス等の一覧
- [ ] P1: `pg_catalog.pg_attribute` — カラム定義
- [ ] P1: `pg_catalog.pg_type` — データ型定義
- [ ] P1: `pg_catalog.pg_namespace` — スキーマ定義
- [ ] P2: `pg_catalog.pg_index` — インデックス情報
- [ ] P2: `pg_catalog.pg_constraint` — 制約情報
- [ ] P2: `pg_catalog.pg_sequence` — シーケンス情報
- [ ] P2: `pg_catalog.pg_depend` — オブジェクト依存関係
- [ ] P3: `pg_catalog.pg_proc` — 関数・プロシージャ定義
- [ ] P3: `pg_catalog.pg_trigger` — トリガー定義
- [ ] P2: `pg_catalog.pg_description` — オブジェクトコメント
- [ ] P2: `pg_catalog.pg_settings` — サーバ設定パラメータ
- [ ] P2: `pg_catalog.pg_database` — データベース一覧
- [ ] P3: `pg_catalog.pg_roles` — ロール一覧
- [ ] P3: `pg_catalog.pg_stat_user_tables` — テーブル統計情報
- [ ] P3: `pg_catalog.pg_stat_activity` — アクティブセッション
- [ ] P3: `pg_catalog.pg_locks` — ロック情報
- [ ] P2: `pg_catalog.pg_enum` — ENUM型の値一覧
- [ ] P2: `pg_catalog.pg_attrdef` — カラムデフォルト値
- [ ] P2: `pg_catalog.pg_views` — ビュー一覧

### 9.2 情報スキーマ (information_schema)

- [ ] P1: `information_schema.tables` — テーブル一覧
- [ ] P1: `information_schema.columns` — カラム一覧
- [ ] P2: `information_schema.table_constraints` — テーブル制約一覧
- [ ] P2: `information_schema.key_column_usage` — キーカラム使用状況
- [ ] P2: `information_schema.referential_constraints` — 外部キー制約
- [ ] P2: `information_schema.constraint_column_usage` — 制約カラム使用状況
- [ ] P2: `information_schema.schemata` — スキーマ一覧
- [ ] P2: `information_schema.views` — ビュー一覧
- [ ] P2: `information_schema.sequences` — シーケンス一覧
- [ ] P3: `information_schema.routines` — 関数・プロシージャ一覧
- [ ] P3: `information_schema.parameters` — 関数パラメータ
- [ ] P3: `information_schema.check_constraints` — チェック制約
- [ ] P3: `information_schema.domains` — ドメイン一覧
- [ ] P3: `information_schema.triggers` — トリガー一覧

## 10. ワイヤープロトコル

### 10.1 接続フェーズ

- [ ] P1: StartupMessage — 接続開始（バージョン、パラメータ）
- [ ] P1: AuthenticationOk — 認証成功
- [ ] P2: AuthenticationCleartextPassword — 平文パスワード認証
- [ ] P2: AuthenticationMD5Password — MD5パスワード認証
- [ ] P3: AuthenticationSASL — SCRAM-SHA-256認証
- [ ] P1: ParameterStatus — サーバパラメータ通知
- [ ] P2: BackendKeyData — バックエンドキー（キャンセル用）
- [ ] P1: ReadyForQuery — クエリ受付可能通知
- [ ] P2: SSLRequest — SSL接続要求
- [ ] P2: CancelRequest — クエリキャンセル要求

### 10.2 Simple Query Protocol

- [ ] P1: Query (F) — SQL文送信
- [ ] P1: RowDescription (B) — 結果カラム情報
- [ ] P1: DataRow (B) — 結果データ行
- [ ] P1: CommandComplete (B) — コマンド完了通知
- [ ] P1: EmptyQueryResponse (B) — 空クエリ応答
- [ ] P1: ErrorResponse (B) — エラー通知
- [ ] P2: NoticeResponse (B) — 警告/通知

### 10.3 Extended Query Protocol

- [ ] P2: Parse (F) — プリペアド文パース
- [ ] P2: ParseComplete (B) — パース完了
- [ ] P2: Bind (F) — パラメータバインド
- [ ] P2: BindComplete (B) — バインド完了
- [ ] P2: Describe (F) — ポータル/ステートメント記述要求
- [ ] P2: ParameterDescription (B) — パラメータ型情報
- [ ] P2: Execute (F) — 実行
- [ ] P2: Close (F) — ポータル/ステートメント閉鎖
- [ ] P2: CloseComplete (B) — 閉鎖完了
- [ ] P2: Sync (F) — 同期要求
- [ ] P2: Flush (F) — フラッシュ要求

### 10.4 COPY Protocol

- [ ] P3: CopyInResponse (B) — COPYインバウンド開始
- [ ] P3: CopyOutResponse (B) — COPYアウトバウンド開始
- [ ] P3: CopyData (F/B) — COPYデータ
- [ ] P3: CopyDone (F/B) — COPY完了
- [ ] P3: CopyFail (F) — COPY失敗

### 10.5 Notification Protocol

- [ ] P3: NotificationResponse (B) — LISTEN/NOTIFY通知

## 11. その他の機能

### 11.1 手続き言語

- [ ] P3: PL/pgSQL — PostgreSQL標準手続き言語
- [ ] P4: PL/Python — Python手続き言語
- [ ] P4: PL/Perl — Perl手続き言語
- [ ] P2: SQL関数 — SQL言語による関数定義

### 11.2 拡張機能 (Extensions)

- [ ] P3: `pgcrypto` — 暗号化関数
- [ ] P2: `uuid-ossp` — UUID生成関数（`gen_random_uuid()` はPG 13+で標準）
- [ ] P3: `hstore` — キー/値ストア型
- [ ] P3: `pg_trgm` — トライグラム類似度検索
- [ ] P3: `btree_gist` / `btree_gin` — B-tree演算子のGiST/GINインデックス対応
- [ ] P3: `citext` — 大文字小文字区別なしテキスト型
- [ ] P4: `tablefunc` — クロスタブ・ピボット
- [ ] P4: `unaccent` — アクセント除去
- [ ] P3: `pgvector` — ベクトル型・近似最近傍検索

### 11.3 パーティショニング

- [ ] P3: RANGE パーティション — 範囲ベースパーティション
- [ ] P3: LIST パーティション — リストベースパーティション
- [ ] P3: HASH パーティション — ハッシュベースパーティション
- [ ] P3: デフォルトパーティション — 未分類行用パーティション

### 11.4 行レベルセキュリティ (RLS)

- [ ] P3: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` — RLS有効化
- [ ] P3: `CREATE POLICY` — ポリシー作成
- [ ] P3: `ALTER POLICY` — ポリシー変更
- [ ] P3: `DROP POLICY` — ポリシー削除

### 11.5 その他

- [ ] P2: `gen_random_uuid()` — UUIDv4 生成（PG 13+標準）
- [ ] P2: `GENERATED ALWAYS AS IDENTITY` — アイデンティティカラム
- [ ] P4: テーブル継承 (`INHERITS`) — レガシー機能
- [ ] P4: `TABLESAMPLE` — テーブルサンプリング
- [ ] P4: 外部データラッパー (FDW) — 外部データアクセス
- [ ] P4: 論理レプリケーション — インメモリでは不要
- [ ] P4: 物理レプリケーション — インメモリでは不要
