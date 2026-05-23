---
name: llm-wiki
description: Claude Code 知識を raw→wiki にコンパイル蓄積。init/ingest/query/synthesize でボールト初期化・ソース取り込み・引用付き回答・派生成果物生成
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion
argument-hint: "<init|ingest <path-or-url> [--type=practice|--feature=<slug>]|query <質問>|synthesize <テーマ>|lint [--check=<csv>]>"
---

# llm-wiki（個人 Claude Code 知識ハブ）

**目的:** 進化の速い Claude Code の知見を「検索ではなくコンパイル」して永続知識ベースに蓄積し、
引用付きの派生成果物（チートシート/Tips 集）を生成・維持する。

**引数:** `$ARGUMENTS`

**使用方法:**
```
/llm-wiki init                                          # ボールト初期化・wiki-vault リンク案内・設定整備
/llm-wiki ingest <path-or-url>                          # ソースを取り込みコンパイル（既存）
/llm-wiki ingest <path-or-url> --type=practice          # practice ページとして取り込み（raw/notes/ 想定）
/llm-wiki ingest <path-or-url> --feature=<slug>         # source 生成 + 指定 feature ページ更新
/llm-wiki query <質問>                                  # Wiki から引用付きで回答（読み取り専用）
/llm-wiki synthesize <テーマ>                           # チートシート/Tips 集等を生成/再生成
/llm-wiki lint [--check=<csv>]                          # 11 検査（Phase 2a 7 + Phase 2b 4、#11 のみ承認制で書き込み）
```

---

## 不変条件（CLAUDE.md「設計上の不変条件」が最上位の正）

このスキルは `CLAUDE.md` の不変条件に従う。**齟齬時は CLAUDE.md > SKILL.md / schema.md**。
データ規約（ページタイプ・フロントマター必須フィールド・命名/[[wikilink]]/tier 判定・schema_version・
co-evolution・責務境界）の唯一の正は **`references/schema.md`** であり、本ファイルでは再記述しない。
ページ本文の雛形は **`references/page-templates.md`**。

要点（詳細は上記参照）:
- raw は不変スナップショット。すべての主張は raw を引用する。
- 既存ページと矛盾する主張は黙って上書きせず「矛盾」セクションに両論併記。
- 操作後は index.md / log.md を更新し、ボールト側 Git に操作単位でコミットする。
- ボールトパスはハードコードせず、本リポジトリ直下の設定ファイル `.llm-wiki.json` から解決する。

---

## ステップ0: 引数パースとモード分岐

1. `$ARGUMENTS` の第 1 トークンをモードとして取り出す。残りを引数とする。
2. 分岐:
   - `init` → **モード A**
   - `ingest` → **モード B**（第 2 引数 = path-or-url。無ければ使用法表示で停止）
   - `query` → **モード C**（残り全体 = 質問。無ければ使用法表示で停止）
   - `synthesize` → **モード D**（残り全体 = テーマ。無ければ使用法表示で停止）
   - `lint` → **モード L**（Phase 2a 機械判定 7 検査・レポートのみ）
   - 上記以外 / 引数なし → 上の「使用方法」を表示して**停止**。
3. `init` 以外のモードは、最初に **ボールト前提チェック**（ステップ0.5）を行う。

### ステップ0.5: ボールト前提チェック（init 以外）

1. 本リポジトリ直下の設定ファイル `.llm-wiki.json` を Read。無ければ
   「先に `/llm-wiki init` を実行してください」と案内して**停止**。
2. 設定の `vault_relative`（`./wiki-vault`）の存在とリンク有効性を Bash で確認
   （`test -e ./wiki-vault`）。不在/リンク切れなら同様に init を案内して停止。
3. ボールト側に未コミット変更があれば（`git -C ./wiki-vault status --porcelain`）、
   状態を提示し続行可否を AskUserQuestion で確認する。

---

## モード A: /llm-wiki init

ボールトを初期化し、本リポジトリ側の設定を整える。

1. **設定ファイル確認**
   - `.llm-wiki.json` が既存なら内容を提示し、再初期化するか AskUserQuestion で確認。

