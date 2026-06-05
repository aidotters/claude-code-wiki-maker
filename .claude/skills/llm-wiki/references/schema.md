# llm-wiki schema（データ規約の単一真実源）

> このファイルは **ページタイプ規約・フロントマター規約・命名/ディレクトリ/[[wikilink]] 規約・
> `schema_version` の唯一の「正」** です（決定 ウ）。
> `SKILL.md` および `CLAUDE.md` はこの規約を **参照するのみ**で、フィールド定義・ページタイプ・
> tier 判定ルールを**再記述しません**（再記述＝矛盾源）。
> 齟齬時の優先順位: **CLAUDE.md（不変条件・運用ポリシー）> SKILL.md（ワークフロー）/ 本ファイル（データ規約）**。

```yaml
schema_version: 1.8.0
```

`schema_version` はセマンティックバージョニング。Phase 1 起点は `1.0.0`、
co-evolution（§5）で改訂する。この版数を持つ文書は本ファイルのみ。

改訂履歴:
- `1.0.0` → `1.1.0`: §4 tier 自動判定に `code.claude.com`（公式 docs の移転先ホスト）を
  Tier A 条件として追加（後方互換の判定拡張＝minor）。
- `1.1.0` → `1.2.0`: practice/feature を Phase 2a で実装解禁（MVP 列を ✅ に更新）。
  後方互換のフィールド・規約追加＝minor。
- `1.2.0` → `1.3.0`: refresh-tier-a baseline fields (`last_tier_a_refresh` /
  `migration_pending`) を `current-baseline.md` に追加。後方互換のフィールド追加＝minor。
- `1.3.0` → `1.4.0`: Phase 3d。`overview.md` に agent 完全所有の `## 現状` セクション
  構造（統計値 5 件・最終 ingest 日付・最終更新日付）を §8 として明文化、
  §3 raw 引用記法直下に「log.md は dirty 状態でも append + commit 可」を明記
  （F-3 dirty escalation ループ解消）。後方互換のフィールド・規約追加＝minor。
- `1.4.0` → `1.4.1`: Phase 3c 着手前の独立 patch。§4 tier 自動判定ルールに
  `platform.claude.com`（Anthropic API + Agent SDK docs の移転先ホスト・
  `docs.anthropic.com/en/api/*` からの 301 移転先）を Tier A 条件として追加。
  後方互換の判定拡張＝patch。
- `1.4.1` → `1.5.0`: Phase 3c。`current-baseline.md` に `discover-tier-a`（モード G）
  専用フィールド `last_discover_tier_a_run` / `pending_discoveries[]` を §2.1 に追加、
  編集境界をモード F（refresh-tier-a）用とモード G（discover-tier-a）用に分離明文化。
  後方互換のフィールド追加＝minor。
- `1.5.0` → `1.6.0`: Phase 3e。`pending_discoveries[]` エントリに任意フィールド
  `declined: true`（stuck candidates 対策の negative cache・既定は不在＝未却下）を追加。
  あわせて §3 に「URL 正規化規約（dedup 用）は SKILL.md モード B step 3.5 が単一正本」の
  所在ポインタを明記（正規化フル仕様の実装は Phase 3e・SKILL.md 側）。
  後方互換のフィールド追加＝minor。
- `1.6.0` → `1.7.0`: Phase 3f（単一 URL watchlist・mode W `refresh-watchlist`）。
  §2 共通フィールドに任意 `watch`（bool・`tier: B` opt-in マーカー・既定不在＝`false` 相当）と
  任意 `fetch_status`（enum `failed`・既定不在＝`ok` 相当・mode W のみ更新）を追加、
  §2.1 に `last_refresh_watchlist_run`（`YYYY-MM-DD`・mode W run heartbeat・**version baseline ではない**）を追加、
  §2.1 編集境界表に mode W 列（`last_refresh_watchlist_run` のみ更新可・version 系は 🚫 不可触）を追加。
  後方互換のフィールド追加＝minor。
