# llm-wiki ページテンプレート（本文スケルトン）

> フロントマターのフィールド定義は **`references/schema.md` §2 が唯一の正**です。
> 本ファイルは**再記述せず**、各テンプレ冒頭に「schema.md §2 に従い充填」と示すに留めます。
> 引用記法・[[wikilink]] 規約・命名規約も `references/schema.md` §3 を参照。
>
> MVP（Phase 1）テンプレートは `source / concept / entity / comparison / synthesis` の 5 タイプ。
> `practice` / `feature` は Phase 2 予約（末尾に節見出しのみ）。

共通ルール:

- フロントマターは `references/schema.md` §2 の必須フィールドを全て埋める（値の保持は MVP から）。
- すべての主張は raw を引用する（本文インライン `（出典: raw/...）` ＋ フロントマター `sources:`）。
- 既存ページと矛盾する新主張は **黙って上書きせず**、`## 矛盾` セクションに両論併記する（定位置は各テンプレ末尾手前に固定）。
- Wiki 外で補完した記述は `⚠️ Wiki 外（Web 検索）` と明示する。

---

## source

```markdown
---
# schema.md §2 に従い充填（type: source）
---

# {タイトル}

## 概要
{この raw ソースが何を述べているかの 2〜4 行要約}

## 要点
- {主張 1}（出典: raw/...）
- {主張 2}（出典: raw/...）

## 関連
- [[related-concept]] — {関係の一言説明}

## 矛盾
{同一トピックの既存ページと矛盾する主張があればここに両論併記。無ければ「現時点で矛盾なし」}

## メモ
{取り込み時の補足・未解決の疑問}
```

---

## concept

```markdown
---
# schema.md §2 に従い充填（type: concept）
---

# {概念名}

## 定義
{1〜3 行で概念を定義}

## なぜ重要か
{この概念が Claude Code 運用でなぜ効くか}（出典: raw/...）

## 適用例
- {具体例 1}（出典: raw/...）

## 関連概念
- [[related-concept]]

## 矛盾
{矛盾があれば両論併記。無ければ「現時点で矛盾なし」}
```

---

## entity

```markdown
---
# schema.md §2 に従い充填（type: entity）
---

# {固有名}

> Claude Code の機能以外の固有物（外部ツール/人物/組織/ライブラリ等）。
> Claude Code 自体の機能は Phase 2 の feature タイプへ。

## 概要
{何者か/何かを 2〜3 行}（出典: raw/...）

## Claude Code との関係
{この entity が Claude Code 運用にどう絡むか}

## 関連
- [[related-page]]

## 矛盾
{矛盾があれば両論併記。無ければ「現時点で矛盾なし」}
```

---

## comparison

```markdown
---
# schema.md §2 に従い充填（type: comparison）
---

# {A} vs {B}（{比較軸}）

## 比較対象
- [[option-a]]
- [[option-b]]

## 比較表
| 観点 | {A} | {B} |
|------|-----|-----|
| {観点1} | … | … |

（各セルの根拠: 出典: raw/...）

## 推奨
{どの状況でどちらを採るか}（出典: raw/...）

## 矛盾
{矛盾があれば両論併記。無ければ「現時点で矛盾なし」}
```

---

## synthesis

派生成果物（チートシート / Tips 集等）。`wiki/syntheses/` に配置。再生成・Phase 2 lint の対象。

```markdown
---
# schema.md §2 に従い充填（type: synthesis）
---

# {テーマ}（synthesis）

> 生成日: {YYYY-MM-DD} / 再生成時はこの行を更新
> このページは Wiki 横断のテーマ統合であり、すべての項目は元ページ/raw を引用する。

## 概要
{このチートシート/Tips 集が何をカバーするか}

## 本文
### {小テーマ 1}
- {項目}（出典: [[source-page]] / raw/...）
- {項目}　⚠️ Wiki 外（Web 検索）— {補完理由と検索元}

## 引用元一覧
- [[page-a]]、[[page-b]] …（統合した Wiki ページ）
- raw/... （直接引用した raw）

## 未カバー / ingest 提案
- {Wiki に不足していてカバーしきれなかった点と、推奨する `/llm-wiki ingest <url>`}
```

---

## practice（⏳ Phase 2 予約）

Phase 2 で定義する。MVP では生成しない（試した実践とその効果を記録するタイプ）。

## feature（⏳ Phase 2 予約）

Phase 2 で定義する。MVP では生成しない（Claude Code 機能ごとの最新仕様・バージョン追従対象）。
