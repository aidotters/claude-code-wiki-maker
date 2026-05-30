---
name: llm-wiki
description: Claude Code 知識を raw→wiki にコンパイル蓄積。init/ingest/query/synthesize でボールト初期化・ソース取り込み・引用付き回答・派生成果物生成
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion
argument-hint: "<init|ingest <path-or-url> [--type=practice|--feature=<slug>]|query <質問>|synthesize <テーマ>|lint [--check=<csv>]|refresh-tier-a [--dry-run]|discover-tier-a [--no-prompt|--dry-run]>"
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
/llm-wiki lint [--check=<csv>]                          # 13 検査（Phase 2a 7 + Phase 2b 4 + Phase 3a 1 + Phase 3c 1、#11 のみ承認制で書き込み）
/llm-wiki refresh-tier-a [--dry-run]                    # Tier A 日次自動再取得（cron / launchd 経由・対話実行も可）
/llm-wiki discover-tier-a [--no-prompt|--dry-run]       # Tier A 未取り込み URL 自動発見 + 承認制 ingest（--no-prompt で cron 用）
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
   - `lint` → **モード L**（Phase 2a 7 + Phase 2b 4 + Phase 3a 1 + Phase 3c 1 の 13 検査）
   - `refresh-tier-a` → **モード F**（Phase 3a・Tier A 日次自動再取得。`--dry-run` 任意）
   - `discover-tier-a` → **モード G**（Phase 3c・Tier A 未取り込み URL 自動発見 + 承認制 ingest。`--no-prompt` / `--dry-run` 任意）
   - 上記以外 / 引数なし → 上の「使用方法」を表示して**停止**。
3. `init` 以外のモードは、最初に **ボールト前提チェック**（ステップ0.5）を行う。

### ステップ0.5: ボールト前提チェック（init 以外）

1. 本リポジトリ直下の設定ファイル `.llm-wiki.json` を Read。無ければ
   「先に `/llm-wiki init` を実行してください」と案内して**停止**。
2. 設定の `vault_relative`（`./wiki-vault`）の存在とリンク有効性を Bash で確認
   （`test -e ./wiki-vault`）。不在/リンク切れなら同様に init を案内して停止。
3. ボールト側に未コミット変更があれば（`git -C ./wiki-vault status --porcelain`）、
   状態を提示し続行可否を AskUserQuestion で確認する。
   - モード F（refresh-tier-a）は対話モードではないため、§F-2 で**自動 skip** に分岐する（AskUserQuestion を起動しない）。

### ステップ0.6: lock 取得（書き込みモード共通）

`.llm-wiki.lock` は **書き込みモード**（B / D / F / G、および lint #11 承認制決着の `## 矛盾` 編集部分）でのみ取得する。`query`（モード C）は読み取り専用のため不要。`lint` 通常実行（11/12/13 検査レポート＋ `wiki/log.md` 追記まで）も**不要**（design.md §6 carve-out）。

- **ファイル**: vault 直下 `.llm-wiki.lock`（`/llm-wiki init` で vault `.gitignore` に追加済）。
- **フォーマット**: 1 行 JSON `{"pid": <PID>, "started_at": "<ISO8601>", "mode": "ingest|synthesize|refresh-tier-a|discover-tier-a|lint-resolve"}`
- **atomic 取得**: `Bash('set -C; echo "{\"pid\":'$$',\"started_at\":\"'$(date -Iseconds)'\",\"mode\":\"<mode>\"}" > ./wiki-vault/.llm-wiki.lock')` で `set -C`（noclobber）により既存ファイルへの書き込みは exit non-zero で失敗。失敗時は **スタール判定** へ進む。
- **スタール判定**: 既存 `.llm-wiki.lock` を Read し、`started_at` から **既定 1 時間**経過 **AND** `Bash('kill -0 <pid> 2>/dev/null')` が non-zero（プロセス死亡）の **両方** が真のときのみ強制奪取（誤奪取防止）。一方だけ真なら他プロセス稼働中扱いとして該当モードの skip 手順に進む。
- **解放**: モード完了時に `Bash('rm -f ./wiki-vault/.llm-wiki.lock')`。例外時も `trap` 相当で削除を試みる。

各モードでの lock 取得タイミングは各モード本文の冒頭で指定する。

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

7. **ボールト側 `.gitignore` 整備**
   - vault 直下 `.gitignore` を Read。存在しなければ作成。
   - `.llm-wiki.lock` 行が無ければ追記（書き込みモード排他制御の lock ファイルが誤コミットされないため）。
   - `.DS_Store` 等の既存除外行は維持。

8. **ボールト側 Git 初期化**
   - `git -C ./wiki-vault init`（未初期化時）→ `add -A` → 初回コミット
     （メッセージ例 `chore: llm-wiki init (schema vX.Y.Z)`）。

9. 完了サマリ（生成パス・確定バージョン・schema_version）を提示する。

10. **session-start hook 設定例の案内（参考・自動インストールしない）**
    - `references/session-start-hook.example.json` が同梱されていることを利用者に案内する。
    - この設定例は Claude Code の `SessionStart` hook で `wiki/current-baseline.md`（現在の正＝`claude_code_version` / `updated` / `last_tier_a_refresh` / `migration_pending`）を ambient context にロードするためのもの。`/llm-wiki query` を呼ぶ前に「いま何が真か」を起動時から把握しておく目的。
    - 利用者が **手動で** `.claude/settings.json`（**project local 推奨**・グローバル `~/.claude/settings.json` への登録は他プロジェクトでも発火するため非推奨）にマージする想定。`/llm-wiki init` は自動マージしない（read-only context preload とはいえ利用者設定ファイルの書き換えは行わない方針）。**マージ対象は `hooks` キーのみ**（example の `_comment` / `_notes` は説明用フィールドなので `.claude/settings.json` にはコピーしない。Claude Code の settings parser が未知の root key をどう扱うかは保証されないため）。
    - `command` は `[ -L ./wiki-vault ] && cat ./wiki-vault/wiki/current-baseline.md 2>/dev/null || true` で **CWD = リポジトリルート前提・vault 不在時は無音終了**。`matcher: "*"` は startup / resume / clear / compact 全部で再注入。narrow したい場合は example の `_notes` 参照。

---

## モード B: /llm-wiki ingest <path-or-url> [--type=practice|--feature=<slug>]

ソースを取り込み、コンパイルする。

**lock**: ステップ 0.5 ボールト前提チェック直後に**取得**（ステップ 0.6 参照）。本モード全体を排他制御し、ステップ 9 のコミット後に解放する。例外時も解放を試みる。

