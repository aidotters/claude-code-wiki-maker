# 開発ガイドライン（最小構成）

> **ステータス: MVP（Phase 1）＋ Phase 2a・2b・3a・3b・3c・3d・3e・3f・3g・4 実装済み**
> このドキュメントは実装済みスキル `.claude/skills/llm-wiki/`（source of truth）と `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`（受け入れ条件の正本）から同期されています。
> 主役機能 `/llm-wiki` は `init` / `ingest` / `query` / `synthesize` / `lint`（16 検査）/ `refresh-tier-a` / `discover-tier-a` / `refresh-watchlist` / `review` / `discover-watchlist` を実装済みです。スキル改修後は `/update-docs`（または `/gen-all-docs`）で実態に同期してください。

このリポジトリは個人の Claude Code 知識ハブで、ビルド対象のアプリケーションコードを持ちません。「開発」とは主に **`.claude/skills/llm-wiki/` のスキル定義の作成・保守**、および **Wiki ボールトの規約の遵守**を指します。本ガイドラインは小規模構成として、テスト/リント/主要規約のみを定義します。設計の全体像（3 層・モード関係・データフロー・設計判断インデックス）は [`architecture.md`](architecture.md) を参照。

## 1. リポジトリの境界

| 場所 | 内容 | バージョン管理 |
|------|------|----------------|
| 本リポジトリ | スキル資産（`.claude/`）・ドキュメント（`docs/`） | このリポジトリの Git |
| `./wiki-vault`（実体は別所在） | Wiki ボールト（`raw/`・`wiki/`） | **別リポジトリの Git**（操作ごとコミット） |

- `wiki-vault` は `.gitignore` 対象。本リポジトリにボールト実体をコミットしない。
- `.claude` をボールト側に持たせない。スキルは本リポジトリ限定（グローバル配置・ボールトコピーをしない）。
- 設定ファイル: `.llm-wiki.json`（ボールト相対パス `./wiki-vault`・`schema_version`・任意の `minitools_path`。`/llm-wiki init` が作成）。

## 2. スキル定義の規約

- スキルは単一スキル `/llm-wiki <操作>` とし、`SKILL.md` 内でモード分岐する（B=ingest 共通 surface / D=lint #11 決着 / F=refresh-tier-a / G=discover-tier-a / W=refresh-watchlist / H=review / I=discover-watchlist）。独立スラッシュコマンドや skill 同梱 hooks は作らない。
- **hooks は `references/*.example.*` に設定例として同梱**し、導入は利用者判断（`.claude/settings.json` への手動マージ）。session-start hook（3b）・会話 URL hook（3e）・launchd plist 例（refresh-tier-a / refresh-watchlist / discover-watchlist）が該当。
- 構成: `.claude/skills/llm-wiki/SKILL.md` ＋ `references/{schema.md, page-templates.md, lint-rules.md}` ＋ 設定例ファイル群。
- 記述粒度・フロントマターは既存 `.claude/skills/*/SKILL.md` と揃え、`gen-all-docs` の規模方針と平仄を保つ。
- 受け入れ条件の正本は `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`。実装はこれを満たすこと。
- schema（`references/schema.md`）とスキルは co-evolve する。schema 改訂時は `.llm-wiki.json` の `schema_version` も更新（現行 **v1.9.0**）。

## 3. Wiki 運用の不変条件（実装で必ず守る）

