---
name: gen-all-docs
description: 全ドキュメント一括生成
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Bash, Grep
---

# 全ドキュメント一括生成

このプロジェクトの全ドキュメントを一括生成してください。
新規プロジェクトと既存プロジェクトの両方に対応しています。

---

## ステップ0: プロジェクト状態の検出

まず、プロジェクトの状態を判定してください。

### 検出対象

1. **ソースコードの存在確認**
   - `src/`, `lib/`, `app/`, `backend/`, `frontend/`, `cmd/`, `internal/` などの主要ディレクトリ
   - `.py`, `.ts`, `.tsx`, `.js`, `.jsx`, `.go`, `.rs`, `.java`, `.kt`, `.rb` などのソースファイル
   - 10個以上の実質的なソースファイルがあれば「ソースコード存在」と判定

2. **アイデアファイルの存在確認**
   - `docs/ideas/*.md` をチェック
   - 1個以上あれば「アイデアファイル存在」と判定

3. **MCP-only プロジェクトの判定**
   - パッケージ定義ファイル（`pyproject.toml` / `package.json` / `Cargo.toml` / `go.mod`）が無い
   - かつソースファイルも 10 個未満
   - かつ `.mcp.json`（または `.claude/.mcp.json`）が存在
   - → **MCP-only プロジェクト** とみなす

### 判定ロジック

| ソースコード | `docs/ideas/*.md` | `.mcp.json` | 判定 | source of truth |
|--------------|-------------------|--------------|------|-----------------|
| 存在 | なし | - | **既存プロジェクトモード** | コード |
| なし/少 | 存在 | - | **新規プロジェクトモード** | ideas |
| 両方存在 | 両方存在 | - | **ユーザーに選択させる** | - |
| なし | なし | あり | **MCP-only モード** | `.mcp.json` |
| なし | 存在 | あり | **MCP-only 新規モード**（ユーザー確認） | ideas + `.mcp.json` |
| どちらもなし | どちらもなし | なし | **エラー**（/brainstormを案内） | - |

### 曖昧なケースの確認

ソースコードとアイデアファイルが両方存在する場合、AskUserQuestionで確認:

```
検出結果:
- ソースファイル: {N}個検出
- アイデアファイル: {N}個検出

どちらのモードで実行しますか？
```

選択肢:
1. **既存モード（推奨）** - コードからドキュメント逆生成
2. **新規モード** - アイデアからドキュメント生成

### エラー時の案内

どちらも存在しない場合:
```
ドキュメント生成のソースが見つかりません。

以下のいずれかを実行してください:
- /brainstorm でアイデアを作成（新規プロジェクトの場合）
- ソースコードを追加（既存プロジェクトの場合）
```

---

## ステップ0.5: プロジェクト規模の判定

このテンプレートは、本格的アプリケーション開発から Claude Code を利用した小規模ツール作成、MCP サーバーのみで構成するプロジェクトまで幅広く利用されます。
規模に応じて生成するドキュメントを最適化するため、以下の指標で判定してください。

### 判定基準

| 指標 | 小規模（ツール） | 中規模 | 大規模（アプリ） |
|------|-----------------|--------|-----------------|
| ソースファイル数 | 〜10 | 11〜50 | 51〜 |
| ディレクトリ階層 | 1〜2層 | 2〜3層 | 3層以上 |
| 主要モジュール数 | 1〜2 | 3〜5 | 6〜 |
| 外部依存（DB/API/UI等） | 少ない | 中程度 | 多い |

複数指標が該当するレベルを採用。新規プロジェクトモードではアイデアファイルの内容から推定。

**MCP-only プロジェクト**は規模を問わず「小規模」相当として扱い、コード関連のドキュメントは生成せず、`.mcp.json` の構成説明と運用手順のみを生成する。

### 判定が曖昧な場合

AskUserQuestion で確認:
```
プロジェクト規模を確認します:
- 検出したソースファイル: {N}個
- 検出したディレクトリ階層: {N}層

生成するドキュメントの粒度は？

1. 小規模（README + CLAUDE.md + 開発ガイドラインのみ）
2. 中規模（+ アーキテクチャ + リポジトリ構造）
3. 大規模（全コアドキュメント生成）
```

---

## 既存プロジェクトモード

ソースコードをsource of truthとしてドキュメントを逆生成します。

### 手順

1. **プロジェクト構造の分析**
   - ソースコードのディレクトリ構造を把握
   - 主要なモジュール・パッケージを特定
   - 使用言語・フレームワークを検出

