# llm-wiki lint 規則

> Phase 2a で機械判定 7 検査（#1/#2/#3/#4/#6/#7/#9）を実装。
> Phase 2b（意味解釈 4 検査・承認制 = #5/#8/#10/#11）で実装完了。
> フロントマター定義・ページタイプは `references/schema.md` を参照（再記述しない）。

## 検査項目（全 11）

| # | 検査 | 概要 | 判定材料 | Phase |
|---|------|------|---------|:-----:|
| 1 | 孤立ページ | どこからも [[wikilink]]・`links:` されないページを検出 | wiki 全ページの links 突合 | 2a ✅ |
| 2 | 陳腐化（更新日） | `updated` が 30 日超のページを警告 | フロントマター `updated` | 2a ✅ |
| 3 | 陳腐化（バージョン乖離） | `claude_code_version` が `current-baseline.md` と乖離 | baseline 比較 | 2a ✅ |
| 4 | `stale:true` 監査 | `stale:true` のページを一覧化し対応を促す | フロントマター `stale` | 2a ✅ |
| 5 | 横断的矛盾スキャン（決定 Z 二段目） | index.md の主張サマリを走査し別トピック間の矛盾を検出 | index.md 主張サマリ | 2b ✅ |
| 6 | 信頼度監査 | `confidence` が低いページの一覧 | フロントマター `confidence` | 2a ✅ |
| 7 | index 同期 | index.md のサマリと実ページの不整合・欠落を検出 | index.md vs wiki/ | 2a ✅ |
| 8 | synthesis 再生成要否 | 引用元更新後に未再生成の synthesis を検出 | synthesis の sources/links 更新日 | 2b ✅ |
| 9 | baseline 鮮度 | `current-baseline.md` 自体の最終更新からの経過日数を監査 | current-baseline.md | 2a ✅ |
| 10 | 3 面相互矛盾（決定 ウ） | CLAUDE.md / SKILL.md / schema.md の相互矛盾を検査（齟齬時 CLAUDE.md 優先） | 3 文書突合 | 2b ✅ |
| 11 | バージョン軸の矛盾決着 | 既存 `## 矛盾` セクションを走査し、両側の `claude_code_version` 差に起因する時系列差を承認制で「決着」注記＋severity 降格 | 各ページ `## 矛盾` 両側の `claude_code_version` / `tier` / `updated`、`current-baseline.md` の `claude_code_version` | 2b ✅ |

practice / feature ページもこれらの検査対象に含む（孤立・更新日・version 乖離・stale・confidence・index 同期はタイプを問わず適用）。lint 走査対象から外れない。

---

## Phase 2a 7 検査の判定ロジック

検査 ID は `--check=<csv>` で指定するキー。

### #1 orphan（孤立ページ）

- 判定: いずれかのページの `links:` フィールドに自分の slug が含まれず、かつ他ページ本文の `[[slug]]` でも参照されず、`wiki/index.md` の本文にも `[[slug]]` で出現しない。
- severity: **警告**
- 例外: `current-baseline.md` / `index.md` / `log.md` / `overview.md` はボールト構造ファイルで通常ページではないため対象外。

### #2 updated（更新日 30 日超）

- 判定: `updated` の日付が「現在日 − 30 日」より古い。
- severity: **警告**
- 例外: `tier: A` でかつ `stale: false` のページも例外扱いしない（Phase 2a では tier 区別なし）。
- 日付比較は ISO 8601（`YYYY-MM-DD`）の文字列比較で十分。

### #3 version（claude_code_version 乖離）

- 判定: 当該ページの `claude_code_version` と `current-baseline.md` の `claude_code_version` を比較。
- `unknown` は対象外（判定スキップ）。
- 比較アルゴリズム:
  - 双方を `.` で split し、`[0]` を major、`[1]` を minor、`[2]` を patch とする。
  - `split(".")[0]` が異なる → **要対応**（major 桁差）
  - major 一致かつ minor または patch のいずれかが異なる → **警告**
  - 完全一致 → 検出しない

### #4 stale（`stale:true` 監査）

- 判定: フロントマター `stale: true`。
- severity: **要対応**

### #6 confidence（信頼度監査）

