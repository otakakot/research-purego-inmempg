# 推奨アーキテクチャ

[← README に戻る](../README.md)

---

## 推奨アーキテクチャ

### 短期的（テスト用途）: DoltgreSQL活用

現時点で最も実用的なのは、**DoltgreSQL をライブラリ的に利用**する方法である。

> **⚠️ 注意**: DoltgreSQL は2025年4月にBeta品質に到達したばかりであり、API の安定性は保証されていない。Beta ステータスのため、バージョンアップ時に破壊的変更が発生するリスクがある点に留意すること。

```go
// 概念的なAPI
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

**実装ステップ**:
1. DoltgreSQL のサーバー起動ロジックをインプロセスgoroutineとして利用
2. ランダムポートでTCPリスナーを起動
3. インメモリストレージバックエンドの設定
4. テストヘルパー関数としてラップ

---

### 中長期的（フル互換を目指す場合）: WASM

PostgreSQLの完全な互換性が必要な場合は、**wazero + PGlite WASM** アプローチが将来的に最も有望。

**解決すべき技術的課題**:
1. PGlite の Emscripten JavaScript ブリッジを Go で再実装
2. wazero の WASI サポートとの整合性確保
3. PostgreSQL ↔ Go 間のデータ通信インターフェースの設計

---

### 野心的（OSS貢献レベル）: Pure Go フルスタック

最も理想的だが最も困難なアプローチ。以下の組み合わせでMVPを構築できる可能性がある:

```
psql-wire + pgplex/pgparser + 独自実行エンジン
```

**MVPのスコープ**（段階的に実装）:

| Phase | 内容 |
|-------|------|
| Phase 1 | 基本的なDDL/DML（CREATE TABLE, INSERT, SELECT, UPDATE, DELETE） |
| Phase 2 | JOIN, サブクエリ, 集約関数 |
| Phase 3 | トランザクション, インデックス |
| Phase 4 | PostgreSQL組み込み関数, 型キャスト |

---

## PostgreSQL ソースコード参照

https://github.com/postgres/postgres から PostgreSQL 19devel のソースコードを参照可能。詳細は [ソースコード概要](pg-source-overview.md)、[アーキテクチャ詳解](pg-architecture.md)、[インメモリ実装への示唆](pg-source-for-inmem.md) を参照。

---

## 関連プロジェクトリンク集

| プロジェクト | 用途 | URL |
|------------|------|-----|
| embedded-postgres | PGバイナリ実行 | https://github.com/fergusstrange/embedded-postgres |
| DoltgreSQL | PG互換DBサーバー | https://github.com/dolthub/doltgresql |
| go-mysql-server | SQLエンジン | https://github.com/dolthub/go-mysql-server |
| ramsql | インメモリSQL | https://github.com/proullon/ramsql |
| PGlite | PG WASM化 | https://github.com/electric-sql/pglite |
| psql-wire | PGワイヤープロトコル | https://github.com/jeroenrinzema/psql-wire |
| pgplex/pgparser | Pure Go PGパーサー | https://github.com/pgplex/pgparser |
| auxten/postgresql-parser | CRDB由来PGパーサー | https://github.com/auxten/postgresql-parser |
| pg_query_go | PGパーサー(CGo) | https://github.com/pganalyze/pg_query_go |
| ebitengine/purego | CGo不要FFI | https://github.com/ebitengine/purego |
| wazero | Go製WASMランタイム | https://github.com/tetratelabs/wazero |

---

## 関連ドキュメント

- [PostgreSQL ソースコード概要](pg-source-overview.md) — PostgreSQL 19devel のソースコード構成と主要コンポーネント
- [PostgreSQL アーキテクチャ詳解](pg-architecture.md) — プロセスモデル、メモリ管理、クエリ処理パイプライン
- [インメモリ実装への示唆](pg-source-for-inmem.md) — PostgreSQL ソースコードから得られるインメモリ実装のヒント

---

[← README に戻る](../README.md)