- `1.7.0` → `1.8.0`: Phase 3g（定点フィード型 Tier B・mode I `discover-watchlist`）。
  §2 共通フィールドに任意 `feed_url`（url 文字列・`--feed` の mode B が立てる・mode I 走査対象マーカー）を追加、
  §2.1 に `last_discover_watchlist_run`（`YYYY-MM-DD`・mode I run heartbeat・**version baseline ではない**）と
  `pending_feed_discoveries[]`（mode I 専用 Tier B フィード発見 URL 保留配列・`declined_reason` 3 値含む）を追加、
  §2.1 編集境界表に mode I 列（`last_discover_watchlist_run` / `pending_feed_discoveries` のみ更新可・version 系は 🚫 不可触）を追加。
  後方互換のフィールド追加＝minor。

---

## 1. ページタイプ定義

ボールトの `wiki/` 配下に置くコンパイル済みページは、必ず以下のいずれかの `type` を持つ。

| type | 用途 | 配置ディレクトリ | MVP |
|------|------|------------------|:---:|
| `source` | 1 つの raw ソースの要約ページ（raw 1 件に 1 ページが基本） | `wiki/sources/` | ✅ |
| `concept` | 抽象的な考え方・原則（例: プログレッシブ・ディスクロージャ、コンテキスト圧迫回避） | `wiki/concepts/` | ✅ |
| `entity` | 固有名を持つ具体物のうち **Claude Code の機能以外**（外部ツール・人物・組織・ライブラリ等） | `wiki/entities/` | ✅ |
| `comparison` | 2 つ以上の選択肢・手法の比較 | `wiki/comparisons/` | ✅ |
| `synthesis` | テーマ横断の派生成果物（チートシート / Tips 集等） | `wiki/syntheses/` | ✅ |
| `practice` | 試した Claude Code 実践とその効果（効いた/効かなかった） | `wiki/practices/` | ✅ |
| `feature` | Claude Code 自体の機能（Skill/Hooks/MCP/Agent SDK 等）ごとの最新仕様まとめ。バージョン追従・陳腐化管理の対象 | `wiki/features/` | ✅ |

- `practice` / `feature` は **Phase 2a で実装済み**。本文スケルトンは `references/page-templates.md`、
  ingest 動線は `SKILL.md` モード B の `--type=practice` / `--feature=<slug>` を参照。
- `entity` と `feature` の線引き: **Claude Code の機能なら `feature`、それ以外の固有物は `entity`**。
  Claude Code 機能の知見は `feature` を使う。

---

## 2. 全ページ共通フロントマター必須フィールド（MVP 確定値）

すべての `wiki/` ページは YAML フロントマターを持ち、以下のフィールドを必ず埋める。
判定ロジック（陳腐化・矛盾検出）は Phase 2 だが、**値の保持は MVP の ingest/synthesize 時点から必須**（決定 ア）。

```yaml
---
type: source                 # source|concept|entity|comparison|synthesis|practice|feature
title: <人間可読タイトル>
tier: A                      # A=Anthropic公式(docs/公式GitHub) / B=その他。判定は §4
claude_code_version: 1.x.y   # この知見が前提とする Claude Code バージョン。不明時は "unknown"
updated: 2026-05-17          # YYYY-MM-DD。最終コンパイル日
stale: false                 # bool。判定ロジックは Phase 2 lint、値の保持は MVP から
confidence: 0.7              # 0.0-1.0。個人利用の既定値は 0.7
sources:                     # raw への引用パス。最低 1 件必須。source ページ自身は自分の raw を指す
  - raw/articles/2026-05-17-foo.md
links:                       # [[wikilink]] 先のページ名（相互参照）。無ければ空リスト []
  - some-concept-page
---
```

フィールド規約:

- **`type`**: §1 のいずれか。
- **`title`**: 人間可読。ファイル名（slug）とは別に保持。
- **`tier`**: `A` または `B`。§4 の判定ルールに従う。
- **`claude_code_version`**: 知見が前提とするバージョン。判別不能時は文字列 `"unknown"`。
- **`updated`**: `YYYY-MM-DD`。そのページを最後にコンパイル/更新した日。
- **`stale`**: 真偽値。MVP は値を保持するのみ（既定 `false`、init フォールバック時の baseline は `true`）。判定は Phase 2。
- **`confidence`**: `0.0`–`1.0`。個人利用前提のため既定 `0.7` を許容。
- **`sources`**: `raw/` 配下への相対パスのリスト。**最低 1 件必須**（不変条件「必ず引用」）。空にしてはならない。
- **`links`**: 相互参照する他ページの slug。無い場合は空リスト `[]` を明示。
- **`watch`**（任意・bool・既定不在＝`false` 相当・Phase 3f v1.7.0）: `tier: B` の source ページのみ意味を持つ watchlist opt-in マーカー。`true` のページが mode W（`refresh-watchlist`）の日次自動再取得対象になる。`/llm-wiki ingest <url> --watch` が立てる（既存ページの後付け登録は frontmatter に手動追記）。`tier: A` ページの `watch` は無視される（mode W は `tier: B` で絞るため）。更新権限は §2.1 編集境界表参照（`--watch` の mode B / mode W）。
- **`fetch_status`**（任意・enum `failed`・既定不在＝`ok` 相当・Phase 3f v1.7.0）: mode W が watchlist URL の取得に失敗したとき当該 source ページに `failed` を立てる fetchability decay マーカー。**mode W のみが更新**（取得失敗で `failed` を Edit、次回取得成功で当該フィールドを削除＝受動回復）。`stale`（内容陳腐化）とは意味が異なる独立カテゴリ。lint #15（`watch-fetch-failed`）が surface する。
- **`feed_url`**（任意・url 文字列・既定不在・Phase 3g v1.8.0）: source ページに RSS/Atom フィード URL を格納する登録マーカー。`/llm-wiki ingest <site-url> --feed=<rss_url>` が立てる。mode I（`discover-watchlist`）がこのフィールドを走査してフィード巡回対象を決定する。`tier: B` の source ページが主な対象だが、`tier: A` ページの `feed_url` も走査対象になり得る（tier フィルタは I-3 では行わない）。更新権限: `--feed` 指定の mode B のみ（立てる）・他モード不可触。

`current-baseline.md` は通常ページではなくボールトの基準ファイルだが、フロントマターは本規約に準じ、
加えて §6 の schema 軽量ポインタを保持する。

### 2.1 `current-baseline.md` 専用フィールド（Phase 3a 追加・v1.3.0 / Phase 3c 拡張・v1.5.0 / Phase 3f 拡張・v1.7.0 / Phase 3g 拡張・v1.8.0）

`current-baseline.md` は §2 の共通フィールドと §6 の schema 軽量ポインタに加え、以下の専用フィールドを保持する。**書き込みモード（モード F `refresh-tier-a` / モード G `discover-tier-a` / モード W `refresh-watchlist` / モード I `discover-watchlist`）が自動更新する領域**であり、§6 の schema 軽量ポインタとは別領域として共存する（各モードとも §6 を不可触）。

```yaml
# --- refresh-tier-a（モード F）専用・Phase 3a v1.3.0 ---
last_tier_a_refresh: 2026-05-23      # YYYY-MM-DD。直近の refresh-tier-a 成功日
migration_pending:                    # 301 リダイレクトの保留事項。既定 []
  - old_url: https://docs.anthropic.com/en/docs/claude-code/overview
    new_url: https://code.claude.com/docs/en/overview
    detected_on: 2026-05-23
    source_slug: claude-code-overview
# --- discover-tier-a（モード G）専用・Phase 3c v1.5.0 / Phase 3e v1.6.0 ---
last_discover_tier_a_run: 2026-05-30  # YYYY-MM-DD。直近の discover-tier-a 成功日
pending_discoveries:                  # 未取り込み発見 URL の保留事項。既定 []
  - url: https://code.claude.com/docs/en/setup
    source_kind: docs                 # docs | github
    detected_on: 2026-05-30
    # declined: true                  # 任意・Phase 3e v1.6.0。利用者が却下した候補（negative cache）。既定は不在＝未却下
# --- refresh-watchlist（モード W）専用・Phase 3f v1.7.0 ---
last_refresh_watchlist_run: 2026-05-31  # YYYY-MM-DD。直近の refresh-watchlist run 日（run heartbeat・version baseline ではない）
# --- discover-watchlist（モード I）専用・Phase 3g v1.8.0 ---
last_discover_watchlist_run: 2026-06-10  # YYYY-MM-DD。直近の discover-watchlist 成功日（run heartbeat・version baseline ではない）
pending_feed_discoveries:                 # Tier B フィード発見 URL の保留。既定 []
  - url: https://simonwillison.net/2026/Jun/01/claude-code-tips/
    feed_source_slug: simonwillison-blog   # feed_url を持つ source ページの slug
    source_kind: feed                      # 固定値 "feed"（docs/github と区別）
    detected_on: 2026-06-05
    # declined: true                       # 任意。ユーザー除外 / stage-2 auto-decline / cap eviction の 3 種
    # declined_reason: relevance | cap     # 任意。不在=ユーザー選択 opt-out・relevance=stage-2 auto・cap=cap eviction
```