- 判定: `confidence` が `0.7` 未満（schema.md §2 の既定値）。
- severity: **情報**

### #7 index（index 同期）

- 判定: `wiki/index.md` の本文に並ぶ各行の `[[slug]]` 集合と、wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md の実ページ集合を突合。
  - 実ページが存在するが index.md に無い → **要対応**（横断矛盾スキャン #5 の前提を壊す）
  - index.md に行があるが実ページが存在しない → **警告**（ファイル削除/リネーム後の取り残し）
- 例外: `current-baseline.md` / `index.md` / `log.md` / `overview.md` はボールト構造ファイルで通常ページではないため、index.md に `[[current-baseline]]` 等の行があっても突合対象外（#1 orphan と同じ例外文言）。

### #9 baseline（baseline 鮮度）

- 判定: `current-baseline.md` の `updated` を現在日と比較。
  - 90 日超 → **要対応**
  - 60 〜 89 日 → **警告**
  - 60 日未満 → 検出しない

---

## Phase 2a しきい値表

| 項目 | しきい値 | 出典/根拠 |
|------|---------|-----------|
| #2 updated | 30 日 | `docs/ideas/...` 機能5「陳腐化（更新日 30 日超）」 |
| #6 confidence | 0.7 未満 | schema.md §2 既定値 |
| #9 baseline 警告 | 60 日 | design.md §1「検査ごとの判定ロジック」 |
| #9 baseline 要対応 | 90 日 | design.md §1「検査ごとの判定ロジック」 |

これらは MVP/2a 固定。`.llm-wiki.json` でのユーザー上書きは Phase 3 以降で検討。

---

## 走査戦略（Phase 2a / 2b 共通）

コンテキスト圧迫を回避するため、wiki ページ本文の Read は行わない（#11 の `## 矛盾` 限定 Read のみ例外）。

### Phase 2a で固定された走査

1. **Glob**: `wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md` で wiki 全ページ列挙（1 回呼び出し）。
2. **フロントマター抽出**: 各ページを `Read(offset=0, limit=50)` でフロントマター先頭部分のみ取得
   （フロントマターは通常 15 行未満。50 行で十分カバー）。Phase 2b では集約マップに `sources` /
   `links` を含めて #8 で再利用する。
3. **index.md**: `Read("wiki/index.md")` を 1 回。
4. **current-baseline.md**: `Read("wiki/current-baseline.md")` を 1 回。
5. 上記 4 つのデータをメモリ上の集約マップに保持し、Phase 2a 7 検査と Phase 2b #5/#8 を差分計算で完結させる。
6. 7 検査のうち #1 orphan のみ、index.md 本文内の `[[wikilink]]` 出現を確認するため index.md の本文走査が必要
   （既に 1 回 Read 済みのデータを使う）。

### Phase 2b で追加する走査

7. **#10 用 本リポジトリ側 3 文書 Read**: `CLAUDE.md` / `.claude/skills/llm-wiki/SKILL.md` /
   `.claude/skills/llm-wiki/references/schema.md` を 1 回ずつ Read（**追加 Read 3 回**）。CWD 起点。
   `--check` で `three-way` が含まれない場合はスキップ。
8. **#11 用 `## 矛盾` 保持ページの限定 Read**:
   `Bash("grep -l '^## 矛盾' wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md")`
   で `## 矛盾` セクション保持ページを抽出 → ヒットページのみ該当セクションを限定 Read
   （`Read(offset=<セクション開始行>, limit=80)` 程度）。`--check` で `version-resolve` が含まれない
   場合はスキップ。**全ページ本文 Read はしない**。

### 走査コスト見積もり

100 ページ規模での Read 呼び出し総数:
- Phase 2a: ページ 100 + index 1 + baseline 1 = **102 回**。
- Phase 2b 追加: 本リポジトリ側 3 文書 + `## 矛盾` 保持ページ（実機で通常 0〜数件）+ Bash grep 1 回。
- 合計: 概ね **105〜110 回**で完結する（コンテキストオーバーフローしない見込み）。

---

## 出力フォーマット

### 対話出力

全件を Markdown 表で出力:

