# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

このリポジトリは **新規プロジェクトの起点としてコピーして使うテンプレート** です。
`.claude/`（コマンド・スキル・エージェント）と、それと連携するリポジトリ構造（`docs/core/`、`docs/ideas/`、`.steering/` など）のスケルトンを提供します。

### 対応プロジェクトの種類

特定のプログラミング言語には依存しません。`/initial-setup` がパッケージマネージャを検出して、言語別のデフォルトコマンドや検出パターンを自動適用します。

- **コード実装あり**: Python（`pyproject.toml`） / TypeScript・Node.js（`package.json`） / Rust（`Cargo.toml`） / Go（`go.mod`） / その他
- **MCP のみ**: `.mcp.json` だけで構成され、独自コードを書かないプロジェクト（Claude Code を MCP サーバーで拡張する用途等）

各 Skill（`validate-code`、`implement-feature`、`acceptance-test`、`update-docs` 等）は、検出した言語に応じてテスト・リント・型チェック等のコマンドを切り替えます。MCP-only モードでは:

- `/validate-code` および `/implement-feature` の静的解析・テスト工程は **スキップ**（`.mcp.json` の構文検証のみ任意で実施）
- `/acceptance-test` は引き続き実施可能（受け入れ条件として `.mcp.json` の構成や環境変数の存在を検証）
- `/update-docs` / `/review-docs` は `.mcp.json` を含む形で実行

> **コピー先のプロジェクトでは、この `CLAUDE.md` を当該プロジェクトの内容に合わせて書き換えてください。**
> 以下の記述（コマンド、ディレクトリ構成、テスト設定）はテンプレートとしてのデフォルト値であり、実プロジェクトでは適宜変更します。
> 多くの場合、`/gen-all-docs` の **既存プロジェクトモード** で `CLAUDE.md` を再生成すれば実態に揃います。

## セットアップ

新規プロジェクトでテンプレートをコピーした直後は、まず **`/initial-setup`** を実行してください。

`initial-setup` Skill が以下を自動で行います:

1. **プロジェクト状態の検出**
   - パッケージマネージャ（`pyproject.toml` / `package.json` / `Cargo.toml` / `go.mod`）を検出
   - ソースディレクトリ・テストディレクトリ・設定ファイルの所在を確認
2. **モードの自動判定（初期化／適合）**
   - 既存プロジェクト: Commands/Skills を実態に合わせて適合
   - 新規プロジェクト: 不足する基本構成（`src/`、`tests/`、`docs/core/`、`CLAUDE.md`、`.env.example`、`.gitignore` 等）を補完
3. **Commands/Skills のプレースホルダ置換**
   - 言語別のデフォルト値（テスト・リント・ビルドコマンド等）を適用
   - `.claude/settings.local.json` の権限/環境変数を更新
4. **`docs/core/` の準備と `/gen-all-docs` の案内**

`/initial-setup` 完了後の流れは `README.md` の「推奨ワークフロー」を参照してください。

## このテンプレート自体の作業

このリポジトリ自体に手を加える場合（Skill の追加・修正、コマンドの改良など）は以下を意識してください。

- スキル（`.claude/skills/*/SKILL.md`）の修正時は、`gen-all-docs` の小規模／中規模／大規模の生成方針と平仄を保つ
- コマンドやスキルの追加時は、`README.md` の「含まれるもの」表と「推奨ワークフロー」も更新する
- 既存プロジェクトに不要なファイル（`src/example.py` のような実装例）は置かない。スケルトンとして空ディレクトリのみを保持する

## Commands（テンプレート既定値）

`/initial-setup` を実行すると検出した言語に合わせて自動的に置換されます。下記はテンプレート初期状態のプレースホルダ（Python 例）です。

### Running Tests
```bash
# 例: Python   → pytest / pytest -v
# 例: TS/Node  → npm test / vitest run
# 例: Rust     → cargo test
# 例: Go       → go test ./...
# 例: MCP-only → （該当なし）
```

### Linting / Formatting / Type-checking
```bash
# 例: Python   → ruff check . / black . / mypy .
# 例: TS/Node  → eslint . / prettier --write . / tsc --noEmit
# 例: Rust     → cargo clippy / cargo fmt
# 例: Go       → golangci-lint run / gofmt -w . / go vet ./...
# 例: MCP-only → .mcp.json のスキーマ検証のみ
```

## Architecture

### Key Directories（テンプレートのスケルトン）

| パス | 役割 |
|------|------|
| `.claude/` | Claude Code 設定（コマンド・スキル・エージェント） |
| `docs/core/` | `/gen-all-docs` が生成するコアドキュメントの出力先 |
| `docs/ideas/` | `/brainstorm` のアウトプット置き場 |
| `docs/plan/` | 計画ドキュメント置き場 |
| `.steering/` | `/plan-feature`〜`/implement-feature` の作業ステアリングファイル置き場 |
| `src/` | ソースコード（空のスケルトン） |
| `tests/` | テストコード（空のスケルトン） |
| `scripts/` | ユーティリティスクリプト |
| `logs/` | ログファイル |

### Configuration
- 環境変数: `.env` (`.env.example` を参照)
- パッケージ定義: 採用する言語に応じて `pyproject.toml` / `package.json` / `Cargo.toml` / `go.mod` 等
- MCP 構成（任意）: `.mcp.json`

## Testing
- テストフレームワーク: 検出した言語に応じる（Python: pytest / TS: vitest 等 / Rust: cargo test / Go: go test）
- テストディレクトリ: `tests/`（言語慣例に従う）
- MCP-only プロジェクトではテスト工程はスキップされる場合あり

## ドキュメント生成のスケール対応

`/gen-all-docs` はプロジェクト規模に応じて生成範囲を切り替えます。Skill 群（`architecture-design`、`repository-structure`、`functional-design` ほか）の前提条件もこの方針と整合する形で記述されています。

| 規模 | 生成範囲 |
|------|----------|
| 小規模 | `README.md` + `CLAUDE.md` + `development-guidelines.md` のみ |
| 中規模 | 上記 + `architecture.md` + `repository-structure.md`（新規時は `product-requirements.md` も） |
| 大規模 | 全コアドキュメント + 必要なオプション |

スケーラブルオプションが未生成の小規模プロジェクトでは、各 Skill は `README.md` / `CLAUDE.md` / 実コードへフォールバックする設計になっています。
