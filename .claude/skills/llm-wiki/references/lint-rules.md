# llm-wiki lint 規則（Phase 2 予約・MVP は枠のみ）

> **ステータス: Phase 2 で実装。MVP（Phase 1）では稼働ロジックを持たない。**
> `/llm-wiki lint` は MVP では「Phase 2・未実装」と案内して停止する（SKILL.md 参照）。
> 本ファイルは Phase 2 で実装する検査項目の一覧を**枠として**記載するに留める。
> フロントマター定義・ページタイプは `references/schema.md` を参照（再記述しない）。

## Phase 2 で実装する検査項目（枠）

| # | 検査 | 概要 | 判定材料（予定） |
|---|------|------|------------------|
| 1 | 孤立ページ | どこからも [[wikilink]]・`links:` されないページを検出 | wiki 全ページの links 突合 |
| 2 | 陳腐化（更新日） | `updated` が 30 日超のページを警告 | フロントマター `updated` |
| 3 | 陳腐化（バージョン乖離） | `claude_code_version` が `current-baseline.md` と乖離 | baseline 比較 |
| 4 | `stale:true` 監査 | `stale:true` のページを一覧化し対応を促す | フロントマター `stale` |
| 5 | 横断的矛盾スキャン（決定 Z 二段目） | index.md の主張サマリを走査し別トピック間の矛盾を検出 | index.md 主張サマリ |
| 6 | 信頼度監査 | `confidence` が低いページの一覧 | フロントマター `confidence` |
| 7 | index 同期 | index.md のサマリと実ページの不整合・欠落を検出 | index.md vs wiki/ |
| 8 | synthesis 再生成要否 | 引用元更新後に未再生成の synthesis を検出 | synthesis の sources/links 更新日 |
| 9 | baseline 鮮度 | `current-baseline.md` 自体の最終更新からの経過日数を監査 | current-baseline.md |
| 10 | 3 面相互矛盾（決定 ウ） | CLAUDE.md / SKILL.md / schema.md の相互矛盾を検査（齟齬時 CLAUDE.md 優先） | 3 文書突合 |
| 11 | バージョン軸の矛盾決着（決定 Z で検出済みの両論併記の時系列解決） | 既存 `## 矛盾` セクションを走査し、両側の `claude_code_version` 差に起因する時系列差を承認制で「決着」注記＋severity 降格する。新規検出ではなく既出矛盾の解決 | 各ページ `## 矛盾` 両側の `claude_code_version` / `tier` / `updated`、`current-baseline.md` の `claude_code_version` |

## #5 と #11 の切り分け（検出 vs 決着）

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

### #11 決着判定ロジック（枠）

`## 矛盾` の両側を `claude_code_version` / `tier` で比較し、決着＝**削除/統合ではなく
注記追加＋severity 降格**（不変条件3「黙って上書きしない」・raw 不変より）:

- `newer.claude_code_version > older.claude_code_version` **かつ** `newer.tier ≥ older.tier`
  （特に 新=Tier A / 旧=Tier B）→ 時系列 supersession 候補。両論セクションは履歴として
  保持したまま `決着: 時系列解決（v_old→v_new、Tier X が新）` を**追記提案**。
- 同一バージョン矛盾、または 旧=Tier A / 新=Tier B の逆向き → 自動決着しない。人間判断へ。
- いずれも **承認制（AskUserQuestion）**。auto-apply・統合・削除はしない。
- `current-baseline.md` の `claude_code_version` を「現在の正」アンカーとして突合し、
  **#3 陳腐化（バージョン乖離）と連動**させる（Phase 2 で独立検査が乱立しないため）。

## 出力（Phase 2 予定）

- 健全性レポートを生成し、ボールト `log.md` に結果サマリを追記する。
- 重大度（要対応 / 警告 / 情報）を付与する。
- severity 規約（既定値は Phase 2 実装時に確定。Phase 2 lint 全体の severity ポリシーが
  未確立のため、ここだけ先に固定すると齟齬源になる）:
  - #11 時系列 supersession 候補（新が version も tier も上位）→ 人手不要寄り（情報/警告レンジ）。
  - #11 逆向き（旧=Tier A / 新=Tier B）・同一バージョン矛盾 → 要対応（人間判断必須）。

## MVP での代替

MVP では lint を稼働させない。ユーザーは `/llm-wiki query` / `synthesize` 実行時に
Wiki 外補完の明示と ingest 提案を通じて、不足・鮮度を手動で把握する。
