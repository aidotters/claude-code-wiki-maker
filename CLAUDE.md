# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **ステータス: 計画段階**
> このリポジトリは `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`（決定 A）に基づき、
> 「テンプレート」から「個人 Claude Code 知識ハブ専用リポジトリ」へ役割転換中です。
> 主役機能 `llm-wiki` は未実装。実装後は `/update-docs` で実態へ同期してください。

## Project Overview

このリポジトリは **個人の Claude Code 知識ハブ専用リポジトリ** です。

進化の速い Claude Code（CLI / Agent SDK / API）のベストプラクティス・公式更新・実践知見を、Karpathy の「LLM Wiki」パターン（**検索ではなくコンパイル**）で永続的な知識ベースに蓄積・整理し続け、そこから「最新チートシート」「開発者向け Tips 集」等の派生成果物（synthesis）を引用付きで生成・維持することを目的とします。

> このリポジトリは **GitHub の "Use this template" でコピーして使うテンプレートではありません**。
> 利用者自身がこのリポジトリを CWD にして `claude` を起動し、`/llm-wiki` を運用します。

### 主役機能: `/llm-wiki`（単一スキル・モード分岐）

`.claude/skills/llm-wiki/` に **本プロジェクト限定**で配置する単一スキル。ユーザーグローバル配置・ボールトへのコピーはしません。SKILL.md 内でモード分岐します。

| モード | 役割 | Phase |
|--------|------|-------|
| `/llm-wiki init` | ボールト初期化・`./wiki-vault` シンボリックリンク案内 | 1（MVP） |
| `/llm-wiki ingest <path-or-url>` | ソース取り込み・コンパイル・相互参照 | 1（MVP） |
| `/llm-wiki query <質問>` | Wiki から引用付きで回答（不足は Web 補完明示） | 1（MVP） |
| `/llm-wiki synthesize <テーマ>` | チートシート/Tips 集等の派生成果物を生成・再生成 | 1（MVP） |
| `/llm-wiki lint` | 健全性・陳腐化・横断的矛盾・信頼度の監査 | 2 |

ロードマップ: Phase 2 = lint＋拡張スキーマ（practice/feature, version baseline）/ Phase 3 = hooks 設定例・URL 自動取得・**Tier A（公式）日次自動更新の先行解禁** / Phase 4 = ソース別取得ツール。

### 既存のドキュメント生成系コマンド/スキル

`/brainstorm` `/gen-all-docs` `/plan-feature` `/implement-feature` 等は、知識ハブ自身の運用・改善（llm-wiki スキルの設計と保守）を支える **補助ツール** として併存します。

## 3 層アーキテクチャ（厳守）

| 層 | 実体 | 所有者 |
|----|------|--------|
| `raw/` | 取得スナップショット（原文 URL・取得日時・取得手段をメタ保持、不変） | 人間が追加、エージェントは読むだけ |
| `wiki/` | コンパイル済み Markdown ページ群（相互参照・[[wikilinks]]） | エージェントが完全所有 |
| スキル（スキーマ） | 規約とワークフロー | エージェントを規律あるメンテナーにする |

### ボールトの所在（実体は分離）

Wiki の実体は **独立した Obsidian ボールト**（例: `~/Documents/ClaudeCodeWiki`、別 Git で管理）。本リポジトリ直下にシンボリックリンク `./wiki-vault` を 1 本張って参照します（`.gitignore` 対象）。Obsidian は閲覧・グラフ・バックリンクの表示レイヤー。`.claude` はボールト側に持たせません。

```
personal-wiki-for-claude-code/        # スキル資産の置き場（このリポジトリ）
├── .claude/skills/llm-wiki/
│   ├── SKILL.md
│   └── references/{schema.md,page-templates.md,lint-rules.md}
├── .gitignore                        # wiki-vault を追記
└── wiki-vault -> ~/Documents/ClaudeCodeWiki   # シンボリックリンク

~/Documents/ClaudeCodeWiki/           # 実体（独立 Obsidian ボールト・別 Git）
├── raw/{docs,articles,videos,github,notes}/
└── wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/
    ├── index.md          # 各ページの主要主張サマリ（1〜2 行）を維持
    ├── log.md
    ├── overview.md
    └── current-baseline.md   # claude_code_version 等の現在の正
```

## 設計上の不変条件（実装時に必ず守る）

1. **検索ではなくコンパイル**: 取り込み時に要約・相互参照・矛盾フラグを確定し維持する。
2. **必ず引用**: すべての主張は特定の `raw/` ソースを引用する。`raw/` は不変スナップショット。
3. **黙って上書きしない**: 既存ページと矛盾する主張は「矛盾」セクションを追加する。
4. **二段の矛盾検出（決定 Z）**: ingest 時は同一トピック（[[wikilink]] 先）のみ即時照合。トピック横断の矛盾は index.md の主張サマリを使う Phase 2 lint に委譲。
5. **フロントマター骨格は MVP から（決定 ア）**: lint の判定ロジックは Phase 2 でも、`claude_code_version` / `updated` / `stale` / 情報源ティア（Tier A=公式 / Tier B=その他）は MVP の ingest/synthesize 時点で全ページに記録する。
6. **情報源ティア**: Tier A（Anthropic 公式ドキュメント/公式 GitHub）は Phase 3 で日次自動更新を先行解禁。`current-baseline.md` は Tier A 由来は自動更新可・手動上書き可、Tier B はバージョン乖離時に対話で更新提案（承認制）。
7. **単一エージェント書き込み前提**: 個人利用・マージ競合回避。信頼度 0.7 程度を許容。
8. **操作ごと Git コミット**: ボールト側（別リポジトリ）に履歴を残す。

## Commands

このリポジトリには独自のビルド対象コードはありません。テスト・リント・型チェックの対象はなく、品質はドキュメントとスキル定義（`.claude/skills/*/SKILL.md`）のレビューで担保します。

- スキル定義の検証: `.claude/skills/*/SKILL.md` のフロントマター・記述粒度を既存 Skill と揃える
- ボールト整合の検証（実装後）: `/llm-wiki lint`

## このリポジトリ自体の作業

- `llm-wiki` スキルの修正時は、本ファイルの「設計上の不変条件」と `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md` の受け入れ条件に従う
- スキルの記述粒度は既存 `.claude/skills/*/SKILL.md` および `gen-all-docs` の小規模／中規模／大規模方針と平仄を保つ
- コマンドやスキルを追加した場合は `README.md` の「含まれるもの」表と「推奨ワークフロー」も更新する
- 実装例（`src/example.py` 等）は置かない。スケルトンの空ディレクトリのみ保持する

## Configuration

- ボールトパス: 設定ファイルに相対パス `./wiki-vault` と実体絶対パスを記録（`/llm-wiki init` が作成）
- `.gitignore`: `wiki-vault` を追記（シンボリックリンクの誤コミット防止）
- 環境変数: `.env`（`.env.example` を参照）
- 依存: Claude Code Skills / Git / Obsidian（表示）/ シンボリックリンク / WebFetch・WebSearch

## ドキュメント生成のスケール対応

`/gen-all-docs` はプロジェクト規模に応じて生成範囲を切り替えます。本リポジトリは小規模（単一スキル・コード実装なし）に該当し、`README.md` + `CLAUDE.md` + `development-guidelines.md` を生成対象とします。