```markdown
| file | check | severity | detail |
|------|-------|----------|--------|
| wiki/sources/foo.md | updated | 警告 | updated=2026-03-01 (83 日経過) |
| wiki/concepts/bar.md | stale | 要対応 | stale:true |
```

### `wiki/log.md` 追記

```markdown
### lint 結果（2026-05-23 14:30）
- severity 集計: 要対応 N / 警告 M / 情報 K
- 検査別件数: orphan=A, updated=B, version=C, stale=D, confidence=E, index=F, baseline=G
```

全件詳細は対話のみ。log.md には集計のみ（log.md 肥大化防止）。

### コミット

ボールト Git で `wiki/log.md` 差分のみを `git add` し `chore: llm-wiki lint (YYYY-MM-DD)` でコミット。lint は他の本文・フロントマター変更を一切行わない。

---

## Phase 2b 4 検査の判定ロジック

### #5 と #11 の切り分け（検出 vs 決着）

決定 Z は矛盾「検出」の二段（ingest 即時／lint 横断）を定義するが、検出済み矛盾の
「決着」ルールは別軸であり #11 として独立させる。両者を混同しないこと。

| | #5 横断的矛盾スキャン | #11 バージョン軸の矛盾決着 |
|---|----------------------|----------------------------|
| 入力 | `index.md` の主張サマリ（別トピック横断） | 既存 `## 矛盾` セクション（同一トピック・両論併記済み） |
| 役割 | 別トピック間の新規**検出**（決定 Z 二段目） | 決定 Z 一段目で検出済みの同一トピック矛盾の**決着提案** |
| 出力 | 新規矛盾の指摘 | 「決着」注記の追記提案＋severity 降格 |

> 受け入れレポートが緩く「横断矛盾」と呼んだ `background-agent-operation` の
> バージョン軸両論併記（2.1.143/Tier A ⇄ 2.0.5/Tier B）は、決定 Z の定義上は
> **別トピック横断ではなく同一トピックの決着案件**であり、#5 ではなく **#11 の対象**。

### Phase 2b severity 規約

- #5 cross-topic → **情報**（候補列挙のみ・本文確認は人間に委ねる）
- #8 synthesis-stale → **警告**（再生成提案の明示）
- #10 three-way → **警告**（規約違反は深刻だが書き込みを伴わない）
- #11 version-resolve → 時系列 supersession 候補（新が version も tier も上位）= **情報**
- #11 逆向き（旧=Tier A / 新=Tier B）・同一バージョン矛盾 = **要対応**（人間判断必須・auto-apply 不可）

### #5 cross-topic 判定ロジック

**入力**: `wiki/index.md` のサマリ行のみ（Phase 2a で 1 回 Read 済みのデータを再利用・**追加 Read 0 回**）。

**走査アルゴリズム**:

1. index.md の本文行から `[[slug]]` と「主要主張サマリ（1〜2 行）」を抽出。schema.md §3 規約により
   index.md は各ページの主要主張サマリを 1〜2 行で保持する前提。
2. サマリ行のペアを総当たりで比較し、以下のいずれかに該当するペアを「矛盾候補」として検出:
   - **否定/肯定対応**: 否定語（`しない` / `不要` / `避ける` / `禁止` 等）と肯定語（`する` / `必要` /
     `推奨` / `許可` 等）が、同じキーワード（`Skill` / `Hook` / `MCP` / `Agent SDK` 等の主要トピック語、
     CLAUDE.md / schema.md 由来の不変条件キーワード）に対して反対方向で出現。
   - **数値・バージョン番号食い違い**: ペア内で同種の数値（日数しきい値・version 番号等）が異なる
     （例: 「30 日経過で警告」と「60 日経過で警告」）。
3. LLM の自然言語判断はここでは控えめにする。主に**キーワード共起ベースの軽量ヒューリスティック**で
   候補を抽出し、対話レポートに「本文確認推奨」として列挙する。深い意味判定は人間に委ねる。

**severity**: 情報（候補列挙のみ）。

**出力詳細フォーマット例**:
```
| index.md | cross-topic | 情報 | [[skill-description]] vs [[skill-trigger-tips]]: "description は短く" vs "description に多くの文脈"（本文確認推奨） |
```

### #8 synthesis-stale 判定ロジック

