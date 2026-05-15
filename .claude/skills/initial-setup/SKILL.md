---
name: initial-setup
description: プロジェクト初期セットアップ（新規/既存対応）
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# 初期セットアップ (initial-setup)

**目的:** Claude Commands/Skillsをプロジェクトに適合させる

**対応モード:**
- **既存プロジェクト**: Commands/Skillsの適合
- **新規プロジェクト**: 基本構成作成 + 適合

**使用方法（別プロジェクトでの導入）:**
```bash
# 1. テンプレートの .claude/ をコピー
cp -r /path/to/project-template-for-claude-code/.claude /path/to/new-project/

# 2. 新プロジェクトで /initial-setup を実行
# → プロジェクトに合わせて自動適合
```

---

## ステップ1: プロジェクト状態の検出

### 1.1 検出対象ファイルの確認

以下のファイル/ディレクトリを確認する:

```
# 必須確認
Bash('ls -la') # ルートディレクトリの確認
Read('CLAUDE.md') # 存在確認（存在しない場合はエラー返却を期待）
```

### 1.2 パッケージマネージャの検出

| ファイル | 言語 | デフォルトソースDir | デフォルトテストDir |
|----------|------|---------------------|---------------------|
| pyproject.toml | Python | `src/` | `tests/` |
| package.json | Node.js / TypeScript | `src/` | `tests/` or `__tests__/` |
| Cargo.toml | Rust | `src/` | `tests/` |
| go.mod | Go | `cmd/`, `internal/` | `*_test.go` |
| (どれも無い・かつ `.mcp.json` あり) | **MCP-only** | （該当なし） | （該当なし） |
| (どれも無い・`.mcp.json` も無い) | 不明 | `src/` | `tests/` |

```
# パッケージマネージャ検出
Glob('pyproject.toml')
Glob('package.json')
Glob('Cargo.toml')
Glob('go.mod')

# MCP-only 判定用
Glob('.mcp.json')
Glob('.claude/.mcp.json')
```

### 1.3 ソースディレクトリの検出

以下の順序で候補を検出:

```
# 既存ソースディレクトリ候補（拡張子は多言語対応）
Glob('src/**/*.{py,ts,tsx,js,jsx,go,rs,java,kt,rb}')
Glob('lib/**/*.{py,ts,tsx,js,jsx,go,rs,java,kt,rb}')
Glob('backend/**/*.{py,ts,go,rs}')
Glob('app/**/*.{py,ts,tsx,js,jsx,go,rs}')
Glob('cmd/**/*.go')         # Go 慣例
Glob('internal/**/*.go')    # Go 慣例
```

**MCP-only モードの判定:**
- パッケージ定義ファイルが見つからず、ソースファイルも 1 件も検出されない場合、`.mcp.json` の存在を確認
- `.mcp.json` が存在する → MCP-only モード（コード関連の検出はスキップし、`.mcp.json` の中身を解析）
- `.mcp.json` も無い場合は「不明」として扱い、ユーザーに確認

### 1.4 設定ファイルの検出

```
# 環境変数/設定ファイル
Glob('.env')
Glob('.env.example')
Glob('settings.yaml') or Glob('config.yaml')
Glob('config/**/*') or Glob('settings/**/*')
```

### 1.5 テストディレクトリの検出

```
Glob('tests/**/*.{py,ts,tsx,js,go,rs}')
Glob('test/**/*.{py,ts,tsx,js,go,rs}')
Glob('__tests__/**/*.{ts,tsx,js,jsx}')
Glob('**/*_test.go')        # Go 慣例
Glob('**/*.test.{ts,tsx,js,jsx}')
```

MCP-only モードではこのステップをスキップする。

### 1.6 検出結果の記録

以下の形式で検出結果を記録する:

```markdown
## プロジェクト検出結果

- CLAUDE.md: {存在する/存在しない}
- 言語/モード: {Python/TypeScript・Node.js/Rust/Go/MCP-only/不明}
- パッケージファイル: {pyproject.toml/package.json/Cargo.toml/go.mod/.mcp.json のみ/なし}
- ソースディレクトリ: {検出パス または なし(MCP-only)}
- テストディレクトリ: {検出パス または なし(MCP-only)}
- 設定ファイル: {検出ファイル または なし}
- MCP 構成: {`.mcp.json` のパス または なし}
```

---

## ステップ2: セットアップモードの判定

### 判定ロジック

