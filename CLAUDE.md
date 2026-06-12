# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **ステータス: MVP（Phase 1）＋ Phase 2a・2b・3a・3b・3d・3c・3e・3f・3g・4・5 実装済み**
> このリポジトリは `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md`（決定 A）に基づき、
> 「テンプレート」から「個人 Claude Code 知識ハブ専用リポジトリ」へ役割転換しました。
> 主役機能 `/llm-wiki` の `init` / `ingest`（Phase 3d 共通 surface 拡張：migration_pending 承認後 ingest を内包、
> 同一 source 判定 3 段ロジック、URL 正規化最小ルール、sources: 末尾 append 明文化、overview 自動更新 inline・
> Phase 3f `--watch` で Tier B watchlist 登録・Phase 3g `--feed=<rss_url>` で Tier B フィード登録〔source ページに `feed_url` を立て mode I 巡回対象に〕・
> Phase 4 step 3 host routing〔`medium.com`/`*.medium.com` → minitools `scrape-medium --cdp` で英語原文 raw〔`fetched_via: minitools-playwright`・対話のみ・F-1 gh api routing 同型〕・Medium + `--watch` は reject〔D8〕〕・
> Phase 4 `--feed=notion-*:` registry append 特例〔document-less ソースを `current-baseline.md.feed_registry[]` に登録・raw/source ページ生成なし・ingest short-circuit〕・
> Phase 5 raw 元日付メタ〔step 3 で経路別に `published_at`/`last_modified`/`*_source` を抽出＝gh-commit/feed-pubdate/sitemap-lastmod/html-meta/html-body〔本文可視日付の保守パース・偽日付防止〕・ベストエフォート・取得不能は unknown・Medium は Phase 2〕＋ `--backfill-dates` 一回限りバッチ〔既存 raw に日付メタを後追い追記・本文/`fetched_at` 不可触＝E1・lint には置かず ingest 側〕＋ index.md 代表鮮度日 `（鮮度: …）` 併記）/
> `query` / `synthesize`（Phase 3d overview 自動更新 inline）/ `lint`（Phase 2a 機械判定 7 検査＋
> Phase 2b 意味解釈 4 検査・#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記＋
> Phase 3a `#12 last-tier-a-refresh` 機械判定／§2.5 migration_pending 提案フローは Phase 3d で
> 共通 surface 経由に再定義＋ Phase 3f `#14 last-refresh-watchlist-run` / `#15 watch-fetch-failed` 機械判定 2 検査追加＋
> Phase 3g `#16 last-discover-watchlist-run` 機械判定 1 検査追加・Phase 5 `#17 source-date-stale` 機械判定 1 検査追加〔代表鮮度日 180 日超で情報・index.md 再利用〕＝17 検査）/ `refresh-tier-a [--dry-run]`（Phase 3a・Tier A 日次自動再取得・
> launchd/cron からの非対話実行・Phase 3b で F-5 空 commit ガード追加・Phase 3d で F-2 dirty check
> から log.md を除外＝pathspec `:!wiki/log.md`、F-4e に sources: append 仕様再掲、
> F-4g/F-5 に overview inline 更新追加）/ `discover-tier-a [--no-prompt|--dry-run]`（Phase 3c・Tier A
> 公式 docs/GitHub の未取り込み URL を自動発見＝`code.claude.com/docs/en/*` sitemap + `anthropics/claude-code`
> の CHANGELOG/README、`pending_discoveries[]` に dedup append、承認制で共通 surface 経由 ingest、
> `--no-prompt` で launchd/cron 非対話 discovery、lint #13 で停止監視。Phase 3e で G-6 承認を
> capped バッチ opt-out（除外を選択・1 run cap N=20・遅延概要）に amend＋除外候補に `declined` negative cache
> を立て stuck candidates を解消）/ `review [--dry-run]`（Phase 3e・mode H・会話 URL hook が vault 外
> `.llm-wiki-inbox.jsonl` に貯めた URL を drain → opt-in 個別承認 → 共通 surface ingest・対話専用）/
> `refresh-watchlist [--dry-run]`（Phase 3f・mode W・mode F の Tier B 版＝`tier:B`＋`watch:true` の source ページを
> 日次自動再取得・W-4a 取得失敗で `fetch_status:failed` を Edit+commit・**W-4f 省略＝current-baseline.md version 系を
> 触らず lint #3 が次回対話で再検出**＝決定6 を壊さず carrier 不要・mode B `--watch` で opt-in 登録・
> launchd/cron は refresh-tier-a と起動時刻を stagger＝lock 競合回避・`references/refresh-watchlist-launchd.plist.example` 同梱）/
> `discover-watchlist [--no-prompt|--dry-run]`（Phase 3g・mode I・`feed_url` を持つ source ページの RSS/Atom を巡回して
> 新着 URL 発見・stage-1 keyword フィルタ〔cron・API コスト 0〕→ stage-2 LLM 判定〔対話のみ・confidence<0.7 で auto-decline〕→
> `pending_feed_discoveries[]` に dedup append・cap/eviction〔per-feed N=50・全体 M=200〕→ capped バッチ opt-out 承認 → 共通 surface ingest・
> `--no-prompt` で launchd/cron 非対話 discovery〔stage-1+append のみ〕・lint #16 で停止監視・
> Phase 4 で I-3 を 2 経路に拡張〔(1) http(s) feed_url curl〔不変〕/ (2) `current-baseline.md.feed_registry[]` の `notion-medium-db` → minitools `discover-notion-medium` で Notion Medium DB 新着取得〕・
> Phase 4c で I-3 に sitemap 経路追加〔feed_registry の `claude-blog-sitemap` → `claude.com/sitemap.xml` を curl して `/blog/<slug>` 英語のみ発見・`route_kind: sitemap`・RSS 不在の公式ブログ対応・stage-1 は title 不在で URL/slug のみ・stage-2 は WebFetch〔Cloudflare なし・Playwright 不要〕・ingest は tier:B 自動付与で非 cap〕・
> 早期 return guard を「feed_url 0 件 AND feed_registry 空」両方真に改修・I-6 stage-2 を source 種別で条件分岐〔notion は永続 `summary` 入力で WebFetch 省く・http-feed/sitemap は WebFetch〕＋ Notion 由来 ingest cap K=5〔Playwright sequential・対話のみ・http-feed/sitemap ingest は非 cap で非破壊〕・
> `references/discover-watchlist-launchd.plist.example` 同梱〔3 系統 stagger 04:00・Phase 4 で env に `NOTION_API_KEY` 追記・4 系統目 plist は作らない・Phase 4c も既存 plist が sitemap 経路を拾う〕）と
> Phase 3b の session-start hook 設定例・Phase 3e の会話 URL hook 設定例
> （`references/{session-start-hook.example.json,conversation-url-hook.example.{json,sh}}`・利用者が `.claude/settings.json` に手動マージ）、
> schema/templates（practice/feature 含む・schema v1.4.0 で overview.md `## 現状` セクション構造定義と
> log.md dirty append 規約を追加・v1.4.1 で `platform.claude.com` を Tier A 追加・v1.5.0 で
> `last_discover_tier_a_run` / `pending_discoveries[]` を追加・v1.6.0 で `pending_discoveries[].declined`
> 追加＋ URL 正規化フル仕様を mode B step 3.5 単一正本化・v1.7.0 で `watch` / `fetch_status`（§2 共通）と
> `last_refresh_watchlist_run`（§2.1・mode W run heartbeat）を追加・v1.8.0 で `feed_url`（§2 共通）と
> `last_discover_watchlist_run` / `pending_feed_discoveries[]`（§2.1・mode I 専用）を追加・v1.9.0 で `feed_registry[]`（§2.1・document-less discovery source 登録 registry・pending array ではない）と
> `pending_feed_discoveries[].summary`（§2.1・notion-medium-db 由来のみ）を追加＋ `fetched_via: minitools-playwright`（§3・Tier B verbatim）＋ URL 正規化 denylist に `source`〔`feed_url` 値域は不変〕を追加・v1.10.0 で `feed_registry[]` の既知 source に `claude-blog-sitemap`〔§2.1・Phase 4c・RSS 不在の公式ブログを sitemap 巡回〕と in-memory `route_kind` 語彙に `sitemap` を追加〔§4 tier 判定表は不可触＝blog は既存「任意ブログ = Tier B」で充足〕・v1.11.0 で raw フロントマター日付メタ 4 フィールド〔§3・`published_at`/`last_modified`/`published_at_source`/`last_modified_source`・値域 `YYYY-MM-DD|unknown`・出所 enum〕＋ raw 不変（E1）と frontmatter メタ補完の関係・index.md 代表鮮度日記法を明文化＋ `pending_feed_discoveries[]` に任意日付メタ〔§2.1・http-feed/sitemap 由来のキャリー用〕を追加〔§4 tier 判定表は不可触〕）を `.claude/skills/llm-wiki/` に実装済みです。
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
| `/llm-wiki ingest <path-or-url> [--type=practice|--feature=<slug>] [--watch] [--feed=<rss_url>|--feed=notion-*:<sel>]` ／ `/llm-wiki ingest --backfill-dates [--dry-run]` | ソース取り込み・コンパイル・相互参照（`--type`／`--feature` は 2a／3d: 共通 surface 拡張で migration_pending 承認後 ingest を内包・同一 source 判定 3 段・sources: 末尾 append・overview 自動更新 inline・`--watch` は 3f: Tier B watchlist 登録・`--feed=<rss_url>` は 3g: Tier B フィード登録〔`feed_url` を立て mode I 巡回対象に〕・**4a**: step 3 host routing で `medium.com` → `scrape-medium --cdp` 英語原文 raw〔対話のみ・Medium+`--watch` は reject〕・**4b**: `--feed=notion-*:<sel>` は document-less ソースを `feed_registry[]` に registry append〔ingest short-circuit・raw/source ページなし〕・**4c**: `--feed=claude-blog-sitemap:default` も同 registry append 特例で公式ブログを sitemap 巡回ソースとして登録・**5**: step 3 で経路別に日付メタ抽出〔`published_at`/`last_modified`/`*_source`・ベストエフォート・Medium は Phase 2〕＋ index.md 代表鮮度日併記・`--backfill-dates` は path-or-url 省略の一回限りバッチで既存 raw に日付メタを後追い追記〔step 0.c short-circuit・本文/`fetched_at` 不可触＝E1〕） | 1（MVP）＋ 2a ＋ 3d ＋ 3f ＋ 3g ＋ 4 ＋ 4c ＋ 5 |
| `/llm-wiki query <質問>` | Wiki から引用付きで回答（不足は Web 補完明示） | 1（MVP） |
| `/llm-wiki synthesize <テーマ>` | チートシート/Tips 集等の派生成果物を生成・再生成（3d: overview 自動更新 inline） | 1（MVP）＋ 3d |
| `/llm-wiki lint [--check=<csv>]` | 健全性・陳腐化・信頼度の監査（2a: 機械判定 7 検査・レポートのみ／2b: 意味解釈 4 検査・承認制／3a: #12 last-tier-a-refresh 機械判定／3d: §2.5 migration_pending 提案フローを共通 surface 経由に再定義／3g: #16 last-discover-watchlist-run 機械判定追加／5: #17 source-date-stale 機械判定追加〔代表鮮度日 180 日超で情報〕＝17 検査） | 2a／2b／3a／3d／3g／5 |
| `/llm-wiki refresh-tier-a [--dry-run]` | Tier A（公式 docs / 公式 GitHub）の既知 URL を日次自動再取得・再コンパイル・`current-baseline.md` の baseline フィールド自動更新。launchd/cron 経由の非対話実行（モード F）。`--dry-run` は副作用ゼロのレポートのみ。3d で F-2 dirty check から log.md 除外・F-4e sources: append 仕様再掲・F-4g/F-5 overview inline 更新 | 3a／3d |
| `/llm-wiki discover-tier-a [--no-prompt\|--dry-run]` | Tier A 公式 docs / 公式 GitHub の**未取り込み URL を自動発見**（α scope = `code.claude.com/docs/en/*` sitemap + `anthropics/claude-code` の `CHANGELOG.md`/`README.md`）し、`current-baseline.md.pending_discoveries[]` に dedup append、承認制で共通 surface（モード B）経由 ingest（モード G）。`--no-prompt` は launchd/cron 用（discovery + append のみ・AskUserQuestion 不発火）、`--dry-run` は副作用ゼロ。discovery scope ≠ refresh scope（§F-3 不可触）。lint #13 で停止監視。Phase 3e で G-6 承認を capped バッチ opt-out（除外選択・cap N=20・遅延概要・`declined` negative cache で stuck candidates 解消）に amend | 3c / 3e |
| `/llm-wiki refresh-watchlist [--dry-run]` | Tier B watchlist（`tier: B` ＋ `watch: true` の source ページ）を mode F の per-source 機械を再利用して**日次自動再取得**（モード W・mode F の Tier B 版）。W-3 走査を `tier:B`＋`watch:true` に改変・W-4a Tier B = WebFetch 既定で取得失敗時は `fetch_status: failed` を Edit+log+**commit**（mode F 非 commit 失敗扱いから逸脱）・W-4b 取得成功で受動回復・**W-4f 省略＝`current-baseline.md` の version 系を触らず Tier B 乖離を自動上書きしない（決定6）＝lint #3 が次回対話で再検出（carrier 不要）**・W-5 `last_refresh_watchlist_run` heartbeat。`--watch` は mode B で opt-in 登録（共通 surface 内部呼び出し G-6/H-5/F migration には非伝播）。launchd/cron は refresh-tier-a と起動時刻 stagger（lock 競合回避）。lint #14 で停止監視・#15 で死 URL surface | 3f |
| `/llm-wiki review [--dry-run]` | 会話 URL hook（`UserPromptSubmit`・`references/conversation-url-hook.example.{json,sh}`）が **vault 外** `.llm-wiki-inbox.jsonl` に貯めた URL を drain・フル正規化・取り込み済み突合 → **opt-in 個別承認** → 共通 surface（モード B）経由 ingest（モード H）。対話専用（cron 非対話 ingest なし）。`--dry-run` は inbox preview のみ | 3e |
| `/llm-wiki discover-watchlist [--no-prompt\|--dry-run]` | 登録済みフィードを巡回し**新着 URL を自動発見**。I-3 は 2 系統 3 種〔(1) `feed_url` を持つ source ページの http(s) RSS/Atom curl〔3g・`http-feed`〕/ (2) `feed_registry[]` の `notion-medium-db` → minitools `discover-notion-medium`〔**4b**・Notion Medium DB〕/ `claude-blog-sitemap` → `claude.com/sitemap.xml` curl〔**4c**・RSS 不在の公式ブログ・`/blog/<slug>` 英語のみ・`route_kind: sitemap`〕〕。stage-1 keyword フィルタ〔cron・API コスト 0・sitemap は title 不在で URL/slug のみ〕→ stage-2 LLM relevance 判定〔対話のみ・notion は永続 `summary` 入力で WebFetch 省く・http-feed/sitemap は WebFetch〕→ `pending_feed_discoveries[]` に dedup append・cap/eviction → capped バッチ opt-out 承認 → 共通 surface 経由 ingest〔Medium は 4a Playwright・ingest cap K=5／blog は WebFetch・tier:B 自動・非 cap〕（モード I）。早期 return guard は「feed_url 0 件 AND feed_registry 空」両方真に改修（4b）。`--no-prompt` は launchd/cron 用（stage-1+append のみ・stage-2/Playwright/WebFetch 不発火）。lint #16 で停止監視。cron は 3 系統 stagger（03:00/03:30/04:00・4 系統目 plist は作らない・4c も既存 plist が拾う）。`--feed` は mode B で opt-in 登録〔共通 surface 非伝播〕 | 3g ＋ 4 ＋ 4c |

