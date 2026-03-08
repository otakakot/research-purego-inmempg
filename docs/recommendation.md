# 推奨アーキテクチャと結論

[← README に戻る](../README.md)

---

## 推奨アーキテクチャ

### 短期的（テスト用途）: DoltgreSQL活用

現時点で最も実用的なのは、**DoltgreSQL をライブラリ的に利用**する方法である。

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

## 結論

### 現状の課題

**Go製のインメモリ・インプロセスPostgreSQLを「完全にPure Goで」実現するのは、現時点では非常に困難**である。

その理由:
- PostgreSQLの互換性は、パーサーだけでなく**実行エンジン**の膨大な実装を必要とする
  - 型システム（数十種類の組み込み型）
  - 関数（数百種類の組み込み関数）
  - 演算子（型ごとの演算子オーバーロード）
  - 暗黙の型キャスト
  - トランザクション分離レベル（Read Committed, Repeatable Read, Serializable）
  - 制約（CHECK, UNIQUE, FOREIGN KEY, EXCLUSION）
- 既存のPure Go SQLエンジン（ramsql等）はPostgreSQL互換性が低い
- DoltgreSQL は最も近い存在だが、ライブラリ化が想定されていない

### 実用的な選択肢

**用途を限定する**ことで実用的なソリューションは構築可能:

| 用途 | 推奨アプローチ | 理由 |
|------|-------------|------|
| テスト（高互換性） | DoltgreSQL インプロセス起動 | 91%+ PG互換性、Pure Go |
| テスト（基本SQL） | ramsql 利用 | 完全インプロセス・インメモリ、簡単 |
| テスト（完全互換） | embedded-postgres | 本物のPostgreSQL、確実 |
| プロダクション | 素直にPostgreSQLを使う | - |

### 注目すべき新技術

以下の組み合わせが、Pure Go フルスタックアプローチの基盤として最も有望:

- **[pgplex/pgparser](https://github.com/pgplex/pgparser)**: Pure Go、PostgreSQL 17.7互換パーサー（99.6%回帰テスト通過）
- **[psql-wire](https://github.com/jeroenrinzema/psql-wire)**: Pure Go、PostgreSQLワイヤープロトコル実装

この2つが揃ったことで、残る課題は**クエリ実行エンジンの実装**に集約される。コミュニティの成長やAIによるコード生成技術の進歩により、将来的に実現可能性は高まっていくと考えられる。

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

[← README に戻る](../README.md)
