# personal-wiki-for-claude-code

> **ステータス: MVP（Phase 1）＋ Phase 2a・2b・3a・3b・3c・3d・3e 実装済み**
> 主役機能 `/llm-wiki` の `init` / `ingest` / `query` / `synthesize` / `lint`（機械判定＋
> 意味解釈 4 検査・#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記）/
> `refresh-tier-a`（Tier A 既知 URL の日次自動再取得）/ `discover-tier-a`（Tier A 未取り込み URL の自動発見＋承認制 ingest）/
> `review`（会話 URL hook が貯めた URL を opt-in 承認 ingest）と、
> session-start hook（Phase 3b）・会話 URL hook（Phase 3e）の設定例
> （`references/*.example.*`・利用者が `.claude/settings.json` に手動マージ／`.claude/settings.example.json` を `cp` で有効化）、
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
| `lint [--check=<csv>]` | 孤立/陳腐化/信頼度/index 同期/baseline 鮮度/refresh・discover 停止の監査（2a: 機械判定 7 検査・レポートのみ／2b: 意味解釈 4 検査・承認制／3a: #12 last-tier-a-refresh 機械判定／3c: #13 discover 停止監視） | 2a／2b／3a／3c |
| `refresh-tier-a [--dry-run]` | Tier A 既知 URL の日次自動再取得・再コンパイル・`current-baseline.md` baseline フィールド自動更新（launchd/cron からの非対話実行・モード F）。`--dry-run` は副作用ゼロのレポートのみ。Phase 3b で同日 2 回目の `last_tier_a_refresh` 空 commit をガード | 3a／3b |
| `discover-tier-a [--no-prompt\|--dry-run]` | Tier A 公式 docs/GitHub の**未取り込み URL を自動発見**し `pending_discoveries[]` に dedup append・承認制で共通 surface 経由 ingest（モード G）。`--no-prompt` は launchd/cron 用（discovery のみ・非対話）、`--dry-run` は副作用ゼロ。Phase 3e で承認を capped バッチ opt-out に amend | 3c／3e |
| `review [--dry-run]` | 会話 URL hook が vault 外 `.llm-wiki-inbox.jsonl` に貯めた URL を drain → **opt-in 個別承認** → 共通 surface 経由 ingest（モード H）。対話専用。`--dry-run` は inbox preview のみ | 3e |

## ロードマップ

| Phase | 範囲 |
|-------|------|
| **1（MVP）** | `init` / `ingest` / `query` / `synthesize` ＋ schema/templates。フロントマター骨格（`claude_code_version`/`updated`/`stale`/ティア）と情報源ティア区分メタを含む |
| **2a（実装済み）** | `lint` 機械判定 7 検査（#1/#2/#3/#4/#6/#7/#9・レポートのみ）＋ `practice` / `feature` テンプレ＋ ingest 動線拡張（`--type=practice` / `--feature=<slug>`） |
| **2b（実装済み）** | `lint` 意味解釈 4 検査（#5 横断矛盾・#8 synthesis 再生成要否・#10 3 面相互矛盾・#11 バージョン軸決着、承認制。#11 のみ `## 矛盾` 末尾に決着注記を追記） |
| **3a（実装済み）** | `/llm-wiki refresh-tier-a` + ロック規約（`.llm-wiki.lock`）＋ lint #12 `last-tier-a-refresh`（refresh 停止監視）。launchd plist 例同梱・schema v1.3.0 で baseline フィールド追加 |
| **3b（実装済み）** | session-start hook 設定例（`references/session-start-hook.example.json`・利用者が手動マージ・`wiki/current-baseline.md` を ambient context にロード）＋ F-5 空 commit ガード（`last_tier_a_refresh` 値変化時のみ commit） |
| **3c（実装済み）** | `/llm-wiki discover-tier-a`（Tier A 公式 docs/GitHub の未取り込み URL を自動発見＝`code.claude.com/docs/en/*` sitemap + `anthropics/claude-code` の CHANGELOG/README・`pending_discoveries[]` に dedup append・承認制 ingest・mode G・lint #13・schema v1.5.0） |
| **3d（実装済み）** | F-4 共通 surface 確立（mode B ingest 拡張で migration_pending 承認後 ingest を内包）＋ sources: append 明文化＋ overview 自動更新（同一 commit inline）＋ log.md append 規約（dirty check から log.md 除外）・schema v1.4.0 |
| **3e（実装済み）** | 会話 URL hook（`UserPromptSubmit` → vault 外 `.llm-wiki-inbox.jsonl`）＋ mode H `review`（opt-in 個別承認 ingest）＋ URL 正規化フル仕様（denylist）＋ stuck candidates 対策（`declined` negative cache）＋ 3c mode G 承認 UX を capped バッチ opt-out に amend |
| 3f（要件のみ記録） | ウォッチリスト型 Tier B 定点観測〈単一 URL 型〉— `refresh-tier-a` の Tier B 版（mode `refresh-watchlist`・登録＝承認 → cron 自動 refresh・relevance フィルタ/取得可否 gate 不要）。設計は次回 |
| 3g（要件のみ記録） | ウォッチリスト型 Tier B 定点観測〈定点フィード型〉— `discover-tier-a` の Tier B 版（サイト登録 → 新着 URL 発見 → relevance 2 段フィルタ → capped バッチ opt-out surface 合流・X は公開 RSS 無し＝ Phase 4 fetcher 依存）。設計は次回 |
| 4 | ソース別取得ツール（X / Medium / Notion / 公式サイト等）。Phase 3g 定点フィード（特に X）の前提依存 |

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
/llm-wiki lint                 # 12 検査（Phase 2a 7 機械判定＋ Phase 2b 4 意味解釈＋ Phase 3a #12 last-tier-a-refresh・#11 のみ承認制で `## 矛盾` 末尾に決着注記）
    ↓
/llm-wiki refresh-tier-a       # Tier A 日次自動再取得（launchd/cron 経由・対話実行も可・--dry-run で副作用ゼロ確認）
```

`lint` の意味解釈 4 検査（#5 横断矛盾・#8 synthesis 再生成要否・#10 3 面相互矛盾・#11 バージョン軸決着）は Phase 2b で、`#12 last-tier-a-refresh`（refresh 停止監視）と `refresh-tier-a` モード本体は Phase 3a で実装済みです。launchd plist 例は `.claude/skills/llm-wiki/references/refresh-tier-a-launchd.plist.example`。

## 設計上の主要決定

- **検索ではなくコンパイル / 必ず引用 / 黙って上書きしない**
- **二段の矛盾検出（決定 Z）**: ingest は同一トピックのみ即時照合、横断矛盾は Phase 2b lint で実装済み
- **フロントマター骨格は MVP から（決定 ア）**: 機械判定 7 検査は Phase 2a、意味解釈 4 検査は Phase 2b、機械判定 #12 は Phase 3a で実装済み
- **情報源ティア**: Tier A（公式）は Phase 3a で日次自動更新（`refresh-tier-a`）を先行解禁・実装済み、Tier B は対話承認制
- **個人利用前提**: 単一エージェント書き込み・操作ごと Git コミット。書き込みモードは `.llm-wiki.lock`（vault 直下・atomic 取得・スタール判定 timestamp 1h ＋ `kill -0` の AND）で排他制御

詳細は `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md` と `docs/core/development-guidelines.md` を参照。
