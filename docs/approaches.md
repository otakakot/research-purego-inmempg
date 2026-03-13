# 実現アプローチの比較

[← README に戻る](../README.md)

> **注**: 本ドキュメント中のPostgreSQLソースコードへの参照は、PostgreSQL 19devel（Copyright © 2026）のソースコード調査に基づいている。ソースコードは https://github.com/postgres/postgres から参照可能。

---

## アプローチ一覧

1. [Pure Go フルスタック](#アプローチ-1-pure-go-フルスタック)
2. [DoltgreSQL ライブラリ化](#アプローチ-2-doltgresql-ライブラリ化)
3. [WASM (wazero + PGlite)](#アプローチ-3-wasm-wazero--pglite)
4. [purego + libpostgres](#アプローチ-4-purego--libpostgres)
5. [embedded-postgres 方式（参考）](#アプローチ-5-embedded-postgres-方式参考)

---

## アプローチ 1: Pure Go フルスタック

### アーキテクチャ

```
pgx / database-sql クライアント
        ↓
psql-wire (ワイヤープロトコル)
        ↓
pgplex/pgparser (SQLパーサー)
        ↓
独自クエリ実行エンジン
        ↓
インメモリストレージ
```

### 評価

| 評価項目 | 評価 | 詳細 |
|---------|------|------|
| Pure Go | ✅ | 完全にPure Go、CGo不要 |
| インプロセス | ✅ | ただしTCP/Unixソケットまたはnet.Pipe()経由 |
| インメモリ | ✅ | 完全なインメモリ動作 |
| PostgreSQL互換性 | ⚠️ | 実行エンジンの実装範囲に依存 |
| 実装コスト | 🔴 非常に大きい | クエリ実行エンジンの実装が最大のボトルネック |
| クロスコンパイル | ✅ | 完全対応 |

### 利用する主要ライブラリ

- **ワイヤープロトコル**: [jeroenrinzema/psql-wire](https://github.com/jeroenrinzema/psql-wire)
- **SQLパーサー**: [pgplex/pgparser](https://github.com/pgplex/pgparser)（PG 17.7ベース。なおPG 19develの`gram.y`は20,059行、`scan.l`は1,421行、バックエンド全体で約417,000行/32サブディレクトリ）
- **実行エンジン**: 独自実装

### 段階的実装プラン（MVP）

1. **Phase 1**: 基本的なDDL/DML
   - CREATE TABLE / DROP TABLE
   - INSERT / SELECT / UPDATE / DELETE
   - 基本データ型（TEXT, INTEGER, BOOLEAN, TIMESTAMP）
   - WHERE句（基本比較演算子）

2. **Phase 2**: クエリ機能の拡充
   - JOIN（INNER, LEFT, RIGHT）
   - サブクエリ
   - 集約関数（COUNT, SUM, AVG, MAX, MIN）
   - GROUP BY / HAVING
   - ORDER BY / LIMIT / OFFSET

3. **Phase 3**: 高度な機能
   - トランザクション（BEGIN, COMMIT, ROLLBACK）
   - インデックス（B-Tree, Hash）
   - SERIAL / BIGSERIAL
   - UNIQUE / NOT NULL制約

4. **Phase 4**: PostgreSQL固有機能
   - 組み込み関数（文字列, 日時, 数値）
   - 暗黙の型キャスト
   - ARRAY型
   - JSONB型

### リスクと課題

- クエリ実行エンジンの実装量が膨大
- PostgreSQLの細かい挙動（暗黙キャスト、NULL処理等）の再現が困難
  - 暗黙キャスト: `src/backend/parser/parse_coerce.c` に実装されており、型変換ルールが複雑
  - NULL処理: `src/backend/executor/` 全体（65ファイル）に三値論理が浸透
  - 型システム: `src/backend/utils/adt/`（119ファイル）に各データ型の演算・変換が実装
- PostgreSQLのバックエンドコードは `src/backend/` 配下に32サブディレクトリ、約417,000行あり、完全な再現は非現実的
- 単独開発では現実的な期間での完成が難しい

---

## アプローチ 2: DoltgreSQL ライブラリ化

### アーキテクチャ

```
pgx クライアント
        ↓
DoltgreSQL (ワイヤープロトコル + パーサー + 実行エンジン)
        ↓
インメモリストレージ (go-mysql-server のメモリバックエンド)
```

### 評価

| 評価項目 | 評価 | 詳細 |
|---------|------|------|
| Pure Go | ✅ | DoltgreSQL自体がPure Go |
| インプロセス | ⚠️ | サーバーをgoroutineで起動、TCP経由で接続 |
| インメモリ | ✅ | ストレージバックエンドをインメモリに設定可能 |
| PostgreSQL互換性 | ⭕ 91%+ | SQLlogictest で 91.17% の正確性 |
| 実装コスト | 🟡 中程度 | ライブラリ化の改修が必要 |
| クロスコンパイル | ✅ | 完全対応 |

### 概念的なAPI

```go
func TestSomething(t *testing.T) {
    // DoltgreSQL をインプロセスで起動（ランダムポート）
    pg, err := inmempg.Start()
    defer pg.Stop()

    // 標準的な pgx で接続
    conn, err := pgx.Connect(ctx, pg.ConnectionString())

    // テスト実行
    conn.Exec(ctx, "CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT)")
    conn.Exec(ctx, "INSERT INTO users (name) VALUES ('Alice')")
}
```

### 実装ステップ

1. DoltgreSQL のサーバー起動ロジックをインプロセスgoroutineとして利用
2. ランダムポートでTCPリスナーを起動
3. インメモリストレージバックエンドの設定（Doltのバージョン管理機能を無効化）
4. テストヘルパー関数としてラップ

### リスクと課題

- DoltgreSQL の内部APIが安定していない可能性（Betaステータス）
- Doltのバージョン管理機能との分離が困難な場合がある
- 依存パッケージが非常に大きくなる（バイナリサイズへの影響）
- DoltgreSQL のアップストリーム変更への追従コスト
- DoltgreSQLは特定のPGバージョンを追跡しており、PostgreSQL 19develで追加された新機能・文法はカバーされていない可能性がある

---

## アプローチ 3: WASM (wazero + PGlite)

### アーキテクチャ

```
Go アプリケーション
        ↓
wazero (WASM ランタイム, Pure Go)
        ↓
PGlite WASM モジュール (= 本物の PostgreSQL)
        ↓
インメモリストレージ (WASM メモリ空間)
```

### 評価

| 評価項目 | 評価 | 詳細 |
|---------|------|------|
| Pure Go | ⚠️ | wazero自体はPure Goだが、WASMモジュールのビルドにEmscripten必要 |
| インプロセス | ✅ | WASMモジュールはGoプロセス内で実行 |
| インメモリ | ✅ | WASM メモリ空間で完全インメモリ動作 |
| PostgreSQL互換性 | ✅ | 本物のPostgreSQLコード |
| 実装コスト | 🔴 大きい | Emscripten JS ブリッジの再実装が必要 |
| クロスコンパイル | ⚠️ | WASMバイナリは固定だがwazeroはPure Go |

### 技術的課題

1. **Emscripten JSブリッジの再実装**
   - PGliteはEmscriptenのJavaScript相互運用層に依存
   - この層をGoで再実装する必要がある（最大の障壁）

2. **WASI互換性**
   - PGliteのWASMモジュールが使用するWASI拡張とwazeroのサポートの整合性
   - ファイルシステム、ネットワーク、スレッド等のエミュレーション

3. **データ通信インターフェース**
   - PostgreSQL ↔ Go 間でSQL文とクエリ結果を効率的にやり取りする仕組み
   - PGliteの入出力パスウェイの理解と再利用

### PGlite の動作原理（参考）

PostgreSQLは通常プロセスフォークモデルだが、Emscripten/WASMではフォーク不可。PGliteはPostgreSQLの「シングルユーザーモード」を利用し、JavaScript環境からの入出力パスウェイを設けている。

### リスクと課題

- Emscripten JS 層の Go への移植の技術的難易度が高い
- WASMの実行パフォーマンスオーバーヘッド
- PGliteのアップストリーム変更への追従
- デバッグの困難さ（WASM内部の問題切り分け）

---

## アプローチ 4: purego + libpostgres

### アーキテクチャ

```
Go アプリケーション
        ↓
ebitengine/purego (FFI, CGo不要)
        ↓
PostgreSQL 共有ライブラリ (.so/.dylib)
        ↓
インメモリモード (RAMディスク or tmpfs)
```

### ebitengine/purego について

[purego](https://github.com/ebitengine/purego) はCGo無しでC関数を呼び出すためのGoライブラリ。Ebitengineゲームエンジンから生まれたプロジェクトで、`CGO_ENABLED=0` でのクロスコンパイルを実現する。

```go
libc, _ := purego.Dlopen("/usr/lib/libSystem.B.dylib", purego.RTLD_NOW|purego.RTLD_GLOBAL)
var puts func(string)
purego.RegisterLibFunc(&puts, libc, "puts")
puts("Calling C from Go without Cgo!")
```

### 評価

| 評価項目 | 評価 | 詳細 |
|---------|------|------|
| Pure Go（ビルド時） | ✅ | CGo不要でビルド可能 |
| インプロセス | ⚠️ | PostgreSQLは共有ライブラリとしてのエンベッド設計ではない |
| インメモリ | ⚠️ | tmpfs等を介した疑似インメモリ |
| PostgreSQL互換性 | ✅ | 本物のPostgreSQL |
| 実装コスト | 🔴 極大 | PostgreSQLの内部APIを直接呼び出す必要があり非常に困難 |
| クロスコンパイル | ❌ | プラットフォームごとの共有ライブラリが必要 |

### 技術的課題

1. **PostgreSQLはエンベッド設計ではない**: PostgreSQLの内部関数はライブラリとして利用されることを想定していない
2. **膨大なAPI surface**: PostgreSQLの内部APIは非公開で不安定
3. **グローバルステート**: PostgreSQLは多くのグローバル変数を使用しており、ライブラリとしての利用が困難
4. **共有ライブラリの配布**: プラットフォームごとの共有ライブラリを用意・配布する必要がある
5. **初期化の複雑さ**: PostgreSQLのサーバー初期化シーケンスは複雑

### リスクと課題

- PostgreSQL のバージョンアップに伴う内部API変更への対応
- メモリ管理の問題（GoのGCとPostgreSQLのmalloc/freeの共存）
- 安定性の保証が困難

---

## アプローチ 5: embedded-postgres 方式（参考）

### アーキテクチャ

```
Go アプリケーション
        ↓
embedded-postgres (プロセス管理)
        ↓
PostgreSQL バイナリ (子プロセス)
```

### 評価

| 評価項目 | 評価 | 詳細 |
|---------|------|------|
| Pure Go | ⚠️ | Go自体はPure Goだがバイナリのダウンロードが必要 |
| インプロセス | ❌ | 子プロセスとして起動 |
| インメモリ | ❌ | ディスクベース（RuntimePathを使用） |
| PostgreSQL互換性 | ✅ | 本物のPostgreSQL |
| 実装コスト | 🟢 既存 | 既存ライブラリそのまま利用 |
| クロスコンパイル | ❌ | プラットフォーム依存のバイナリが必要 |

### 用途

要件を満たさない（インプロセスでもインメモリでもない）が、**最も確実にPostgreSQL互換のテスト環境を構築**できる方法として参考に含める。CIやローカルテスト環境での利用実績が豊富。

---

## 比較サマリー

| アプローチ | Pure Go | インプロセス | インメモリ | PG互換性 | 実装コスト | 推奨度 |
|-----------|---------|------------|----------|---------|-----------|--------|
| 1. Pure Go フルスタック | ✅ | ✅ | ✅ | ⚠️ | 🔴 極大 | 長期目標 |
| 2. DoltgreSQL活用 | ✅ | ⚠️ | ✅ | ⭕ 91%+ | 🟡 中 | ⭐ 短期推奨 |
| 3. WASM (wazero) | ⚠️ | ✅ | ✅ | ✅ | 🔴 大 | 中長期有望 |
| 4. purego + libpostgres | ⚠️ | ⚠️ | ⚠️ | ✅ | 🔴 極大 | 非推奨 |
| 5. embedded-postgres | ⚠️ | ❌ | ❌ | ✅ | 🟢 小 | 確実だが要件外 |

---

[← README に戻る](../README.md)
