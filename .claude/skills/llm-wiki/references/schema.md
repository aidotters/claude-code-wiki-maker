# llm-wiki schema（データ規約の単一真実源）

> このファイルは **ページタイプ規約・フロントマター規約・命名/ディレクトリ/[[wikilink]] 規約・
> `schema_version` の唯一の「正」** です（決定 ウ）。
> `SKILL.md` および `CLAUDE.md` はこの規約を **参照するのみ**で、フィールド定義・ページタイプ・
> tier 判定ルールを**再記述しません**（再記述＝矛盾源）。
> 齟齬時の優先順位: **CLAUDE.md（不変条件・運用ポリシー）> SKILL.md（ワークフロー）/ 本ファイル（データ規約）**。

```yaml
schema_version: 1.1.0
```

`schema_version` はセマンティックバージョニング。Phase 1 起点は `1.0.0`、
co-evolution（§5）で改訂する。この版数を持つ文書は本ファイルのみ。

改訂履歴:
- `1.0.0` → `1.1.0`: §4 tier 自動判定に `code.claude.com`（公式 docs の移転先ホスト）を
  Tier A 条件として追加（後方互換の判定拡張＝minor）。

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
| `practice` | 試した Claude Code 実践とその効果（効いた/効かなかった） | `wiki/practices/` | ⏳ Phase 2 予約 |
| `feature` | Claude Code 自体の機能（Skill/Hooks/MCP/Agent SDK 等）ごとの最新仕様まとめ。バージョン追従・陳腐化管理の対象 | `wiki/features/` | ⏳ Phase 2 予約 |

- `practice` / `feature` は **Phase 2 予約**。MVP では生成しない（テンプレートも Phase 2）。
- `entity` と `feature` の線引き: **Claude Code の機能なら `feature`、それ以外の固有物は `entity`**。
  MVP は `feature` を使わないため、Claude Code 機能の知見も当面 `concept` または `source` に収める。

---

## 2. 全ページ共通フロントマター必須フィールド（MVP 確定値）

すべての `wiki/` ページは YAML フロントマターを持ち、以下のフィールドを必ず埋める。
判定ロジック（陳腐化・矛盾検出）は Phase 2 だが、**値の保持は MVP の ingest/synthesize 時点から必須**（決定 ア）。

```yaml
---
type: source                 # source|concept|entity|comparison|synthesis（practice|feature は Phase 2）
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

---

## 3. 命名・ディレクトリ・[[wikilink]] 規約

### ディレクトリ

```
<ボールト>/
├── raw/{docs,articles,videos,github,notes}/   # 取得スナップショット（不変・人間が追加）
└── wiki/
    ├── sources/  concepts/  entities/  comparisons/  syntheses/
    ├── practices/  features/                  # Phase 2 予約（MVP では空）
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
schema_version: 1.0.0
schema_repo_commit: <本リポジトリの該当 commit ハッシュ>
schema_summary: >
  ページタイプ source/concept/entity/comparison/synthesis（practice/feature は Phase 2）、
  共通フロントマター必須（type/title/tier/claude_code_version/updated/stale/confidence/sources/links）、
  必ず raw 引用・[[wikilink]]・黙って上書きしない。
```

これにより repo B（ボールト）単体でも「どの schema 版でコンパイルされたか」を
repo A の commit に追跡でき、ボールトの自己記述性を回復する。

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
