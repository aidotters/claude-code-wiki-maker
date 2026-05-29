# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **ステータス: MVP（Phase 1）＋ Phase 2a・2b・3a・3b・3d 実装済み**
> このリポジトリは `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`（決定 A）に基づき、
> 「テンプレート」から「個人 Claude Code 知識ハブ専用リポジトリ」へ役割転換しました。
> 主役機能 `/llm-wiki` の `init` / `ingest`（Phase 3d 共通 surface 拡張：migration_pending 承認後 ingest を内包、
> 同一 source 判定 3 段ロジック、URL 正規化最小ルール、sources: 末尾 append 明文化、overview 自動更新 inline）/
> `query` / `synthesize`（Phase 3d overview 自動更新 inline）/ `lint`（Phase 2a 機械判定 7 検査＋
> Phase 2b 意味解釈 4 検査・#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記＋
> Phase 3a `#12 last-tier-a-refresh` 機械判定／§2.5 migration_pending 提案フローは Phase 3d で
> 共通 surface 経由に再定義）/ `refresh-tier-a [--dry-run]`（Phase 3a・Tier A 日次自動再取得・
> launchd/cron からの非対話実行・Phase 3b で F-5 空 commit ガード追加・Phase 3d で F-2 dirty check
> から log.md を除外＝pathspec `:!wiki/log.md`、F-4e に sources: append 仕様再掲、
> F-4g/F-5 に overview inline 更新追加）と Phase 3b の session-start hook 設定例
> （`references/session-start-hook.example.json`・利用者が `.claude/settings.json` に手動マージ）、
> schema/templates（practice/feature 含む・schema v1.4.0 で overview.md `## 現状` セクション構造定義と
> log.md dirty append 規約を追加）を `.claude/skills/llm-wiki/` に実装済みです。
> スキル改修後は `/update-docs` で本ファイルを実態へ同期してください。

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
| `/llm-wiki ingest <path-or-url> [--type=practice|--feature=<slug>]` | ソース取り込み・コンパイル・相互参照（`--type`／`--feature` は 2a／3d: 共通 surface 拡張で migration_pending 承認後 ingest を内包・同一 source 判定 3 段・sources: 末尾 append・overview 自動更新 inline） | 1（MVP）＋ 2a ＋ 3d |
| `/llm-wiki query <質問>` | Wiki から引用付きで回答（不足は Web 補完明示） | 1（MVP） |
| `/llm-wiki synthesize <テーマ>` | チートシート/Tips 集等の派生成果物を生成・再生成（3d: overview 自動更新 inline） | 1（MVP）＋ 3d |
| `/llm-wiki lint [--check=<csv>]` | 健全性・陳腐化・信頼度の監査（2a: 機械判定 7 検査・レポートのみ／2b: 意味解釈 4 検査・承認制／3a: #12 last-tier-a-refresh 機械判定／3d: §2.5 migration_pending 提案フローを共通 surface 経由に再定義） | 2a／2b／3a／3d |
| `/llm-wiki refresh-tier-a [--dry-run]` | Tier A（公式 docs / 公式 GitHub）の既知 URL を日次自動再取得・再コンパイル・`current-baseline.md` の baseline フィールド自動更新。launchd/cron 経由の非対話実行（モード F）。`--dry-run` は副作用ゼロのレポートのみ。3d で F-2 dirty check から log.md 除外・F-4e sources: append 仕様再掲・F-4g/F-5 overview inline 更新 | 3a／3d |

ロードマップ: Phase 2a（**実装済み**）= 機械判定 lint 7 検査＋ practice/feature テンプレ＋ ingest 動線拡張 / Phase 2b（**実装済み**）= 意味解釈 lint 4 検査（横断矛盾・synthesis 再生成要否・3 面相互矛盾・バージョン軸決着、承認制） / Phase 3a（**実装済み**）= `/llm-wiki refresh-tier-a` + ロック規約 + lint #12（refresh 停止監視） / Phase 3b（**実装済み**）= session-start hook 設定例（read-only context preload）＋ F-5 空 commit ガード / Phase 3c = `/llm-wiki discover-tier-a`（未取り込み URL の自動発見、未設計） / Phase 3d（**実装済み**）= F-4 共通 surface 確立（mode B ingest 拡張で migration_pending 承認後 ingest を内包）＋ F-6 sources: append 明文化＋ C overview 自動更新（同一 commit inline）＋ F-3 log.md append 規約（F-2 dirty check から log.md 除外） / Phase 3e = 会話中の URL 自動取り込み（B・trigger 設計、未設計） / Phase 4 = ソース別取得ツール。

### 既存のドキュメント生成系コマンド/スキル

`/brainstorm` `/gen-all-docs` `/plan-feature` `/implement-feature` 等は、知識ハブ自身の運用・改善（llm-wiki スキルの設計と保守）を支える **補助ツール** として併存します。

## 3 層アーキテクチャ（厳守）

