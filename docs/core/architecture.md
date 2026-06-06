# アーキテクチャ設計書

> **このドキュメントの位置づけ（読み手＝保守者）**
> `/llm-wiki` スキルの**構造（3 層・モード関係・データフロー）と設計判断（なぜそうなったか）の整理された全体像**を提供します。Phase 1〜4 で積み上がった決定が複雑化したため、散在する根拠を一望できるよう「圧縮した俯瞰図＋決定インデックス」に集約しました。
>
> **責務境界（齟齬時の優先順）**: `CLAUDE.md`＝不変条件・運用ポリシー（最上位）／`SKILL.md`＝ワークフロー（モード分岐手順）／`references/schema.md`＝データ規約（`schema_version` の唯一の正）。本ドキュメントは**これら 3 つの上位レイヤー（構造と判断）を俯瞰するもの**で、モード別の手順・検査数・スキーマ詳細といった「腐りやすい現状記述」は再掲せず、CLAUDE.md / SKILL.md / schema.md を参照に逃がしています（二重管理を避け、決定という append-stable な情報に集中）。各決定の深い根拠は `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`（以下「spec」）を指します。

---

## 1. 全体像（1 段落）

このリポジトリは Karpathy の「LLM Wiki」パターン（**検索ではなくコンパイル**）を Claude Code スキル `/llm-wiki` として実装した、個人の Claude Code 知識ハブです。情報源を取り込む時点で要約・相互参照・矛盾フラグを**一度確定して維持**し、そこから引用付きの派生成果物（チートシート等）を生成します。データは **3 層**（不変の `raw/` ／ コンパイル済み `wiki/` ／ 規約たる schema）に分離され、すべての操作は**単一の書き込み共通 surface（mode B = ingest）**に収束します。Tier A（公式）は自動更新を解禁、Tier B（その他）は承認制を守りつつ定点観測する、という**ティアで非対称な自動化**が運用の背骨です。

---

## 2. 3 層アーキテクチャとボールト分離

### 2.1 3 層（厳守）

| 層 | 実体 | 所有者 | 不変条件 |
|----|------|--------|----------|
| `raw/` | 取得スナップショット（原文 URL・取得日時・取得手段をメタ保持） | 人間・fetcher が追加、エージェントは**読むだけ** | **不変**（追加のみ・削除しない＝E1）。すべての主張はここを引用 |
| `wiki/` | コンパイル済み Markdown ページ群（`[[wikilinks]]` 相互参照） | **エージェントが完全所有** | 黙って上書きしない（矛盾は `## 矛盾` 追加） |
| スキル / schema | 規約とワークフロー | repo A（本リポジトリ） | `schema_version` の正は `references/schema.md` のみ（決定 ウ） |

### 2.2 ボールト分離（2 リポジトリ）

```
repo A: personal-wiki-for-claude-code/   ← スキル資産（このリポジトリ・Git A）
├── .claude/skills/llm-wiki/{SKILL.md, references/{schema,page-templates,lint-rules}.md, *.example.*}
├── .llm-wiki.json                        ← ボールト相対パス・schema_version・任意 minitools_path
└── wiki-vault ─symlink─┐                 (.gitignore 対象)
                        ▼
repo B: ~/Documents/claude-code-wiki/     ← Wiki 実体（独立 Obsidian ボールト・別 Git B）
├── raw/{docs,articles,videos,github,notes}/
└── wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/
    ├── index.md            ← 各ページの主要主張サマリ（横断 lint の入力）
    ├── log.md              ← 操作ログ（追記のみ・dirty でも append 可）
    ├── overview.md         ← 統計と現状（## 現状 セクションは agent 所有）
    └── current-baseline.md ← claude_code_version 等の現在の正 ＋ schema 軽量ポインタ
```

スキル資産（schema）と data（raw/wiki）を別リポジトリに分離しつつ、`current-baseline.md` に schema 軽量ポインタ（`schema_version` / repo A commit / 規約サマリ）を置くことで repo B 単体でも自己記述性を回復する（決定 ウ）。`.claude` はボールト側に持たせない。

### 2.3 ページタイプ（schema）

