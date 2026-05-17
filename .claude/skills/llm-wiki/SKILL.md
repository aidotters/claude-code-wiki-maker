---
name: llm-wiki
description: Claude Code 知識を raw→wiki にコンパイル蓄積。init/ingest/query/synthesize でボールト初期化・ソース取り込み・引用付き回答・派生成果物生成
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion
argument-hint: "<init|ingest <path-or-url>|query <質問>|synthesize <テーマ>|lint>"
---

# llm-wiki（個人 Claude Code 知識ハブ）

**目的:** 進化の速い Claude Code の知見を「検索ではなくコンパイル」して永続知識ベースに蓄積し、
引用付きの派生成果物（チートシート/Tips 集）を生成・維持する。

**引数:** `$ARGUMENTS`

**使用方法:**
```
/llm-wiki init                       # ボールト初期化・wiki-vault リンク案内・設定整備
/llm-wiki ingest <path-or-url>       # ソースを取り込みコンパイル
/llm-wiki query <質問>               # Wiki から引用付きで回答（読み取り専用）
/llm-wiki synthesize <テーマ>        # チートシート/Tips 集等を生成/再生成
/llm-wiki lint                       # Phase 2・未実装（案内のみ）
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
   - `lint` → **モード L**（Phase 2 案内のみ）
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
   - 無ければ実体パス（既定候補 `~/Documents/ClaudeCodeWiki`）を AskUserQuestion で確認し、
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

## モード B: /llm-wiki ingest <path-or-url>

ソースを取り込み、コンパイルする。

1. **引数判定**: URL（`http(s)://`）か ローカルパスかを判定。

2. **raw 確保**
   - **URL**: `WebFetch` で取得 → `raw/<種別>/<取得日 YYYY-MM-DD>-<slug>.md` に保存。
     原文 URL・取得日時・取得手段・tier（`references/schema.md` §4 で判定）をメタ記録。
     取得失敗時はユーザーに手動 raw 保存を案内して**中断**（黙って空ページを作らない）。
   - **ローカルパス**: 既存 raw ファイルとして検証。無ければエラーで中断
     （raw は人間が追加するもの。ingest が raw を新規創作しない）。

3. **既出チェック**
   - `wiki/log.md` を Grep し同一ソースの既出を確認。既出なら再取り込み可否を
     AskUserQuestion で確認（強制しない）。

4. **全文読込・要点確認**
   - raw を全文読込し要点を抽出 → ユーザーに要点を提示し AskUserQuestion で確認。

5. **ページ生成/更新**
   - `references/schema.md` のページタイプ規約・`references/page-templates.md` の雛形に従い、
     `source` ページ（必須）＋関連 `concept`/`entity`/`comparison` を生成/更新する。
   - フロントマターは `references/schema.md` §2 の必須フィールドを全て充填する
     （tier 判定は §4。判定ロジックは Phase 2 だが値の保持は MVP から必須）。
   - 本文に raw 引用と [[wikilink]] を含める（記法は `references/schema.md` §3）。

6. **矛盾検出（一段目・同一トピックのみ）**
   - 新主張が触れる [[wikilink]] 先の**既存ページのみ**を読み、矛盾があれば当該ページに
     `## 矛盾` セクションを追記し両論併記（黙って上書きしない）。
   - トピック横断の矛盾は MVP では検出しない（Phase 2 lint へ委譲。下記モード L）。

7. **Tier B のバージョン乖離提案**
   - tier が B（`references/schema.md` §4）かつ当該知見の前提バージョンが
     `current-baseline.md` と乖離する場合、`current-baseline.md` 更新を
     AskUserQuestion で**承認制**提案する（自動更新しない）。

8. **index/log 更新・コミット**
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

## モード L: /llm-wiki lint

**Phase 2・未実装。** 以下を表示して停止する:

```
/llm-wiki lint は Phase 2 で実装予定です（MVP では未実装）。
検査予定項目は .claude/skills/llm-wiki/references/lint-rules.md を参照してください。
なお MVP では横断的矛盾検出（決定 Z 二段目）も Phase 2 です。ingest は
同一トピック（[[wikilink]] 先）のみ即時照合し、トピック横断の矛盾は検出しません。
当面の代替: /llm-wiki query / synthesize 実行時の「⚠️ Wiki 外」明示と
ingest 提案で不足・鮮度を手動把握してください。
```

---

## エラーハンドリング（ワークフロー上の分岐）

| 事象 | 扱い |
|------|------|
| `./wiki-vault` 不在/リンク切れ | init 以外は中断し「先に /llm-wiki init」を案内 |
| WebFetch 失敗（init） | 対話フォールバック（`claude --version`）＋ `current-baseline.md` を暫定/`stale` 記録・上書き提案を残す |
| WebFetch 失敗（ingest） | 手動 raw 保存を案内し中断（黙って空ページを作らない） |
| 既出ソース再取り込み | AskUserQuestion で可否確認、強制しない |
| 矛盾検出 | 上書き禁止、`## 矛盾` 追記で両論併記 |
| ボールト未コミット変更あり | 操作前に状態提示し続行可否を確認 |

---

## co-evolution（schema 改訂時）

`references/schema.md` を改訂したら、同ファイル §5 の手順に従う
（`schema_version` 更新 → ボールト `current-baseline.md` の軽量ポインタ更新 →
ボールト `log.md` に `schema vN→vN+1: 要旨` 追記）。本ファイルは手順の所在を示すのみ。
