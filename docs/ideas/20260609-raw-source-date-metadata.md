# raw ソースの元日付メタ（published_at / last_modified / date_source）

> 作成日: 2026-06-09
> ステータス: implemented
> 実装日: 2026-06-10
> ステアリングディレクトリ: `.steering/20260610-raw-source-date-metadata/`
> 優先度: P1

## 概要

raw スナップショットに **元ドキュメント自身の日付**（公開日・最終更新日とその出所）を記録し、一括取り込み時の鮮度判別を可能にするとともに、矛盾解決・lint 陳腐化判定・synthesis・表示の **機械可読な鮮度シグナル** として活用する。

## 背景

### 現状の課題

- raw フロントマターは `fetched_at`（ファイル名の取得日 `YYYY-MM-DD`）/ `source_url` / `fetched_via` を持つが、**元文書がいつ書かれた/更新されたか**を持たない（`references/schema.md` §3）。
- 複数ソースを一括取り込みすると、すべて同じ「取得日」になり**時系列が潰れる**。古い記事も今朝のリリースノートも見分けがつかない。
- 鮮度を**機械判断に使えない**。矛盾解決の「新しい方を採る」決着、陳腐化検知、synthesis の引用鮮度がいずれも取得日 or コンパイル日（`updated`）止まりで、ソース自体の新旧を表現できない。

### 解決したいこと

- 一括取り込み時に「このソースは古い/新しい」が一目で分かる（表示・並べ替え＝目的 A）。
- 元日付を機械シグナルとして矛盾解決・lint・synthesis に食わせる（目的 B）。
- 取れない日付は無理に代替せず `unknown` として正直に扱い、出所の信頼度も残す。

## 解決策

### アプローチ

raw フロントマターに 3 フィールドを追加し、**ベストエフォートで取得・取れなければ `unknown`・代替日付は入れない**。意味論は「**最終更新日を優先、無ければ公開日**」だが、両者を別フィールドで保持し、畳み込みは表示・判断の時点で行う。

```yaml
# raw フロントマター（追加分）
published_at: 2026-03-12        # 公開日。YYYY-MM-DD または unknown
last_modified: 2026-05-30       # 最終更新日。YYYY-MM-DD または unknown
date_source: feed-pubdate       # 日付の出所（信頼度判断用）。※出所の持ち方（単一 vs per-date）は未決事項参照
```

### 設計方針

1. **2 フィールド別々保持**: `published_at` と `last_modified` を分けて持つ。「古い公開だが最近更新＝まだ生きている記事」を区別できる。表示・鮮度判断では `last_modified ?? published_at` を「鮮度日」として畳む。
2. **ベストエフォート＋ unknown 許容**: 取れなければ `unknown`。取得日やコンパイル日で**代替しない**（偽の鮮度を作らない）。
3. **`date_source` で出所を記録**: 語彙 `gh-commit | feed-pubdate | sitemap-lastmod | html-meta | manual | unknown`。`gh-commit`/`feed-pubdate`/`sitemap-lastmod` は信頼、`html-meta` は不確実、として後段の信頼度判断・再検証対象の絞り込みに使う。
4. **wiki ページは元日付を集約しない**: wiki ページは自分の作成日・更新日（コンパイル日）と `sources:` のみ持つ。元日付の正本は raw 側に置き、辿れば分かる。複数 raw を束ねた時の集約値同期問題を回避する。（なお機能 3/b4 で index/overview に出す代表鮮度日は、index.md が ingest 毎に主張サマリを再コンパイルする既存メンテに乗るだけで、per-page frontmatter のような**新規の同期負担を生まない**点で区別される。この区別が妥当かは未決事項参照）
5. **Tier A 優先は不変**: 日付で公式（Tier A）の権威を覆さない。日付は**同 Tier 内の決着**と**補助注記**に使う。日付が `unknown` の時は日付軸を使わず従来の Tier / version 軸で判断する。
6. **取得経路は段階化**: 確実に取れる経路から実装し、不確実・前提整備が要る経路は後続にする。

### 代替案と比較

| 案 | メリット | デメリット | 採否 |
|----|---------|-----------|------|
| 1 フィールド（鮮度日のみ）に畳む | 軽い・unknown 率が下がる | 公開 vs 更新の区別が消え (B) の判断材料が減る | 不採用 |
| 2 フィールド別々保持 | 「公開は古いが更新は新しい」を区別可 | 埋めるコスト・unknown 率増 | **採用** |
| wiki ページに最新 last_modified を集約 | 横断処理が wiki だけで完結 | source 更新のたび集約値がズレる同期地獄 | 不採用 |
| 取れない日付を取得日で代替 | unknown が消える | 偽の鮮度を作り (B) を汚染 | 不採用 |

