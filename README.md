# personal-wiki-for-claude-code

進化の速い **Claude Code**（CLI / Agent SDK / API）の知識を、検索ではなく**コンパイル**して蓄積し続ける、**個人の Claude Code 知識ハブ**です。

ベストプラクティス・公式更新・自分の試行錯誤を、相互参照された永続的な Wiki に整理し続け、そこから「最新チートシート」「開発者向け Tips 集」等を**引用付き**で生成・維持します（Karpathy の「LLM Wiki」パターンを Claude Code スキル `/llm-wiki` として実装）。

> このリポジトリは **コピーして使うテンプレートではありません**。このリポジトリを CWD にして `claude` を起動し、`/llm-wiki` を運用します。

---

## これで何ができる？

| やりたいこと | コマンド | こうなる |
|------------|---------|---------|
| 記事や公式 docs を知識として取り込む | `/llm-wiki ingest <URL またはパス>` | 要約・相互参照・矛盾チェックを済ませた Wiki ページが作られる（既存と矛盾すれば「矛盾」セクションで明示） |
| 蓄積した知識に質問する | `/llm-wiki query "<質問>"` | Wiki から**引用付き**で回答。情報が足りなければ Web 補完を明示して取り込みを提案 |
| チートシート / Tips 集を作る | `/llm-wiki synthesize "<テーマ>"` | `wiki/syntheses/` に引用付きの派生成果物を生成・再生成 |
| 知識ベースの健全性を点検する | `/llm-wiki lint` | 孤立ページ・陳腐化・矛盾・信頼度などを監査してレポート |
| 公式 docs を毎日自動で最新化する | `/llm-wiki refresh-tier-a`（cron 推奨） | Anthropic 公式 docs/GitHub の既知 URL を日次で再取得・再コンパイル |
| 追いたいサイトの新着を自動で拾う | `/llm-wiki ingest <URL> --feed=<rss_url>` → `/llm-wiki discover-watchlist` | フィードを巡回して関連新着を発見 → 承認したものだけ取り込む |

「どの操作が何をするか」の一覧は下の「`/llm-wiki` コマンド一覧」セクションを参照してください。

---

## コンセプト: 検索ではなくコンパイル

通常のメモアプリや RAG はステートレスで、ソースを足しても知識が「コンパイル」されず、矛盾や陳腐化が放置されます。本リポジトリは **3 層アーキテクチャ**でこれを解決します。

| 層 | 役割 | 所有 |
|----|------|------|
| `raw/` | 取得スナップショット（原文 URL・取得日時・取得手段を保持、不変） | 人間が追加 |
| `wiki/` | コンパイル済みページ群（要約・相互参照・`[[wikilinks]]`） | エージェントが所有 |
| スキル | 規約とワークフロー（必ず引用・矛盾は明示・操作ごと Git） | 規律の源 |

Wiki の実体は**独立した Obsidian ボールト**（別 Git 管理）で、本リポジトリからはシンボリックリンク `./wiki-vault` で参照します。Obsidian はグラフ/バックリンク/閲覧の表示レイヤーです。

> 設計の全体像（モード関係・データフロー・設計判断）は **[`docs/core/architecture.md`](docs/core/architecture.md)**、不変条件と運用ポリシーは **[`CLAUDE.md`](CLAUDE.md)** を参照。

---

## セットアップ

**前提**: Claude Code / Git / （表示に）Obsidian / シンボリックリンクが使える環境。

```bash
# 1. このリポジトリを CWD にする
cd ~/Projects/personal-wiki-for-claude-code

# 2. Wiki ボールトの実体を用意し、シンボリックリンクを張る（init が案内します）
ln -s ~/Documents/claude-code-wiki ./wiki-vault

# 3. Claude Code を起動して初期化
claude
> /llm-wiki init
```

`/llm-wiki init` がボールトの初期化・`.llm-wiki.json`（設定）・`.gitignore` 整備・`current-baseline.md` の初期バージョン取得まで行います。

**（任意）Medium 取り込みを使う場合**: 外部リポジトリ [minitools](docs/others/minitools-phase4-instructions.md) の 2 つの CLI に依存します。`init` で `minitools_path` を設定すると有効化されます（未設定/不在なら Medium 機能のみ無効化され、他の操作は通常どおり動きます）。

---

## 基本の使い方

```bash
claude
> /llm-wiki ingest https://code.claude.com/docs/en/skills        # 公式 docs を取り込む
> /llm-wiki ingest https://medium.com/.../claude-code-tips        # Medium 記事（要 minitools・対話のみ）
> /llm-wiki ingest ./my-notes.md --type=practice                 # 自分の実践メモを practice として取り込む
> /llm-wiki query "Skill の description を確実にトリガーさせる書き方は？"
> /llm-wiki synthesize "最新の Claude Code チートシート"
> /llm-wiki lint
```

- **`ingest`** は取り込み時に要約・相互参照・矛盾照合まで済ませます（あとから検索で繋ぐのではなく、取り込み時に「コンパイル」する）。`--type=practice` / `--feature=<slug>` でページ種別を指定できます。
- **`query`** は `index.md` → 関連ページの順に読み、引用付きで答えます。Wiki に無い内容は Web 補完を明示します。
- **`synthesize`** の成果物（チートシート等）は再生成・`lint` の対象になります。

---

## 最新を自動で保つ（任意・cron 運用）

放置による陳腐化を防ぐため、定点観測を自動化できます（launchd/cron から非対話実行）。