2. **既存ドキュメントの参照**（存在する場合）

   `docs/` 配下の確認対象:
   - `docs/*.md`（ルート直下のドキュメント）
   - `docs/core/*.md`（以前生成されたドキュメント）
   - `README.md`, `CLAUDE.md`

   **活用方針**:
   | 状況 | 対応 |
   |------|------|
   | コードと整合 | 記述を参考に、表現や構成を引き継ぐ |
   | コードと不整合 | **コードを優先**、古い記述は無視 |
   | 関連性が不明 | コードベースのみから生成 |

   **注意**: 既存ドキュメントはあくまで参考。source of truthはコードベース

3. **ドキュメント生成**（`docs/core/` に出力。`README.md` と `CLAUDE.md` はリポジトリルートに出力）

   各ドキュメントはSkillのテンプレート構造を参照し、コードから内容を逆生成:

   **真のコアドキュメント（規模を問わず必須）:**

   | ドキュメント | 出力先 | 参照Skill | 内容 |
   |-------------|--------|-----------|------|
   | `README.md` | リポジトリルート | - | 概要・インストール・使い方の入口 |
   | `CLAUDE.md` | リポジトリルート | `Skill('init')` | Claude Code 向け開発コンテキスト |
   | `development-guidelines.md` | `docs/core/` | `Skill('development-guidelines')` | 既存パターンから規約抽出 |

   **スケーラブルオプション（プロジェクト規模に応じて生成）:**

   | ドキュメント | 出力先 | 参照Skill | 中規模以上で推奨 | 大規模で推奨 |
   |-------------|--------|-----------|:---:|:---:|
   | `architecture.md` | `docs/core/` | `Skill('architecture-design')` | ✓ | ✓ |
   | `repository-structure.md` | `docs/core/` | `Skill('repository-structure')` | ✓ | ✓ |
   | `functional-design.md` | `docs/core/` | `Skill('functional-design')` |  | ✓ |
   | `glossary.md` | `docs/core/` | `Skill('glossary-creation')` |  | ✓ |
   | `api-reference.md` | `docs/core/` | - |  | ✓（API提供時） |
   | `diagrams.md` | `docs/core/` | - |  | ✓ |
   | `CHANGELOG.md` | リポジトリルート | - |  | ✓ |

   **小規模プロジェクトでの生成方針**:
   小規模では「真のコア」のみ生成し、それ以外はスキップ。`development-guidelines.md` も最小構成（テスト・リント・主要規約のみ）でよい。

4. **生成後の確認**
   - 各ファイルの存在確認
   - 生成サマリーを表示

---

## 新規プロジェクトモード

`docs/ideas/*.md` をsource of truthとして計画段階ドキュメントを生成します。

### 手順

1. **アイデアファイルの選択**

   複数のideaファイルがある場合、AskUserQuestionで選択:
   ```
   docs/ideas/ に複数のアイデアファイルが見つかりました:
   1. 20250115-auth-feature.md
   2. 20250120-api-design.md
   3. 20250124-data-pipeline.md

   どのアイデアからドキュメントを生成しますか？
   ```

   1つだけの場合はそのまま使用。

2. **不足情報の一括確認**

   アイデアファイルの「技術的考慮事項」に記載がない場合、AskUserQuestionで一括確認:
   ```
   ドキュメント生成に必要な情報を確認します:
   ```

   確認項目（該当するもののみ）:
   - 主要言語: [Python / TypeScript・Node.js / Rust / Go / MCP-only / その他]
   - Webフレームワーク: [FastAPI / Express / Hono / Gin / Actix / なし]
   - データベース: [SQLite / PostgreSQL / その他 / なし]
   - テストフレームワーク: [pytest / vitest / jest / cargo test / go test / なし(MCP-only)]
   - 主要 MCP サーバー（MCP-only または併用時）: [サーバー名のリスト]