## 実装する機能

### ロードマップ（段階的開発）

| Phase | 機能 | 概要 |
|-------|------|------|
| 1 | 確実 3 経路＋ WebFetch ベストエフォート | gh commit date / feed pubDate / sitemap lastmod ＋ WebFetch（`article:modified_time` / JSON-LD `dateModified`）（今回のスコープ中核） |
| 1 | raw メタ拡張・(B) 機械シグナル統合・表示露出 | 下記機能 1〜4（今回のスコープ） |
| 1 | 遡及補完 | 既存 raw を取れる範囲で後追い補完（下記機能 5） |
| 2 | Medium 経路 | Medium 取り込み**開始前**に scrape 出力の日付有無を確認 → 無ければ minitools 側を先に整備してから解禁 |

### 機能1: raw フロントマター拡張

`published_at` / `last_modified` / `date_source` の 3 フィールドを追加。schema の co-evolution で `schema_version` を次 minor に上げ、§3 raw フロントマター仕様と `date_source` 語彙表を追記。

### 機能2: 取得経路ごとの日付抽出（段階化）

| 経路（mode / fetched_via） | 日付の在り処 | `date_source` | Phase |
|---|---|---|---|
| 公式 GitHub（gh api） | commit の `committer.date` / CHANGELOG エントリ日付 | `gh-commit` | 1 |
| RSS/Atom フィード（mode I） | 項目の `pubDate` / `updated` | `feed-pubdate` | 1 |
| blog sitemap / docs sitemap（mode I / 公式 docs） | sitemap の `lastmod` | `sitemap-lastmod` | 1 |
| 任意 URL（WebFetch） | `article:modified_time` / JSON-LD `dateModified`（ベストエフォート） | `html-meta` | 1 |
| Medium（minitools scrape） | 記事メタの published/updated（**出力に含まれるか要確認**） | （未定） | 2 |
| 取得不能 | — | `unknown` | 全 Phase |

### 機能3: 表示・並べ替えへの露出（目的 A / b4）

index.md / overview.md に各ページの代表「鮮度日」を出して人が眺められるようにする。機械処理（機能 4）も raw 総なめを避けるためこの代表値を再利用する。

### 機能4: (B) 機械シグナル統合

- **b1 矛盾解決の決着補助**: 矛盾の判定・決着時に `last_modified` の新旧を判断材料に足す。**ただし Tier A 優先は維持**し、日付は同 Tier 内の決着＋補助注記に使う。`unknown` の時は日付軸を使わない。Phase 2b #11（バージョン軸決着）と並ぶ第 2 の決着軸として整理する。
- **b2 lint 陳腐化判定**: `last_modified` が著しく古いソースに stale を提案する検査を追加（現状の `updated`＝コンパイル日 /`claude_code_version` ベースに「ソース自体が古い」軸を足す）。
- **b3 synthesis の鮮度**: チートシート/Tips 生成時、古いソースに注記、または新しい順に引用。

### 機能5: 遡及補完

既存の取り込み済み raw に対し、sitemap / feed / gh から取れる範囲で後追い補完する。取れない分は `unknown` のまま。起動形態（専用ワンショット vs 既存 refresh/lint/ingest への相乗り）は実装計画で決める（anti-duplication 方針 D7 に従い既存モード相乗りを優先検討）。

## 受け入れ条件

> **Phase 5 verified（2026-06-12・PR #32 `1d177fd`→main `708db73`）**。詳細な検証結果と判定の canonical tracker は `.steering/20260610-raw-source-date-metadata/requirements.md`（23 項目 PASS）。本節は idea 原案ベースのため一部表記を plan-feature 確定仕様に追従済: **単一 `date_source` → per-date `published_at_source`/`last_modified_source`**、**出所 enum に `html-body` を追加（7 値）**。Medium 日付（Phase 2 ゲート）のみ未達で据え置き。

### raw メタ拡張
- [x] raw フロントマターに `published_at` / `last_modified` ＋ per-date 出所（`published_at_source` / `last_modified_source`）を記録できる
- [x] 取得できない日付は `unknown` として記録され、取得日・コンパイル日で代替されない
- [x] 出所が定義語彙（`gh-commit | feed-pubdate | sitemap-lastmod | html-meta | html-body | manual | unknown`）のいずれかである
- [x] schema_version が co-evolution で更新され、§3 と CLAUDE.md / development-guidelines に反映される（v1.11.0）

### 取得経路（Phase 1）
- [x] gh api 経路で commit 日付を `gh-commit` として記録する
- [x] フィード経路で `pubDate`/`updated` を `feed-pubdate` として記録する
- [x] sitemap 経路で `lastmod` を `sitemap-lastmod` として記録する
- [x] WebFetch 経路で取れた場合のみ `html-meta`（不在時は本文可視日付の保守パース `html-body`）として記録し、取れなければ `unknown`