ロードマップ: Phase 2a（**実装済み**）= 機械判定 lint 7 検査＋ practice/feature テンプレ＋ ingest 動線拡張 / Phase 2b（**実装済み**）= 意味解釈 lint 4 検査（横断矛盾・synthesis 再生成要否・3 面相互矛盾・バージョン軸決着、承認制） / Phase 3a（**実装済み**）= `/llm-wiki refresh-tier-a` + ロック規約 + lint #12（refresh 停止監視） / Phase 3b（**実装済み**）= session-start hook 設定例（read-only context preload）＋ F-5 空 commit ガード / Phase 3c（**実装済み**）= `/llm-wiki discover-tier-a`（Tier A 未取り込み URL の自動発見＋承認制 ingest・mode G・lint #13・schema v1.5.0 `pending_discoveries[]`/`last_discover_tier_a_run`） / Phase 3d（**実装済み**）= F-4 共通 surface 確立（mode B ingest 拡張で migration_pending 承認後 ingest を内包）＋ F-6 sources: append 明文化＋ C overview 自動更新（同一 commit inline）＋ F-3 log.md append 規約（F-2 dirty check から log.md 除外） / Phase 3e（**実装済み**）= 会話 URL hook（`UserPromptSubmit` → vault 外 inbox）＋ mode H `review`（opt-in 個別承認 ingest）＋ URL 正規化フル仕様（denylist）＋ stuck candidates 対策（`declined` negative cache）＋ 3c mode G G-6 承認 UX amendment（capped バッチ opt-out） / Phase 3f（**実装済み**）= ウォッチリスト型 Tier B 定点観測〈単一 URL 型〉（`refresh-tier-a` の Tier B 版・mode `refresh-watchlist` 新設＝`tier:B`＋`watch:true` 走査・W-4f 省略で current-baseline.md version 系不可触〔決定6・carrier 不要〕・mode B `--watch` opt-in 登録〔共通 surface 非伝播〕・`fetch_status` fetchability decay マーカー・lint #14 停止監視/#15 死 URL surface・schema v1.7.0〔`watch`/`fetch_status`/`last_refresh_watchlist_run`〕・cron stagger plist 同梱） / Phase 3g（**実装済み**）= ウォッチリスト型 Tier B 定点観測〈定点フィード型〉（`discover-tier-a` の Tier B 版・mode I `discover-watchlist` 新設＝`feed_url` 走査・RSS/Atom curl 巡回・stage-1 keyword フィルタ〔cron・API コスト 0〕・stage-2 LLM relevance 判定〔対話のみ〕・`pending_feed_discoveries[]` dedup append+cap/eviction・capped バッチ opt-out 承認・mode B `--feed` opt-in 登録〔共通 surface 非伝播〕・`declined_reason` 3 値 discriminator・lint #16 停止監視・schema v1.8.0・cron 3 系統 stagger plist 同梱） / Phase 4（**実装済み**）= Medium 取り込み・2 層構造（X deferred）。**4a per-host content routing**（mode B step 3 host 別分岐・`medium.com`/`*.medium.com` → minitools `scrape-medium --cdp` で英語原文 raw〔`fetched_via: minitools-playwright`・Tier B・verbatim 原則〕・対話のみ〔Playwright auth decay を cron 経路に持ち込まない・F-1 gh api routing 同型〕・Medium+`--watch` は reject〔D8〕）＋ **4b Notion-DB-as-discovery**（mode I I-3 を feed_registry 経路で拡張・`current-baseline.md.feed_registry[]` の `notion-medium-db` を minitools `discover-notion-medium` で cron 巡回〔API キー認証のみ＝decay しない〕・stage-2 は永続 `summary` 再利用で Medium に WebFetch しない・承認分 Medium ingest は K=5 cap〔Playwright sequential tail 制限〕・**新規 mode/lint/4 系統目 plist なし**〔mode I 流用・anti-duplication D7〕）＋ `--feed=notion-*:` registry append 特例＋ minitools_path 設定〔未設定/不在は Medium 機能のみ無効化・clean failure〕＋ schema v1.9.0〔`feed_registry[]`・`pending_feed_discoveries[].summary`・`fetched_via: minitools-playwright`・denylist `source`・`feed_url` 値域不変〕 / Phase 4c（**実装済み**）= `claude.com/blog` 定点観測（mode I I-3 に sitemap 経路追加・feed_registry の `claude-blog-sitemap` → `claude.com/sitemap.xml` curl で `/blog/<slug>` 英語のみ発見・**Tier B**〔§4「任意ブログ = B」で充足・§4 改訂なし・refresh 除外マーカー不要〕・stage-1 は title 不在で URL/slug のみ・stage-2 は WebFetch〔Cloudflare なし・Playwright 不要〕・ingest 非 cap・**新規 mode/lint/4 系統目 plist なし**〔mode I 流用・D7〕・schema v1.10.0〔`feed_registry[]` 既知 source に `claude-blog-sitemap`・`route_kind` に `sitemap`〕） / Phase 5（**実装済み**）= raw 元日付メタ（`published_at`/`last_modified`/per-date `*_source`・ベストエフォート・unknown 許容・代替なし）。mode B step 3 で経路別抽出〔gh-commit/feed-pubdate/sitemap-lastmod/html-meta/html-body〕・mode I I-3/I-5 で http-feed/sitemap 日付をキャリー（notion/Medium は Phase 2・blog は sitemap に lastmod 無く ingest 時 html-body 回収）・mode B step 9 で index.md 代表鮮度日 `（鮮度: …）` 併記（b4）・b1 ingest 時の `## 矛盾` に `last_modified` 補助注記（Tier A 優先不変・#11 日付軸はスコープ外）・b3 synthesize の鮮度反映・lint #17 source-date-stale（情報・index 再利用で追加 Read 0）・`--backfill-dates` 一回限りバッチ（mode B step 0.c・既存 raw に後追い追記・本文/`fetched_at` 不可触＝E1・lint には置かず ingest 側）・schema v1.11.0。新規 mode/plist なし（ingest 流用） / Phase 4+（将来）= X 自動巡回（公開 RSS 無し・ToS グレー・取得 spike を着手前 gate に・deferred）・YouTube transcript・Medium 著者フィード（mode I http(s) feed として登録）・Medium 日付抽出（Phase 5 の Phase 2・`scrape-medium` 出力確認後）。

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
claude-code-wiki-maker/        # スキル資産の置き場（このリポジトリ）
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
5. **フロントマター骨格は MVP から（決定 ア）**: lint の機械判定 7 検査は Phase 2a で実装済み（意味解釈 4 検査は Phase 2b 実装済み、Phase 3a で #12 `last-tier-a-refresh` を追加、Phase 3g で #16 `last-discover-watchlist-run` を追加、Phase 5 で #17 `source-date-stale` を追加）。`claude_code_version` / `updated` / `stale` / 情報源ティア（Tier A=公式 / Tier B=その他）は MVP の ingest/synthesize 時点で全ページに記録する。`current-baseline.md` には Phase 3a で `last_tier_a_refresh` / `migration_pending` を追加（schema v1.3.0）。Phase 3d で schema v1.4.0 = `overview.md` に agent 完全所有の `## 現状` セクション構造（統計値 5 件・最終 ingest / 最終更新 2 日付）を追加、§3 raw 引用記法直下に「log.md は dirty 状態でも append + commit 可」を明記。Phase 3g で schema v1.8.0 = `feed_url`（§2 共通）と `last_discover_watchlist_run` / `pending_feed_discoveries[]`（§2.1）を追加。Phase 4 で schema v1.9.0 = `feed_registry[]`（§2.1・document-less discovery source 登録・pending array ではない）と `pending_feed_discoveries[].summary`（§2.1・notion-medium-db 由来）と `fetched_via: minitools-playwright`（§3・Tier B verbatim）と URL 正規化 denylist の `source` を追加（`feed_url` 値域は不変）。`.llm-wiki.json` に `minitools_path` を追加（未設定/不在は Medium 機能のみ無効化）。Phase 4c で schema v1.10.0 = `feed_registry[]` の既知 `source` 値に `claude-blog-sitemap`（document-less な sitemap 巡回ソース）を追加、in-memory `route_kind` 語彙（mode I I-3）に `sitemap` を追加（§4 tier 判定表は不可触＝blog は既存「任意ブログ = Tier B」で充足）。**Phase 4c では lint は新規検査なし（#16 を流用）**。Phase 5 で schema v1.11.0 = raw フロントマター日付メタ 4 フィールド（§3・`published_at`/`last_modified`/`published_at_source`/`last_modified_source`・値域 `YYYY-MM-DD|unknown`・出所 enum `gh-commit|feed-pubdate|sitemap-lastmod|html-meta|html-body|manual|unknown`〔`html-body`＝本文可視日付の保守パース・publication-context 限定・偽日付防止〕）と raw 不変（E1）と frontmatter メタ補完の関係・index.md 代表鮮度日記法を §3 に明文化、`pending_feed_discoveries[]` に任意日付メタ（§2.1・http-feed/sitemap 由来のキャリー）を追加。lint #17 `source-date-stale` を新設（16→17 検査・index.md 再利用で追加 Read 0）。
6. **情報源ティア**: Tier A（Anthropic 公式ドキュメント/公式 GitHub）は Phase 3a で日次自動更新（モード F `refresh-tier-a`）を先行解禁・実装済み。`current-baseline.md` は Tier A 由来は自動更新可・手動上書き可、Tier B はバージョン乖離時に対話で更新提案（承認制）。書き込みモード（B / D / F / G / W / H / I／lint #11 承認制決着）は `.llm-wiki.lock`（vault 直下・atomic 取得・スタール判定 timestamp 1h ＋`kill -0` の AND）で排他制御する。Tier B watchlist は Phase 3f で日次自動再取得（モード W `refresh-watchlist`・`tier:B`＋`watch:true`）を解禁したが、**baseline の version 系は自動更新しない**（W-4f 省略・決定6＝Tier B は承認制）。Tier B フィード（`feed_url` 保持 source ページ）は Phase 3g で新着 URL 自動発見（モード I `discover-watchlist`）を解禁したが、**baseline の version 系は自動更新しない**（W-4f 省略と同理由）。Phase 4 で document-less な discovery source（Notion Medium DB）を `current-baseline.md.feed_registry[]` に登録し mode I I-3 が巡回対象に追加（cron は Notion DB の API キー認証のみ＝decay しない経路に限定し、Playwright を使う Medium content fetch〔4a〕は対話のみ＝auth decay を cron に持ち込まない〔D3〕）。Medium = Tier B で baseline version 系は不可触（mode I/W と同型）。Phase 4c で公式ブログ `claude.com/blog`（RSS 不在）を `feed_registry[]` の `claude-blog-sitemap` として登録し mode I I-3 が `claude.com/sitemap.xml` を curl 巡回（cron は公開 sitemap の curl のみ＝auth 不要・decay しない）。**blog = Tier B**（公式だが規範 docs ではない announcement＝§4「任意ブログ = B」で充足し §4 改訂不要・tier:B ゆえ mode F の F-3 refresh 対象外で write-once blog の毎日再取得を回避＝refresh 除外マーカー不要・`watch` 未設定で mode W も非対象）。tier と discovery 機構は直交し、関連性が不均質なソースは関連性フィルタを持つ mode I に載せる（mode G は同質ソース前提で filter なし）。
7. **単一エージェント書き込み前提**: 個人利用・マージ競合回避。信頼度 0.7 程度を許容。
8. **操作ごと Git コミット**: ボールト側（別リポジトリ）に履歴を残す。