2. **ボールト実体パスの確定**
   - `./wiki-vault` が既に有効なシンボリックリンクならその実体を採用。
   - 無ければ実体パス（既定候補 `~/Documents/claude-code-wiki`）を AskUserQuestion で確認し、
     `ln -s <実体パス> ./wiki-vault` を**案内し、承認を得て実行**する。

3. **ボールト骨格生成**
   - `references/schema.md` §3 のディレクトリ規約に従い、`raw/` と `wiki/` のサブディレクトリ、
     `wiki/index.md` `wiki/log.md` `wiki/overview.md` `wiki/current-baseline.md` を雛形生成する
     （既存ファイルは上書きしない）。
   - 各雛形フロントマター/構成は `references/schema.md`・`references/page-templates.md` に従う。

4. **current-baseline.md の初期 `claude_code_version` 確定（決定 イ）**
   - **WebFetch 対象 URL（確定）**: `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md`
     - 取得不可時フォールバック URL: `https://github.com/anthropics/claude-code/releases`
   - 取得テキストを `raw/docs/<取得日 YYYY-MM-DD>-claude-code-release.md` に保存し、
     原文 URL・取得日時・取得手段・Tier（`references/schema.md` §4 によりこの取得元は A）を
     メタとして記録する。
   - `current-baseline.md` はこの raw を引用して `claude_code_version` を確定する
     （不変条件「すべての主張は raw を引用」を init でも満たす）。
   - **WebFetch 失敗時のみ**: `claude --version` の実行をユーザーに案内（`! claude --version`）し、
     申告値をセット。raw 引用が無いため `current-baseline.md` に
     「ソース: 手動入力（暫定）・取得日」と明記し、フロントマターは
     `references/schema.md` §2 に従い `stale` を真として記録、
     次回オンライン時に Tier A 取得で上書き提案する旨を本文に残す。

5. **schema 軽量ポインタ記録（決定 ウ）**
   - `current-baseline.md` に `references/schema.md` §6 の軽量ポインタを記録する
     （`schema_version` / 本リポジトリの該当 commit ハッシュ＝`git rev-parse HEAD` / 規約 1〜2 行サマリ）。
     schema 全文は複製しない。

6. **本リポジトリ側の整備**
   - `.gitignore` に `wiki-vault` 行が無ければ追記する（誤コミット防止）。
   - `.llm-wiki.json` を生成する。MVP は相対パス `./wiki-vault` を正、絶対パスは参考値、
     `schema_version` は `references/schema.md` の値を転記:
     ```json
     { "vault_relative": "./wiki-vault",
       "vault_absolute": "<実体絶対パス>",
       "schema_version": "<references/schema.md の schema_version>" }
     ```

7. **ボールト側 Git 初期化**
   - `git -C ./wiki-vault init`（未初期化時）→ `add -A` → 初回コミット
     （メッセージ例 `chore: llm-wiki init (schema vX.Y.Z)`）。

8. 完了サマリ（生成パス・確定バージョン・schema_version）を提示する。

---

## モード B: /llm-wiki ingest <path-or-url> [--type=practice|--feature=<slug>]

ソースを取り込み、コンパイルする。

1. **引数パース**
   - 第 2 トークン: `path-or-url`。
   - 残りトークンは `--key=value` 形式。許容キーは `--type=practice` と `--feature=<slug>` のみ。
     未知キーはエラーで中断（メッセージで許容キーを案内）。
   - `--type=practice` と `--feature=<slug>` を**同時指定した場合はエラーで中断**
     （practice は主型、feature は派生型として意味が衝突するため）。

2. **引数判定**: URL（`http(s)://`）か ローカルパスかを判定。