0. **lock 取得**（ステップ 0.6 の手順）。失敗時はステップ 0.6 の skip 手順に従う。

0.b **migration_pending 提案**（書き込み前・lock 取得直後）: モード L §ステップ 2.5 の手順を**同一ロジックで適用**（候補 1 件でも「適用しない」併置、`multiSelect: true`、上位 4 件、承認分は **共通 surface 経由**で new_url を本モード step 3 (ii) に渡して新規 raw を ingest し既存 source ページに統合＋当該 migration_pending エントリ削除＋ 1 commit。Phase 3d 共通 surface 設計）。0 件選択は通常 ingest 続行。

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

3.5. **同一 source 判定（共通 surface・Phase 3d）**

   raw 保存後・wiki 更新前に、入力 URL（URL 指定の場合）から既存 source ページとの突合を行う。ローカルパス入力の場合は本 step を skip し既存 (iii) 新規 source 作成パスに進む。

   **URL 正規化（3d 用最小ルール）**: 突合前に URL を次の最小ルールで正規化する:
   - host を lowercase 化
   - 末尾スラッシュを 1 個まで除去（`/page/` → `/page`、`/` 単独はそのまま）

   > フル仕様（tracking param 除去・フラグメント除去・http→https 強制・allowlist マッチ等）は Phase 3e で本格設計予定。3d ではこの最小ルールのみ実装する。

   **3 段判定**: 正規化後の URL を次の優先順で判定する:

   | 優先 | 判定 | アクション |
   |------|------|------------|
   | (i) | 既存 source ページの最新 raw の `source_url` と完全一致（双方を正規化して比較）。**解決はモード F F-3 step 3〜4 と同じ走査**: 各 `wiki/sources/*.md` の `sources:` 末尾（`YYYY-MM-DD` プレフィックス最大）の raw を Read し、その raw のフロントマター `source_url` を取得する。**source ページ自身のフロントマターに `source_url` は無い**（schema §2 共通フィールドに含まれず、`source_url` は raw のフロントマターキー＝schema §3）ため、必ず raw を辿る。`source_url` を欠く raw は突合対象外。 | 既存 source ページに統合（step 6 へ。本 raw を sources: 末尾 append、再コンパイル、`updated` 進行） |
   | (ii) | `current-baseline.md.migration_pending[].new_url` のいずれかと一致 | 該当エントリの `source_slug` で示される旧 source ページに統合（新 raw＝`source_url`=new_url を `sources:` 末尾 append することで F-3 走査が以降 new_url を最新 URL として解決する。**source ページ自身に `source_url` フィールドは無いため書き換え対象は無い**）、migration_pending エントリを削除（step 6 / step 9 内で同一 commit）。tier は旧ページの値を継承（再判定しない） |
   | (iii) | 上記いずれにも一致しない | 新規 source ページを作成（既存挙動・step 6 (a)/(b)/(c) と同じ） |

   判定結果（i/ii/iii とマッチした既存ページがあれば slug）を以降の step に伝搬する。

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

   **共通 surface 追記事項（Phase 3d・step 3.5 の判定が (i) または (ii) の場合）**:
   - **sources: 末尾 append（F-6・時系列保証）**: 既存 source ページのフロントマター `sources:` 末尾に新 raw のパスを append。順序は時系列保証（新しい raw が末尾）。既存 raw は不変保持（E1）で削除・並べ替えしない。
   - **(ii) の追加処理**: マッチした旧 source ページへ新 raw（フロントマター `source_url` = new_url・正規化前の原文 URL を保持）を `sources:` 末尾 append する。これにより F-3 走査（`sources:` 末尾 raw → その raw の `source_url`）が以降 new_url を最新 URL として解決する（**source ページ自身に `source_url` フィールドは無いため書き換えは行わない／不要**。旧記述「旧 source ページのフロントマター `source_url` を書き換え」は存在しないフィールドを指していた誤りで Phase 3c carve-out 実機検証で是正）。`tier` は旧ページの値を継承（不可触）。`title` 等の手動編集領域は不可触。`updated` を今日付に進める。
   - **(ii) の migration_pending エントリ削除**: `current-baseline.md.migration_pending[]` から該当エントリ（`source_slug` で特定）を削除する。これは step 9 のコミット内で同一 commit に含める。
     - **anchor 戦略**: `old_string` には当該エントリ 4 キー全体（`  - old_url: ...` から `    source_url: ...` まで・前後の `\n` を含む 5 行）を厳密マッチで指定し `replace_all: false`。複数エントリがあっても `old_url` で一意に特定されるため衝突しない。

7. **矛盾検出（一段目・同一トピックのみ）**
   - 新主張が触れる [[wikilink]] 先の**既存ページのみ**を読み、矛盾があれば当該ページに
     `## 矛盾` セクションを追記し両論併記（黙って上書きしない）。
   - トピック横断の矛盾は MVP では検出しない（Phase 2b lint #5 へ委譲）。

8. **Tier B のバージョン乖離提案**
   - tier が B（`references/schema.md` §4）かつ当該知見の前提バージョンが
     `current-baseline.md` と乖離する場合、`current-baseline.md` 更新を
     AskUserQuestion で**承認制**提案する（自動更新しない）。

8.5. **overview 自動更新（Phase 3d・C）**

   `wiki/overview.md` の `## 現状` セクションを更新する。詳細仕様は `references/schema.md` §8 参照。

   - **統計取得**: `Glob('wiki/sources/[!_]*.md')` 等で各タイプの 5 ディレクトリ（sources / concepts / syntheses / practices / features）を count（`_fixture-*` 除外）。
   - **日付**: 「最終 ingest」は本日付、「最終更新」も本日付（後段の値変化ガードで差替検査）。
   - **値変化ガード**: `wiki/overview.md` を Read し `## 現状` セクションの現状の 5 件 + 2 日付をパース。**すべて同値なら Edit を skip し** `wiki/log.md` に `overview unchanged (<日付>)` を 1 行追記、step 9 へ進む。
   - **1 つでも変化があれば**: `## 現状` セクション（見出し直後から空行 or 次見出しまで）を Edit で置換し、step 9 のコミットに含める。
   - **境界判定失敗時**（`## 現状` 見出しが見つからない）: overview Edit を skip し log.md に `overview update skipped: section boundary not found (<日付>)` を warning 追記。step 9 へ。
   - **更新対象が無い場合**: step 6 で source ページ更新なしのケース（dry-run 相当）は overview 更新も skip。