汎用 5 種（`source` / `concept` / `entity` / `comparison` / `synthesis`）＋ Claude Code 特化 2 種（`practice`＝試した実践とその効果／`feature`＝機能の最新仕様・`claude_code_version` 保持）。線引き: 抽象原則は `concept`、Claude Code の機能は `feature`、その他固有物は `entity`。詳細は `references/schema.md`。

---

## 3. モードモデル（共通 surface パターン）

`/llm-wiki <操作>` は単一スキル内でモード分岐する。設計の核は **「すべての書き込みが mode B（ingest）に収束する」** こと（Phase 3d で F-4 として確立）。上流の各モードは「URL を発見・承認する」役割に徹し、実際の取り込みは共通 surface に委譲する。これにより URL 正規化・dedup・矛盾照合・sources: append・overview 更新・commit が一箇所に集約され、二重実装を排除している。

```
              読み取り専用（lock 不要）
              ┌─ query ──────────────────────► index.md → 関連ページ → 引用付き回答
              │
書き込みモード │   ┌──── 上流モード（発見・承認）── 承認 URL を B に渡す ──┐
（.llm-wiki    │   │  F  refresh-tier-a     Tier A 既知 URL 日次再取得（cron）  │
 .lock 排他）  │   │  G  discover-tier-a    Tier A 未取り込み URL 発見→承認     │
              │   │  W  refresh-watchlist  Tier B watch:true 単一 URL 再取得    │
              │   │  H  review             会話 URL hook inbox → 個別承認(対話) │
              │   │  I  discover-watchlist Tier B フィード新着発見→承認        │
              │   └────────────────────────┬───────────────────────────────────┘
              │                             ▼
              ├─►  B  ingest ───────►  ┌── 共通 surface ──────────────────────┐
              │    （共通 surface）     │ 1. raw 確保（host routing・§4.1）    │
              │                         │ 2. wiki コンパイル（要約/相互参照/   │
              │                         │    同一トピック矛盾照合 → ## 矛盾）  │
              │                         │ 3. index/overview/log 更新 → commit  │
              │                         └─────────────────────────────────────┘
              │
              └─►  D  lint #11 決着 ──► ## 矛盾 末尾に決着注記を in-place 追記
                   （URL を渡さない・ingest には合流しない独立 writer）
```

- **D（lint #11 決着）は funnel に入らない**: 上流モード（F/G/W/H/I）は発見した URL を B に渡して取り込ませるが、D は URL を発見も移送もせず、矛盾の決着注記を `## 矛盾` 末尾に in-place 追記する独立した書き込みモード（lock は取得するが ingest には合流しない・lock 取得モードの全体集合は §5.2）。
- **mode B が単独で持つ拡張**: `--type=practice` / `--feature=<slug>`（2a）、`--watch`（3f＝Tier B watchlist 登録）、`--feed=<rss_url>` / `--feed=notion-*:<sel>`（3g/4＝フィード登録）、host routing（4a）。
- **`--watch` / `--feed` は共通 surface 内部呼び出し（G/H/F migration）には伝播させない**＝default-off を維持し誤発火を防ぐ（決定 D2・D5）。

---

## 4. データフロー

### 4.1 ingest（mode B）の raw 確保 = per-host routing

取り込みの第一段「raw 確保」は host で分岐する（4a・F-1 の gh api routing を先例として踏襲）:

| host | 取得経路 | 備考 |
|------|----------|------|
| 一般 URL | `WebFetch`（要約） | raw に `note:` 明示＋ `source_url` 再検証経路を残す（[[webfetch-raw-snapshot-policy]]） |
| `github.com/*` blob | `gh api`（Tier A verbatim） | WebFetch では本文取得不能のため（F-1 hotfix） |
| `medium.com` / `*.medium.com` | minitools `scrape-medium --cdp`（Playwright・英語原文 verbatim） | **対話のみ**（Playwright auth decay を cron に持ち込まない＝D3）。`--watch` は reject（D8） |
| ローカルパス | 直接読込 | — |

### 4.2 各操作の流れ