3. **raw 確保**
   - **URL**: `WebFetch` で取得 → `raw/<種別>/<取得日 YYYY-MM-DD>-<slug>.md` に保存。
     原文 URL・取得日時・取得手段・tier（`references/schema.md` §4 で判定）をメタ記録。
     取得失敗時はユーザーに手動 raw 保存を案内して**中断**（黙って空ページを作らない）。
   - **ローカルパス**: 既存 raw ファイルとして検証。無ければエラーで中断
     （raw は人間が追加するもの。ingest が raw を新規創作しない）。
     - `--type=practice` 指定時に raw が未存在の場合、`raw/notes/` への事前配置を案内して中断
       （practice ページの `sources:` 必須を満たすため）。

4. **既出チェック**
   - `wiki/log.md` を Grep し同一ソースの既出を確認。既出なら再取り込み可否を
     AskUserQuestion で確認（強制しない）。

5. **全文読込・要点確認**
   - raw を全文読込し要点を抽出 → ユーザーに要点を提示し AskUserQuestion で確認。

6. **ページ生成/更新（引数による分岐）**

   **(a) 引数無指定（既存挙動・変更なし）**:
   - `references/schema.md` のページタイプ規約・`references/page-templates.md` の雛形に従い、
     `source` ページ（必須）＋関連 `concept`/`entity`/`comparison` を生成/更新する。

   **(b) `--type=practice`**:
   - 主たる生成型を `practice` に切り替え、`wiki/practices/<slug>.md` を
     `references/page-templates.md` の practice テンプレで生成する
     （セクション「試した内容 / 文脈・前提 / 結果 / 結論 / 関連 / 矛盾」）。
   - source ページも併存生成する（raw の要約として `wiki/sources/<slug>.md`）。
     practice は raw に対する「実践と効果の記録」として別ページ。
   - 関連 concept/entity の派生は通常 ingest と同じく必要に応じて生成。

   **(c) `--feature=<slug>`**:
   - 通常の source 生成フローを実行（source + 派生 concept/entity）。
   - `wiki/features/<slug>.md` の存在を確認:
     - 存在しない → `references/page-templates.md` の feature テンプレで新規作成。
     - 存在する → 「バージョン別仕様差分」セクションに今回 source の知見を追記。
       既存記述と矛盾する場合は schema.md §「黙って上書きしない」に従い `## 矛盾` セクションへ。
   - feature ページのフロントマター `claude_code_version` / `updated` を新 source の値で更新
     （version 進行を反映）。本文の他部分は触らない。
   - **バージョン逆行ケース**（新 source の `claude_code_version` が既存 feature ページより古い）は
     `## 矛盾` セクション追記＋AskUserQuestion で続行可否を確認（黙って上書きしない）。

   いずれの分岐でも、フロントマターは `references/schema.md` §2 の必須フィールドを全て充填する
   （tier 判定は §4。判定ロジックは Phase 2a だが値の保持は MVP から必須）。
   本文に raw 引用と [[wikilink]] を含める（記法は `references/schema.md` §3）。

7. **矛盾検出（一段目・同一トピックのみ）**
   - 新主張が触れる [[wikilink]] 先の**既存ページのみ**を読み、矛盾があれば当該ページに
     `## 矛盾` セクションを追記し両論併記（黙って上書きしない）。
   - トピック横断の矛盾は MVP では検出しない（Phase 2b lint #5 へ委譲）。

8. **Tier B のバージョン乖離提案**
   - tier が B（`references/schema.md` §4）かつ当該知見の前提バージョンが
     `current-baseline.md` と乖離する場合、`current-baseline.md` 更新を
     AskUserQuestion で**承認制**提案する（自動更新しない）。

9. **index/log 更新・コミット**
   - `wiki/index.md` に各生成/更新ページの主要主張サマリ（1〜2 行）を維持
     （Phase 2 横断矛盾スキャンの前提）。
   - `wiki/log.md` に操作（日時・ソース・生成/更新ページ）を追記。
   - ボールト側 Git に操作単位でコミット。

---

## モード C: /llm-wiki query <質問>

Wiki から引用付きで回答する。**読み取り専用**（ボールトに書き込まない）。