9. **index/log 更新・コミット**
   - `wiki/index.md` に各生成/更新ページの主要主張サマリ（1〜2 行）を維持
     （Phase 2 横断矛盾スキャンの前提）。
   - `wiki/log.md` に操作（日時・ソース・生成/更新ページ）を追記。
   - step 6 共通 surface (ii) で `current-baseline.md.migration_pending` エントリ削除が発生した場合は同一 commit に含める。
   - step 8.5 で overview Edit が発生した場合は同一 commit に含める。
   - **呼び出し元が discover-tier-a（モード G）由来**で `current-baseline.md.pending_discoveries` エントリ削除をステージしている場合は、それも同一 commit に含める（モード G G-6 が ingest 本体呼び出し前後にステージする・「ingest と候補削除を同一 commit」契約の担保）。上記 migration_pending / overview と同じく「呼び出しコンテキスト由来の付随ステージ変更を per-source commit に同梱する」一般規約として扱う。
   - ボールト側 Git に操作単位でコミット。

10. **lock 解放**（ステップ 0.6 の手順）。例外時も `trap` 相当で削除を試みる。

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

**lock**: ステップ 0.5 直後に**取得**（ステップ 0.6 参照）、最終コミット後に解放する。

0. **lock 取得**（ステップ 0.6 の手順）。
1. `wiki/index.md` → テーマ関連ページ群を選択読込。
2. `references/page-templates.md` の `synthesis` 雛形に従い
   `wiki/syntheses/<slug>.md` を生成、または既存があれば再生成する。
   フロントマターは `references/schema.md` §2 に従い充填。
3. すべての項目は元 Wiki ページ/raw を引用する。Wiki 外で補完した箇所は
   **`⚠️ Wiki 外（Web 検索）`** と明示し、ingest を提案する。
3.5. **overview 自動更新（Phase 3d・C）**: モード B step 8.5 と同じ仕様（`references/schema.md` §8）。統計 5 件 + 2 日付を計算し `wiki/overview.md` の `## 現状` セクションを Read、全値同値なら Edit を skip し log.md に `overview unchanged (<日付>)` を追記、差分があれば Edit して step 4 のコミットに同梱する。境界判定失敗時は skip + log warning。
4. `wiki/index.md` のサマリ更新・`wiki/log.md` 追記・ボールト側 Git コミット（overview Edit が発生していれば同一 commit に含める）。
5. **lock 解放**（ステップ 0.6 の手順）。

---

## モード L: /llm-wiki lint [--check=<csv>]

Phase 2a 機械判定 7 検査（#1 孤立 / #2 更新日 30 日超 / #3 `claude_code_version` 乖離 /
#4 `stale:true` 監査 / #6 信頼度 / #7 index 同期 / #9 `current-baseline.md` 鮮度）に加え、
**Phase 2b 意味解釈 4 検査**（#5 cross-topic / #8 synthesis-stale / #10 three-way /
#11 version-resolve、うち #11 は AskUserQuestion 承認制で `## 矛盾` 末尾に決着注記を追記）と、
**Phase 3a/3c 機械判定 2 検査**（#12 last-tier-a-refresh / #13 last-discover-tier-a-run、いずれも書き込みなし）を実行する。

**書き込みは `wiki/log.md` への結果サマリ追記＋ #11 承認時のみ `## 矛盾` 末尾 1 行追記のみ**。
本文・フロントマター・index.md への自動補完は一切しない（不変条件「黙って上書きしない」）。

**lock 扱い**（design.md §6 carve-out）: 通常 lint（12 検査レポート＋ log.md 追記まで）は lock を **取得しない**（log.md は append-only で refresh と並行しても順序問題のみ・実害なし）。**#11 承認制決着の `## 矛盾` 編集部分のみ**ステップ 0.6 の lock を取得し書き込み完了後に解放する。

### 書き込み副作用境界（13 検査 × 書き込み有無 × lock）

| # | id | 書き込み | lock |
|---|----|---------|------|
| 1 | orphan | なし（対話レポート＋log.md 集計のみ） | 不要 |
| 2 | updated | なし | 不要 |
| 3 | version | なし | 不要 |
| 4 | stale | なし | 不要 |
| 5 | cross-topic | なし | 不要 |
| 6 | confidence | なし | 不要 |
| 7 | index | なし | 不要 |
| 8 | synthesis-stale | なし（detail に手動再生成コマンドを併記） | 不要 |
| 9 | baseline | なし | 不要 |
| 10 | three-way | なし | 不要 |
| 11 | version-resolve | **承認時のみ** 該当ページ `## 矛盾` 末尾に 1 行追記＋ log.md に決着行追記 | **取得**（決着適用部分のみ） |
| 12 | last-tier-a-refresh | なし | 不要 |
| 13 | last-discover-tier-a-run | なし | 不要 |

検査項目の判定ロジック・しきい値・走査戦略・`## 矛盾` パース仕様・決着注記の正規記法は
`references/lint-rules.md` を参照（SKILL.md では再記述しない）。

1. **引数パース**
   - 第 2 トークン以降から `--check=<csv>` を抽出。`<csv>` は
     `orphan|updated|version|stale|confidence|index|baseline|cross-topic|synthesis-stale|three-way|version-resolve|last-tier-a-refresh|last-discover-tier-a-run`
     のサブセット（カンマ区切り）。
   - 未指定なら全 13 検査。未知キーはエラーで中断し、上記 13 キー一覧を案内。

2. **ステップ 0.5 ボールト前提チェック**を継承（init 以外と同じ手順）。**ステップ 0.6 lock は通常 lint では取得しない**（design.md §6 carve-out）。