| CLAUDE.md | ソースDir | `.mcp.json` | モード | 処理内容 |
|-----------|-----------|--------------|--------|----------|
| あり | あり | - | 適合モード | Commands/Skillsの適合のみ |
| なし | あり | - | 適合モード + CLAUDE.md生成 | CLAUDE.md生成 → 適合 |
| あり | なし | あり | MCP-only 適合モード | コード関連を無効化し MCP 用に適合 |
| なし | なし | あり | MCP-only 初期化モード | MCP 用最小構成を新規作成 |
| なし | なし | なし | 初期化モード | 全て新規作成（言語はユーザー確認） |

### ユーザー確認

AskUserQuestion を使用して以下を確認:

**質問1: セットアップモードの確認**
```
検出結果:
- 言語: {検出された言語}
- ソースディレクトリ: {検出パス}
- 設定ファイル: {検出ファイル}

以下のモードでセットアップを実行しますか？
- モード: {初期化モード/適合モード}
```

オプション:
- `はい、続行する` (推奨)
- `いいえ、中止する`

**質問2: ソースディレクトリの確認（検出されなかった場合のみ）**
```
ソースディレクトリが検出できませんでした。
ソースコードを配置するディレクトリを指定してください:
```

オプション:
- `src/` (推奨)
- `lib/`
- `backend/`
- `app/`
- その他（手動入力）

---

## ステップ3: 基本構成の作成（初期化モードのみ）

### 3.1 ディレクトリ構造の作成

**通常モード:**
```bash
Bash('mkdir -p {検出ソースDir} {検出テストDir} docs/ideas docs/core .steering')
# 例: mkdir -p src tests docs/ideas docs/core .steering
```

**MCP-only モード:**
```bash
# src/ や tests/ は作成しない
Bash('mkdir -p docs/ideas docs/core .steering')
# .mcp.json が無い場合は空のスケルトンを作成
```

### 3.2 CLAUDE.md の作成

以下のテンプレートで CLAUDE.md を作成:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

{プロジェクト名}は{目的/概要}です。

## Commands

### Running Tests
\`\`\`bash
# Run all tests
{テストコマンド: pytest / npm test / cargo test / go test ./...}
\`\`\`

### Linting/Formatting
\`\`\`bash
{リントコマンド: ruff check . / eslint . / cargo clippy / golangci-lint run}
{フォーマットコマンド: black . / prettier --write . / cargo fmt / gofmt -w .}
\`\`\`

## Architecture

### Key Directories
- `{ソースディレクトリ}/`: ソースコード
- `tests/`: テストコード
- `docs/`: ドキュメント

### Data Flow
{データフローの概要を記載}

## Testing
- テストフレームワーク: {pytest / jest / cargo test / go test}
- テストディレクトリ: `tests/`
```

### 3.3 .env.example の作成

```
# Environment Variables

# Example:
# API_KEY=your_api_key_here
# DATABASE_URL=sqlite:///data/app.db
```

### 3.4 .gitignore の確認

既存の .gitignore がない場合、言語に応じた基本的な .gitignore を作成:

```
# Python
__pycache__/
*.py[cod]
.env
.venv/
dist/
*.egg-info/

# Node.js
node_modules/
.env
dist/

# General
.DS_Store
*.log
```

---

## ステップ4: Commands/Skills の適合

### 4.1 適合対象ファイル

以下のファイルを読み込み、パターン置換を行う:

**スキルファイル:**
- `.claude/skills/**/*.md` (全ファイル)

### 4.2 置換パターン

| 置換対象 | 検索パターン | 置換先 | 説明 |
|----------|--------------|--------|------|
| ソースパス | `backend/` | `{検出されたソースディレクトリ}/` | ソースコードパス |
| テストパス | `tests/` | `{検出されたテストディレクトリ}/` | テストパス |
| Pythonコマンド | `uv run python` | `{検出されたPythonランナー}` | Python実行 |
| テストコマンド | `uv run pytest` | `{検出されたテストコマンド}` | テスト実行 |

### 4.3 言語別のデフォルト置換

| 言語 | テスト | リント | 型/静的検査 | フォーマッタ | 実行 |
|------|--------|--------|-------------|--------------|------|
| Python (`pyproject.toml`) | `pytest` | `ruff check .` | `mypy .` | `black .` | `python` / `uv run python` |
| TypeScript・Node.js (`package.json`) | `npm test` / `vitest run` | `eslint .` | `tsc --noEmit` | `prettier --write .` | `node` / `npx ts-node` |
| Rust (`Cargo.toml`) | `cargo test` | `cargo clippy` | （`cargo check`） | `cargo fmt` | `cargo run` |
| Go (`go.mod`) | `go test ./...` | `golangci-lint run` | `go vet ./...` | `gofmt -w .` | `go run` |
| MCP-only | （なし） | （なし） | `.mcp.json` のスキーマ検証のみ | （なし） | （なし） |
| 不明 | ユーザー入力 | ユーザー入力 | ユーザー入力 | ユーザー入力 | ユーザー入力 |