- **`last_tier_a_refresh`**: `YYYY-MM-DD`。`refresh-tier-a` の全ソース処理後に 1 度だけ更新。`--dry-run` では更新しない。`lint #12`（`last-tier-a-refresh`）が監視。
- **`migration_pending`**: 配列。既定 `[]`。`refresh-tier-a` が 301 検出時に 1 ソース 1 回だけ append（重複は `source_slug` で抑止）。対話モード（`ingest` / `lint`）の AskUserQuestion 承認で該当エントリを削除。エントリの形は `{old_url, new_url, detected_on, source_slug}` の 4 キー。
- **`last_discover_tier_a_run`**: `YYYY-MM-DD`。`discover-tier-a` の全処理後に 1 度だけ更新（値変化ガード付き・同日 2 回目以降は skip）。`--dry-run` では更新しない。`lint #13`（`last-discover-tier-a-run`）が監視。
- **`pending_discoveries`**: 配列。既定 `[]`。`discover-tier-a` が Tier A 公式 docs / 公式 GitHub の未取り込み URL を発見時に append（重複は正規化後 `url` で抑止＝dedup、`detected_on` は古い方を保持）。対話モードの AskUserQuestion 承認 → 共通 surface ingest 成功で該当エントリを削除。エントリの形は `{url, source_kind, detected_on, declined?}`。`source_kind` は `docs` | `github`。**`declined`（任意・Phase 3e v1.6.0）**: 利用者が G-6 の opt-out バッチで除外した候補に `true` を立てる（negative cache）。`declined: true` のエントリは以後 G-4 dedup（再 append しない）と G-6 提示（表示しない）から除外され、stuck candidates（興味のない候補の首位居座り）を解消する。手動解除は当該エントリの `declined` を削除。`migration_pending` が既存 source ページありの保留（`source_slug` キー）なのに対し、`pending_discoveries` は source ページ未作成の保留（`url` キー）。
- **`last_refresh_watchlist_run`**（Phase 3f v1.7.0）: `YYYY-MM-DD`。`refresh-watchlist`（モード W）の全ソース処理後に 1 度だけ更新（値変化ガード付き・同日 2 回目以降は skip）。`--dry-run` では更新しない。`lint #14`（`last-refresh-watchlist-run`）が監視。**これは run heartbeat であって version baseline ではない**＝mode W が `current-baseline.md` に触れるのはこの 1 フィールドだけで、`claude_code_version` / `updated`（version 系）は **不可触**（W-4f 省略・Tier B 乖離を自動上書きしない＝決定6）。
- **`last_discover_watchlist_run`**（Phase 3g v1.8.0）: `YYYY-MM-DD`。`discover-watchlist`（モード I）の全フィード処理後に 1 度だけ更新（値変化ガード付き・同日 2 回目以降は skip + log `last_discover_watchlist_run unchanged (<date>)`）。`--dry-run` では更新しない。`lint #16`（`last-discover-watchlist-run`）が監視。**これは run heartbeat であって version baseline ではない**＝mode I は `claude_code_version` / `updated`（version 系）は **不可触**（W-4f 省略と同理由・Tier B 乖離を自動上書きしない＝決定6）。
- **`pending_feed_discoveries`**（Phase 3g v1.8.0）: 配列。既定 `[]`。mode I が stage-1 keyword フィルタ通過の Tier B フィード記事 URL を append（dedup キー = 正規化後 url・既存エントリありなら append skip・`detected_on` は古い方を保持）。対話モードの AskUserQuestion 承認 → 共通 surface ingest 成功で該当エントリを削除。`declined: true` は ①ユーザー選択（`declined_reason` 不在）②stage-2 auto-decline（`declined_reason: relevance`）③cap eviction（`declined_reason: cap`）の 3 種（design §4.2）。フィールド: `{url, feed_source_slug, source_kind: "feed", detected_on, declined?, declined_reason?}`。`declined_reason` の 3 値: 不在＝ユーザー選択 opt-out / `relevance`＝stage-2 auto-decline（confidence < 0.7）/ `cap`＝cap eviction（per-feed N=50・全体 M=200 を超過した最古エントリを invisible 化）。escape hatch＝`declined` を手動削除で再候補化可。`pending_discoveries[]`（Tier A 専用・mode G 所有）とは**別配列**（queue 分離設計・mode H inbox 分離の前例と整合）。