2.5. **migration_pending 提案**（書き込み前・通常 lint 検査群の手前。Phase 3d 共通 surface 経由に再定義）:
   - `Read("./wiki-vault/wiki/current-baseline.md")` でフロントマター `migration_pending` を取得（後続の走査で再利用するためメモリ保持）。
   - 配列が空なら通常検査群（ステップ 3）に進む。非空なら以下の AskUserQuestion を起動:
     - `question`: 「Tier A docs ホスト移転を承認しますか？」
     - `options`: 各 `migration_pending` エントリ 1 件ごとに `<source_slug>: <old_url> → <new_url>` ラベル、および**「適用しない」を必ず併置**（候補 1 件のときも・Phase 2b 振り返り由来）。
     - `multiSelect: true`、候補 5 件超は `detected_on` 古い順で上位 4 件に絞り、残りは次回提示。
   - 承認分の処理（**Phase 3d 共通 surface 経由**・旧仕様「URL 書き換え単独」は廃止）:
     - (i) 承認された各エントリの `new_url` を**モード B（ingest）の共通 surface に渡して新規 raw を ingest する**。モード B step 3.5 の同一 source 判定 (ii) が `migration_pending[].new_url` 一致を検出し、旧 source ページに統合（新 raw＝`source_url`=new_url を sources: 末尾 append することで F-3 走査が以降 new_url を最新 URL として解決する＝**source ページ自身に `source_url` フィールドは無いため書き換えは不要**、再コンパイル、`updated` 進行、tier 不可触、title 等の手動編集領域は不可触）＋当該 migration_pending エントリ削除（モード B step 6 内・anchor 戦略はモード B 内に記載）＋ 1 commit が成立する。
     - (ii) 当該 raw の `source_url` は変更しない（raw 不変条件 E1）。旧 raw（old_url 由来）は不変保持され、新 raw のみ追加される。
     - (iii) モード B が `.llm-wiki.lock` の取得・解放を自身で行うため、本サブステップで lock 取得は不要。モード B が 1 ソース 1 commit を `chore: migrate source_url <slug> <old>→<new>` 相当のメッセージで作成する（共通 surface (ii) ケース判定の commit メッセージはモード B 内で決まる）。
   - 0 件選択は何もせず通常検査群へ進む。

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
     - **#12 用**: 既存の `current-baseline.md` Read を再利用する（追加 Read 0 回）。
     - **#13 用**: 同じく既存の `current-baseline.md` Read を再利用する（追加 Read 0 回・`last_discover_tier_a_run` フィールドを参照）。
   - 以上のデータをメモリ上の集約マップに保持し、以降は追加 Read を行わない。

4. **検査実行**
   - `references/lint-rules.md` の判定ロジック節（Phase 2a 7 検査 + Phase 2b 4 検査 + Phase 3a #12）に従い、
     `--check` で指定された検査を実行。severity は「要対応 / 警告 / 情報」の 3 段。
   - **#5 / #8 / #10 / #12 / #13 はレポートのみ**。
   - **#11 は候補検出後にステップ 8 の承認制 UX を起動**（書き込みは承認後のみ）。

5. **対話出力**
   - Markdown 表（カラム: file / check / severity / detail）で全 13 検査の結果を統合出力。

6. **`wiki/log.md` 追記**
   - `### lint 結果（YYYY-MM-DD HH:MM）` セクションを追記。
   - severity 別集計（要対応 N / 警告 M / 情報 K）と検査別件数を 1 行ずつ記録:
     `検査別件数: orphan=A, updated=B, version=C, stale=D, confidence=E, index=F, baseline=G, cross-topic=H, synthesis-stale=I, three-way=J, version-resolve=K, last-tier-a-refresh=L, last-discover-tier-a-run=M`
   - 全件詳細は対話のみ（log.md 肥大化防止）。

7. **レポートコミット**
   - ボールト Git で `wiki/log.md` の差分のみを `git add` し
     `chore: llm-wiki lint (YYYY-MM-DD)` でコミット。
   - lint は他のファイルを変更しないため、log.md 以外の差分は発生しない。
     もし発生していたら不変条件違反としてユーザーに報告し中断（自動書き込みの取り残し検知）。

8. **#11 承認制 UX**（候補が 1 件以上ある場合のみ）

   ステップ 5–7 の検査全件レポート出力＋レポートコミット**後**に起動する。

   **overview 更新なし（Phase 3d）**: 本サブステップは `## 矛盾` 末尾 1 行追記＋ log.md 決着行追記のみで、`wiki/overview.md` は不可触（source ページ統計に変化なしのため。`references/schema.md` §8.4 更新タイミング表参照）。書き込みモードであっても overview 自動更新は走らない。

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
| `--check` 未知キー | 中断し 12 キー一覧を案内 |
| フロントマター YAML パース失敗 | 該当ページのみ「要対応: フロントマター不正」表示し他検査継続 |
| `sources:` 空 | 「要対応: sources 空（schema.md §2 違反）」表示 |
| `current-baseline.md` 不在 | #3/#9/#12 をスキップ |
| ボールト未コミット変更あり | AskUserQuestion で続行可否 |
| `## 矛盾` セクション構造不正（grep ヒットだが Read で該当行なし） | 「要対応: ## 矛盾 セクション構造不正」表示、他検査継続 |
| #10 で本リポジトリ側 3 文書のいずれかが Read 不能 | #10 をスキップし要対応表示 |
| #11 候補ページが Read できない | 該当候補のみスキップ、他候補は続行 |
| AskUserQuestion で 0 件選択 | 追記なし・コミットなしで終了 |
| #11 候補が 5 件超 | 上位 4 件のみ承認確認、残りは次回 lint で再検出 |
| `## 矛盾` 末尾に既に「**決着（**」行がある | 二重追記を回避してスキップ |
| #8 で synthesis の `sources:` が空 | Phase 2a `sources:` 空エラー扱いに委ね、#8 はスキップ |
| #12 `last_tier_a_refresh` 未設定 / parse 不能 | 要対応として個別レポート、他検査継続（詳細は `references/lint-rules.md` §Phase 3a 追加） |
| `migration_pending` が YAML として parse 不能 | 「要対応: current-baseline.md の migration_pending 破損」を表示し、本フローはスキップして通常検査群へ進む |

---

## モード F: /llm-wiki refresh-tier-a [--dry-run]

Tier A（公式 docs / 公式 GitHub）ソースの**日次自動再取得**を行う非対話モード。`launchd` / `cron` から
`claude --print '/llm-wiki refresh-tier-a' --allowedTools=Read,Write,Edit,Bash,Grep,Glob,WebFetch` 形式で起動される。**AskUserQuestion は一切起動しない**（対話シェルから force-run でも同じコードパス）。

**lock**: ステップ F-1 で取得、ステップ F-7 で解放。

### F-1. lock 取得

ステップ 0.6 の atomic 取得手順に従い `mode: refresh-tier-a` で取得。失敗時は `wiki/log.md` に
`refresh-tier-a: locked, skipped (YYYY-MM-DD)` を 1 行追記し `exit 0`。スタール判定で奪取した場合は
`refresh-tier-a: stale lock recovered (pid=X, started=Y)` を追記してから F-2 へ進む。

### F-2. vault dirty-state チェック

`Bash("git -C ./wiki-vault status --porcelain -- ':!wiki/log.md'")` の出力が**非空**なら、`wiki/log.md` に
`refresh-tier-a: vault dirty, skipped (YYYY-MM-DD)` を追記、log.md だけの 1 commit `chore: log refresh-tier-a skipped (dirty)` を作成し、lock を解放して終了（stash / 自動 commit 禁止）。