**入力**: 集約マップから `type: synthesis` のページ群と、その `sources` / `links` 先ページの `updated`
（Phase 2a 集約マップに `sources` / `links` を含めて再利用・**追加 Read 0 回**）。

**走査アルゴリズム**:

1. 集約マップから `type: synthesis` のページを抽出。
2. 各 synthesis の `sources:` と `links:` を引いて、対応する引用元ページの `updated` を集約マップから取得。
3. 引用元のうち 1 件でも `引用元.updated > synthesis.updated` なら「再生成候補」。差分日数を detail に表示。
4. `sources:` のうちボールト内に該当ページが見つからない（リネーム済み等）は #7 index 同期検査の領域なのでスキップ。
5. synthesis の `sources:` が空の場合は Phase 2a #4 既存エラー扱いに委ね、#8 はスキップ。

**severity**: 警告。

**再生成提案**: `detail` に **`再生成提案: /llm-wiki synthesize <slug>`** を併記して、ユーザーが対話セッションで
手動再実行できる形にする。`/llm-wiki synthesize` を lint **内部から呼び出さない**（auto-apply 化されると
不変条件「黙って上書きしない」と整合しなくなる）。

**出力詳細フォーマット例**:
```
| wiki/syntheses/cheatsheet.md | synthesis-stale | 警告 | 引用元 3/5 が synthesis.updated=2026-04-01 より新しい（最新: 2026-05-20）。再生成提案: /llm-wiki synthesize cheatsheet |
```

### #10 three-way 判定ロジック

**入力**: 本リポジトリ側 3 文書を 1 回ずつ Read（CWD 起点・**追加 Read 3 回**）:
- `CLAUDE.md`
- `.claude/skills/llm-wiki/SKILL.md`
- `.claude/skills/llm-wiki/references/schema.md`

**走査アルゴリズム** — **構造化抽出**に限定（全文自然言語比較は持ち込まない）:

1. **フィールド名抽出**: schema.md §2 のフロントマター必須フィールド名（`type` / `title` / `tier` /
   `claude_code_version` / `updated` / `stale` / `confidence` / `sources` / `links`）を列挙し、
   SKILL.md / CLAUDE.md のいずれかに「再記述」が存在しないかを Grep で検出。schema 単一所有規約
   （schema.md 冒頭・§7 責務境界）に照らし、再記述があれば「規約違反: フィールド定義の再記述
   （schema.md 単一所有違反）」として警告。
2. **モード見出し抽出**: SKILL.md の `## モード A:` / `## モード B:` / `## モード C:` / `## モード D:` /
   `## モード L:` をリストアップし、CLAUDE.md 内で言及されているモード名と整合するか確認。CLAUDE.md
   に SKILL.md に存在しないモード名（旧名残のモード）があれば「規約違反: モード参照不整合」として警告。
3. **ステップ番号抽出**: SKILL.md の `ステップ0` / `ステップ0.5` / `ステップ1` 等のステップ参照を
   CLAUDE.md / schema.md から Grep し、SKILL.md に存在しないステップ番号への参照を検出
   （リファクタ後の取り残し検出）。
4. **規約フレーズ抽出**: 以下の固定フレーズリストを 3 文書から Grep:
   - 「黙って上書きしない」
   - 「raw は不変」 / 「不変スナップショット」
   - 「必ず引用」
   - 「Tier A」 / 「Tier B」
   - 「schema_version」
   - 「claude_code_version」
   - 各フレーズの出現コンテキストが 3 文書で意味的に整合しているかは LLM が読み比べる
     （ここだけ自然言語判断を許容するが、フレーズ近傍 ±3 行のみ）。
5. **CLAUDE.md 優先**: 規約フレーズで矛盾が見つかった場合、`CLAUDE.md > SKILL.md / schema.md`（schema.md §7）
   の優先順を detail に明記し、修正方向は CLAUDE.md を真とする旨を案内する。

**severity**: 警告。

**出力詳細フォーマット例**:
```
| CLAUDE.md vs schema.md | three-way | 警告 | "黙って上書きしない" の対象範囲が食い違う: CLAUDE.md は「すべての書き込み」、schema.md §3 は「ページ本文の主張のみ」と読める（CLAUDE.md 優先で要すり合わせ） |
```