1. `wiki/index.md` を読み、質問に関連するページを特定する。
2. 関連ページ**のみ**を選択読込（全 wiki 走査禁止＝コンテキスト圧迫回避）。
3. 引用付きで回答を統合する（各主張に出典ページ/raw を併記）。
4. Wiki に不足がある場合は `WebSearch`/`WebFetch` で補完し、その箇所を
   **`⚠️ Wiki 外（Web 検索）`** と明示する。
5. 補完で有用な未取り込みソースが見つかれば `/llm-wiki ingest <url>` を提案する
   （提案のみ。query では取り込まない）。

---

## モード D: /llm-wiki synthesize <テーマ>

テーマ横断の派生成果物（チートシート/Tips 集等）を生成/再生成する。

1. `wiki/index.md` → テーマ関連ページ群を選択読込。
2. `references/page-templates.md` の `synthesis` 雛形に従い
   `wiki/syntheses/<slug>.md` を生成、または既存があれば再生成する。
   フロントマターは `references/schema.md` §2 に従い充填。
3. すべての項目は元 Wiki ページ/raw を引用する。Wiki 外で補完した箇所は
   **`⚠️ Wiki 外（Web 検索）`** と明示し、ingest を提案する。
4. `wiki/index.md` のサマリ更新・`wiki/log.md` 追記・ボールト側 Git コミット。

---

## モード L: /llm-wiki lint [--check=<csv>]

Phase 2a 機械判定 7 検査（#1 孤立 / #2 更新日 30 日超 / #3 `claude_code_version` 乖離 /
#4 `stale:true` 監査 / #6 信頼度 / #7 index 同期 / #9 `current-baseline.md` 鮮度）に加え、
**Phase 2b 意味解釈 4 検査**（#5 cross-topic / #8 synthesis-stale / #10 three-way /
#11 version-resolve、うち #11 は AskUserQuestion 承認制で `## 矛盾` 末尾に決着注記を追記）を実行する。

**書き込みは `wiki/log.md` への結果サマリ追記＋ #11 承認時のみ `## 矛盾` 末尾 1 行追記のみ**。
本文・フロントマター・index.md への自動補完は一切しない（不変条件「黙って上書きしない」）。

### 書き込み副作用境界（11 検査 × 書き込み有無）

| # | id | 書き込み |
|---|----|---------|
| 1 | orphan | なし（対話レポート＋log.md 集計のみ） |
| 2 | updated | なし |
| 3 | version | なし |
| 4 | stale | なし |
| 5 | cross-topic | なし |
| 6 | confidence | なし |
| 7 | index | なし |
| 8 | synthesis-stale | なし（detail に手動再生成コマンドを併記） |
| 9 | baseline | なし |
| 10 | three-way | なし |
| 11 | version-resolve | **承認時のみ** 該当ページ `## 矛盾` 末尾に 1 行追記＋ log.md に決着行追記 |

検査項目の判定ロジック・しきい値・走査戦略・`## 矛盾` パース仕様・決着注記の正規記法は
`references/lint-rules.md` を参照（SKILL.md では再記述しない）。

1. **引数パース**
   - 第 2 トークン以降から `--check=<csv>` を抽出。`<csv>` は
     `orphan|updated|version|stale|confidence|index|baseline|cross-topic|synthesis-stale|three-way|version-resolve`
     のサブセット（カンマ区切り）。
   - 未指定なら全 11 検査。未知キーはエラーで中断し、上記 11 キー一覧を案内。

2. **ステップ 0.5 ボールト前提チェック**を継承（init 以外と同じ手順）。

3. **走査**（`references/lint-rules.md` §走査戦略の通り）
   - `Glob("wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md")` で全ページ列挙（1 回）。
   - 各ページを `Read(offset=0, limit=50)` でフロントマター部分のみ取得（本文不読）。
     集約マップに `sources` / `links` を含める（#8 用）。
   - `Read("wiki/index.md")`（1 回・サマリ行と [[wikilink]] を抽出）。
   - `Read("wiki/current-baseline.md")`（1 回）。
   - **Phase 2b 追加 Read**（`--check` で対象検査が含まれる場合のみ）:
     - **#10 用**: `Read("CLAUDE.md")` / `Read(".claude/skills/llm-wiki/SKILL.md")` /
       `Read(".claude/skills/llm-wiki/references/schema.md")` を 1 回ずつ（CWD 起点）。
     - **#11 用**: `Bash("grep -l '^## 矛盾' wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/*.md")`
       で `## 矛盾` 保持ページを抽出 → ヒットページのみ該当セクションを限定 Read
       （`Read(offset=<セクション開始行>, limit=80)` 程度）。**全ページ本文 Read はしない**。
   - 以上のデータをメモリ上の集約マップに保持し、以降は追加 Read を行わない。