**編集境界（v1.5.0 で 2 モードに分離明文化）**:

| 領域 | モード F `refresh-tier-a` | モード G `discover-tier-a` | モード W `refresh-watchlist`（v1.7.0） | **モード I `discover-watchlist`**（v1.8.0） |
|------|:------------------------:|:-------------------------:|:-------------------------------------:|:-------------------------------------------:|
| `last_tier_a_refresh` / `migration_pending` | 更新可 | 不可触 | **不可触** | **不可触** |
| `last_discover_tier_a_run` / `pending_discoveries` | 不可触 | 更新可 | **不可触** | **不可触** |
| `last_refresh_watchlist_run` | 不可触 | 不可触 | **更新可** | **不可触** |
| **`last_discover_watchlist_run` / `pending_feed_discoveries`** | 不可触 | 不可触 | 不可触 | **更新可** |
| §2 共通 `claude_code_version` / `updated`（baseline version 系） | 更新可（per-source ingest 由来） | 更新可（共通 surface ingest 由来） | **🚫 不可触（W-4f 省略）** | **🚫 不可触（W-4f 省略と同理由）** |
| §6 schema 軽量ポインタ（`schema_version` / `schema_repo_commit` / `schema_summary`） | **不可触** | **不可触** | **不可触** | **不可触** |

§6 の schema 軽量ポインタは §5 の co-evolution 経路でのみ更新する。各書き込みモードは自分の担当フィールドのみを書き換え、相手モードのフィールドには触れない。`pending_discoveries[].declined`（Phase 3e v1.6.0）はモード G が更新する（G-6 の除外で `true` を立てる・モード F / W / co-evolution 経路は不可触）。**モード W は `current-baseline.md` の `last_refresh_watchlist_run` 1 フィールドのみ更新可で、`claude_code_version` / `updated`（version 系）は不可触**（W-4f 省略＝Tier B 乖離を自動上書きしない決定6 の成立条件。W-4e で進んだ source ページの `claude_code_version` と baseline の乖離は lint #3 が次回対話で再検出する）。source ページ側 `watch` / `fetch_status`（§2 共通フィールド）は **`--watch` 指定の mode B（`watch` を立てる）とモード W（`fetch_status` を更新）が書き換え、他モード・co-evolution 経路は不可触**。会話 URL（モード H `review`）は vault 外 inbox を queue とし、`pending_discoveries` には書き込まない（Tier A discovery 専用）。

---

## 3. 命名・ディレクトリ・[[wikilink]] 規約

### ディレクトリ