**Phase 3d（F-3）修正**: 判定式は git pathspec `:!wiki/log.md` で `wiki/log.md` のみを除外する。log.md は schema.md §3「log.md dirty 状態 append 規約」で agent 完全所有・追記のみと規定されており、dirty 状態でも append + commit 可。これにより skip 時の log append commit が成功し、dirty escalation ループ（log.md 追記が次回 refresh で dirty 検知して skip → さらに append → …）が解消される。`grep -v 'wiki/log.md'` ベース実装は `wiki/log.md.bak` 等の false negative を生むため pathspec exclusion を採用する。

> **F-3 と F-4 の独立論点訂正**（2026-05-24 brainstorm の旧フレーミングを 2026-05-29 brainstorm で訂正）: F-3 は cron dirty escalation の特殊事象（本 F-2 で単独解消）、F-4 は通常 ingest と同じ append 規約（モード B 共通 surface で扱う）。両者は独立論点であり「同じ log.md append 規約として束ねる」旧フレーミングは廃止。

### F-3. 対象 Tier A ソース集合の決定

`references/schema.md` §2.1 / §3 の規約に従って次の手順で機械的に決める（シードリスト/別途のクロール設定は持たない）:

1. `Glob('./wiki-vault/wiki/sources/*.md')` でページ列挙、各ページを `Read(offset=0, limit=50)` でフロントマター取得。
2. フロントマター `tier: A` のページのみ候補。
3. 各候補ページの `sources:` 末尾（ファイル名プレフィックス `YYYY-MM-DD` が最大のもの）を最新 raw として解決。
4. 当該 raw のフロントマター `source_url` を取得。`source_url` が無い／`tier: A` でない raw は skip＋log `(refresh-tier-a: no source_url <slug>)`。
5. 結果は `(source_slug, latest_raw_path, source_url)` の三つ組リスト（`source_slug` の ASCII 昇順で決定論的に並べる）。
6. **孤立 raw**（対応する source ページが無い）は対象外。lint #1 と責務分離。

### F-4. per-source ループ

各三つ組について以下を順に実行（失敗ソースは skip＋log し commit せず次へ・**`git push しない`**）:

**F-4a. 取得（経路 routing）**:
- `source_url` が `https://github.com/{owner}/{repo}/blob/{ref}/{path}` パターンにマッチする場合は **gh api 経路** を使う（WebFetch では JS レンダリング前の HTML シェルしか返らず本文取得不能なため）:
  - `Bash('gh api "repos/{owner}/{repo}/contents/{path}?ref={ref}" --jq .content | base64 -d')` を実行。`{ref}` はブランチ名／タグ名／sha のいずれでもよい。
  - 取得経路フラグ `fetch_method = gh-api` を立て、F-4c のフロントマター生成に伝搬する。
  - 失敗時はそのソースを skip し `wiki/log.md` に `fail <slug>: <error>` 行を追記、次のソースへ（gh CLI 未インストール／`gh auth` 切れ／404 などはエラーハンドリング表参照）。
- それ以外の URL は **WebFetch 経路**:
  - `WebFetch(source_url, "<取得テキスト全文を要約せず可能な限り原文に近い形で抽出>")` を試行。
  - 取得経路フラグ `fetch_method = webfetch` を立てる。
  - 失敗時はそのソースを skip し `wiki/log.md` に `fail <slug>: <error>` 行を追記、次のソースへ。

**F-4b. 301 リダイレクト検出**（WebFetch 経路のみ発火・gh api 経路では skip）:
- 取得結果のメタが redirect を示す or status が 301 の場合:
  - `current-baseline.md` フロントマター `migration_pending` を Read。
  - 当該 `source_slug` のエントリが**既に存在**すれば skip＋ log `(suppressed: pending migration <slug>)`。再 append しない。
  - 存在しなければ `migration_pending` に 1 エントリ append: `{old_url: source_url, new_url: <リダイレクト先>, detected_on: <今日>, source_slug: <slug>}`。
  - `current-baseline.md` を 1 commit `refresh(tier-a): migration_pending append <slug>`。
  - 当該ソースの本文再コンパイルは行わず次のソースへ（古い URL のままで運用継続）。

**F-4c. 通常取得成功時の raw 追加保存**:
- 保存先: `raw/<種別>/<取得日 YYYY-MM-DD>-<slug>.md`（種別は raw の既存配置に揃える。docs / articles / github 等）。
- 既存ファイル**上書き禁止**（E1 不変条件）。同日 2 回目以降は末尾に `-2`, `-3`, ... の連番を付与:
  - `Bash('ls ./wiki-vault/raw/<種別>/<取得日>-<slug>*.md 2>/dev/null | wc -l')` で件数を取得し、`N>0` なら `<slug>-(N+1)` を使う。
- フロントマター: `source_url` / `fetched_at` / `tier: A` を必ず記録。`fetched_via` と `note` は F-4a の取得経路で分岐:
  - `fetch_method = webfetch` の場合: `fetched_via: WebFetch` / `note: WebFetch 要約（逐語性ポリシーは memory/webfetch-raw-snapshot-policy.md 参照）`
  - `fetch_method = gh-api` の場合: `fetched_via: "gh api repos/{owner}/{repo}/contents/{path}?ref={ref} (verbatim / 逐語コピー)"` / `note: "原文逐語スナップショット（gh api 経由で base64 デコード）。要約ではない。再検証は source_url を参照。"`

**F-4d. 差分判定**:
- 新 raw の `fetched_at` > 該当 `wiki/sources/<slug>.md` の `updated` なら **F-4e 再コンパイル**へ進む。
- 等しい／古い場合は raw 追加のみで wiki 更新スキップ。`wiki/log.md` に `unchanged <slug>` を追記。

**F-4e. 再コンパイル**:
- 既存 `ingest`（モード B）と同じ「**同一トピック [[wikilink]] 先のみ照合**・矛盾は `## 矛盾` 追記」の経路を踏襲。横断矛盾は lint #5 委譲。
- `wiki/sources/<slug>.md` のフロントマター `claude_code_version` / `updated` を新 raw の値で更新。
- **sources: 末尾 append（F-6・時系列保証）**: 新 raw のパスを `wiki/sources/<slug>.md` のフロントマター `sources:` 末尾に append（モード B step 6 共通 surface 追記事項と同じ仕様）。既存 raw は不変保持で削除・並べ替えしない。
- 本文は最小改変（要約差分の反映のみ）。`confidence` は維持（既存値を尊重）。

**F-4f. current-baseline.md の baseline フィールド更新**:
- 当該ページに `claude_code_version` 更新が含まれていれば `current-baseline.md` の `claude_code_version` / `updated` を更新。
- **`schema_version` / `schema_repo_commit` / `schema_summary` は不可触**（schema 軽量ポインタは co-evolution 経路のみ）。