3. **計画段階ドキュメント生成**（`docs/core/` に出力。`README.md` と `CLAUDE.md` はリポジトリルートに出力）

   各ドキュメントは対応するSkillのテンプレート・ガイドを参照して生成:

   **真のコアドキュメント（規模を問わず必須）:**

   | ドキュメント | 出力先 | 参照Skill | 内容 |
   |-------------|--------|-----------|------|
   | `README.md` | リポジトリルート | - | 概要・インストール・使い方の入口 |
   | `CLAUDE.md` | リポジトリルート | `Skill('init')` | Claude Code 向け開発コンテキスト |
   | `development-guidelines.md` | `docs/core/` | `Skill('development-guidelines')` | 技術スタックに基づく規約 |

   **スケーラブルオプション（プロジェクト規模に応じて生成）:**

   | ドキュメント | 出力先 | 参照Skill | 中規模以上で推奨 | 大規模で推奨 |
   |-------------|--------|-----------|:---:|:---:|
   | `product-requirements.md` | `docs/core/` | `Skill('prd-writing')` | ✓ | ✓ |
   | `architecture.md` | `docs/core/` | `Skill('architecture-design')` | ✓ | ✓ |
   | `repository-structure.md` | `docs/core/` | `Skill('repository-structure')` | ✓ | ✓ |
   | `functional-design.md` | `docs/core/` | `Skill('functional-design')` |  | ✓ |
   | `glossary.md` | `docs/core/` | `Skill('glossary-creation')` |  | ✓ |
   | `api-reference.md` | `docs/core/` | - |  | ✓（API提供時） |
   | `diagrams.md` | `docs/core/` | - |  | ✓ |
   | `CHANGELOG.md` | リポジトリルート | - |  | ✓ |

   **小規模プロジェクトでの生成方針**:
   小規模では「真のコア」のみ生成し、PRD等はスキップ。アイデアファイルの内容を `README.md` の概要セクションに集約してよい。

   **生成順序（中規模以上）:**
   1. `README.md`（最初に生成、プロジェクトの入口）
   2. `CLAUDE.md`
   3. `product-requirements.md`（生成する場合、他のドキュメントの基盤となる）
   4. `architecture.md`
   5. `repository-structure.md`
   6. `development-guidelines.md`
   7. `functional-design.md`, `glossary.md`（大規模時）
   8. `api-reference.md`, `diagrams.md`, `CHANGELOG.md`（オプション）

4. **計画段階マーカーの付与**

   全ドキュメントの冒頭に以下を追加:
   ```markdown
   > **ステータス: 計画段階**
   > このドキュメントは `docs/ideas/{filename}.md` から生成されました。
   > 実装後は `/update-docs` で実態に同期してください。
   ```

5. **生成後の確認**
   - 各ファイルの存在確認
   - 生成サマリーを表示

---

## 出力先

```
<リポジトリルート>/
├── README.md                       # 概要・使い方の入口（真のコア）
├── CLAUDE.md                       # Claude Code 向けコンテキスト（真のコア）
├── CHANGELOG.md                    # 変更履歴（オプション・大規模）
└── docs/core/
    ├── development-guidelines.md   # 開発ガイドライン（真のコア）
    ├── product-requirements.md     # PRD（新規モードかつ中規模以上）
    ├── architecture.md             # アーキテクチャ設計書（中規模以上）
    ├── repository-structure.md     # リポジトリ構造定義書（中規模以上）
    ├── functional-design.md        # 機能設計書（大規模）
    ├── glossary.md                 # 用語集（大規模）
    ├── api-reference.md            # API仕様書（大規模・API提供時）
    └── diagrams.md                 # 図表（大規模）
```

### 規模別の生成パターン

| 規模 | 生成ドキュメント |
|------|-----------------|
| **MCP-only** | `README.md` + `CLAUDE.md`（`.mcp.json` 構成と運用手順を中心に記述。`development-guidelines.md` はオプション） |
| **小規模**（Claude Codeツール等） | `README.md` + `CLAUDE.md` + `development-guidelines.md`（最小構成） |
| **中規模** | 上記 + `architecture.md` + `repository-structure.md`（+ 新規時 `product-requirements.md`） |
| **大規模**（本格アプリ） | 全コアドキュメント + 必要なオプション |

---

## 生成ドキュメントの違い（モード別）

### 真のコアドキュメント

| ドキュメント | 既存プロジェクト | 新規プロジェクト |
|-------------|------------------|------------------|
| `README.md` | コードと既存記述から要約 | アイデアから入口記述を生成 |
| `CLAUDE.md` | コードベースの文脈を抽出 | 想定スタック・ディレクトリ構成を記述 |
| `development-guidelines.md` | 既存パターンから規約抽出 | 技術スタックに基づく規約 |

### スケーラブルオプション

| ドキュメント | 既存プロジェクト | 新規プロジェクト |
|-------------|------------------|------------------|
| `product-requirements.md` | 生成しない（実装済み） | **詳細なPRD**を生成 |
| `architecture.md` | 実コードから逆生成 | アイデアから**想定**構造を生成 |
| `repository-structure.md` | 実ディレクトリ構造 | **想定**ディレクトリ構造 |
| `functional-design.md` | 実装機能から逆生成 | アイデアから**想定**設計を生成 |
| `glossary.md` | コードから用語抽出 | アイデアから用語定義 |
| `api-reference.md` | 実在クラス/関数を文書化 | **想定API**のスタブ生成 |
| `diagrams.md` | 実データフローを図示 | **想定**フローを図示 |
| `CHANGELOG.md` | gitログから生成 | 「初期計画」として生成 |