### #11 version-resolve 判定ロジック

**入力**:
- `Bash("grep -l '^## 矛盾' wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md")`
  でヒットしたページ群（`## 矛盾` 保持ページのみ）。
- 各ヒットページの `## 矛盾` セクションを限定 Read（セクション開始行から `limit=80` 程度）。
- 集約マップから各ページの `claude_code_version` / `tier` / `updated`。
- `current-baseline.md` の `claude_code_version`（Phase 2a で 1 回 Read 済み）。

#### `## 矛盾` セクションのパース仕様

セクション内の両論行は以下の形式を期待する（実機例 `wiki/concepts/background-agent-operation.md:35-38` から確定）:

```
## 矛盾
- **<ラベル>（<version>・Tier <X>）**: <主張本文>（出典: raw/<種別>/<取得日>-<slug>.md）。
- **<ラベル>（<version>・Tier <X>）**: <主張本文>（出典: raw/<種別>/<取得日>-<slug>.md）。
- 評価: <人間記述>。
```

- `<ラベル>` は `本ページ` または `[[<slug>]]`。`本ページ` の場合は所属ページ自身の集約マップを使う。
- `<version>` は semver（`2.1.143` 等）または `unknown`。`unknown` を含む両論は対象外（人間判断へ）。
- `<X>` は `A` または `B`。
- 「評価:」行は機械パース対象外（人間記述として保持）。
- 既存ページが上記形式を満たさない場合（フリーフォーム両論など）、その候補は対象外として detail に
  「パース失敗: 両論行が `- **<ラベル>（<version>・Tier <X>）**: ...` 形式でない」を表示する
  （既存ページに後付け構造制約を課さない＝不変条件「黙って上書きしない」と整合）。

#### 判定ロジック

`## 矛盾` の両側を `claude_code_version` / `tier` / `updated` で比較し、決着＝**削除/統合ではなく
注記追加＋severity 降格**（不変条件3「黙って上書きしない」・raw 不変より）:

1. 上記パース仕様で両論行を抽出。`<ラベル>` `<version>` `<tier>` `<出典 raw>` を取得。
2. `<ラベル>` が `[[<slug>]]` なら集約マップの該当ページから `updated` を補完。`本ページ` なら所属ページ自身から取得。
3. 判定:
   - `newer.<version> > older.<version>` **かつ** `newer.<tier> ≥ older.<tier>`
     （特に 新=Tier A / 旧=Tier B）→ **時系列 supersession 候補（情報）**。
     両論セクションは履歴として保持したまま「決着」注記を**追記提案**。
   - 同一バージョン矛盾、または 旧=Tier A / 新=Tier B の逆向き → **要対応**（人間判断必須・auto-apply 不可）。
4. `current-baseline.md` の `claude_code_version` を「現在の正」アンカーとして突合し、新側が baseline と
   一致する場合は detail に「baseline=v_baseline と一致」を併記する（severity 自体は変えない＝表示情報のみ）。
   **#3 陳腐化（バージョン乖離）と連動**。
5. version 比較は Phase 2a #3 と同じ semver 比較ロジック（`split(".")` で major/minor/patch）を流用する。
6. いずれも **承認制（AskUserQuestion）**。auto-apply・統合・削除はしない。

#### #11 決着注記の正規記法

承認された候補に対して `## 矛盾` セクションの末尾に **1 行**を追記する:

```
**決着（YYYY-MM-DD）**: 時系列解決（v_old→v_new、Tier X が新）
```

- **追記位置**: `## 矛盾` セクションの末尾。次の `##` 見出しがあればその直前、無ければファイル末尾。
- **書き込みは AskUserQuestion 承認制で、auto-apply は禁止**。
- **二重追記回避**: 既に「**決着（**」で始まる行が `## 矛盾` セクション内に存在する場合はスキップする。
- **フロントマターは触らない**（`stale` / `confidence` の変更・両論削除・統合は一切行わない）。
- 本記法は `references/schema.md` には書かない（schema は ingest/synthesize が守るべきデータ規約の正で、
  決着注記は lint の出力フォーマットであるため）。`schema.md` §7 責務境界に従い、本ファイル
  （`references/lint-rules.md`）が正となる。