```bash
# 公式（Tier A）: 既知 URL を日次再取得 ＋ 未取り込み URL を自動発見
> /llm-wiki refresh-tier-a          # 既知の公式 docs/GitHub を再取得・再コンパイル
> /llm-wiki discover-tier-a         # 公式の未取り込み URL を発見 → 承認したものを取り込む

# その他サイト（Tier B）: 追いたい URL/フィードを定点観測
> /llm-wiki ingest <URL> --watch    # この URL を watchlist 登録（日次再取得の対象に）
> /llm-wiki refresh-watchlist       # watchlist の URL を日次再取得
> /llm-wiki ingest <URL> --feed=<rss_url>   # サイトのフィードを購読登録
> /llm-wiki ingest --feed=claude-blog-sitemap:default   # 公式ブログ claude.com/blog を定点観測（RSS 不在・sitemap 巡回）
> /llm-wiki discover-watchlist      # フィード/sitemap を巡回 → 関連新着を発見 → 承認して取り込む

# 会話中に見た URL を後でまとめて取り込む（会話 URL hook と併用）
> /llm-wiki review                  # hook が貯めた URL を個別承認して取り込む
```

- 公式（Tier A）は**自動更新**、その他（Tier B）は**承認制**（勝手にバージョン基準を書き換えません）。
- cron は 3 系統の起動時刻をずらして競合を避けます。設定例は `.claude/skills/llm-wiki/references/*-launchd.plist.example`、各 hook の設定例は同 `references/*.example.*`（`.claude/settings.json` に手動マージ、または `cp .claude/settings.example.json .claude/settings.json` で一括有効化）。
- `lint` が自動化の停止や死んだ URL を検知して知らせます。

---

## `/llm-wiki` コマンド一覧

| 操作 | 内容 |
|------|------|
| `init` | ボールト初期化・`./wiki-vault` リンク案内・設定/`.gitignore` 整備 |
| `ingest <path-or-url> [--type=practice\|--feature=<slug>] [--watch] [--feed=<rss_url>\|--feed=notion-*:<sel>]` | ソースを取り込み、要約・相互参照・矛盾明示。すべての書き込み操作はこの共通経路に収束 |
| `query <質問>` | `index.md` → 関連ページの順で引用付き回答（不足は Web 補完を明示） |
| `synthesize <テーマ>` | チートシート/Tips 集等を `wiki/syntheses/` に引用付きで生成・再生成 |
| `lint [--check=<csv>]` | 孤立/陳腐化/信頼度/index 同期/baseline 鮮度/自動化停止/死 URL を監査（一部は承認制で決着注記を追記） |
| `refresh-tier-a [--dry-run]` | Tier A（公式）既知 URL の日次自動再取得・再コンパイル・baseline 自動更新 |
| `discover-tier-a [--no-prompt\|--dry-run]` | Tier A の未取り込み URL を自動発見 → 承認制で取り込み |
| `refresh-watchlist [--dry-run]` | Tier B watchlist（`watch:true`）の日次自動再取得 |
| `review [--dry-run]` | 会話 URL hook が貯めた URL を個別承認して取り込み（対話専用） |
| `discover-watchlist [--no-prompt\|--dry-run]` | 登録フィード（RSS/Atom ＋ Notion DB ＋ 公式ブログ sitemap）を巡回し関連新着を発見 → 承認制で取り込み |

各操作の引数・分岐の詳細は `.claude/skills/llm-wiki/SKILL.md`、設計の全体像は [`docs/core/architecture.md`](docs/core/architecture.md) を参照。

---

## 含まれるもの

| パス | 内容 |
|------|------|
| `.claude/skills/llm-wiki/` | **主役スキル**（`SKILL.md` ＋ `references/{schema,page-templates,lint-rules}.md` ＋ hook/plist 設定例）。本プロジェクト限定 |
| `.claude/skills/`, `.claude/agents/` | 知識ハブの運用・保守を支える補助ツール（`/brainstorm` `/gen-all-docs` `/plan-feature` `/implement-feature` 等） |
| `docs/ideas/` | 要件・設計スペック（本機能の source of truth） |
| `docs/core/` | コアドキュメント（`architecture.md` / `development-guidelines.md`。`/gen-all-docs` が生成） |
| `docs/plan/`, `.steering/` | 計画・作業ステアリングファイル置き場（`/plan-feature` `/implement-feature` が使用） |
| `wiki-vault -> ...` | 独立 Obsidian ボールトへのシンボリックリンク（`.gitignore` 対象・init が作成） |

---

## 補助ツールでスキル自体を保守する

知識の蓄積・運用は主役スキル `/llm-wiki` で回します。スキル本体の設計・改善は補助ツールで回します。

```
/brainstorm        # 要件を docs/ideas/ にまとめる・壁打ち
/gen-all-docs      # README / CLAUDE.md / architecture / development-guidelines を同期
/plan-feature      # llm-wiki スキルの実装計画を .steering/ に作成
/implement-feature # SKILL.md・references を実装
/review-docs       # ドキュメント/スキル定義の品質をレビュー
```

---

## 開発状況

**MVP（Phase 1）＋ Phase 2〜4・4c まで実装・検証済み**（schema v1.10.0）。Phase 4 では Medium 取り込み（per-host content routing ＋ Notion DB ベースの新着発見）、Phase 4c では公式ブログ `claude.com/blog` の定点観測（RSS 不在のため sitemap 巡回・Tier B）を追加しました。

Phase ごとの進化の経緯と設計判断は [`docs/core/architecture.md` §7](docs/core/architecture.md) に、各機能の詳細仕様は [`CLAUDE.md`](CLAUDE.md) に整理しています。今後の予定（X 自動巡回・YouTube transcript 等）は同ドキュメントの「4+（将来）」を参照。