- **query**（読み取り・lock 不要）: `index.md` → 関連ページ特定 → 該当ページのみ読込 → 引用付き回答。Wiki に無い情報は Web 補完を明示し ingest を提案。
- **synthesize**: wiki 群 → `wiki/syntheses/` に引用付きで生成・再生成。overview を inline 更新（3d）。**自動再生成はしない**（lint #8 が引用元の `updated` 進行を検出して要否を surface）。
- **lint**: 16 検査（機械判定＋意味解釈＋自動化停止監視）。#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記。検査の内訳は CLAUDE.md / `references/lint-rules.md` を参照。

---

## 5. ティアモデルと自動化

### 5.1 Tier で非対称な自動化

| | Tier A（Anthropic 公式 docs / 公式 GitHub） | Tier B（記事・動画・Notion・個人メモ等） |
|---|---|---|
| 既知 URL の再取得 | **F** `refresh-tier-a`（日次・自動） | **W** `refresh-watchlist`（`watch:true` のみ・日次） |
| 未取り込み URL の発見 | **G** `discover-tier-a`（sitemap + CHANGELOG/README） | **I** `discover-watchlist`（RSS/Atom + Notion DB） |
| `current-baseline.md` version 系 | **自動更新可**（手動上書きも可） | **自動更新しない**（承認制＝決定6・W-4f 省略） |

Tier B が baseline を自動更新しない理由（決定6）: 再コンパイルで source ページの `claude_code_version` は進むため乖離は vault に**自己記述**され、`lint #3`（version 乖離）が次回対話で再検出して承認制の更新提案に合流する。よって「3 つ目の pending array」は不要（決定 D1 系の判断）。

### 5.2 並行制御（`.llm-wiki.lock`）

書き込みモード（B / D / F / G / W / H / I）は vault 直下の `.llm-wiki.lock` を**開始時に atomic 取得・終了時に解放**して排他する。`query` は読み取り専用のため lock を取らない（refresh 中でも並行可・raw 追加と wiki 再コンパイルは atomic commit 単位）。スタールロック判定は **timestamp 経過（既定 1h）＋ `kill -0` PID liveness の AND**（誤奪取防止）。lock ファイルは `.gitignore` 対象。

### 5.3 自動化（launchd / cron）

- F / W / I は `--no-prompt`（非対話）と `--dry-run`（副作用ゼロ）を持つ。
- 3 系統の plist は**起動時刻を stagger**（03:00 / 03:30 / 04:00）して同一 lock の競合 skip を回避。**4 系統目 plist は作らない**（mode I を流用＝D7）。
- **cron 経路は decay しない取得手段に限定**（D3）: Tier A docs / Notion DB の API キー認証のみ。Playwright auth decay を持つ Medium content fetch（4a）は**対話のみ**で、cron では発火しない。
- 自動化が停止すると baseline が偽陽性で「新鮮」に見えるため、`last_*_run` heartbeat ＋ lint #12〜#16 で停止を監視する。

---

## 6. 設計判断インデックス

> **ラベル体系は意図的に「現状のまま」記載**しています（正準化＝リナンバリングはしない）。CLAUDE.md / SKILL.md がこれらを現行ラベルで参照しているため、付け替えると新たな不整合を生むからです。ラベルは 4 系統が混在します: **ローマ字かな系**（基盤決定・spec 設計方針由来）／**数字系**（決定6・番号がずれている点に注意）／**D 系**（Phase 3f/3g/4 brainstorm 連番・D4/D6 は欠番）／**ステップ系**（モード内手順・受け入れテスト発見事項）。各行の「出典」は深掘り先。

### 6.1 基盤決定（ローマ字かな系・spec『設計方針』）