### (B) 機械シグナル
- [x] b1: 矛盾の決着で日付を補助材料に使う一方、Tier A 優先が日付で覆らない
- [x] b1: 日付 `unknown` の矛盾では日付軸を使わず従来軸（Tier / version）で判断する
- [x] b2: `last_modified` が古いソースに対する陳腐化 lint 検査（#17 source-date-stale・代表鮮度日 180 日超で情報）がレポートされる
- [x] b3: synthesis 成果物がソースの鮮度を反映（注記または引用順）する
- [x] b4: index / overview に代表鮮度日が表示される

### 遡及補完
- [x] 既存 raw を sitemap/feed/gh から取れる範囲で補完でき、取れない分は `unknown` のまま残る（`--backfill-dates`・実 vault で scanned=237 / filled=237〔該当経路 unknown 0〕実走）

### Medium（Phase 2 ゲート）
- [ ] Medium 取り込み開始前に scrape 出力の日付有無が確認され、無ければ minitools 整備が先行する（**Phase 2・未達で据え置き**）

## スコープ外

### 今回対象外
- **wiki ページへの元日付集約**（設計方針 4 で意図的に持たない）
- **Medium の日付抽出**（Phase 2・scrape 出力確認と minitools 整備が前提）
- **代替日付・推定での穴埋め**（`unknown` のまま）
- **X / YouTube 等の新ソース日付**（別ロードマップ Phase 4+ に従う）

### 将来対応予定
- Medium 経路（Phase 2）
- `html-meta` で拾った不確実な日付の再検証フロー（`date_source` で絞り込み）

## 未決事項（/plan-feature で確定）

- **`date_source` の持ち方（単一 vs per-date）**: `published_at` と `last_modified` は別経路から埋まることが多く、特に ⑤遡及補完では「初回 ingest で `published_at` を feed から、後の補完で `last_modified` を sitemap から」が**通常ケース**になる。このとき単一 `date_source` ではどちらか一方しか出所を記述できない。選択肢は (a) per-date provenance（`published_at_source` / `last_modified_source` の 2 本）、(b) 単一 `date_source` で勝者の鮮度日（`last_modified ?? published_at`）の出所のみ記述。フィールド構造に関わるため plan-feature 冒頭で確定する。
- **index/overview 代表鮮度日の同期方式**: 設計方針 4 で per-page 集約は却下したが、機能 3/b4 の代表鮮度日も更新時の同期問題を内包する。「index.md は既存の再コンパイルに乗る」という区別で吸収できるか、別の更新トリガーが要るかを確定する。

## 技術的考慮事項

### 既存コードとの関係

- `references/schema.md` §3（raw フロントマター仕様・`fetched_via` 語彙）への追記と co-evolution（§5）
- `SKILL.md` の各取得経路（mode B step 3 host routing / mode F gh api / mode I feed・sitemap / WebFetch 共通）への日付抽出ステップ追加
- lint ルール（`references/lint-rules.md`）への陳腐化検査追加（b2）
- 矛盾解決ロジック（決定 Z / Phase 2b #11 バージョン軸決着）との統合（b1）
- index.md / overview.md の表示構造（b4）

### リスクと対策

| リスク | 影響度 | 対策 |
|-------|--------|------|
| **raw 不変条件との衝突**（不変条件 8：raw は不変・再取得は新スナップショット追加）。遡及補完は既存 raw frontmatter を後から書き換える | 高 | 「本文スナップショットの不変」と「メタ frontmatter への日付追記」を分けて整理する。追記がスナップショット本文を変えない範囲なら不変原則と両立する旨を schema に明文化（要 plan-feature で確定） |
| 日付で Tier A の権威を意図せず覆す | 中 | Tier A 優先を不変とし、日付は同 Tier 内決着＋補助注記に限定。`unknown` は日付軸不使用 |
| `html-meta` の不確実な日付が (B) を汚染 | 中 | `date_source` で信頼度を区別し、`html-meta` は補助扱い・再検証可能にする |
| 遡及補完を新モード化すると mode 乱立（D7 違反） | 中 | 既存 refresh/lint/ingest への相乗りを優先検討 |
| wiki ページに作成日フィールドが無い可能性 | 低 | 現状 `updated`（コンパイル日）はある。作成日が必要なら `created` を足すか検討（plan-feature） |
| unknown 率が高く (B) のシグナルが薄くなる | 低 | Phase 1 で確実 3 経路を押さえ、確実経路ソースの被覆率を確保 |

## 更新履歴

- 2026-06-09: 初版作成（ブレインストーミングセッション）