#### #11 決着適用時の log.md 追記フォーマット

承認による決着適用が発生したら `wiki/log.md` の lint 結果サマリ直下に **1 行ずつ**追記する:

```
- 決着適用: `<slug>` (v_old→v_new, Tier X→Tier Y, YYYY-MM-DD)
```

複数候補を承認した場合は候補数ぶん 1 行ずつ追記する。本ファイルが log.md 決着行フォーマットの正
（`SKILL.md` モード L は本節を参照）。

**出力詳細フォーマット例**（候補検出時・対話レポート）:
```
| wiki/concepts/background-agent-operation.md | version-resolve | 情報 | ## 矛盾: v2.0.5 (Tier B) → v2.1.143 (Tier A) — 時系列 supersession 候補（baseline=2.1.143 と一致）。決着適用は AskUserQuestion で確認 |
```

---

## エラーハンドリング（Phase 2a / 2b 共通）

### Phase 2a 共通

| 事象 | 扱い |
|------|------|
| `--check=<csv>` に未知のキーが含まれる | エラーメッセージで中断（許容キー一覧 `orphan|updated|version|stale|confidence|index|baseline|cross-topic|synthesis-stale|three-way|version-resolve` を案内） |
| フロントマター YAML パース失敗 | 当該ページを「要対応: フロントマター不正」として個別レポートし他検査は継続 |
| `sources:` が空のページ | 「要対応: sources 空（schema.md §2 違反）」として表示（既存の不変条件違反検知） |
| `current-baseline.md` 不在 | #3/#9 をスキップし「要対応: baseline 不在。`/llm-wiki init` を再実行」を表示 |
| ボールトに未コミット変更あり | SKILL.md ステップ 0.5 と同様に AskUserQuestion で続行可否 |

### Phase 2b 追加

| 事象 | 扱い |
|------|------|
| `## 矛盾` セクションを保持するページが Bash grep で抽出されたが Read 時に該当行が見当たらない | 「要対応: ## 矛盾 セクション構造不正」として個別レポートし他検査継続 |
| #10 で本リポジトリ側 3 文書のいずれかが Read 不能（パス変更等） | #10 をスキップし「要対応: <ファイル> 不在/Read 不能。SKILL.md と schema.md のパスを確認」を表示 |
| #11 候補ページが Read できない（権限等） | 該当候補のみスキップ、他候補は続行 |
| AskUserQuestion で「いずれも適用しない」（0 件選択） | 追記なし・コミットなしで終了。候補は対話レポートに残る |
| #11 候補が 5 件超 | 上位 4 件のみ承認確認、残りは次回 lint で再検出。severity 高い順（要対応 > 情報）→ version 差大きい順（major 桁差 > minor 桁差）でソート |
| `## 矛盾` 末尾に既に「**決着（YYYY-MM-DD）**: 」行が存在 | 二重追記を回避してスキップ（同候補がもう一度承認されても二重に書かない） |
| #8 で synthesis の `sources:` が空 | Phase 2a `sources:` 空エラー扱いに委ね、#8 はスキップ |

---

## 動作確認用 fixture（22 ケース・人手再現カタログ）

実機 vault に fixture を作らない。各検査につき「検出されるべき」「検出されないべき」最小ケースをフロントマター例で記述し、必要時にユーザーが既存ページを一時編集 / 該当条件を満たす個体を特定して再現する。**前提日: 2026-05-23**。

### #1 orphan

- 検出: 任意ページ `wiki/practices/lonely.md`（`links: []`、本文に [[wikilink]] なし、index.md に行なし、他ページからも参照なし）→ **警告**
- 非検出: `wiki/sources/foo.md`（少なくとも 1 ページの `links:` に `foo` が含まれる、または index.md に `[[foo]]` 行あり）→ 検出されない

### #2 updated

- 検出: `updated: 2026-04-01`（52 日経過）→ **警告**
- 非検出: `updated: 2026-05-10`（13 日経過）→ 検出されない

### #3 version