| ID | 一言で | 出典（spec） |
|----|--------|--------------|
| **決定 A** | リポジトリ役割をテンプレート → 個人 Claude Code 知識ハブ専用へ転換 | 設計方針9 ／ 代替案と比較（採用案 A） |
| **決定 Z** | 二段の矛盾検出（ingest は同一トピックのみ即時照合・横断は index.md サマリで lint） | 更新履歴 2026-05-17 |
| **決定 ア** | フロントマター骨格は MVP から（lint 判定は Phase 2 でも、フィールドは MVP の ingest で全ページに埋める） | 設計方針8 |
| **決定 イ** | `current-baseline.md` 初期化＝init が公式 GitHub 最新リリースを取得・raw 引用、失敗時のみ `claude --version` 対話フォールバック | 設計方針10 |
| **決定 ウ** | schema の単一所有・co-evolution・責務境界（`schema_version` の正は schema.md のみ／ボールトは軽量ポインタ／齟齬時 CLAUDE.md 優先） | 設計方針11 |
| **決定 エ** | Phase 3a Tier A 自動更新の運用ポリシー（専用 mode・lock・raw 追加方式・synthesis 自動再生成しない・301 は migration_pending・dirty skip・plist は手動 load） | 設計方針12 |

### 6.2 数字系

| ID | 一言で | 出典（spec） |
|----|--------|--------------|
| **決定6** | 個人利用前提・**単一エージェント書き込み**（信頼度 0.7 許容）。Tier B が承認制で baseline を自動上書きしない根拠の源 | 設計方針**7**（※ラベルと番号がずれている） |

### 6.3 D 系（Phase 3f/3g/4 brainstorm 連番・D4/D6 欠番）

| ID | 一言で | Phase | 出典 |
|----|--------|:---:|------|
| **D1** | registry-vs-flag → **flag**（別 registry を持たず source ページ frontmatter `watch:true`・URL は raw が正本） | 3f | spec 3f ／ SKILL §走査戦略 |
| **D2** | opt-in **default-off**（`watch` 不在 or `false` は対象外） | 3f | spec 3f |
| **D3** | cron は **decay しない経路のみ**（Notion DB の API キー認証だけ・Playwright auth decay を cron に持ち込まない） | 4 | SKILL I-3 ／ spec Phase 4 |
| **D5** | retrofit 専用コマンドを新設しない（`watch:true` 手動追記で足りる・ingest 後の毎回 prompt は誤発火リスクで不採用） | 3f | SKILL retrofit |
| **D7** | anti-duplication（Notion-DB discovery は新規 mode でなく **mode I 拡張**・`feed_registry[]` 経路・4 系統目 plist / lint #17 / 4 つ目 pending array は作らない） | 4 | spec Phase 4 |
| **D8** | Medium URL は `--watch` 不可（mode W は WebFetch 既定で Playwright に乗れず毎晩 fail ＝ mode B reject ＋ mode W 防御 skip） | 4 | SKILL §5.3 |

### 6.4 ステップ系（モード内手順・受け入れテスト発見事項）

| ID | 一言で | 出典 |
|----|--------|------|
| **F-1** | `github.com` blob URL → `gh api` routing（WebFetch では本文取得不能） | spec F-1 ／ SKILL F-4a |
| **F-2** | cron dirty check（`git status --porcelain` が非空なら refresh skip・log.md は pathspec `:!wiki/log.md` で除外） | spec F-3 |
| **F-3** | log.md append 規約（dirty 状態でも追記 + commit 可・agent 完全所有） | spec F-3 ／ schema §3 |
| **F-4** | migration 承認後は old URL 書き換えでなく **new_url で新規 raw を ingest**（共通 surface = mode B 拡張） | spec F-4 |
| **F-5** | 空 commit ガード（`last_tier_a_refresh` の値変化時のみ commit） | spec F-5 |
| **F-6** | 再コンパイル時に新 raw を source ページ `sources:` 末尾に append（時系列保証） | spec F-6 |
| **G-6** | discover-tier-a 承認 = **capped バッチ opt-out**（除外を選択・1 run cap N=20・`declined` negative cache） | spec Phase 3c/3e |
| **W-4f** | refresh-watchlist は baseline version 系を**触らない**（決定6 帰結・lint #3 が再検出） | SKILL mode W |
| **I-3** | discover-watchlist のフィード巡回 = 2 経路（http(s) `feed_url` curl ／ `feed_registry[]` の `notion-medium-db` → `discover-notion-medium`） | SKILL I-3 |
| **I-6** | stage-2 relevance 判定を source 種別で分岐（notion は永続 `summary` 入力で WebFetch 省く／http-feed は WebFetch） | SKILL I-6 |