4. **検査実行**
   - `references/lint-rules.md` の判定ロジック節（Phase 2a 7 検査 + Phase 2b 4 検査）に従い、
     `--check` で指定された検査を実行。severity は「要対応 / 警告 / 情報」の 3 段。
   - **#5 / #8 / #10 はレポートのみ**。
   - **#11 は候補検出後にステップ 8 の承認制 UX を起動**（書き込みは承認後のみ）。

5. **対話出力**
   - Markdown 表（カラム: file / check / severity / detail）で全 11 検査の結果を統合出力。

6. **`wiki/log.md` 追記**
   - `### lint 結果（YYYY-MM-DD HH:MM）` セクションを追記。
   - severity 別集計（要対応 N / 警告 M / 情報 K）と検査別件数を 1 行ずつ記録:
     `検査別件数: orphan=A, updated=B, version=C, stale=D, confidence=E, index=F, baseline=G, cross-topic=H, synthesis-stale=I, three-way=J, version-resolve=K`
   - 全件詳細は対話のみ（log.md 肥大化防止）。

7. **レポートコミット**
   - ボールト Git で `wiki/log.md` の差分のみを `git add` し
     `chore: llm-wiki lint (YYYY-MM-DD)` でコミット。
   - lint は他のファイルを変更しないため、log.md 以外の差分は発生しない。
     もし発生していたら不変条件違反としてユーザーに報告し中断（自動書き込みの取り残し検知）。

8. **#11 承認制 UX**（候補が 1 件以上ある場合のみ）

   ステップ 5–7 の検査全件レポート出力＋レポートコミット**後**に起動する。

   1. **候補の選別**: #11 の時系列 supersession 候補をリスト化する。5 件超なら上位 4 件のみ提示
      （AskUserQuestion の選択肢上限 4 件）。ソート順: severity 高い順（要対応 > 情報）→ version 差大きい順
      （major 桁差 > minor 桁差）。残りは対話レポートに「次回 lint で再検出可」と明示。
   2. **AskUserQuestion** を起動:
      - `question`: 「次の N 件に決着注記を追記しますか？（適用したいページを選択。何も選ばなければ追記なしで終了）」
      - `options`: 候補ページごとに 1 件、ラベル形式は `<slug> (v_old=X Tier B → v_new=Y Tier A)`
      - `multiSelect: true`
      - 「いずれも適用しない」専用オプションは置かない（0 件選択がそのまま「適用しない」を意味する）
   3. **選択 0 件** → 追記なし・コミットなしで終了。候補は対話レポートに残る。
   4. **選択ページごとの末尾アンカー手順**:
      a. 該当ページの `## 矛盾` セクション末尾を Read で確認（既に限定 Read 済みデータを使用可）。
      b. 既に決着行（`references/lint-rules.md` §「#11 決着注記の正規記法」の二重追記回避規約）が
         セクション内にあればスキップ。
      c. セクション末尾の最終非空行を取得し、Edit で
         - `old_string` = 最終非空行（そのまま）
         - `new_string` = 最終非空行 + `\n` + 決着行（記法は `references/lint-rules.md`
           §「#11 決着注記の正規記法」の正規記法に従う。SKILL.md では再記述しない）
         - `replace_all: false` 厳守
      d. `wiki/log.md` のサマリ直下に決着行を 1 行追記する（記法は `references/lint-rules.md`
         §「#11 決着適用時の log.md 追記フォーマット」を参照）。
   5. **決着適用コミット**: 追記が 1 件以上発生したらボールト Git で
      `chore: llm-wiki lint resolve (YYYY-MM-DD)` でコミット（`## 矛盾` 編集と log.md 追記をまとめる）。
      レポートコミット（ステップ 7）とは分離する。

