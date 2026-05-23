# personal-wiki-for-claude-code

> **ステータス: MVP（Phase 1）＋ Phase 2a・2b 実装済み**
> 主役機能 `/llm-wiki` の `init` / `ingest` / `query` / `synthesize` / `lint`（機械判定 7 検査＋
> 意味解釈 4 検査・#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記）と
> schema/templates（practice/feature 含む）を `.claude/skills/llm-wiki/` に実装済みです。

進化の速い **Claude Code**（CLI / Agent SDK / API）の知識を、検索ではなく**コンパイル**して蓄積し続ける、**個人の Claude Code 知識ハブ**リポジトリです。

ベストプラクティス・公式更新・自分の試行錯誤を、相互参照された永続的な Wiki に整理し続け、そこから「最新チートシート」「開発者向け Tips 集」等を**引用付き**で生成・維持します。Karpathy の「LLM Wiki」パターンを Claude Code スキル `/llm-wiki` として実装します。

> このリポジトリは **コピーして使うテンプレートではありません**。
> このリポジトリを CWD にして `claude` を起動し、`/llm-wiki` を運用します。

## コンセプト: 検索ではなくコンパイル

通常のメモアプリや RAG はステートレスで、ソースを足しても知識が「コンパイル」されず矛盾や陳腐化が放置されます。本リポジトリは 3 層アーキテクチャでこれを解決します。

| 層 | 役割 | 所有 |
|----|------|------|
| `raw/` | 取得スナップショット（原文 URL・取得日時・取得手段を保持、不変） | 人間が追加 |
| `wiki/` | コンパイル済みページ群（要約・相互参照・[[wikilinks]]） | エージェントが所有 |
| スキル | 規約とワークフロー（必ず引用・矛盾は明示・操作ごと Git） | 規律の源 |

Wiki の実体は**独立した Obsidian ボールト**（別 Git 管理）。本リポジトリからはシンボリックリンク `./wiki-vault` で参照します（実体は分離・`.gitignore` 対象）。Obsidian はグラフ/バックリンク/閲覧の表示レイヤーです。

## 使い方

```bash
cd ~/Projects/personal-wiki-for-claude-code
ln -s ~/Documents/claude-code-wiki ./wiki-vault   # 初回のみ（init が案内）
claude
> /llm-wiki init
> /llm-wiki ingest https://medium.com/.../some-claude-code-best-practice
> /llm-wiki query "Skill の description を確実にトリガーさせる書き方は？"
> /llm-wiki synthesize "最新の Claude Code チートシート"
> /llm-wiki lint
```

### `/llm-wiki` の操作

| 操作 | 内容 | Phase |
|------|------|:---:|
| `init` | ボールト初期化・`./wiki-vault` リンク案内・設定/`.gitignore` 整備 | 1（MVP） |
| `ingest <path-or-url> [--type=practice\|--feature=<slug>]` | ソースを取り込み、source ページ生成・相互参照・矛盾は明示（`--type`／`--feature` は 2a） | 1（MVP）＋ 2a |
| `query <質問>` | index → 関連ページの順で読み引用付き回答（不足は Web 補完を明示） | 1（MVP） |
| `synthesize <テーマ>` | チートシート/Tips 集等を `wiki/syntheses/` に引用付き生成・再生成 | 1（MVP） |
| `lint [--check=<csv>]` | 孤立/陳腐化/信頼度/index 同期/baseline 鮮度の監査（2a: 機械判定 7 検査・レポートのみ／2b: 意味解釈 4 検査・承認制） | 2a／2b |

## ロードマップ

