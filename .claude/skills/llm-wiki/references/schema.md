# llm-wiki schema（データ規約の単一真実源）

> このファイルは **ページタイプ規約・フロントマター規約・命名/ディレクトリ/[[wikilink]] 規約・
> `schema_version` の唯一の「正」** です（決定 ウ）。
> `SKILL.md` および `CLAUDE.md` はこの規約を **参照するのみ**で、フィールド定義・ページタイプ・
> tier 判定ルールを**再記述しません**（再記述＝矛盾源）。
> 齟齬時の優先順位: **CLAUDE.md（不変条件・運用ポリシー）> SKILL.md（ワークフロー）/ 本ファイル（データ規約）**。

```yaml
schema_version: 1.4.0
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

`current-baseline.md` は通常ページではなくボールトの基準ファイルだが、フロントマターは本規約に準じ、
加えて §6 の schema 軽量ポインタを保持する。

### 2.1 `current-baseline.md` 専用フィールド（Phase 3a 追加・v1.3.0）

`current-baseline.md` は §2 の共通フィールドと §6 の schema 軽量ポインタに加え、以下の専用フィールドを保持する。**`refresh-tier-a`（モード F）が自動更新する領域**であり、§6 の schema 軽量ポインタとは別領域として共存する（refresh は §6 を不可触）。

```yaml
last_tier_a_refresh: 2026-05-23      # YYYY-MM-DD。直近の refresh-tier-a 成功日
migration_pending:                    # 301 リダイレクトの保留事項。既定 []
  - old_url: https://docs.anthropic.com/en/docs/claude-code/overview
    new_url: https://code.claude.com/docs/en/overview
    detected_on: 2026-05-23
    source_slug: claude-code-overview
```

- **`last_tier_a_refresh`**: `YYYY-MM-DD`。`refresh-tier-a` の全ソース処理後に 1 度だけ更新。`--dry-run` では更新しない。`lint #12`（`last-tier-a-refresh`）が監視。
- **`migration_pending`**: 配列。既定 `[]`。`refresh-tier-a` が 301 検出時に 1 ソース 1 回だけ append（重複は `source_slug` で抑止）。対話モード（`ingest` / `lint`）の AskUserQuestion 承認で該当エントリを削除。エントリの形は `{old_url, new_url, detected_on, source_slug}` の 4 キー。

**refresh の編集境界**: 上記 2 フィールドと、§2 共通フィールドのうち `claude_code_version` / `updated` のみを更新可。**§6 の schema 軽量ポインタ（`schema_version` / `schema_repo_commit` / `schema_summary`）は不可触**。schema 軽量ポインタは §5 の co-evolution 経路でのみ更新する。

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
| URL ホストが `github.com` かつパスが `anthropics/`（claude-code 等の公式リポジトリ） | A |
| 上記以外（`medium.com` / `youtube.com` / `notion.so` / 任意ブログ / ローカルメモ 等） | B |
| 判断不能（ホスト不明・ローカルパスで出所が曖昧 等） | AskUserQuestion でユーザーに確認 |

> 注: `docs.anthropic.com/en/docs/claude-code/*` は `code.claude.com/docs/en/*` へ 301 リダイレクトする。
> WebFetch は cross-host redirect を自動追従しないため、リダイレクト先 URL で呼び直すこと（取得元ホストは追従先 `code.claude.com` で判定する）。

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

**更新権限の境界（v1.3.0 で明記）**: `schema_version` / `schema_repo_commit` / `schema_summary` の 3 フィールドは **§5 の co-evolution 経路でのみ更新**する。`refresh-tier-a`（モード F）は §2.1 の `last_tier_a_refresh` / `migration_pending`、および §2 共通フィールドの `claude_code_version` / `updated` のみを書き換え、本節の軽量ポインタは**不可触**。

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