- 検出（要対応）: ページ `claude_code_version: 1.5.0` / baseline `2.1.143`（major 桁差）→ **要対応**
- 検出（警告）: ページ `claude_code_version: 2.0.5` / baseline `2.1.143`（minor 桁差）→ **警告**
- 非検出: ページ `claude_code_version: unknown`、または `2.1.143` と完全一致 → 検出されない

### #4 stale

- 検出: フロントマターに `stale: true` → **要対応**
- 非検出: `stale: false` → 検出されない

### #6 confidence

- 検出: `confidence: 0.5` → **情報**
- 非検出: `confidence: 0.7` または `0.9` → 検出されない

### #7 index

- 検出（要対応）: 実ページ `wiki/practices/new-page.md` が存在し index.md に行が無い → **要対応**
- 検出（警告）: index.md に `[[ghost]]` 行があるが `wiki/*/ghost.md` が存在しない → **警告**
- 非検出: 実ページと index.md の `[[slug]]` 集合が一致 → 検出されない

### #9 baseline

- 検出（要対応）: `current-baseline.md` の `updated: 2026-02-15`（97 日経過）→ **要対応**
- 検出（警告）: `updated: 2026-03-15`（69 日経過）→ **警告**
- 非検出: `updated: 2026-05-10`（13 日経過）→ 検出されない

### #5 cross-topic

- 検出: index.md にサマリ行ペア `[[skill-description]]: description は短く保つ` と `[[skill-trigger-tips]]: description に多くの文脈を入れる` → **情報**（否定/肯定対応で同じキーワード `description` に反対方向の主張）
- 非検出: 同一トピック（`description`）で方向が一致するサマリ群（例: `[[skill-description]]: description は短く` と `[[skill-naming]]: 名前は短く`）→ 検出されない

### #8 synthesis-stale

- 検出: `wiki/syntheses/cheatsheet.md` の `synthesis.updated: 2026-04-01` / 引用元の最新 `updated: 2026-05-20` → **警告**（再生成提案 `/llm-wiki synthesize cheatsheet` を併記）
- 非検出: `synthesis.updated >= max(引用元.updated)` → 検出されない

### #10 three-way

- 検出: `schema.md` §2 に `claude_code_version` 必須記述があるが `SKILL.md` が `cc_version` と誤記（モード B の引数案内等） → **警告**（規約違反: フィールド名不一致）
- 非検出: 3 文書で `claude_code_version` 用語が一致 → 検出されない

### #11 version-resolve

- 検出（情報）: `wiki/concepts/background-agent-operation.md` の `## 矛盾` に
  `- **本ページ（2.0.5・Tier B）**: ...` と `- **[[release-notes]]（2.1.143・Tier A）**: ...`
  の両論 → **情報**（時系列 supersession 候補、`baseline=2.1.143` と一致なら detail に併記）
- 検出（要対応）: 同一バージョン両論（`2.1.143 Tier A` ⇄ `2.1.143 Tier B` 等）、または逆向き（旧=Tier A / 新=Tier B）
  → **要対応**（人間判断必須・auto-apply 不可）
- 非検出: `## 矛盾` セクション無し → 対象外（検出されない）
- 非検出: `## 矛盾` セクションあるが両論行が `- **<ラベル>（<version>・Tier <X>）**: ...` 形式でない
  → パース失敗として detail 表示するが「決着候補」としては検出されない

受け入れ条件の基準は「11 検査 × 2 ケース＝22 ケース」相当。上記カタログは:
- Phase 2a: #3 / #7 / #9 で severity 別の境界値を分解しており、計 17 ケース。
- Phase 2b: 4 検査 × 検出/非検出 + #11 要対応ケース 1 = 9 ケース。
- 合計 **26 ケース**（22 を上回る粒度）。Phase 2b 完了時に対話レポートで全件が期待通り分類されることを 1 回確認する
  （実機状態で再現しないケースは fixture カタログでスペック検証済みとして扱う）。

---

## MVP（Phase 1）での代替

Phase 2a 実装前は lint を稼働させず、ユーザーは `/llm-wiki query` / `synthesize` 実行時の
「⚠️ Wiki 外」明示と ingest 提案を通じて、不足・鮮度を手動で把握していた。Phase 2b 実装後は意味解釈系 4 検査も並行運用。