> ステップ系の完全な手順・分岐は SKILL.md 該当節を参照（本表は ID → 意味 → 出典の索引）。

---

## 7. Phase 進化の経緯（なぜこの順か）

決定が積み上がった順序＝設計の依存関係。後続 Phase は前 Phase の機構を**流用**して肥大を避けている。

| Phase | 加わったもの | 前提にした機構 |
|-------|-------------|----------------|
| **1（MVP）** | `init` / `ingest` / `query` / `synthesize` ＋ schema/templates。フロントマター骨格を先行（決定 ア） | — |
| **2a / 2b** | `lint`（機械判定 7 ＋ 意味解釈 4）＋ practice/feature テンプレ | 1 の frontmatter 骨格 |
| **3a** | `refresh-tier-a`（Tier A 日次自動更新）＋ `.llm-wiki.lock` ＋ lint #12 | 決定6 との競合制御が中核論点 |
| **3b** | session-start hook 設定例 ＋ F-5 空 commit ガード | 3a |
| **3c** | `discover-tier-a`（Tier A 未取り込み URL 発見） | 3a lock / migration_pending 流儀 |
| **3d** | **共通 surface 確立**（mode B 拡張で migration ingest を内包）＋ sources: append ＋ overview inline ＋ log.md 規約 | 全モードの収束点を定義 |
| **3e** | 会話 URL hook ＋ `review`（mode H）＋ URL 正規化フル仕様 ＋ G-6 capped バッチ opt-out | 3d 共通 surface |
| **3f** | `refresh-watchlist`（mode W＝Tier B 単一 URL）・決定 D1/D2/D5・W-4f | mode F の per-source 機械を Tier B に流用 |
| **3g** | `discover-watchlist`（mode I＝Tier B フィード）・2 段 relevance フィルタ | mode G を Tier B に流用 |
| **4** | Medium 2 層構造（4a per-host content routing ＋ 4b Notion-DB discovery）・決定 D3/D7/D8 | F-1 routing と mode I を流用（新 mode/lint/plist を作らない） |
| 4+（将来・deferred） | X 自動巡回（公開 RSS 無し・ToS グレー・gate 前提）・YouTube transcript・Medium 著者フィード | mode I http(s) feed として登録 |

---

## 8. 外部依存

| 依存 | 用途 | 必須性 |
|------|------|--------|
| Claude Code Skills | スキル実行基盤（単一スキル＋モード分岐） | 必須 |
| Git（×2） | repo A（スキル資産）と repo B（ボールト・操作ごと commit）の履歴 | 必須 |
| WebFetch / WebSearch | URL 取得・query/synthesize の Wiki 外補完 | 必須 |
| シンボリックリンク（`ln -s`） | 本リポジトリ → ボールト実体の参照 | 必須 |
| Obsidian | 表示レイヤー（グラフ/バックリンク/閲覧） | 任意（表示のみ） |
| `gh` CLI | `github.com` blob の本文取得（F-1） | Tier A GitHub ソース利用時 |
| minitools 2 CLI（`scrape-medium` / `discover-notion-medium`）＋ `uv` ＋ `NOTION_API_KEY` ＋ Chrome ログイン済セッション | Medium 取り込み（4a/4b） | **任意**。`.llm-wiki.json` の `minitools_path` 未設定/不在なら **Medium 機能のみ無効化**し他モードは通常動作（clean failure） |

---

## 9. スコープ外（設計上の非対象）

- チーム利用向け調整機構（レビューゲート・貢献者追跡・アクセス制御）
- セマンティック検索 / MCP 連携（200 ページ・100 ソース超で再検討）
- 複数エージェント同時書き込みの競合解決（単一エージェント前提＝決定6）
- X 自動巡回（公開 RSS 無し・ToS グレー・取得 spike を着手前 gate に・**deferred**）

---

詳細な受け入れ条件と決定の一次根拠は spec（`docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`）、現状リファレンスは `CLAUDE.md`、ワークフロー実装は `.claude/skills/llm-wiki/SKILL.md`、データ規約は `references/schema.md` を参照。