**F-4g. overview 自動更新（Phase 3d・C）**:
- モード B step 8.5 と同じ仕様（`references/schema.md` §8）。
- 統計 5 件 + 2 日付を計算し `wiki/overview.md` の `## 現状` セクションを Read。**全値同値なら Edit を skip し** log.md に `overview unchanged (<日付>)` を 1 行追記。1 つでも差分があれば Edit。
- 境界判定失敗時は skip + log warning。`--dry-run` では Edit / commit せず `would-update overview <fields>` をレポート。

**F-4h. per-source commit**:
- ボールト側 Git で当該ソース関連の差分（raw 追加・wiki/sources/<slug>.md 更新・overview 更新があれば含む）のみを `git add` し、`refresh(tier-a): <slug> at <取得日>` でコミット。
- **`git push しない`**。

### F-5. 全ソース処理後の last_tier_a_refresh 更新

- `current-baseline.md` フロントマターの現在の `last_tier_a_refresh` を Read。
- **値が本日付と等しい場合**（同日 2 回目以降の force-run）: Edit / commit を**スキップ**し、`wiki/log.md` に `last_tier_a_refresh unchanged (<date>)` を 1 行追記して F-6 へ進む（空 commit ガード）。
- **値が本日付と異なる場合**: フロントマターを本日付に Edit。**さらに overview 自動更新を inline で実行**（モード B step 8.5 と同じ仕様・値変化ガード付き）。両編集を 1 commit `refresh(tier-a): last_tier_a_refresh = <date>` に同梱する（F-4g の per-source commit が既に overview 値を最新化している可能性があるため、F-5 では値変化ガードで skip されるのが典型ケース）。
- `--dry-run` モードではいずれの分岐も commit を行わず、`would-update last_tier_a_refresh <old> -> <today>` または `last_tier_a_refresh unchanged (<date>)` を標準出力にレポートするのみ（overview の差分予測も含める）。

### F-6. サマリ追記

- `wiki/log.md` に 1 行 `refresh-tier-a: ok=N skip=M fail=K (YYYY-MM-DD)` を追記。
- 1 commit `chore: log refresh-tier-a summary`。

### F-7. lock 解放

ステップ 0.6 の解放手順に従う。例外時も `trap` 相当で削除を試みる。

### `--dry-run` モード

- F-1（lock 取得）/ F-2（dirty-state）/ F-3（対象集合決定）を実行。
- F-4 ループは **per-source の判定結果**（`unchanged` / `would-update` / `would-append-migration-pending` / `fail 予測`）を**標準出力にレポート**するのみ。
- **raw 追加・wiki 更新・current-baseline 更新・git commit を一切行わない**。
- F-5 / F-6 の commit も行わない。
- F-7 lock 解放のみ実行（dry-run でも並行実行禁止）。

### モード F のエラーハンドリング

| 事象 | 扱い |
|------|------|
| `.llm-wiki.lock` を他プロセスが取得済み（生存中） | F-1 で skip log を追記して終了 |
| `.llm-wiki.lock` がスタール（1h 経過＋`kill -0` fail） | 強制奪取し `stale lock recovered` ログ追記して通常実行 |
| vault dirty | F-2 で `vault dirty, skipped` ログ追記して終了（lock 解放） |
| WebFetch 失敗（個別ソース） | F-4a で当該ソース skip、log に `fail <slug>: <error>` 行 |
| `gh: command not found`（gh CLI 未インストール） | F-4a gh api 経路で当該ソース skip、log に `fail <slug>: gh CLI not installed` 行。launchd `EnvironmentVariables` の `PATH` に `gh` を含めるよう案内 |
| `gh auth status` 失敗（認証切れ／token 失効） | F-4a gh api 経路で当該ソース skip、log に `fail <slug>: gh auth required` 行。次回 refresh 前に対話セッションで `gh auth login` |
| gh api が 404（ref／path 不在・リポジトリ rename） | F-4a gh api 経路で当該ソース skip、log に `fail <slug>: gh api 404 <ref>/<path>` 行。連続 fail の場合は手動で source ページの `sources:` 末尾の `source_url` を新パスへ更新 |
| 301 リダイレクト（WebFetch 経路のみ） | F-4b で `migration_pending` append（既出はサプレッション）、当該ソース再コンパイルなし。gh api 経路では F-4b 自体が発火しない |
| 同日 raw 衝突 | F-4c で `-2, -3, ...` 連番付与（既存上書き禁止） |
| `last_tier_a_refresh` 既に本日付（同日 2 回目以降の force-run） | F-5 で Edit / commit を skip し log に `last_tier_a_refresh unchanged (<date>)` を 1 行追記して F-6 へ（空 commit ガード） |
| 再コンパイル中の wikilink 解決例外 | 当該ソース skip し log に `recompile fail <slug>` 行 |
| `current-baseline.md` Read 失敗（破損） | 全実行中止し log に `baseline unreadable, aborted` 追記、lock 解放 |
| `migration_pending` YAML 破損 | `current-baseline.md` Read 失敗扱いに準じる |

### 対象規模・recurring cost

想定対象は Tier A 主要 docs ＋公式 GitHub リリースで一桁〜十数件。日次 WebFetch 10〜15 リクエスト/日。
Phase 3a では per-source の weekly/daily 切替は実装しない。

---

## モード G: /llm-wiki discover-tier-a [--no-prompt|--dry-run]

Tier A 公式 docs / 公式 GitHub の**未取り込み URL を自動発見**し、`current-baseline.md` の `pending_discoveries[]` に登録、承認制で**共通 surface（モード B）経由 ingest** する。手動 `ingest` の初期登録コストを下げるのが目的（Phase 3c）。

**discovery scope = α 厳格（CLI 中心）**:
- **docs**: `https://code.claude.com/docs/en/*`（英語のみ・`agent-sdk/*` 含む。翻訳版 11 言語は除外）
- **GitHub**: `anthropics/claude-code` repo **ルートの `CHANGELOG.md` + `README.md`**（repo に `docs/` は存在しない＝公式 docs は `code.claude.com` に移管済。`plugins/**` / `examples/**` は本 phase 対象外）
- **β/γ scope**（`platform.claude.com/docs/en/api/*` 1422 URL・Agent SDK 別 repo 等）は本 phase 対象外。手動 `ingest` 経路で対応。

**discovery scope ≠ refresh scope（Y 案）**: discover-tier-a は発見 + 候補リスト化 + 承認制 ingest のみ。`refresh-tier-a`（モード F）の §F-3 対象集合は**不可触**。発見 URL は承認 → モード B ingest → `wiki/sources/<slug>.md` 作成 → §F-3 の対象集合決定で初めて refresh 対象になる。この順序で Phase 3a の cost assumption（日次 10〜15 req）は崩れない。