1. **検索ではなくコンパイル**: 取り込み時に要約・相互参照・矛盾フラグを確定し維持。
2. **必ず引用**: 全主張は特定の `raw/` ソースを引用。`raw/` は不変スナップショット（原文 URL・取得日時・取得手段をメタ保持。WebFetch は要約のため raw に `note:` 明示＋再検証経路を残す。Medium は `fetched_via: minitools-playwright` の英語原文 verbatim）。
3. **黙って上書きしない**: 既存と矛盾する主張は「矛盾」セクションを追加。
4. **二段の矛盾検出（決定 Z）**: ingest は同一トピック（[[wikilink]] 先）のみ即時照合。横断矛盾は index.md の主張サマリを使う `lint`（Phase 2b・実装済み）に委譲。ingest/synthesize は index.md に各ページの主要主張サマリ（1〜2 行）を維持する。
5. **フロントマター骨格は MVP から（決定 ア）**: `claude_code_version` / `updated` / `stale` / 情報源ティアは MVP の ingest/synthesize で全ページに記録。`lint` の機械判定・意味解釈は Phase 2a/2b で、refresh/discover/watchlist 系の停止監視（#12〜#16）は Phase 3a/3c/3f/3g で実装済み。
6. **情報源ティア**: Tier A（Anthropic 公式ドキュメント/公式 GitHub）/ Tier B（その他）。
   - Tier A の既知 URL は **日次自動再取得**（`refresh-tier-a`・モード F・Phase 3a）、未取り込み URL は**自動発見＋承認制 ingest**（`discover-tier-a`・モード G・Phase 3c）。`current-baseline.md` は Tier A 由来は自動更新可・手動上書き可。
   - Tier B は**承認制**。watchlist（`watch:true`）の日次自動再取得（`refresh-watchlist`・モード W・Phase 3f）とフィード（`feed_url` / `feed_registry[]`）の新着自動発見（`discover-watchlist`・モード I・Phase 3g/4）を解禁したが、**`current-baseline.md` の version 系は自動更新しない**（W-4f 省略・決定6＝乖離は lint #3 が次回対話で再検出）。
7. **単一エージェント書き込み前提**: 個人利用・マージ競合回避。信頼度 0.7 程度を許容。
8. **操作ごと Git コミット**: ボールト側に `index.md` / `log.md` 更新とともにコミット（`log.md` は dirty 状態でも append + commit 可）。

## 4. ページタイプ（スキーマ）

| タイプ | 用途 |
|--------|------|
| source / concept / entity / comparison / synthesis | 汎用。`synthesis` はチートシート/Tips 集等の派生成果物 |
| practice | 試した Claude Code 実践とその効果（効いた/効かなかった） |
| feature | Claude Code 自体の機能（Skill/Hooks/MCP/Agent SDK 等）の最新仕様。`claude_code_version` を持つ |

線引き: 抽象的な原則は `concept`、Claude Code の機能は `feature`、それ以外の固有物（外部ツール/人物/組織/ライブラリ）は `entity`。

## 5. 並行制御・自動化

- **排他制御**: 書き込みモード（B / D / F / G / W / H / I・lint #11 承認制決着）は `.llm-wiki.lock`（vault 直下・atomic 取得・スタール判定は timestamp 1h ＋ `kill -0` の AND）で排他する。
- **非対話自動化**: `refresh-tier-a` / `refresh-watchlist` / `discover-watchlist` は launchd/cron からの非対話実行を前提に、`--no-prompt` / `--dry-run` を持つ。cron 経路は **API キー認証のみの取得**（Tier A docs / Notion DB）に限定し、Playwright auth decay を持つ Medium content fetch（4a）は**対話のみ**。
- **stagger**: 3 系統の launchd plist は起動時刻をずらし（03:00/03:30/04:00）、lock 競合を回避する。**4 系統目 plist は作らない**（mode I を流用）。
- **minitools 依存（Phase 4・任意）**: Medium 機能は外部リポジトリ minitools の 2 CLI（`scrape-medium` / `discover-notion-medium`）に依存。`.llm-wiki.json` の `minitools_path` 未設定/ディレクトリ不在なら **Medium 機能のみ無効化し他モードは通常動作**（clean failure）。

## 6. テスト/品質

- アプリケーションコードがないため、自動テスト・リント・型検査の対象はない。
- 品質担保:
  - スキル定義は受け入れ条件（idea ドキュメント）との突き合わせでレビュー（`/review-docs`）。
  - ボールト整合は `/llm-wiki lint`（16 検査・実装済み。Phase 2a 機械判定 7 ＋ Phase 2b 意味解釈 4 ＋ Phase 3a/3c/3f/3g 機械判定 5。#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記）で監査し結果を `log.md` に追記。
- ドキュメントは実装済みスキルを source of truth とし、改修後は `/update-docs`（または `/gen-all-docs`）で同期する。

## 7. コミット規約

- 本リポジトリ: 変更内容を簡潔に。スキル/モード追加時は `README.md`（含まれるもの・操作表・推奨ワークフロー）・`CLAUDE.md`・本ファイルを同時更新。
- ボールト側（別リポジトリ）: `/llm-wiki` の各操作が `index.md`/`log.md` 更新を伴って自動コミットする。Tier B の取得失敗は `fetch_status: failed` を Edit + commit（死 URL は lint #15 で surface・受動回復）。