```
<ボールト>/
├── raw/{docs,articles,videos,github,notes}/   # 取得スナップショット（不変・人間が追加）
└── wiki/
    ├── sources/  concepts/  entities/  comparisons/  syntheses/
    ├── practices/  features/                  # Phase 2a 実装済み
    ├── index.md           # 各ページの主要主張サマリ（1〜2 行）を維持
    ├── log.md             # 操作ログ（追記のみ）
    ├── overview.md        # 全体俯瞰
    └── current-baseline.md  # claude_code_version 等の現在の正 + schema 軽量ポインタ（§6）
```

- raw ファイル名: `raw/<種別>/<取得日 YYYY-MM-DD>-<slug>.md`
  - `<種別>` は `docs|articles|videos|github|notes` のいずれか。
  - 公式 Claude Code リリース取得物は `raw/docs/<取得日>-claude-code-release.md`。
- wiki ページ名: `wiki/<タイプ複数形ディレクトリ>/<slug>.md`
  - `<slug>` は小文字・ケバブケース（英数とハイフン）。
- raw は **不変**。再取得は新しい取得日のスナップショットを*追加*し、過去ファイルは消さない。

### [[wikilink]]

- ページ間の相互参照は本文中で `[[slug]]` 形式（Obsidian 互換）で記述する。
- 同時にフロントマター `links:` にも slug を列挙し、本文リンクと整合させる。
- リンク先が未作成でも `[[slug]]` は記述可（将来作成の予約マーカーを兼ねる）。

### raw 引用記法

- 本文中の主張には引用元 raw をインライン明示する: 例 `（出典: raw/articles/2026-05-17-foo.md）`。
- フロントマター `sources:` と本文引用は整合させる。
- Wiki 外（Web 検索等）で補完した記述は本文に **`⚠️ Wiki 外（Web 検索）`** と明示し、raw 引用と区別する。

### raw フロントマター必須キー（v1.3.0 追記）

- **Tier A の raw は `source_url` を必須**（`refresh-tier-a` の対象集合決定に使うため）。フィールド値は取得元の URL 原文。
- Tier B の raw は `source_url` 任意（現状の運用と互換）。
- 既存 raw が `source_url` を欠く場合は、次回 `ingest` または手動編集で補完する（refresh 対象外として skip＋log）。

### URL 正規化規約の所在（v1.6.0 追記・Phase 3e）

- 取り込み済み判定（dedup）に使う **URL 正規化規約の単一正本は `SKILL.md` モード B step 3.5**（host lowercase ＋ fragment 除去 ＋ 末尾スラッシュ除去 ＋ tracking param の curated denylist 除去 ＋ Tier A host allowlist 正準化）。モード G G-4 / モード H H-3 はこれを参照する。
- 正規化は **突合 workflow** の規約のため schema（data 規約の正）ではなく SKILL.md が所有する。raw の `source_url` は原文を保持し（E1 不変）、突合は比較時に両辺を正規化する（normalize-on-compare・既存データの移行不要）。

### log.md dirty 状態 append 規約（v1.4.0 追記）

- `wiki/log.md` は agent 完全所有・追記のみの規約のため、vault が dirty 状態でも append + commit してよい。
- 結果として `refresh-tier-a`（モード F）の F-2 dirty-state 判定式は log.md を除外する（`git -C wiki-vault status --porcelain -- ':!wiki/log.md'`）。log.md 以外の dirty のみで skip し、log.md 追記は実行できる（dirty escalation ループ防止）。

---

## 4. tier 自動判定ルール

ソースの取得元（URL ホスト）で `tier` を機械的に決める:

| 条件 | tier |
|------|:----:|
| URL ホストが `docs.anthropic.com` | A |
| URL ホストが `code.claude.com`（公式 Claude Code docs。`docs.anthropic.com/en/docs/claude-code/*` からの 301 移転先） | A |
| URL ホストが `platform.claude.com`（Anthropic API + Agent SDK 公式 docs。`docs.anthropic.com/en/api/*` からの 301 移転先） | A |
| URL ホストが `github.com` かつパスが `anthropics/`（claude-code 等の公式リポジトリ） | A |
| 上記以外（`medium.com` / `youtube.com` / `notion.so` / 任意ブログ / ローカルメモ 等） | B |
| 判断不能（ホスト不明・ローカルパスで出所が曖昧 等） | AskUserQuestion でユーザーに確認 |