### エラーハンドリング（lint）

`references/lint-rules.md` §エラーハンドリング表（Phase 2a/2b 共通＋ Phase 2b 追加）を参照
（再記述しない）。要点:

| 事象 | 扱い |
|------|------|
| `--check` 未知キー | 中断し 11 キー一覧を案内 |
| フロントマター YAML パース失敗 | 該当ページのみ「要対応: フロントマター不正」表示し他検査継続 |
| `sources:` 空 | 「要対応: sources 空（schema.md §2 違反）」表示 |
| `current-baseline.md` 不在 | #3/#9 をスキップ |
| ボールト未コミット変更あり | AskUserQuestion で続行可否 |
| `## 矛盾` セクション構造不正（grep ヒットだが Read で該当行なし） | 「要対応: ## 矛盾 セクション構造不正」表示、他検査継続 |
| #10 で本リポジトリ側 3 文書のいずれかが Read 不能 | #10 をスキップし要対応表示 |
| #11 候補ページが Read できない | 該当候補のみスキップ、他候補は続行 |
| AskUserQuestion で 0 件選択 | 追記なし・コミットなしで終了 |
| #11 候補が 5 件超 | 上位 4 件のみ承認確認、残りは次回 lint で再検出 |
| `## 矛盾` 末尾に既に「**決着（**」行がある | 二重追記を回避してスキップ |
| #8 で synthesis の `sources:` が空 | Phase 2a `sources:` 空エラー扱いに委ね、#8 はスキップ |

---

## エラーハンドリング（ワークフロー上の分岐）

| 事象 | 扱い |
|------|------|
| `./wiki-vault` 不在/リンク切れ | init 以外は中断し「先に /llm-wiki init」を案内 |
| WebFetch 失敗（init） | 対話フォールバック（`claude --version`）＋ `current-baseline.md` を暫定/`stale` 記録・上書き提案を残す |
| WebFetch 失敗（ingest） | 手動 raw 保存を案内し中断（黙って空ページを作らない） |
| `--type=practice` + `--feature=<slug>` 同時指定（ingest） | エラーで中断（意味が衝突するため両立不可） |
| `--type=practice` で raw 未存在（ingest） | `raw/notes/` への事前配置を案内し中断（practice の `sources:` 必須を満たせない） |
| `--feature=<slug>` でバージョン逆行（ingest） | `## 矛盾` 追記＋AskUserQuestion で続行可否 |
| 既出ソース再取り込み | AskUserQuestion で可否確認、強制しない |
| 矛盾検出 | 上書き禁止、`## 矛盾` 追記で両論併記 |
| ボールト未コミット変更あり | 操作前に状態提示し続行可否を確認 |
| lint で `--check` 未知キー | 11 キー一覧を案内し中断 |
| lint 中にフロントマター YAML パース失敗 | 当該ページを「要対応: フロントマター不正」として個別レポートし他検査継続 |
| lint #10 で本リポジトリ側 3 文書が Read 不能 | #10 をスキップし要対応表示、他検査継続 |
| lint #11 で `## 矛盾` セクション構造不正 | 「要対応: ## 矛盾 セクション構造不正」表示、他検査継続 |
| lint #11 で AskUserQuestion 0 件選択 | 追記なし・コミットなしで終了（候補は対話レポートに残る） |
| lint #11 で `## 矛盾` 末尾に既に決着行あり | 二重追記を回避してスキップ |

---

## co-evolution（schema 改訂時）

`references/schema.md` を改訂したら、同ファイル §5 の手順に従う
（`schema_version` 更新 → ボールト `current-baseline.md` の軽量ポインタ更新 →
ボールト `log.md` に `schema vN→vN+1: 要旨` 追記）。本ファイルは手順の所在を示すのみ。