**実行モード**:

| モード | フラグ | 動作 | 想定起動元 |
|--------|--------|------|-----------|
| 既定（対話） | なし | discovery → append → AskUserQuestion 承認 → 共通 surface ingest | 対話シェル |
| 非対話 | `--no-prompt` | discovery → append のみ。AskUserQuestion 不発火・ingest なし | launchd / cron |
| dry-run | `--dry-run` | discovery レポートのみ。pending_discoveries / last_discover_tier_a_run 更新も skip・副作用ゼロ | 対話シェル（preview） |

`--no-prompt` と `--dry-run` は併用可（discovery 結果のみレポート・副作用ゼロ）。

**lock**: ステップ G-1 で取得、ステップ G-8 で解放。ingest 中も mode G が lock を保持し続ける（G-6 はモード B の **ingest 本体 step 3〜9 のみ**を呼び、モード B の step 0 lock 取得 / step 10 lock 解放は呼ばない＝lock 再入防止）。

### G-1. lock 取得

ステップ 0.6 の atomic 取得手順に従い `mode: discover-tier-a` で取得。失敗時は `wiki/log.md` に `discover-tier-a: locked, skipped (YYYY-MM-DD)` を 1 行追記し終了。スタール判定で奪取した場合は `discover-tier-a: stale lock recovered (pid=X, started=Y)` を追記してから G-2 へ。

### G-2. vault dirty-state チェック

モード F の F-2 と同じ判定式 `Bash("git -C ./wiki-vault status --porcelain -- ':!wiki/log.md'")` を使う（log.md は agent 完全所有・追記のみのため除外）。出力が**非空**なら `wiki/log.md` に `discover-tier-a: vault dirty, skipped (YYYY-MM-DD)` を追記、log.md だけの 1 commit を作成し、lock を解放して終了（stash / 自動 commit 禁止）。

### G-3. discovery（sitemap + gh api fetch）

- **docs**: `Bash("curl -sL --max-time 30 https://code.claude.com/sitemap.xml")` で sitemap XML を取得し、`<loc>` タグを抽出して `https://code.claude.com/docs/en/` で始まる URL のみフィルタ（翻訳版除外）。**WebFetch は sitemap.xml を要約してしまうため使わない**（curl で逐語取得）。
- **GitHub**: `Bash("gh api repos/anthropics/claude-code/git/trees/main?recursive=1 --jq '.tree[] | select(.type==\"blob\") | .path'")` で全 path を列挙し、**repo ルートの `CHANGELOG.md` と `README.md` のみ**抽出（`docs/` は repo に存在しないため対象外・`plugins/**` / `examples/**` / `.claude/**` は除外）。URL 化規約は `https://github.com/anthropics/claude-code/blob/main/{path}`（`main` 決め打ち）。
- いずれかの経路が失敗しても他経路は続行（gh api 失敗でも docs 側は続行・エラーハンドリング表参照）。
- **キャッシュは持たない**（起動の度に毎回 fetch・α scope は docs 142 + GitHub 2 件で recurring cost は許容範囲）。

### G-4. 突合 + 正規化

- 既存 `Glob("./wiki-vault/wiki/sources/*.md")` の各 source ページについて、**モード F F-3 step 1〜4 と同じ走査**で既存 URL を解決する: 各ページのフロントマター `sources:` 末尾（`YYYY-MM-DD` プレフィックス最大）の raw を Read し、その raw のフロントマター `source_url` を取得して既存 URL 集合に入れる。`source_url` を欠く raw は skip。**source ページ自身のフロントマターに `source_url` は無い**（schema §2 共通フィールドに含まれず、`source_url` は raw のフロントマターキー＝schema §3）ため、source ページから直接読まず必ず raw を辿る（旧記述「各ページ `source_url`（フロントマター）を収集」は誤りで、Phase 3c carve-out 実機検証で既存集合が空になり取り込み済み URL が誤って再候補化するバグを修正）。
- `current-baseline.md.pending_discoveries[]` と `current-baseline.md.migration_pending[].new_url` を Read。
- **URL 正規化規約は モード B step 3.5 を参照**（Phase 3d 最小ルール: host lowercase + 末尾スラッシュ除去のみ）。フル仕様（tracking param 除去・フラグメント除去・http→https 強制等）は Phase 3e で本格設計する（脚注）。
- 発見 URL を正規化し、`既存 source_url` ∪ `migration_pending.new_url` に含まれるものを除外 → **未取り込み候補集合**。両集合とも正規化後に突合する。

### G-5. pending_discoveries append（dedup ルール）

- `current-baseline.md.pending_discoveries[]` を Read。
- 未取り込み候補のうち、既存 `pending_discoveries[].url`（正規化後）に**含まれないもののみ** append（**dedup キー = 正規化後 url**）。
- **既存エントリありなら append skip**（`detected_on` は古い方を保持＝最初に発見した日付）。これにより cron で日次 `--no-prompt` 起動しても sitemap 不変なら 1 度 append すれば以後は no-op となり、**リスト爆発を防ぐ**。
- エントリ形式: `{url: <正規化後 URL>, source_kind: docs|github, detected_on: <今日>}`（`references/schema.md` §2.1）。
- append 後の配列で `current-baseline.md` を Edit。
- **`--no-prompt` の場合**: ここまでで **1 commit `chore: discover-tier-a: N new candidates (YYYY-MM-DD)`** に集約（per-URL commit にしない・migration_pending append 流儀と整合）。その後 G-7 へ（G-6 の ingest は skip）。
- **`--dry-run` の場合**: Edit / commit せず `would-append <url>` を標準出力にレポート。

### G-6. 共通 surface ingest（既定モードのみ）

`--no-prompt` / `--dry-run` では本ステップを skip。

1. `pending_discoveries[]` から `detected_on` ASC → URL ASCII 昇順 fallback で**上位 4 件**を抽出。
2. **AskUserQuestion**（`multiSelect: true`）で提示:
   - `question`: 「Tier A 未取り込み URL を ingest しますか？（適用したい URL を選択。何も選ばなければ ingest なしで終了）」
   - `options`: 候補ごとに `<source_kind>: <url>` ラベル、および**「適用しない」を必ず併置**（モード B 0.b / モード L §2.5 の migration_pending 提案と同流儀）。
   - 残り（5 件目以降）は次回 discover-tier-a 起動時に再候補化（対話レポートに明示）。
   - 0 件選択（適用しない）は ingest 実行なし・pending_discoveries 不変で G-7 へ。
