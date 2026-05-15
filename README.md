# project-template-for-claude-code

新規プロジェクトの起点として GitHub の **"Use this template"** から新規リポジトリを作成して使うことを前提とした、Claude Code 用テンプレートリポジトリです。

`.claude/`（コマンド・スキル・エージェント）と、それと連携するリポジトリ構造（`docs/core/`、`docs/ideas/`、`.steering/` など）をひとまとめに提供します。

## 対応プロジェクトの種類

特定のプログラミング言語に依存せず、以下のいずれにも適用できます。

| プロジェクト種別 | 例 | 主な技術スタック |
|------------------|-----|------------------|
| **Python** | データ処理 / CLI / FastAPI 等 | `pyproject.toml` + `pytest` + `ruff` + `mypy` |
| **TypeScript / Node.js** | Web アプリ / CLI / ライブラリ | `package.json` + `vitest` 等 + `eslint` + `tsc` |
| **Rust** | CLI / システムツール | `Cargo.toml` + `cargo test` + `clippy` |
| **Go** | CLI / API サーバー | `go.mod` + `go test` + `golangci-lint` |
| **MCP のみ** | Claude Code を MCP サーバーで拡張する構成。コード実装なし | `.mcp.json` のみ |
| その他 | 上記以外の言語・複合スタック | `/initial-setup` で手動指定 |

`/initial-setup` がパッケージマネージャを検出して言語別のデフォルト（テスト・リント・ビルドコマンド）を自動適用します。**MCP のみのプロジェクト**（ソースコードを書かず、MCP サーバーの構成・運用のみを行うプロジェクト）にも対応します。

## 使い方

### 1. テンプレートから新規プロジェクトを作成する

GitHub の **"Use this template"** 機能を使って、新規リポジトリを作成します。

#### 方法 A: GitHub CLI (`gh`) を使う（推奨）

1コマンドで「新規リポジトリ作成 + ローカルへのクローン」までを完結できます。

```bash
gh repo create <new-project-name> --template <owner>/project-template-for-claude-code --private --clone
```

> `gh` のインストールがまだの場合は [GitHub CLI 公式インストールガイド](https://cli.github.com/) を参照してください。初回利用時は `gh auth login` で認証が必要です。

#### 方法 B: `git` コマンドのみで行う

`gh` を使わず、Web UI と `git` の組み合わせで同等の結果（履歴1コミットの新規リポジトリ）を作る手順です。

1. GitHub の Web UI で空のリポジトリ `<owner>/<new-project-name>` を作成する（README や `.gitignore` は付けない）

2. ローカルでテンプレートを取得し、履歴を初期化して push する

   ```bash
   git clone --depth=1 https://github.com/<owner>/project-template-for-claude-code.git <new-project-name>
   cd <new-project-name>
   rm -rf .git
   git init
   git add -A
   git commit -m "chore: initial commit from template"
   git branch -M main
   git remote add origin https://github.com/<owner>/<new-project-name>.git
   git push -u origin main
   ```

いずれの方法でも、テンプレート本体の履歴・リモートを引き継がない、クリーンな新規リポジトリとして作業を開始できます。

### 2. `/initial-setup` を実行する

新規プロジェクトのルートで Claude Code を起動し、`/initial-setup` を実行します。

- パッケージマネージャ（`pyproject.toml` / `package.json` / `Cargo.toml` / `go.mod`）を検出し、言語に合わせて Commands/Skills のデフォルト値を自動置換します
- 必要なディレクトリ（`src/`、`tests/`、`docs/core/` 等）と `CLAUDE.md`、`.env.example`、`.gitignore` のスケルトンを補完します
- 既存プロジェクト・新規プロジェクトの両方に対応（モードを自動判定／確認）

### 3. `CLAUDE.md` と `README.md` を編集する

コピー先のプロジェクトの内容に合わせて書き換えます。

### 4. ドキュメント生成ワークフローを起動する

- 新規アイデアから始める場合: `/brainstorm` → `/gen-all-docs`
- 既存コードがある場合: `/gen-all-docs`（コードから逆生成）

## 含まれるもの

| パス | 内容 |
|------|------|
| `.claude/commands/` | カスタムスラッシュコマンド（`/plan-feature`, `/implement-feature`, `/validate-code`, `/gen-all-docs` ほか） |
| `.claude/skills/` | スキル定義（PRD作成、アーキテクチャ設計、機能設計、用語集作成、ドキュメント生成など） |
| `.claude/agents/` | サブエージェント定義（技術調査、ドキュメントレビュー、実装検証） |
| `.claude/settings.local.json` | ローカル設定 |
| `docs/core/` | コアドキュメントの出力先（`/gen-all-docs` が生成） |
| `docs/ideas/` | ブレインストーミングのアウトプット置き場 |
| `docs/plan/` | 計画ドキュメント置き場 |
| `.steering/` | `/plan-feature`〜`/implement-feature` の作業ステアリングファイル置き場 |
| `src/`, `tests/`, `scripts/`, `logs/` | プロジェクトの標準ディレクトリ（空のスケルトン） |

## ドキュメント生成のスケール対応

`/gen-all-docs` はプロジェクト規模を判定して、以下の粒度でドキュメントを生成します:

| 規模 | 生成ドキュメント |
|------|------------------|
| 小規模（Claude Code ツール等） | `README.md` + `CLAUDE.md` + `development-guidelines.md` |
| 中規模 | 上記 + `architecture.md` + `repository-structure.md`（新規時は `product-requirements.md` も） |
| 大規模（本格アプリ） | 全コアドキュメント + 必要なオプション（`functional-design.md`, `glossary.md`, `api-reference.md`, `diagrams.md`, `CHANGELOG.md`） |

各 Skill（`architecture-design`、`repository-structure`、`functional-design` など）も、この規模別生成方針と整合する形で前提条件を定義しています。

## 推奨ワークフロー

```
（"Use this template" で新規リポジトリ作成）
    ↓
/initial-setup       # 言語/構造を検出し Commands/Skills を適合、不足ファイルを補完
    ↓
/brainstorm          # アイデアを docs/ideas/ にまとめる（新規プロジェクト時）
    ↓
/gen-all-docs        # 規模に応じて docs/core/ にコアドキュメントを生成
    ↓
/plan-feature        # 機能ごとの計画を .steering/ に作成（requirements.md / design.md / tasklist.md）
    ↓
/implement-feature   # tasklist.md に従って実装
    ↓
/validate-code       # コード品質（リント・型/静的検査・テスト）を検証
                     #   ※ MCP-only プロジェクトではスキップ
                     #     （`.mcp.json` のスキーマ検証のみ任意で実施）
    ↓
/acceptance-test     # 受け入れ条件（requirements.md / アイデアファイル）の合否を検証
    ↓
/update-docs         # 実装をドキュメントに反映
    ↓
/review-docs         # ドキュメント品質をレビュー
```

**MCP-only プロジェクトでの差分:**
- `/validate-code` はスキップ（独自コードが無いため、リント・型検査・テストの対象がない）。`.mcp.json` の構文チェックのみ任意で実施
- `/implement-feature` の静的解析・テスト工程も同様にスキップされ、`.mcp.json` の動作確認に置き換わる
- `/acceptance-test` は引き続き実施可能（受け入れ条件として「特定の MCP サーバーが `.mcp.json` に定義されている」「環境変数が設定されている」などを検証）