## Commands

このリポジトリには独自のビルド対象コードはありません。テスト・リント・型チェックの対象はなく、品質はドキュメントとスキル定義（`.claude/skills/*/SKILL.md`）のレビューで担保します。

- スキル定義の検証: `.claude/skills/*/SKILL.md` のフロントマター・記述粒度を既存 Skill と揃える
- ボールト整合の検証: `/llm-wiki lint`（Phase 2a 機械判定 7 検査＋ Phase 2b 意味解釈 4 検査＋ Phase 3a/3c/3f/3g 機械判定 5 検査＋ Phase 5 機械判定 1 検査〔#17 source-date-stale〕＝17 検査・実装済み。#11 のみ承認制で `## 矛盾` 末尾に決着注記を追記）

## このリポジトリ自体の作業

- `llm-wiki` スキルの修正時は、本ファイルの「設計上の不変条件」と `docs/ideas/20260516-llm-wiki-skill-for-claude-code.md` の受け入れ条件に従う
- スキルの記述粒度は既存 `.claude/skills/*/SKILL.md` および `gen-all-docs` の小規模／中規模／大規模方針と平仄を保つ
- コマンドやスキルを追加した場合は `README.md` の「含まれるもの」表と「推奨ワークフロー」も更新する
- 実装例（`src/example.py` 等）は置かない。スケルトンの空ディレクトリのみ保持する