> 注: `docs.anthropic.com/en/docs/claude-code/*` は `code.claude.com/docs/en/*` へ 301 リダイレクトする。
> `docs.anthropic.com/en/api/*` は `platform.claude.com/docs/en/*` へ 301 リダイレクトする（v1.4.1 で確認）。
> WebFetch は cross-host redirect を自動追従しないため、リダイレクト先 URL で呼び直すこと（取得元ホストは追従先 `code.claude.com` / `platform.claude.com` で判定する）。

- Tier A = Anthropic 公式（権威ソース）。Phase 3 で日次自動再取得・baseline 自動更新を先行解禁予定。
- Tier B = その他。`current-baseline.md` 更新はバージョン乖離時に対話提案（承認制）。
- MVP は **ティア区分メタデータの付与まで**。自動更新本体は Phase 3。

---

## 5. co-evolution 規約（schema 改訂時の手順）

`references/schema.md` を改訂する場合、以下を必ず一連で行う（schema 進化をボールト側からも辿れるように）:

1. 本ファイルの `schema_version` をセマンティックに更新する（後方非互換は major、フィールド追加は minor、字句修正は patch）。
2. 本リポジトリ直下 `.llm-wiki.json` の `schema_version` を新版数に更新する
   （設定ファイルへの転記値が古い版数で取り残されないように）。
3. ボールト側 `current-baseline.md` の schema 軽量ポインタ（§6）を更新する
   （`schema_version` / 本リポジトリの該当 commit ハッシュ / 規約 1〜2 行サマリ）。
4. ボールト側 `log.md` に `schema vN→vN+1: 変更要旨` の 1 行を追記する。

schema 全文をボールトへ複製してはならない（二重管理・矛盾回避。単一真実源は常に本リポジトリ＝repo A）。

---

## 6. ボールトへの schema 軽量ポインタ（決定 ウ）

ボールト側 `current-baseline.md` には、schema 全文ではなく以下の **軽量ポインタのみ**を保持する:

```yaml
schema_version: 1.2.0
schema_repo_commit: <本リポジトリの該当 commit ハッシュ>
schema_summary: >
  ページタイプ source/concept/entity/comparison/synthesis/practice/feature、
  共通フロントマター必須（type/title/tier/claude_code_version/updated/stale/confidence/sources/links）、
  必ず raw 引用・[[wikilink]]・黙って上書きしない。
```

これにより repo B（ボールト）単体でも「どの schema 版でコンパイルされたか」を
repo A の commit に追跡でき、ボールトの自己記述性を回復する。

**更新権限の境界（v1.3.0 で明記・v1.5.0 で mode G 追記・v1.7.0 で mode W 追記・v1.8.0 で mode I 追記）**: `schema_version` / `schema_repo_commit` / `schema_summary` の 3 フィールドは **§5 の co-evolution 経路でのみ更新**する。`refresh-tier-a`（モード F）は §2.1 の `last_tier_a_refresh` / `migration_pending`、`discover-tier-a`（モード G）は §2.1 の `last_discover_tier_a_run` / `pending_discoveries`、`refresh-watchlist`（モード W）は §2.1 の `last_refresh_watchlist_run`、`discover-watchlist`（モード I）は §2.1 の `last_discover_watchlist_run` / `pending_feed_discoveries` **のみ**を更新する（モード W・I は version 系も不可触＝W-4f 省略と同理由）。モード F / G は §2 共通フィールドの `claude_code_version` / `updated` も書き換える（詳細は §2.1 編集境界表）、本節の軽量ポインタは全モード**不可触**。

---

## 7. 責務境界と Phase 2 lint の 3 面相互矛盾チェック

| 文書 | 責務 | 変更の重さ |
|------|------|-----------|
| `CLAUDE.md` | 不変条件・運用ポリシー（「なぜ」「破ってはいけない原則」）。**最上位** | 最重 |
| `SKILL.md` | ワークフロー（モード分岐手順） | 重 |
| `references/schema.md`（本ファイル） | データ規約（「データの形」）。co-evolution の主対象 | 中 |