置換ルール:
- 各 SKILL ファイル内の Python 既定値（`pytest` / `ruff check` / `mypy` / `black` 等）を、検出言語の対応コマンドへ書き換える
- ソースディレクトリは検出値（`src/` / `lib/` / `cmd/` 等）に統一
- MCP-only モードではテスト・静的解析・カバレッジ系のコマンドを **無効化／省略** とマーク（コマンドを空文字または「該当なし」で置換）し、`.mcp.json` の検証ステップのみ残す

### 4.4 settings.local.json の更新

検出された言語/ツールに基づいて settings.local.json を更新:

```json
{
  "permissions": {
    "allow": [
      // 既存の許可を保持しつつ、言語固有の許可を追加/変更
    ]
  }
}
```

### 4.5 適合処理の実行

各対象ファイルに対して:

1. ファイルを読み込む
2. 置換パターンを適用
3. 変更があった場合のみファイルを更新
4. 変更箇所を記録

---

## ステップ5: docs/core/ の準備

### 5.1 ディレクトリの確認

```
Bash('mkdir -p docs/core docs/ideas')
```

### 5.2 /gen-all-docs の案内

完了レポートに以下を含める:

```
ドキュメント生成の案内:
プロジェクトドキュメントを生成するには、以下を実行してください:

/gen-all-docs

`/gen-all-docs` はプロジェクト規模を判定して、以下のドキュメントを生成します:

【真のコア（規模を問わず必ず生成）】
- README.md             （ルート配置）
- CLAUDE.md             （ルート配置）
- docs/core/development-guidelines.md

【中規模以上で追加】
- docs/core/architecture.md
- docs/core/repository-structure.md
- docs/core/product-requirements.md（新規プロジェクト時）

【大規模で追加】
- docs/core/functional-design.md
- docs/core/glossary.md
- docs/core/api-reference.md（API提供時）
- docs/core/diagrams.md
- CHANGELOG.md           （ルート配置）

小規模プロジェクト（Claude Code ツール等）では「真のコア」3点のみが生成されます。

MCP-only プロジェクトでは、`development-guidelines.md` の代わりに `.mcp.json` の構成と運用手順を記載した最小ドキュメントが生成されます。
```

---

## ステップ6: 完了レポートとユーザー確認

**このステップでワークフローは停止する。**

### 6.1 完了レポートの出力

以下の形式でレポートを出力:

```markdown
# セットアップ完了レポート

## 検出されたプロジェクト情報

| 項目 | 値 |
|------|-----|
| 言語/モード | {Python/TypeScript・Node.js/Go/Rust/MCP-only/不明} |
| パッケージファイル | {pyproject.toml/package.json/go.mod/Cargo.toml/.mcp.json のみ/なし} |
| ソースディレクトリ | {検出パス} |
| テストディレクトリ | {検出パス} |
| 設定ファイル | {検出ファイル} |

## 実行されたセットアップ

### モード: {初期化モード/適合モード}

### 作成されたファイル（初期化モードのみ）
- [ ] CLAUDE.md
- [ ] .env.example
- [ ] src/ ディレクトリ
- [ ] tests/ ディレクトリ
- [ ] docs/ideas/ ディレクトリ
- [ ] docs/core/ ディレクトリ
- [ ] .steering/ ディレクトリ

### 適合されたファイル
| ファイル | 変更内容 |
|----------|----------|
| {ファイル名} | {置換内容の要約} |

## 次のステップ

1. **CLAUDE.md を確認・編集**
   - プロジェクト概要を更新
   - コマンド例を確認

2. **ドキュメント生成**
   \`\`\`
   /gen-all-docs
   \`\`\`

3. **機能開発の開始**
   \`\`\`
   /plan-feature [機能名]
   \`\`\`

## 注意事項

- `.claude/` ディレクトリはバージョン管理に含めることを推奨
- `settings.local.json` には個人設定が含まれるため、必要に応じて .gitignore に追加
```

### 6.2 確認待ち状態

ユーザーにレポートを提示して停止する。