## Configuration

- ボールトパス: 本リポジトリ直下の設定ファイル `.llm-wiki.json` に相対パス `./wiki-vault`（正）・実体絶対パス（参考）・`schema_version`（`references/schema.md` から転記。co-evolution 時に更新）を記録（`/llm-wiki init` が作成）
- minitools パス（Phase 4・任意）: `.llm-wiki.json` の `minitools_path` に Medium 取り込み用外部リポジトリ minitools の絶対パスを記録（`/llm-wiki init` が対話設定・既定候補 `/Users/tak/Projects/minitools`）。未設定/ディレクトリ不在なら Medium 機能（4a content routing・4b Notion DB discovery）のみ無効化し他モードは通常動作（clean failure）
- `.gitignore`: `wiki-vault`（シンボリックリンクの誤コミット防止）と `.steering/` を追記
- 環境変数: `.env`（`.env.example` を参照）
- 依存: Claude Code Skills / Git / Obsidian（表示）/ シンボリックリンク / WebFetch・WebSearch / （Phase 4・Medium 機能のみ）minitools 2 CLI〔`scrape-medium` / `discover-notion-medium`〕＋ `uv` ＋ `NOTION_API_KEY`（4b cron）＋ Chrome ログイン済みセッション（4a `--cdp`・対話のみ）

## ドキュメント生成のスケール対応

`/gen-all-docs` はプロジェクト規模に応じて生成範囲を切り替えます。本リポジトリは小規模（単一スキル・コード実装なし）に該当し、`README.md` + `CLAUDE.md` + `docs/core/{architecture.md, development-guidelines.md}` を生成対象とします（`architecture.md` は積み上がった設計判断の俯瞰＝決定インデックスを担い、現状細部の再掲は避けて本ファイル / SKILL.md を参照に逃がす方針）。
