# Go製インメモリ・インプロセスPostgreSQLの実現可能性調査

## 概要

本ドキュメントは、Go言語でインメモリかつインプロセスで動作するPostgreSQL互換データベースを実装するための技術調査レポートである。CGo不要（Pure Go）での実現を主眼に置きつつ、各アプローチの実現可能性・トレードオフを整理する。

---

## 目次

| セクション | 内容 |
|-----------|------|
| [既存プロジェクトの調査](docs/existing-projects.md) | embedded-postgres, DoltgreSQL, ramsql, PGlite, psql-wire の詳細分析 |
| [主要コンポーネント分析](docs/components.md) | ワイヤープロトコル、SQLパーサー、実行エンジン、ストレージ、接続方式 |
| [実現アプローチの比較](docs/approaches.md) | 5つのアプローチの詳細な評価と比較 |
| [推奨アーキテクチャ](docs/recommendation.md) | 短期・中長期の推奨事項、関連リンク集 |
| [ライブラリ詳細リファレンス](docs/libraries.md) | 全11プロジェクトのライセンス・依存関係・バージョン情報 |
| [PostgreSQL機能一覧](docs/pg-features.md) | 実装すべき640+の機能を優先度付きで網羅的に整理 |
| [実装TODOリスト](docs/todo.md) | 全536機能のチェックリスト（Phase 1/2/3） |
| [互換性テスト手法](docs/compatibility-testing.md) | PG回帰テスト、SQLLogicTest、差分テスト等のテスト戦略 |
| **実装詳細調査** | |
| [psql-wire 詳細分析](docs/deep-dive-psql-wire.md) | ハンドラAPI、型システム、Extended Query Protocol、認証、並列パイプライニング |
| [pgparser 詳細分析](docs/deep-dive-pgparser.md) | 210 ASTノード型、パーサーAPI、式の表現、ゼロ依存アーキテクチャ |
| [クエリ実行エンジン詳細](docs/deep-dive-engine.md) | go-mysql-server の5層アーキテクチャ、主要インターフェース、最適化ルール |
| [インプロセス接続パターン](docs/deep-dive-connection.md) | net.Pipe() + pgx DialFunc、カスタムListener、統合パターン |

---

## 背景と目的

Go言語でのテストやローカル開発において、実際のPostgreSQLサーバーを起動せずに、インメモリ・インプロセスでPostgreSQL互換のSQLエンジンを利用したいというニーズがある。理想的な要件は以下の通り：

- **インプロセス**: 別プロセスの起動が不要で、Go の `*sql.DB` や `pgx` から直接接続可能
- **インメモリ**: ディスクI/O不要で高速に動作
- **PostgreSQL互換**: PostgreSQLの構文・型システム・関数をできる限り忠実に再現
- **Pure Go（CGo不要）**: クロスコンパイル容易、ビルド時にCコンパイラ不要
- **軽量**: テスト用途に適した起動速度・メモリ消費

---

## 調査対象プロジェクト

> 詳細: [既存プロジェクトの調査](docs/existing-projects.md)

| プロジェクト | Star | 方式 | Pure Go | インプロセス | PG互換性 | ライセンス |
|------------|------|------|---------|------------|---------|-----------|
| [embedded-postgres](https://github.com/fergusstrange/embedded-postgres) | 1,149 | バイナリ子プロセス | ⚠️ | ❌ | ✅ 100% | MIT |
| [DoltgreSQL](https://github.com/dolthub/doltgresql) | 1,668 | Go製PG互換DB | ✅ | ⚠️ | ⭕ 91% | Apache-2.0 |
| [ramsql](https://github.com/proullon/ramsql) | 927 | インメモリSQLドライバ | ✅ | ✅ | ⚠️ 低い | BSD-3-Clause |
| [PGlite](https://github.com/electric-sql/pglite) | 14,835 | PostgreSQL WASM化 | ❌ | ✅ | ✅ 100% | Apache-2.0 |
| [psql-wire](https://github.com/jeroenrinzema/psql-wire) | 219 | PGワイヤープロトコル | ✅ | - | - | Apache-2.0 |

---

## 主要コンポーネント

> 詳細: [主要コンポーネント分析](docs/components.md)

```
┌─────────────────────────────────────────────┐
│         PostgreSQL クライアント              │
│         (pgx, database/sql, psql)           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  A. ワイヤープロトコル (psql-wire)           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  B. SQLパーサー (pgplex/pgparser)           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  C. クエリ実行エンジン (独自 or 既存活用)    │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  D. インメモリストレージ                     │
└─────────────────────────────────────────────┘
```

---

## アプローチ比較サマリー

> 詳細: [実現アプローチの比較](docs/approaches.md)

| アプローチ | Pure Go | インプロセス | インメモリ | PG互換性 | 実装コスト | 推奨度 |
|-----------|---------|------------|----------|---------|-----------|--------|
| 1. Pure Go フルスタック | ✅ | ✅ | ✅ | ⚠️ | 🔴 極大 | 長期目標 |
| 2. DoltgreSQL活用 | ✅ | ⚠️ | ✅ | ⭕ 91%+ | 🟡 中 | ⭐ 短期推奨 |
| 3. WASM (wazero + PGlite) | ⚠️ | ✅ | ✅ | ✅ | 🔴 大 | 中長期有望 |
| 4. purego + libpostgres | ⚠️ | ⚠️ | ⚠️ | ✅ | 🔴 極大 | 非推奨 |
| 5. embedded-postgres | ⚠️ | ❌ | ❌ | ✅ | 🟢 小 | 確実だが要件外 |

---

> 詳細: [推奨アーキテクチャ](docs/recommendation.md)