| Phase | 範囲 |
|-------|------|
| **1（MVP）** | `init` / `ingest` / `query` / `synthesize` ＋ schema/templates。フロントマター骨格（`claude_code_version`/`updated`/`stale`/ティア）と情報源ティア区分メタを含む |
| **2a（実装済み）** | `lint` 機械判定 7 検査（#1/#2/#3/#4/#6/#7/#9・レポートのみ）＋ `practice` / `feature` テンプレ＋ ingest 動線拡張（`--type=practice` / `--feature=<slug>`） |
| **2b（実装済み）** | `lint` 意味解釈 4 検査（#5 横断矛盾・#8 synthesis 再生成要否・#10 3 面相互矛盾・#11 バージョン軸決着、承認制。#11 のみ `## 矛盾` 末尾に決着注記を追記） |
| 3 | session-start hook 設定例・URL 自動取得・overview 自動更新・**Tier A（公式）日次自動更新の先行解禁** |
| 4 | ソース別取得ツール（X / Medium / Notion / 公式サイト等） |

## 含まれるもの

| パス | 内容 |
|------|------|
| `.claude/skills/llm-wiki/` | **主役スキル**（SKILL.md＋`references/{schema,page-templates,lint-rules}.md`）。本プロジェクト限定・グローバル配置やボールトコピーはしない |
| `.claude/skills/`, `.claude/agents/` | 知識ハブの運用・保守を支える補助ツール。`/brainstorm` `/gen-all-docs` `/plan-feature` `/implement-feature` 等はすべて `.claude/skills/` 配下のスキルとして実装（`.claude/commands/` は使用しない） |
| `docs/ideas/` | アイデア・要件ドキュメント（`/brainstorm` の出力。本機能の source of truth） |
| `docs/core/` | コアドキュメントの出力先（`/gen-all-docs` が生成） |
| `docs/plan/`, `.steering/` | 計画・作業ステアリングファイル置き場 |
| `wiki-vault -> ...` | 独立 Obsidian ボールトへのシンボリックリンク（`.gitignore` 対象・init が作成） |

## 推奨ワークフロー

スキル本体の設計・改善は補助ツールで回します。

```
/brainstorm          # 要件を docs/ideas/ にまとめる・壁打ち
    ↓
/gen-all-docs        # README / CLAUDE.md / development-guidelines を同期
    ↓
/plan-feature        # llm-wiki スキルの実装計画を .steering/ に作成
    ↓
/implement-feature   # SKILL.md・references を実装
    ↓
/review-docs         # ドキュメント/スキル定義の品質をレビュー
```

知識の蓄積・運用そのものは、主役スキル `/llm-wiki` で回します。

```
/llm-wiki init                 # ボールト初期化・wiki-vault リンク・設定/.gitignore 整備
    ↓
/llm-wiki ingest <path-or-url> # ソースを取り込みコンパイル（要約・相互参照・矛盾明示）
    ↓
/llm-wiki query <質問>         # index→関連ページの順で引用付き回答（不足は Web 補完を明示）
    ↓
/llm-wiki synthesize <テーマ>  # チートシート/Tips 集等を引用付きで生成・再生成
    ↓
/llm-wiki lint                 # 11 検査（Phase 2a 7 機械判定＋ Phase 2b 4 意味解釈・#11 のみ承認制で `## 矛盾` 末尾に決着注記）
```

`lint` の意味解釈 4 検査（#5 横断矛盾・#8 synthesis 再生成要否・#10 3 面相互矛盾・#11 バージョン軸決着）は Phase 2b で実装済みです。

## 設計上の主要決定

- **検索ではなくコンパイル / 必ず引用 / 黙って上書きしない**
- **二段の矛盾検出（決定 Z）**: ingest は同一トピックのみ即時照合、横断矛盾は Phase 2b lint で実装済み
- **フロントマター骨格は MVP から（決定 ア）**: 機械判定 7 検査は Phase 2a、意味解釈 4 検査は Phase 2b で実装済み
- **情報源ティア**: Tier A（公式）は Phase 3 で日次自動更新を先行解禁、Tier B は対話承認制
- **個人利用前提**: 単一エージェント書き込み・操作ごと Git コミット

詳細は `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md` と `docs/core/development-guidelines.md` を参照。