3. 承認分の各 URL について、**モード B の ingest 本体（step 3 raw 確保 〜 step 9 commit、step 0 lock / step 10 解放は除外）**を内部呼び出し:
   - モード B step 3.5 の同一 source 判定は (i) 既存 source 統合 or (iii) 新規 source 作成に分岐（(ii) migration_pending 経路は G-4 突合で除外済のため発生しない）。
   - モード B 内の AskUserQuestion 系（step 4 既出チェック・step 5 要点確認）はそのまま発火（多段確認は許容）。
   - **ingest 成功時**: 当該 URL の `pending_discoveries[]` エントリ削除を Edit でステージし、**モード B step 9 の per-source commit に同梱**（モード B 既存の「付随ステージ変更を同一 commit に含める」枠組みを利用・migration_pending 削除と同じ機構）。これにより「ingest と候補削除が同一 commit」を保ち中間状態を作らない。
   - **ingest 失敗時**: 当該 URL は `pending_discoveries[]` に残置、log に `fail <url>: <error>` 行を追記し次の URL へ。
4. overview 自動更新は G-6 内で呼ぶモード B step 8.5 が担当する（mode G 単独の overview 更新 step は持たない）。

### G-7. last_discover_tier_a_run 更新

- `current-baseline.md.last_discover_tier_a_run` を Read。
- **本日付と異なる場合**: 本日付に Edit + 1 commit `chore: discover-tier-a: last_discover_tier_a_run = <date>`。
- **本日付と同じ場合**（同日 2 回目以降）: Edit / commit を skip し `wiki/log.md` に `last_discover_tier_a_run unchanged (<date>)` を 1 行追記（値変化ガード・空 commit 回避・モード F F-5 同流儀）。
- **`--dry-run` の場合**: いずれも commit せず `would-update last_discover_tier_a_run <old> -> <today>` または `unchanged (<date>)` をレポート。

### G-8. サマリ追記 + lock 解放

- `wiki/log.md` に 1 行 `discover-tier-a: found=N appended=A ingested=I skipped=S (YYYY-MM-DD)` を追記し 1 commit `chore: log discover-tier-a summary`。
- ステップ 0.6 の解放手順に従い lock を解放。例外時も `trap` 相当で削除を試みる。

### `--dry-run` モード

- G-1（lock）/ G-2（dirty）/ G-3（discovery）/ G-4（突合）を実行。
- G-5（append）は `would-append <url>` レポートのみ（Edit / commit なし）。
- G-6（ingest）は skip。
- G-7（last_discover_tier_a_run）は `would-update` / `unchanged` レポートのみ（Edit / commit なし）。
- G-8 は lock 解放のみ実行（dry-run でも並行実行禁止のため lock は取得する）。**raw 追加・wiki 更新・current-baseline 更新・git commit を一切行わない**。

### stuck candidates の扱い（既知の限界・Phase 3c）

`detected_on` ASC + 上位 4 件提示の組み合わせで、利用者が興味のない候補が首位に居座ると新規発見が表示されにくくなる。**3c では既知の限界として放置**する。対処したい場合は対話セッションで `current-baseline.md.pending_discoveries[]` から該当エントリを手動削除する。明示却下（negative cache）フラグの設計は Phase 3e 以降で検討。

### モード G のエラーハンドリング

| 事象 | 扱い |
|------|------|
| `.llm-wiki.lock` を他プロセスが取得済み（生存中） | G-1 で skip log を追記して終了 |
| `.llm-wiki.lock` がスタール（1h 経過＋`kill -0` fail） | 強制奪取し `stale lock recovered` ログ追記して通常実行 |
| vault dirty（log.md 以外） | G-2 で `vault dirty, skipped` ログ追記して終了（lock 解放） |
| `curl` sitemap 5xx / timeout | docs 経路を skip + log `discover-tier-a: sitemap fetch failed`、GitHub 経路は続行 |
| sitemap XML パース失敗（`<loc>` 抽出 0 件） | 同上（docs 経路 skip） |
| `gh api` 失敗（auth / 404） | GitHub 経路を skip + log `discover-tier-a: gh api failed`、docs 経路は続行 |
| `gh: command not found`（gh CLI 未インストール） | GitHub 経路を skip + log `gh CLI not installed`。launchd `EnvironmentVariables` の `PATH` に `gh` を含めるよう案内 |
| `pending_discoveries` / `migration_pending` YAML 破損 | 全実行中止し log に `baseline unreadable, aborted` 追記、lock 解放（モード F の baseline 破損扱いに準じる） |
| 共通 surface（モード B）呼び出し失敗（個別 URL） | 当該 URL skip、pending_discoveries に残置、log に `fail <url>: <error>` 行、次の URL へ |
| AskUserQuestion 0 件選択（「適用しない」） | ingest 実行なし、pending_discoveries 不変、G-7 へ進む |
| `last_discover_tier_a_run` 既に本日付（同日 2 回目以降） | G-7 で Edit / commit を skip し log に `unchanged` 追記（空 commit ガード） |

### 対象規模・recurring cost（モード G）

docs 142 + GitHub 2 件を毎回 fetch。突合で未取り込みのみ候補化するため append は初回以降逓減する（dedup により定常状態では 0 件 append）。**`git push しない`**（モード F と同じく）。

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
| lint で `--check` 未知キー | 13 キー一覧を案内し中断 |
| lint 中にフロントマター YAML パース失敗 | 当該ページを「要対応: フロントマター不正」として個別レポートし他検査継続 |
| lint #10 で本リポジトリ側 3 文書が Read 不能 | #10 をスキップし要対応表示、他検査継続 |
| lint #11 で `## 矛盾` セクション構造不正 | 「要対応: ## 矛盾 セクション構造不正」表示、他検査継続 |
| lint #11 で AskUserQuestion 0 件選択 | 追記なし・コミットなしで終了（候補は対話レポートに残る） |
| lint #11 で `## 矛盾` 末尾に既に決着行あり | 二重追記を回避してスキップ |
| discover-tier-a の各事象（sitemap fetch 失敗・gh api 失敗・dirty・lock 競合・YAML 破損・共通 surface 呼び出し失敗等） | モード G「モード G のエラーハンドリング」表を参照 |

---

## co-evolution（schema 改訂時）

`references/schema.md` を改訂したら、同ファイル §5 の手順に従う
（`schema_version` 更新 → ボールト `current-baseline.md` の軽量ポインタ更新 →
ボールト `log.md` に `schema vN→vN+1: 要旨` 追記）。本ファイルは手順の所在を示すのみ。
