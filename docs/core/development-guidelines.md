# 開発ガイドライン（最小構成）

> **ステータス: MVP（Phase 1）実装済み**
> このドキュメントは `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md` から生成されました。
> 主役機能 `/llm-wiki` の `init` / `ingest` / `query` / `synthesize` は `.claude/skills/llm-wiki/` に実装済みです（`lint` は Phase 2）。スキル改修後は `/update-docs` で実態に同期してください。

このリポジトリは個人の Claude Code 知識ハブで、ビルド対象のアプリケーションコードを持ちません。「開発」とは主に **`.claude/skills/llm-wiki/` のスキル定義の作成・保守**、および **Wiki ボールトの規約の遵守**を指します。本ガイドラインは小規模構成として、テスト/リント/主要規約のみを定義します。

## 1. リポジトリの境界

| 場所 | 内容 | バージョン管理 |
|------|------|----------------|
| 本リポジトリ | スキル資産（`.claude/`）・ドキュメント（`docs/`） | このリポジトリの Git |
| `./wiki-vault`（実体は別所在） | Wiki ボールト（`raw/`・`wiki/`） | **別リポジトリの Git**（操作ごとコミット） |

- `wiki-vault` は `.gitignore` 対象。本リポジトリにボールト実体をコミットしない。
- `.claude` をボールト側に持たせない。スキルは本リポジトリ限定（グローバル配置・ボールトコピーをしない）。

## 2. スキル定義の規約

- スキルは単一スキル `/llm-wiki <操作>` とし、`SKILL.md` 内でモード分岐する。独立スラッシュコマンドや skill 同梱 hooks は作らない（hooks は `references/` に**設定例**として記載し、導入は利用者判断）。
- 構成: `.claude/skills/llm-wiki/SKILL.md` ＋ `references/{schema.md, page-templates.md, lint-rules.md}`。
- 記述粒度・フロントマターは既存 `.claude/skills/*/SKILL.md` と揃え、`gen-all-docs` の規模方針と平仄を保つ。
- 受け入れ条件の正本は `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`。実装はこれを満たすこと。

## 3. Wiki 運用の不変条件（実装で必ず守る）

1. **検索ではなくコンパイル**: 取り込み時に要約・相互参照・矛盾フラグを確定し維持。
2. **必ず引用**: 全主張は特定の `raw/` ソースを引用。`raw/` は不変スナップショット（原文 URL・取得日時・取得手段をメタ保持）。
3. **黙って上書きしない**: 既存と矛盾する主張は「矛盾」セクションを追加。
4. **二段の矛盾検出（決定 Z）**: ingest は同一トピック（[[wikilink]] 先）のみ即時照合。横断矛盾は index.md の主張サマリを使う Phase 2 `lint` に委譲。ingest/synthesize は index.md に各ページの主要主張サマリ（1〜2 行）を維持する。
5. **フロントマター骨格は MVP から（決定 ア）**: `lint` 判定は Phase 2 でも、`claude_code_version` / `updated` / `stale` / 情報源ティアは MVP の ingest/synthesize で全ページに記録。
6. **情報源ティア**: Tier A（Anthropic 公式ドキュメント/公式 GitHub）/ Tier B（その他）。`current-baseline.md` は Tier A 由来は自動更新可・手動上書き可、Tier B はバージョン乖離時に対話で更新提案（承認制）。Tier A の日次自動更新は Phase 3 で先行解禁。
7. **単一エージェント書き込み前提**: 個人利用・マージ競合回避。信頼度 0.7 程度を許容。
8. **操作ごと Git コミット**: ボールト側に `index.md` / `log.md` 更新とともにコミット。

## 4. ページタイプ（スキーマ）

| タイプ | 用途 |
|--------|------|
| source / concept / entity / comparison / synthesis | 汎用。`synthesis` はチートシート/Tips 集等の派生成果物 |
| practice（Phase 2） | 試した Claude Code 実践とその効果（効いた/効かなかった） |
| feature（Phase 2） | Claude Code 自体の機能（Skill/Hooks/MCP/Agent SDK 等）の最新仕様。`claude_code_version` を持つ |

線引き: 抽象的な原則は `concept`、Claude Code の機能は `feature`、それ以外の固有物（外部ツール/人物/組織/ライブラリ）は `entity`。

## 5. テスト/品質

- アプリケーションコードがないため、自動テスト・リント・型検査の対象はない。
- 品質担保:
  - スキル定義は受け入れ条件（idea ドキュメント）との突き合わせでレビュー（`/review-docs`）。
  - ボールト整合は実装後 `/llm-wiki lint`（Phase 2）で監査し結果を `log.md` に追記。
- 計画段階ドキュメントには計画段階マーカーを付与し、実装後は `/update-docs` で同期する。

## 6. コミット規約

- 本リポジトリ: 変更内容を簡潔に。スキル/コマンド追加時は `README.md`（含まれるもの・推奨ワークフロー）と本ファイルを同時更新。
- ボールト側（別リポジトリ）: `/llm-wiki` の各操作が `index.md`/`log.md` 更新を伴って自動コミットする。