- 齟齬が生じた場合の優先順位は **CLAUDE.md > SKILL.md / schema.md**。
- Phase 2 の `/llm-wiki lint` は、この 3 面（CLAUDE.md / SKILL.md / schema.md）の
  相互矛盾も健全性チェックの対象に含める（MVP では未実装、`references/lint-rules.md` に枠を予約）。

---

## 8. `overview.md` の構造定義（v1.4.0 追記・Phase 3d）

`wiki/overview.md` はボールトの全体俯瞰ページ。Phase 3d で **手動編集領域** と **agent 完全所有領域**の境界を明確化し、書き込みモード操作（mode B ingest / mode F refresh-tier-a / mode D synthesize）で agent が後者を自動更新する。

### 8.1 領域境界

```markdown
# overview

<手動編集領域: 上部の説明文（ボールトの説明・raw/wiki/規約所在）>

## 現状
<agent 完全所有領域: 統計値行・最終 ingest 行・最終更新行（5 件 + 2 日付）>

<手動編集領域: 末尾の案内文（`/llm-wiki ingest <path-or-url>` から始まる行）>
```

- **境界判定**: 見出し文字列 `## 現状` の検出で agent 所有領域を識別する。利用者が当該見出しテキストを書き換えると agent は領域を識別できなくなり、その場合は overview 更新を **skip し log.md に warning** を追記する（黙って上書きしない）。
- **手動編集領域**: 上部説明文と末尾案内文は agent **不可触**。
- **agent 所有領域**: `## 現状` 見出し直後から次の空行 or 次の見出しまでの範囲が agent の自動更新領域。

### 8.2 統計フィールド定義

`## 現状` セクションは次の 5 件のカウントと 2 件の日付を保持する:

| フィールド | 定義 |
|------------|------|
| ソース数 | `wiki/sources/*.md` のうち `_fixture-*` を除いた count |
| concept 数 | `wiki/concepts/*.md` のうち `_fixture-*` を除いた count |
| synthesis 数 | `wiki/syntheses/*.md` のうち `_fixture-*` を除いた count |
| practice 数 | `wiki/practices/*.md` のうち `_fixture-*` を除いた count |
| feature 数 | `wiki/features/*.md` のうち `_fixture-*` を除いた count |
| 最終 ingest | 最後に raw が追加された日付（`YYYY-MM-DD`、refresh-tier-a 含む） |
| 最終更新 | 統計値が変化した最新日付（= overview Edit が走った日付、`YYYY-MM-DD`） |

- 取得は `Glob` で各ディレクトリを列挙して count する（`index.md` 1 回読みは不要）。
- **`_fixture-*` で始まるファイルは lint テスト用のため除外**する（false count 防止）。
- 「最終 ingest」と「最終更新」を別フィールドにする理由: refresh-tier-a で同日に複数回 ingest が走っても、統計が変わらなければ「最終更新」は同値で skip 可能（値変化ガード semantics の明確化）。

### 8.3 値変化ガード

書き込みモード操作の同一 commit 内で overview 更新を inline 実行する際、`## 現状` セクションの 5 件 + 2 日付の全値が現状と一致するなら Edit を skip し、`wiki/log.md` に `overview unchanged` 行を 1 行追記する（Phase 3b F-5 と同じ流儀）。`--dry-run`（mode F）では Edit / commit を行わず差分予測のみレポートする。

### 8.4 更新タイミング

| 操作 | overview 更新 | 同一 commit |
|------|---------------|-------------|
| mode B 手動 ingest（既存 / migration 承認後 / 新規） | ✓ | ingest commit 内に inline |
| mode F refresh-tier-a per-source | ✓ | 各 per-source commit 内に inline（値変化なしなら skip） |
| mode F refresh-tier-a last_tier_a_refresh 更新（F-5） | ✓ | F-5 commit 内に inline |
| mode F refresh-tier-a summary（F-6） | × | log.md のみ |
| mode D synthesize | ✓ | synthesize commit 内に inline |
| mode L lint #11 承認制決着 | × | source ページ統計に変化なし |
