# llm-wiki lint 規則

> Phase 2a で機械判定 7 検査（#1/#2/#3/#4/#6/#7/#9）を実装。
> Phase 2b（意味解釈 4 検査・承認制 = #5/#8/#10/#11）は枠のみ保持し本フェーズで変更しない。
> フロントマター定義・ページタイプは `references/schema.md` を参照（再記述しない）。

## 検査項目（全 11）

| # | 検査 | 概要 | 判定材料 | Phase |
|---|------|------|---------|:-----:|
| 1 | 孤立ページ | どこからも [[wikilink]]・`links:` されないページを検出 | wiki 全ページの links 突合 | 2a ✅ |
| 2 | 陳腐化（更新日） | `updated` が 30 日超のページを警告 | フロントマター `updated` | 2a ✅ |
| 3 | 陳腐化（バージョン乖離） | `claude_code_version` が `current-baseline.md` と乖離 | baseline 比較 | 2a ✅ |
| 4 | `stale:true` 監査 | `stale:true` のページを一覧化し対応を促す | フロントマター `stale` | 2a ✅ |
| 5 | 横断的矛盾スキャン（決定 Z 二段目） | index.md の主張サマリを走査し別トピック間の矛盾を検出 | index.md 主張サマリ | 2b |
| 6 | 信頼度監査 | `confidence` が低いページの一覧 | フロントマター `confidence` | 2a ✅ |
| 7 | index 同期 | index.md のサマリと実ページの不整合・欠落を検出 | index.md vs wiki/ | 2a ✅ |
| 8 | synthesis 再生成要否 | 引用元更新後に未再生成の synthesis を検出 | synthesis の sources/links 更新日 | 2b |
| 9 | baseline 鮮度 | `current-baseline.md` 自体の最終更新からの経過日数を監査 | current-baseline.md | 2a ✅ |
| 10 | 3 面相互矛盾（決定 ウ） | CLAUDE.md / SKILL.md / schema.md の相互矛盾を検査（齟齬時 CLAUDE.md 優先） | 3 文書突合 | 2b |
| 11 | バージョン軸の矛盾決着 | 既存 `## 矛盾` セクションを走査し、両側の `claude_code_version` 差に起因する時系列差を承認制で「決着」注記＋severity 降格 | 各ページ `## 矛盾` 両側の `claude_code_version` / `tier` / `updated`、`current-baseline.md` の `claude_code_version` | 2b |

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

## 走査戦略（Phase 2a）

コンテキスト圧迫を回避するため、本文 Read は行わない。

1. **Glob**: `wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md` で wiki 全ページ列挙（1 回呼び出し）。
2. **フロントマター抽出**: 各ページを `Read(offset=0, limit=50)` でフロントマター先頭部分のみ取得（フロントマターは通常 15 行未満。50 行で十分カバー）。
3. **index.md**: `Read("wiki/index.md")` を 1 回。
4. **current-baseline.md**: `Read("wiki/current-baseline.md")` を 1 回。
5. 上記 4 つのデータをメモリ上の集約マップに保持し、7 検査をすべて差分計算で完結させる。**追加 Read 不要**。
6. 7 検査のうち #1 orphan のみ、index.md 本文内の `[[wikilink]]` 出現を確認するため index.md の本文走査が必要（既に 1 回 Read 済みのデータを使う）。

100 ページ規模でも Read 呼び出しは合計約 102 回で完結する（ページ 100 + index 1 + baseline 1）。

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

## #5 と #11 の切り分け（検出 vs 決着・Phase 2b 設計用）

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

### #11 決着判定ロジック（枠・Phase 2b 実装）

`## 矛盾` の両側を `claude_code_version` / `tier` で比較し、決着＝**削除/統合ではなく
注記追加＋severity 降格**（不変条件3「黙って上書きしない」・raw 不変より）:

- `newer.claude_code_version > older.claude_code_version` **かつ** `newer.tier ≥ older.tier`
  （特に 新=Tier A / 旧=Tier B）→ 時系列 supersession 候補。両論セクションは履歴として
  保持したまま `決着: 時系列解決（v_old→v_new、Tier X が新）` を**追記提案**。
- 同一バージョン矛盾、または 旧=Tier A / 新=Tier B の逆向き → 自動決着しない。人間判断へ。
- いずれも **承認制（AskUserQuestion）**。auto-apply・統合・削除はしない。
- `current-baseline.md` の `claude_code_version` を「現在の正」アンカーとして突合し、
  **#3 陳腐化（バージョン乖離）と連動**させる（Phase 2 で独立検査が乱立しないため）。

### Phase 2b severity 規約（枠）

- #11 時系列 supersession 候補（新が version も tier も上位）→ 人手不要寄り（情報/警告レンジ）。
- #11 逆向き（旧=Tier A / 新=Tier B）・同一バージョン矛盾 → 要対応（人間判断必須）。

---

## エラーハンドリング（Phase 2a）

| 事象 | 扱い |
|------|------|
| `--check=<csv>` に未知のキーが含まれる | エラーメッセージで中断（許容キー一覧 `orphan|updated|version|stale|confidence|index|baseline` を案内） |
| フロントマター YAML パース失敗 | 当該ページを「要対応: フロントマター不正」として個別レポートし他検査は継続 |
| `sources:` が空のページ | 「要対応: sources 空（schema.md §2 違反）」として表示（既存の不変条件違反検知） |
| `current-baseline.md` 不在 | #3/#9 をスキップし「要対応: baseline 不在。`/llm-wiki init` を再実行」を表示 |
| ボールトに未コミット変更あり | SKILL.md ステップ 0.5 と同様に AskUserQuestion で続行可否 |

---

## 動作確認用 fixture（14 ケース・人手再現カタログ）

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

14 ケース（#1×2 + #2×2 + #3×3 + #4×2 + #6×2 + #7×3 + #9×3 = 17 を簡約し 7 検査 × 2 ケースを基準）を Phase 2a 完了時に対話レポートで全件が期待通り分類されることを 1 回確認する。

---

## MVP（Phase 1）での代替

Phase 2a 実装前は lint を稼働させず、ユーザーは `/llm-wiki query` / `synthesize` 実行時の
「⚠️ Wiki 外」明示と ingest 提案を通じて、不足・鮮度を手動で把握していた。