---

## CLAUDE.md テンプレート（言語別）

### Python プロジェクト用

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

{プロジェクト概要を記載}

## Commands

### Running Tests
\`\`\`bash
pytest
pytest tests/test_example.py
pytest -v
\`\`\`

### Linting/Formatting
\`\`\`bash
ruff check .
black .
mypy .
\`\`\`

## Architecture

### Key Directories
- `src/`: ソースコード
- `tests/`: テストコード
- `docs/`: ドキュメント

### Configuration
- 環境変数: `.env` (`.env.example` を参照)
- 設定: `pyproject.toml`

## Testing
- テストフレームワーク: pytest
- テストディレクトリ: `tests/`
- フィクスチャ: `tests/conftest.py`
```

### Node.js プロジェクト用

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

{プロジェクト概要を記載}

## Commands

### Running Tests
\`\`\`bash
npm test
npm run test:watch
\`\`\`

### Linting/Formatting
\`\`\`bash
npm run lint
npm run format
\`\`\`

### Development
\`\`\`bash
npm run dev
\`\`\`

## Architecture

### Key Directories
- `src/`: ソースコード
- `tests/` or `__tests__/`: テストコード
- `docs/`: ドキュメント

### Configuration
- 環境変数: `.env` (`.env.example` を参照)
- パッケージ: `package.json`

## Testing
- テストフレームワーク: Jest / Vitest
- テストディレクトリ: `tests/` or `__tests__/`
```

### Go プロジェクト用

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

{プロジェクト概要を記載}

## Commands

### Running Tests
\`\`\`bash
go test ./...
go test -v ./...
go test -cover ./...
\`\`\`

### Linting/Formatting
\`\`\`bash
golangci-lint run
gofmt -w .
\`\`\`

### Build
\`\`\`bash
go build ./...
\`\`\`

## Architecture

### Key Directories
- `cmd/`: エントリーポイント
- `internal/`: 内部パッケージ
- `pkg/`: 公開パッケージ

### Configuration
- 環境変数: `.env` (`.env.example` を参照)
- モジュール: `go.mod`

## Testing
- テストファイル: `*_test.go`
- テーブル駆動テストを推奨
```

### Rust プロジェクト用

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

{プロジェクト概要を記載}

## Commands

### Running Tests
\`\`\`bash
cargo test
cargo test -- --nocapture
\`\`\`

### Linting/Formatting
\`\`\`bash
cargo clippy
cargo fmt
\`\`\`

### Build
\`\`\`bash
cargo build
cargo build --release
\`\`\`

## Architecture

### Key Directories
- `src/`: ソースコード
- `tests/`: 統合テスト

### Configuration
- 環境変数: `.env` (`.env.example` を参照)
- パッケージ: `Cargo.toml`

## Testing
- ユニットテスト: 各モジュール内の `#[cfg(test)]`
- 統合テスト: `tests/` ディレクトリ
```

### MCP-only プロジェクト用

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

{プロジェクト概要を記載}

このリポジトリは独自のソースコードを持たず、`.mcp.json` で構成された MCP サーバー群を Claude Code から利用する運用用プロジェクトです。

## MCP Configuration

\`\`\`bash
# .mcp.json の構文確認
cat .mcp.json | jq .
\`\`\`

利用している MCP サーバー: {`.mcp.json` の `mcpServers` から抽出して列挙}

## Commands

このプロジェクトには独自のテスト・ビルドコマンドはありません。
`.mcp.json` の編集後は Claude Code を再起動して MCP サーバーが正しく登録されるか確認してください。

## Architecture

### Key Files
- `.mcp.json`: 利用する MCP サーバーの定義
- `docs/core/`: 運用ドキュメント
- `.steering/`: 作業ステアリングファイル

### Configuration
- 環境変数: `.env` (`.env.example` を参照)
- MCP 認証情報: `.mcp.json` の `env` セクション、または環境変数

## 運用ルール

- 機密情報（API キー等）は `.mcp.json` に直接書かず、環境変数経由で注入する
- `.mcp.json` を変更した場合は `/update-docs` で `README.md` / `CLAUDE.md` の MCP サーバー一覧を同期する
```

---

## 完了条件

このワークフローは、以下の条件を満たした時点で完了（ユーザー確認待ち）となる:

- プロジェクト状態が検出されている
- セットアップモードが決定されている
- (初期化モードの場合) 基本構成が作成されている
- Commands/Skills が適合されている
- 完了レポートがユーザーに提示されている