| 層 | 実体 | 所有者 |
|----|------|--------|
| `raw/` | 取得スナップショット（原文 URL・取得日時・取得手段をメタ保持、不変） | 人間が追加、エージェントは読むだけ |
| `wiki/` | コンパイル済み Markdown ページ群（相互参照・[[wikilinks]]） | エージェントが完全所有 |
| スキル（スキーマ） | 規約とワークフロー | エージェントを規律あるメンテナーにする |

### ボールトの所在（実体は分離）

Wiki の実体は **独立した Obsidian ボールト**（例: `~/Documents/claude-code-wiki`、別 Git で管理）。本リポジトリ直下にシンボリックリンク `./wiki-vault` を 1 本張って参照します（`.gitignore` 対象）。Obsidian は閲覧・グラフ・バックリンクの表示レイヤー。`.claude` はボールト側に持たせません。

```
personal-wiki-for-claude-code/        # スキル資産の置き場（このリポジトリ）
├── .claude/skills/llm-wiki/
│   ├── SKILL.md
│   └── references/{schema.md,page-templates.md,lint-rules.md}
├── .gitignore                        # wiki-vault を追記
└── wiki-vault -> ~/Documents/claude-code-wiki   # シンボリックリンク

~/Documents/claude-code-wiki/           # 実体（独立 Obsidian ボールト・別 Git）
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
5. **フロントマター骨格は MVP から（決定 ア）**: lint の機械判定 7 検査は Phase 2a で実装済み（意味解釈 4 検査は Phase 2b 実装済み、Phase 3a で #12 `last-tier-a-refresh` を追加）。`claude_code_version` / `updated` / `stale` / 情報源ティア（Tier A=公式 / Tier B=その他）は MVP の ingest/synthesize 時点で全ページに記録する。`current-baseline.md` には Phase 3a で `last_tier_a_refresh` / `migration_pending` を追加（schema v1.3.0）。Phase 3d で schema v1.4.0 = `overview.md` に agent 完全所有の `## 現状` セクション構造（統計値 5 件・最終 ingest / 最終更新 2 日付）を追加、§3 raw 引用記法直下に「log.md は dirty 状態でも append + commit 可」を明記。
6. **情報源ティア**: Tier A（Anthropic 公式ドキュメント/公式 GitHub）は Phase 3a で日次自動更新（モード F `refresh-tier-a`）を先行解禁・実装済み。`current-baseline.md` は Tier A 由来は自動更新可・手動上書き可、Tier B はバージョン乖離時に対話で更新提案（承認制）。書き込みモード（B / D / F／lint #11 承認制決着）は `.llm-wiki.lock`（vault 直下・atomic 取得・スタール判定 timestamp 1h ＋`kill -0` の AND）で排他制御する。
7. **単一エージェント書き込み前提**: 個人利用・マージ競合回避。信頼度 0.7 程度を許容。
8. **操作ごと Git コミット**: ボールト側（別リポジトリ）に履歴を残す。

## Commands

このリポジトリには独自のビルド対象コードはありません。テスト・リント・型チェックの対象はなく、品質はドキュメントとスキル定義（`.claude/skills/*/SKILL.md`）のレビューで担保します。

- スキル定義の検証: `.claude/skills/*/SKILL.md` のフロントマター・記述粒度を既存 Skill と揃える
- ボールト整合の検証: `/llm-wiki lint`（Phase 2a 機械判定 7 検査＋ Phase 2b 意味解釈 4 検査・実装済み。#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記）

## このリポジトリ自体の作業

- `llm-wiki` スキルの修正時は、本ファイルの「設計上の不変条件」と `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md` の受け入れ条件に従う
- スキルの記述粒度は既存 `.claude/skills/*/SKILL.md` および `gen-all-docs` の小規模／中規模／大規模方針と平仄を保つ
- コマンドやスキルを追加した場合は `README.md` の「含まれるもの」表と「推奨ワークフロー」も更新する
- 実装例（`src/example.py` 等）は置かない。スケルトンの空ディレクトリのみ保持する

## Configuration

- ボールトパス: 本リポジトリ直下の設定ファイル `.llm-wiki.json` に相対パス `./wiki-vault`（正）・実体絶対パス（参考）・`schema_version`（`references/schema.md` から転記。co-evolution 時に更新）を記録（`/llm-wiki init` が作成）
- `.gitignore`: `wiki-vault`（シンボリックリンクの誤コミット防止）と `.steering/` を追記
- 環境変数: `.env`（`.env.example` を参照）
- 依存: Claude Code Skills / Git / Obsidian（表示）/ シンボリックリンク / WebFetch・WebSearch

## ドキュメント生成のスケール対応

`/gen-all-docs` はプロジェクト規模に応じて生成範囲を切り替えます。本リポジトリは小規模（単一スキル・コード実装なし）に該当し、`README.md` + `CLAUDE.md` + `development-guidelines.md` を生成対象とします。