---

## MCP-only モード

`.mcp.json` がプロジェクトの中心で、独自コードを書かない構成向けの最小モード。

### source of truth
- `.mcp.json`（または `.claude/.mcp.json`）と `docs/ideas/*.md`

### 生成対象（最小構成）

| ドキュメント | 出力先 | 内容 |
|-------------|--------|------|
| `README.md` | リポジトリルート | プロジェクト概要、利用する MCP サーバー一覧、セットアップ手順 |
| `CLAUDE.md` | リポジトリルート | Claude Code 向けコンテキスト。MCP サーバーごとの用途と推奨ワークフロー |
| `docs/core/mcp-configuration.md`（任意） | `docs/core/` | `.mcp.json` の各エントリの役割、認証情報の管理方法、運用上の注意 |

`development-guidelines.md` は MCP-only では原則生成しない（コーディング規約が不要なため）。
ただしユーザーが「運用ルール」を明文化したい場合は、最小構成で生成してもよい。

### 生成内容のポイント

- `.mcp.json` の構造を Read で取得し、各 MCP サーバーの `name` と `command` / `args` を整理
- 各 MCP サーバーの目的・必要な権限・取り扱う情報を README/CLAUDE.md に記述
- コード関連のセクション（テスト・リント・型チェック等）は省略

### スコープ外
- `architecture.md` / `repository-structure.md` / `functional-design.md` / `api-reference.md` / `diagrams.md` 等のコード前提ドキュメントは生成しない
- 必要になった時点でユーザーが個別 Skill（`/architecture-design` など）で追加

---

## source of truth の原則

| プロジェクト状態 | source of truth | 更新方向 |
|------------------|-----------------|----------|
| 新規（計画段階） | `docs/ideas/*.md` | ideas → core |
| 既存（実装済み） | ソースコード | code → core |
| MCP-only | `.mcp.json` + `docs/ideas/*.md` | mcp.json → README/CLAUDE.md |
| 実装完了後 | ソースコード | `/update-docs`で同期 |

**原則**: `docs/core/`は常に派生物（sourceではない）

---

## 注意事項

- 既存ファイルは上書きされます
- プロジェクトの実態（コードまたはアイデア）に基づいて内容を生成してください
- 不明な部分は推測せず、「要確認」と記載してください
- 新規プロジェクトモードでは、計画段階マーカーを必ず付与してください

---

## product-requirements.md の生成仕様

新規プロジェクトモードで生成する `product-requirements.md` は、以下の構成で作成してください。

### 必須セクション

1. **プロダクト概要**
   - 名称
   - プロダクトコンセプト（箇条書き4項目程度）
   - プロダクトビジョン（1段落）
   - 目的（箇条書き）

2. **ターゲットユーザー**
   - プライマリーペルソナ（名前、年齢、属性）
   - 基本属性
   - 技術スタック（ユーザーの技術レベル）
   - 現在の課題
   - 期待する解決策
   - 1日の典型的なワークフロー

3. **成功指標（KPIs）**
   - プライマリーKPI（表形式: 指標 / 目標 / 測定方法）
   - セカンダリーKPI（表形式）

4. **機能要件**（優先度別）
   - P0（必須）: コア機能
   - P1（重要）: 重要機能
   - P2（できれば）: 将来機能

   各機能には以下を含める:
   - **ユーザーストーリー**: 「〜として、〜するために、〜が欲しい」形式
   - **受け入れ条件**: チェックリスト形式（`- [ ]`）
   - **検証方法**: 表形式（検証項目 / テストデータ / 合格基準）
   - **優先度**: P0/P1/P2

5. **非機能要件**
   - パフォーマンス（表形式: 処理 / 目標 / 測定条件）
   - ユーザビリティ
   - 信頼性
   - セキュリティ

6. **技術スタック**
   - 表形式（項目 / 技術 / 選定理由）

7. **スコープ外**
   - 明示的に対象外とする項目（箇条書き）

8. **リスクと対策**
   - 表形式（リスク / 影響度 / 発生可能性 / 対策）

9. **開発フェーズ**
   - フェーズごとに:
     - 目標
     - 実装内容
     - 成功基準（チェックリスト形式）

10. **APIインターフェース（想定）**
    - 採用言語のコード例（Python / TypeScript / Rust / Go 等。プロジェクトの主要言語に合わせる）
    - REST API 例（エンドポイント一覧、該当する場合）
    - MCP-only プロジェクトでは `.mcp.json` のサンプルと利用 MCP ツール一覧

### 参照ドキュメント

既存の詳細なPRD例として `docs/refs/product-requirements.md` を参照可能。
形式や粒度の参考にしてください。
