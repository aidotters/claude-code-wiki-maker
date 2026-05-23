# LLM Wiki Skill for Claude Code（Claude Code 知識の第二の脳）

> 作成日: 2026-05-16
> ステータス: Phase 1 MVP verified（2026-05-22）/ Phase 2a verified（2026-05-23）/ Phase 2b verified（2026-05-23）/ Phase 3・4 未着手
> 優先度: P1

## 概要

Karpathy の「LLM Wiki」パターン（検索ではなくコンパイル）を Claude Code スキルとして実装し、進化の速い Claude Code のベストプラクティス・公式更新・実践知見を、相互参照された永続的な知識ベースに蓄積・整理し続けるための個人 Wiki を構築する。蓄積した知識から「最新の Claude Code チートシート」「開発者向け Tips 集」等の派生成果物を生成・維持できることを中核目的とする。

**リポジトリの役割転換（決定 A）:** 本リポジトリは従来「新規プロジェクトの起点としてコピーして使うテンプレート」だったが、本機能の導入に伴い **個人の Claude Code 知識ハブ専用リポジトリ** へ役割転換する。llm-wiki が主役機能であり、`CLAUDE.md` の「テンプレート」定義および `README.md` を本リポジトリの新しい役割に合わせて書き換える（テンプレートとしてのコピー利用は前提としない）。既存のドキュメント生成系コマンド/スキル群（`gen-all-docs` 等）は知識ハブの運用補助として併存させる。

## 背景

### 現状の課題

- Claude Code（CLI / Agent SDK / API）は更新が速く、新機能・ベストプラクティスを追い続けるのが負担。
- 知識が公式ドキュメント・外部記事・YouTube・GitHub・自分の試行錯誤メモに散在し、必要なときに根拠を再発見するコストが高い。
- 通常のメモアプリや RAG はステートレスで、ソースを追加するたびに知識が「コンパイル」されず、矛盾や陳腐化が放置される。
- 古い情報（旧バージョン前提の Tips）と新しい情報が区別されず混在する。
- 「最新版のチートシート/Tips 集を作って」と指示しても、根拠付き・最新の派生成果物として生成・維持される仕組みがない。

### 解決したいこと

- ソースを取り込むたびに、要約・概念・エンティティ・実践知見ページが自動でコンパイル・相互参照される状態にする。
- 蓄積知識から、引用付きで最新のチートシート/Tips 集（synthesis）を生成し、再生成・健全性チェックの対象として維持する。
- 「なぜこの設定/パターンを採ったか」「どのバージョンで何が変わったか」が引用付きで即座に引ける。
- 帳簿管理（相互参照更新・陳腐化検出・矛盾検出）を Claude Code に委ね、人間は「何を取り込むか／何を問うか」に集中する。

## 解決策

### アプローチ

記事（Reza Rezvani: "LLM Wiki Skill — Build a Second Brain With Claude Code and Obsidian"）の設計を**設計図として参照しつつ、ゼロから自作**する。3 層アーキテクチャを厳守する。

1. **raw/** — 取得スナップショットとして不変保存（人間が追加、エージェントは読むだけ）
2. **wiki/** — エージェントが完全所有するコンパイル済み Markdown ページ群
3. **スキル（スキーマ）** — エージェントを規律あるメンテナーにする規約とワークフロー

Wiki の実体は**独立した Obsidian ボールト**（例: `~/Documents/claude-code-wiki`、別 Git でバージョン管理）に置く。Obsidian はグラフビュー/バックリンク/閲覧用の表示レイヤー。スキルは**本リポジトリ（個人 Claude Code 知識ハブ専用リポジトリ）のみ**に `.claude/skills/llm-wiki/` として実装し、**ユーザーグローバル配置やボールトへのコピーはしない**。本プロジェクトからボールトを参照するため、本プロジェクト直下にシンボリックリンク `./wiki-vault` を 1 本張る（実体は分離・論理的に参照可能）。スキルは単一スキル `/llm-wiki <操作>` として SKILL.md 内でモード分岐する（独立スラッシュコマンド・skill 同梱 hooks は作らない）。

```
# 想定ワークフロー（本プロジェクトで claude を起動。CWD ≠ ボールト）
cd ~/Projects/personal-wiki-for-claude-code
ln -s ~/Documents/claude-code-wiki ./wiki-vault   # 初回のみ（init が案内）
claude
> /llm-wiki init
> /llm-wiki ingest https://medium.com/.../some-claude-code-best-practice
> /llm-wiki query "Skill の description を確実にトリガーさせる書き方は？"
> /llm-wiki synthesize "最新の Claude Code チートシート"
> /llm-wiki lint
```

### 設計方針

1. **検索ではなくコンパイル**: 取り込み時に要約・相互参照・矛盾フラグを一度確定し、その後も維持する。
2. **3 層の厳密分離**: `raw/` は取得スナップショットとして不変保存（原文 URL・取得日時・取得手段をメタ保持し再検証可能）。すべての主張は特定の raw ソースを引用する。
3. **Claude Code 特化のスキーマ拡張**: 汎用5タイプ（source / concept / entity / comparison / synthesis）に加え、`practice`（試した実践とその効果）と `feature`（機能ごとの最新仕様まとめ）を追加。
4. **派生成果物の一級市民化**: チートシート/Tips 集は `/llm-wiki synthesize` で `wiki/syntheses/` に保存し、再生成・lint の対象とする。query（質問応答）とは目的を分離。
5. **陳腐化への強化**: フロントマターに `claude_code_version` を持たせ、ボールトの基準ファイル `wiki/current-baseline.md` と比較して陳腐化（バージョン乖離・更新日 30 日超）を検出。`current-baseline.md` は **Tier A（権威ソース）由来は自動更新を許容、手動上書き可**（C1 を改訂。従来の完全手動から変更）。**初期値は `/llm-wiki init` が公式 GitHub の最新リリースから確定する**（下記「current-baseline.md の初期化（決定 イ）」）。
6. **情報源ティア（決定）**: ソースを **Tier A（Anthropic 公式ドキュメントサイト / 公式 GitHub＝権威ソース）** と **Tier B（記事/動画/Notion/個人メモ等）** に区分し、フロントマターにティアを持たせる。
   - **Tier A**: 日次で自動再取得（raw に新スナップショット追加）→ 該当ページ再コンパイル → `current-baseline.md` 自動更新。E1（raw 不変）は「新しい取得日のスナップショットを *追加*、過去は消さない」ため維持される。
   - **Tier B**: (iii) を採用 — ingest 時にバージョン乖離を検知して `current-baseline.md` 更新を対話提案（承認制）＋ Phase 2 lint でベースライン鮮度を監査。手動主体。
   - **ロードマップ位置づけ**: 日次自動再取得＋自動再コンパイルは自律実行＋自動書き込みのため **Phase 3（運用自動化）で Tier A 限定の先行解禁**。MVP（Phase 1）は **ティア区分メタデータを持つところまで**で、自動更新本体は実装しない（ただし init の初期ベースライン取得は MVP で公式取得経路を一度通す。下記決定 イ）。
7. **個人利用前提**: 単一エージェント書き込み（マージ競合回避）、信頼度 0.7 程度を許容。
8. **フロントマター骨格は MVP から（決定 ア）**: 陳腐化・矛盾の **判定ロジック（lint）は Phase 2** のままだが、`claude_code_version` / `updated` / `stale` 等のフロントマター・フィールドは **MVP の ingest/synthesize 時点から全ページに埋める**。後付け移行は情報欠損で実質不可能なため、データ骨格だけ先行させて Phase 2 が過去ページにも効くようにする。
9. **リポジトリ役割の更新（決定 A）**: `CLAUDE.md` の「テンプレート」定義と `README.md` を「個人 Claude Code 知識ハブ」へ書き換える（`CLAUDE.md` は対応済み。後述）。`.claude/skills/*/SKILL.md` の記述粒度は既存 Skill 群と揃え、`README.md` の「含まれるもの」表は知識ハブ用途として再構成する。
10. **current-baseline.md の初期化（決定 イ）**: `/llm-wiki init` が `current-baseline.md` の初期 `claude_code_version` を確定する。方式は **(c) WebFetch 優先＋失敗時フォールバック**:
    - 公式 GitHub の最新リリース（`CHANGELOG.md`/Releases）を `WebFetch` で取得し、取得テキストを `raw/docs/<取得日>-claude-code-release.md` に保存（原文 URL・取得日時・取得手段・Tier A をメタ記録）。`current-baseline.md` はこの raw スナップショットを引用する（不変条件「すべての主張は raw を引用」を init でも満たす）。
    - 取得失敗（オフライン等）時のみ対話フォールバック（ユーザーに `claude --version` を案内して申告値をセット）。この場合は raw 引用が無いため `current-baseline.md` に「ソース: 手動入力（暫定）・取得日」と明記し、`stale:true` を立てて **次回オンライン時に Tier A 取得で上書き提案**する旨を記録する。
    - この経路は Phase 3 の Tier A 日次自動更新（取得 → raw 追加 → 再コンパイル → baseline 更新）と同一経路であり、init がその初回実行に相当する（実装の再利用性を担保）。
11. **schema の所在・共進化・責務境界（決定 ウ）**: Karpathy の gist では schema が「LLM を規律ある Wiki メンテナーにする生きた設定文書」として data と同一ボールトに同居・co-evolve する。本設計は schema 資産（`SKILL.md` / `references/schema.md`）を本リポジトリ（repo A）に置き raw/wiki を別ボールト（repo B）に置く分離を**維持**するが、Karpathy の「ボールト＝自己記述的」価値を保つため次を MVP 規約とする:
    - **schema の単一所有**: ページタイプ（5+2）・フロントマター必須フィールド・[[wikilink]]/命名/ディレクトリ規約の「正」は `references/schema.md` のみが持ち、`schema_version`（セマンティック版数）を持つ唯一の文書とする。`SKILL.md`・`CLAUDE.md` は schema 定義を**参照するのみで再記述しない**（再記述＝矛盾源）。
    - **ボールトへの軽量ポインタ**: ボールト側 `current-baseline.md` に `schema_version` / 本リポジトリの該当 commit ハッシュ / 規約 1〜2 行サマリを記録（全文複製はしない＝二重管理・矛盾を回避。単一真実源は常に repo A）。これにより repo B 単体でも「どの schema 版でコンパイルされたか」を repo A の commit へ追跡でき、自己記述性を回復する。
    - **co-evolution の追跡**: `schema.md` 改訂時は `schema_version` を上げ、ボールト側ポインタを更新し、ボールト `log.md` に「schema vN→vN+1: 変更要旨」を追記する（schema 進化を repo B 側からも辿れる）。この運用を MVP 規約として `SKILL.md`/`references/schema.md` に明文化する。
    - **責務境界（齟齬時の優先順）**: `CLAUDE.md`＝不変条件・運用ポリシー（「なぜ」「破ってはいけない原則」、最上位）／`SKILL.md`＝ワークフロー（モード分岐手順、ワークフロー変更は重い意思決定）／`references/schema.md`＝データ規約（「データの形」、co-evolution の主対象）。齟齬時は **CLAUDE.md > SKILL.md/schema.md** で CLAUDE.md 優先。Phase 2 lint はこの 3 面の相互矛盾も健全性チェック対象に含める。

### 代替案と比較

| 案 | メリット | デメリット | 採否 |
|----|---------|-----------|------|
| 記事を設計図にゼロから自作 | リポジトリ規約に合わせ込める／中身を完全理解できる | 実装工数が大きい | 採用 |
| 既存 `alirezarezvani/claude-skills` の llm-wiki を流用 | 最短で動く | テンプレート規約と乖離、理解が浅くなる | 不採用 |
| 独立コマンド `/wiki-*` + skill 同梱 hooks | 記事の構成に忠実 | Claude Code ではスキル/コマンド/Hooks は別レイヤー。Anthropic 推奨はスキル | 不採用（スキル一本化） |
| ボールトをこのコードベースに同居 / `.claude` をボールトに持たせる | Git 一元管理が楽 | Obsidian ボールトとして使いにくい／二重管理 | 不採用（シンボリックリンクで代替） |
| スキルのユーザーグローバル配置 | どこからでも `/llm-wiki` | 本プロジェクト限定にしたい意向に反する | 不採用 |

#### リポジトリの役割（テンプレート vs 知識ハブ）

| 案 | メリット | デメリット | 採否 |
|----|---------|-----------|------|
| (A) テンプレートをやめ、個人 Claude Code 知識ハブ専用リポジトリへ役割転換 | 「この特定リポジトリで `/llm-wiki` を使う」設計と整合。役割が明快 | `CLAUDE.md`/`README.md` の全面書き換えが必要。テンプレート用途は失う | **採用** |
| (B) テンプレートは維持し、llm-wiki はコピー時に除外する例外資産 | テンプレート用途を残せる | 例外管理が複雑（`/initial-setup` 除外ロジック等）、設計意図が二重化 | 不採用 |
| (C) llm-wiki もテンプレートの一部として配布、各プロジェクトが固有 Wiki を持つ | テンプレート用途を残せる | 「単一の個人ボールト」前提を放棄することになり中核目的とずれる | 不採用 |

## 実装する機能

### ロードマップ

| Phase | 機能 | 概要 |
|-------|------|------|
| 1 | `/llm-wiki init` `ingest` `query` `synthesize` + schema/templates | コア取り込み・問い合わせ・派生成果物生成（MVP・完了） |
| 2a | `/llm-wiki lint`（機械判定 7 検査・レポートのみ）＋ practice/feature テンプレ＋ ingest 動線拡張 | フロントマター集約とリンク突合で完結する健全性・陳腐化検査 |
| 2b | `/llm-wiki lint`（意味解釈 4 検査・承認制） | 横断的矛盾・synthesis 再生成要否・3 面相互矛盾・バージョン軸決着 |
| 3 | session-start hook（設定例）、URL 自動取得、overview 自動更新、**Tier A 日次自動再取得・再コンパイル・baseline 自動更新（先行解禁）** | 運用自動化 |
| 4 | ソース別取得ツール（X / Medium / Notion / 公式サイト等） | 取り込み拡充 |

> **Phase 2 を 2a/2b に分割した理由**: lint 検査 11 項目（`references/lint-rules.md`）のうち、フロントマター集約とファイル間突合で完結する機械判定系（#1/#2/#3/#4/#6/#7/#9）と、意味解釈が要る系（#5/#8/#10/#11）で実装難易度が大きく異なる。前者を 2a で先に出してドッグフーディングを開始し、後者は承認制 UX を含めて一括設計する（2b）。決定 Z 二段目（#5 横断矛盾）は受け入れ条件上 Phase 2 だったが、意味解釈系のため 2b に下ろす。

### 機能1: スキル本体（SKILL.md と規約）

`.claude/skills/llm-wiki/` に `SKILL.md` と `references/{schema.md,page-templates.md,lint-rules.md}` を配置（`commands/` は作らず SKILL.md でモード分岐。session-start hook は `references/` に **設定例** として記載し、Hooks レイヤーへの導入は利用者判断）。規約（raw 不変・必ず引用・[[wikilinks]]・全ページ YAML フロントマター・index/log 更新・操作ごと Git コミット・ボールトパスは設定ファイル参照）を明文化。

**schema の責務境界（決定 ウ）を明文化**: `references/schema.md` のみがページタイプ・フロントマター規約の「正」と `schema_version` を持ち、`SKILL.md`/`CLAUDE.md` は参照のみ・再記述しない。齟齬時の優先は CLAUDE.md（不変条件）> SKILL.md/schema.md。schema.md 改訂時は `schema_version` を上げ、ボールト側ポインタ（`current-baseline.md` の schema 欄）とボールト `log.md` を更新する co-evolution 規約を SKILL.md/schema.md に記載する。

### 機能2: 初期化（/llm-wiki init）

`./wiki-vault` シンボリックリンクの存在確認（無ければ実体パスを対話で確認し `ln -s` を案内・実行）→ ボールトに `raw/`・`wiki/`・`index.md`・`log.md`・`overview.md`・`wiki/current-baseline.md` を作成 → ボールト側 Git を初期化 → 本プロジェクトの `.gitignore` に `wiki-vault` を、設定ファイル（相対パス `./wiki-vault` と実体絶対パスを記録）を作成。

**`current-baseline.md` の初期 `claude_code_version` 確定（決定 イ・(c) 方式）**: init は公式 GitHub の最新リリース（`CHANGELOG.md`/Releases）を `WebFetch` で取得し、`raw/docs/<取得日>-claude-code-release.md` に保存（原文 URL・取得日時・取得手段・Tier A をメタ記録）。`current-baseline.md` はこの raw を引用してバージョンを確定する。取得失敗時のみ対話フォールバック（`claude --version` を案内して申告値をセット、`stale:true`＋「手動入力（暫定）」と明記し次回オンライン時に Tier A 取得で上書き提案）。この取得経路は Phase 3 Tier A 自動更新と同一経路で、init はその初回実行に相当する。

### 機能3: 取り込み（/llm-wiki ingest <path-or-url>）

ソース検証 → 全文読込・分析 → ユーザーと要点確認 → ページ作成/更新 → index.md / log.md 更新 → Git コミット。**矛盾検出は二段方式（決定 Z）**: ingest 時は新ソースが触れる concept/feature の [[wikilink]] 先（＝同一トピックの既存ページ）だけを照合し即時検出（全走査せずコンテキスト圧迫を回避）。トピックを跨ぐ横断的矛盾は index.md の主張サマリを使う Phase 2 lint の矛盾スキャンに委譲する。URL 指定時は取得テキストを `raw/<種別>/<取得日>-<slug>.md` に保存し、原文 URL・取得日時・取得手段をメタとして記録（E1: 取得スナップショット方式。公式ドキュメントも特別扱いせずリンク＋取得日付で保存し、必要時に読みに行く）。

### 機能4: 問い合わせ（/llm-wiki query <質問>）

index.md → 関連ページの順で読み、引用付きで Wiki から回答を統合（D2）。Wiki に不足があれば `WebSearch`/`WebFetch` で補完し「⚠️ Wiki 外（Web 検索）」と明示。検索で有用なソースが見つかれば `/llm-wiki ingest <url>` での取り込みを提案する。

### 機能5: 派生成果物生成（/llm-wiki synthesize <テーマ>）

Wiki 横断でテーマ（例: 最新チートシート、開発者向け Tips 集）を統合し、引用付きの synthesis ページを `wiki/syntheses/` に作成/再生成。不足は query 同様 Web で補完・明示し、ingest 提案。生成物は index.md / log.md 反映・Git コミットされ、以後 lint と再生成の対象になる。

### 機能6: 健全性チェック（/llm-wiki lint）

検査項目の全体像は `.claude/skills/llm-wiki/references/lint-rules.md` に 11 項目で予約。実装は Phase 2a（機械判定）と 2b（意味解釈・承認制）に分割する。

**Phase 2a（機械判定 7 検査・レポートのみ）**:

- #1 孤立ページ、#2 更新日 30 日超、#3 `claude_code_version` 乖離、#4 `stale:true` 監査、#6 信頼度監査、#7 index 同期、#9 `current-baseline.md` 鮮度
- 全検査は**レポートのみ**で書き込みを行わない（不変条件「黙って上書きしない」と整合。`stale:true` 自動付与・index 自動補完もしない）
- 起動は `/llm-wiki lint` 一括＋ `--check=<csv>` 部分実行（例: `--check=stale,baseline`）
- severity は「要対応 / 警告 / 情報」の 3 段
- 出力は対話で全件表示、`wiki/log.md` には severity 別サマリ 1〜数行を追記（別レポートファイルは作らない＝オーバーエンジニアリング回避）
- 走査戦略は **Glob で全ページ列挙 → フロントマターのみ Read（本文は読まない）＋ index.md 1 回読み**でコンテキスト圧迫を回避

**Phase 2b（意味解釈 4 検査・承認制）**:

- #5 横断的矛盾スキャン（決定 Z 二段目。index.md 主張サマリの別トピック間矛盾検出）
- #8 synthesis 再生成要否（引用元更新後に未再生成の synthesis 検出）
- #10 3 面相互矛盾（CLAUDE.md / SKILL.md / schema.md の齟齬。CLAUDE.md 優先）
- #11 バージョン軸決着（既存 `## 矛盾` セクションの supersession 候補を AskUserQuestion で「決着」注記＋severity 降格。auto-apply・統合・削除はしない）
- 書き込みを伴う検査はすべて AskUserQuestion 承認制

前提として ingest/synthesize は index.md に各ページの主要主張サマリ（1〜2 行）を維持する（Phase 1 完了時点で実機 vault でも維持されていることを確認済み）。

### 機能7: 拡張スキーマ（Phase 2a）

| ページタイプ | 用途 |
|---------|------|
| source / concept / entity / comparison / synthesis | 汎用タイプ（synthesis はチートシート/Tips 集等の派生成果物にも使用） |
| practice | 試した Claude Code 実践とその効果（効いた/効かなかった） |
| feature | 機能（Skills/Commands/Hooks/MCP/Agent SDK 等）ごとの最新仕様まとめ |

タイプの使い分け:
- `concept`: 抽象的な考え方・原則（例: プログレッシブ・ディスクロージャ、コンテキスト圧迫回避）。
- `entity`: 固有名を持つ具体物のうち **Claude Code の機能以外**（外部ツール、人物、組織、ライブラリ等）。
- `feature`: Claude Code 自体の機能（Skill/Hooks/MCP/Agent SDK 等）。**バージョン追従・陳腐化管理の対象**で `claude_code_version` を持つ。entity と紛らわしいが「Claude Code の機能なら feature、それ以外の固有物は entity」で線引きする。

フロントマター追加: `claude_code_version`（その知見が前提とするバージョン。`wiki/current-baseline.md` が現在の正。主に `feature` / `practice` で使用）。

**ingest 動線拡張**: `/llm-wiki ingest <path-or-url>` に以下の引数を追加する（非対称な 2 引数。practice は主型、feature は派生型として動線が異なるため）:

- `--type=practice`: 主たる生成型を `practice` にする。入力は基本 `raw/notes/` のユーザーメモを想定。「試した実践と効果」を記録するページを `wiki/practices/` に生成する
- `--feature=<slug>`: source 生成に加えて `wiki/features/<slug>.md` を更新（既存があれば追記＝継続更新、無ければ新規）。1 つの Tier A docs ingest で source と feature の両方を一気に更新する動線
- 引数無指定時の既存挙動（source ＋ 派生 concept/entity/comparison）は変更しない
- 自動タイプ判定は Phase 3 以降（無指定時の挙動として後付け可能）

## 受け入れ条件

### リポジトリ役割の更新（決定 A）

> ※ `CLAUDE.md` 側は commit 50232e9 "docs: reframe repo as personal Claude Code knowledge hub (llm-wiki)" で対応済み。残作業は `README.md` の再構成。実装時は下記の済項目を「達成済み」として検証する（再書き換え・上書きはしない）。

- [x] `CLAUDE.md` の「新規プロジェクトの起点としてコピーして使うテンプレート」という定義が「個人 Claude Code 知識ハブ専用リポジトリ」へ書き換えられている（commit 50232e9）
- [x] `CLAUDE.md` から「コピー先のプロジェクトでは書き換えてください」等のテンプレート前提の記述が除去/再構成されている（commit 50232e9）
- [x] `README.md` がテンプレート紹介ではなく知識ハブ（llm-wiki が主役）の説明として再構成されている（commit 942ca3c）

### スキル構成
- [x] `.claude/skills/llm-wiki/` に SKILL.md と references が存在する（本プロジェクトのみ。グローバル配置・ボールトコピーをしない）
- [x] SKILL.md が `init` / `ingest` / `query` / `synthesize` / `lint` のモード分岐を持つ
- [x] `README.md` の「含まれるもの」表と「推奨ワークフロー」に llm-wiki が主役機能として追記されている

### schema の所在・共進化・責務境界（決定 ウ）
- [x] `references/schema.md` のみが `schema_version` とページタイプ/フロントマター規約の「正」を持ち、SKILL.md/CLAUDE.md は参照のみで定義を再記述していない
- [x] ボールト側 `current-baseline.md` に `schema_version` / 本リポジトリの該当 commit ハッシュ / 規約 1〜2 行サマリ（軽量ポインタ）が記録される（schema 全文の複製はしない）
- [x] `schema.md` 改訂時に `schema_version` 更新・ボールトポインタ更新・ボールト `log.md` への「schema vN→vN+1: 要旨」追記を行う co-evolution 規約が SKILL.md/schema.md に明文化されている（v1.0.0→1.1.0 で実例化済）
- [x] 責務境界（齟齬時 CLAUDE.md > SKILL.md/schema.md）と Phase 2 lint による 3 面相互矛盾チェックが規約に記載されている

### /llm-wiki init
- [x] `./wiki-vault` が無ければ実体パスを対話確認し `ln -s` を案内/実行する
- [x] 実行すると raw/・wiki/・index.md・log.md・overview.md・wiki/current-baseline.md とボールト側 Git 追跡が作られる
- [x] 本プロジェクトの `.gitignore` に `wiki-vault` が追記され、設定ファイルに相対パス `./wiki-vault` と実体絶対パスが記録される
- [x] `current-baseline.md` の初期 `claude_code_version` を公式 GitHub 最新リリースの `WebFetch` で確定し、取得テキストを `raw/docs/<取得日>-claude-code-release.md` に Tier A メタ付きで保存して引用する（決定 イ）
- [x] WebFetch 失敗時は `claude --version` 案内の対話フォールバックに切り替え、`current-baseline.md` に「手動入力（暫定）」＋`stale:true` を記録し次回オンライン時の Tier A 上書き提案を残す（仕様は SKILL.md モード A.4 に明文化。実機フォールバック発火は未経由）

### /llm-wiki ingest
- [x] パス指定で raw のソースを取り込み、source 要約ページを生成する
- [x] URL 指定で取得テキストを raw/ に保存し（原文 URL・取得日時・取得手段をメタ記録）取り込める
- [x] 既出ソースは log.md 検索で検知し再取り込み可否を確認する
- [x] 生成ページに YAML フロントマターと raw への引用、[[wikilinks]] が含まれる
- [x] MVP の生成ページに `claude_code_version` / `updated` / `stale` フロントマターが（判定ロジックは Phase 2 でも）埋められている
- [x] MVP の生成ページに情報源ティア（Tier A / Tier B）のフロントマターが付与される（自動更新本体は Phase 3）
- [x] Tier B ソースの ingest 時、バージョン乖離があれば `current-baseline.md` 更新を対話提案する（承認制）
- [x] 既存ページと矛盾する主張は「矛盾」セクションを追加し、黙って上書きしない（ingest 時は同一トピック＝[[wikilink]] 先のみ照合。横断的矛盾は Phase 2 lint に委譲）
- [x] 操作後に index.md / log.md 更新と Git コミットが行われる
- [x] index.md に各ページの主要主張サマリ（1〜2 行）が維持される（Phase 2 横断矛盾スキャンの前提）

### /llm-wiki query
- [x] index.md → 関連ページの順で読み、引用付きで回答を統合する
- [x] Wiki に不足がある場合は Web 検索で補完し「Wiki 外」と明示し、有用ソースの ingest を提案する

### /llm-wiki synthesize（MVP）
- [x] テーマ指定でチートシート/Tips 集等の synthesis ページを `wiki/syntheses/` に引用付きで生成する
- [x] 既存の synthesis を再生成でき、index.md / log.md 反映と Git コミットが行われる
- [x] Wiki 外で補完した箇所は「Wiki 外（Web 検索）」と明示される

### /llm-wiki lint（Phase 2a・機械判定・レポートのみ）
- [x] 7 検査を実装する: #1 孤立 / #2 更新日 30 日超 / #3 `claude_code_version` 乖離 / #4 `stale:true` 監査 / #6 信頼度 / #7 index 同期 / #9 `current-baseline.md` 鮮度
- [x] すべての検査がレポートのみで書き込みを行わない（`stale:true` 自動付与・index 自動補完もしない＝不変条件「黙って上書きしない」と整合）
- [x] 起動は `/llm-wiki lint` 一括実行＋ `--check=<csv>` で部分実行できる
- [x] severity を「要対応 / 警告 / 情報」の 3 段で付与する
- [x] 健全性レポートを対話で全件表示し、`wiki/log.md` に severity 別サマリを追記する
- [x] 走査戦略はフロントマター集約と index.md 1 回読みで完結し、本文走査を最小化する（コンテキスト圧迫回避）

### /llm-wiki lint（Phase 2b・意味解釈・承認制）
- [x] #5 横断的矛盾スキャン（決定 Z 二段目。index.md 主張サマリの別トピック間矛盾検出）
- [x] #8 synthesis 再生成要否（引用元更新後に未再生成の synthesis を検出）
- [x] #10 3 面相互矛盾（CLAUDE.md / SKILL.md / schema.md の齟齬。CLAUDE.md 優先）
- [x] #11 バージョン軸決着（既存 `## 矛盾` セクションの supersession 候補を AskUserQuestion で「決着」注記＋severity 降格。auto-apply・統合・削除はしない）
- [x] 書き込みを伴う検査はすべて AskUserQuestion 承認制で、auto-apply しない

### スキーマ拡張（Phase 2a）
- [x] practice / feature ページタイプのテンプレートが `page-templates.md` に定義されている
- [x] `/llm-wiki ingest` に `--type=practice`（主たる生成型を practice にする）と `--feature=<slug>`（source に加えて指定 feature ページを更新）を追加する
- [x] 引数無指定時の既存挙動（source ＋ 派生 concept/entity/comparison）は変更しない

## スコープ外

### 今回対象外
- チーム利用向けの調整機構（レビューゲート、貢献者追跡、アクセス制御）
- セマンティック検索 / `qmd` 等 MCP 連携（200ページ・100ソース超で検討）
- 複数エージェント同時書き込みの競合解決
- ソース別取得ツール（X / Medium / Notion / 公式サイト等）の専用実装 → Phase 4

### 将来対応予定
- session-start hook による自動コンテキストロード（Phase 3）
- URL 自動取得・overview 自動更新（Phase 3）
- Tier A（公式サイト/公式 GitHub）の日次自動再取得・再コンパイル・`current-baseline.md` 自動更新（Phase 3 先行解禁）
- ソース別取得ツール群（Phase 4）
- 毎晩の自律 `/llm-wiki lint`（信頼モデル整備後）
- 規模拡大時の検索レイヤー追加

## 技術的考慮事項

### ディレクトリ構成

```
personal-wiki-for-claude-code/        # 個人 Claude Code 知識ハブ専用リポジトリ（スキル資産の置き場）
├── .claude/skills/llm-wiki/
│   ├── SKILL.md
│   └── references/{schema.md,page-templates.md,lint-rules.md}  # session-start hook は設定例として記載
├── .gitignore                        # wiki-vault を追記
└── wiki-vault -> ~/Documents/claude-code-wiki   # シンボリックリンク（gitignore 対象）

~/Documents/claude-code-wiki/           # 実体（独立 Obsidian ボールト・別 Git。.claude は持たない）
├── raw/{docs,articles,videos,github,notes}/
└── wiki/{sources,concepts,entities,comparisons,syntheses,practices,features}/
    ├── index.md
    ├── log.md
    ├── overview.md
    └── current-baseline.md           # claude_code_version 等の現在の正（改訂 C1: Tier A 自動更新可・手動上書き可。init が公式 GitHub 取得で初期化＝決定 イ）。schema 軽量ポインタ（schema_version / repo A commit / 規約サマリ）も保持＝決定 ウ
```

### 既存コードとの関係

- 参照: 記事のスキル設計（SKILL.md / schema / templates）
- 整合: 既存 `.claude/skills/*/SKILL.md` の記述粒度、`gen-all-docs` の規模方針
- 影響: `CLAUDE.md` の役割定義の全面書き換え（テンプレート → 知識ハブ。**commit 50232e9 で対応済み**）、`README.md` の再構成（含まれるもの表・推奨ワークフロー。**残作業**）、本プロジェクトの `.gitignore`

### 依存コンポーネント

| コンポーネント | 用途 |
|--------------|------|
| Claude Code Skills | スキルの実行基盤（単一スキル＋モード分岐） |
| Git | Wiki のバージョン履歴（ボールト側・別リポジトリ） |
| Obsidian | 表示レイヤー（グラフ/バックリンク/閲覧） |
| シンボリックリンク（`ln -s`） | 本プロジェクトからボールト実体を参照 |
| WebFetch / WebSearch | URL ソース取得・query/synthesize の Wiki 外補完 |

### リスクと対策

| リスク | 影響度 | 対策 |
|-------|--------|------|
| 取り込み時のハルシネーション（誤帰属・概念の誤統合） | 中 | 厳格な引用強制 + 定期 lint。raw は取得スナップショットとして保持し再検証可能 |
| 長文ソースでコンテキスト圧迫 | 中 | index → 対象ページ特定 → 該当ページのみ読込の選択的読み込み |
| メンテナンス放置による陳腐化 | 高 | 遭遇時に都度取り込む運用 + `current-baseline.md` ベース lint で陳腐化を可視化 |
| 「最新版」期待と実態の乖離（ingest 不足時） | 中 | synthesize/query は Wiki 外補完を明示し ingest を提案。期待値を本ドキュメントに明記 |
| WebFetch が原文を忠実再現しない | 低 | E1（取得スナップショット＋URL/日時メタ）と定義。必要時に原文を再取得して検証 |
| Tier A 日次自動再取得（スケジュール実行）と対話セッションの同時書き込み競合 | 中 | 単一エージェント書き込み前提（決定 6）と競合しうる。Phase 3 設計時にロック/キュー or 実行時間帯分離を検討（MVP では発生しない） |
| シンボリックリンク切れ・誤コミット | 低 | 設定ファイルに実体絶対パスを記録、`.gitignore` に `wiki-vault`、init で存在検証 |
| テンプレート規約との乖離 | 低 | 既存 Skill の粒度に合わせ、README 表も同時更新 |

## 更新履歴

- 2026-05-16: 初版作成（ブレインストーミングセッション）
- 2026-05-17: 矛盾検出を二段方式（決定 Z）に確定 — ingest 時は同一トピック（[[wikilink]] 先）のみ即時照合、横断的矛盾は index.md 主張サマリを使う Phase 2 lint に委譲。index.md に主張サマリ維持を前提条件として追加。lint に baseline 鮮度監査を追加
- 2026-05-17: 情報源ティア（Tier A=公式/Tier B=その他）を導入。Tier A は Phase 3 で日次自動再取得・再コンパイル・baseline 自動更新を先行解禁、Tier B は (iii)。C1 を「Tier A 自動更新可・手動上書き可」に改訂。MVP はティア区分メタのみ。スケジュール実行と対話書き込みの競合をリスクに追加。MVP フロントマター骨格（決定 ア）を受け入れ条件に追加
- 2026-05-17: リポジトリ役割を決定 A（テンプレート → 個人 Claude Code 知識ハブ専用リポジトリ）に確定。`CLAUDE.md`/`README.md` の書き換えを機能スコープ・受け入れ条件・影響範囲に追加。代替案に「リポジトリの役割」比較表を追加
- 2026-05-17: 壁打ちセッションで以下を反映 — Karpathy gist の schema 概念と照合し決定 ウを確定（schema の単一所有＝`references/schema.md` のみが `schema_version` と規約の正を持ち SKILL.md/CLAUDE.md は参照のみ／ボールトへは軽量ポインタのみ＝全文複製せず単一真実源を repo A に集約／schema 改訂時の `schema_version`・ポインタ・ボールト `log.md` 更新を MVP co-evolution 規約として明文化／責務境界は齟齬時 CLAUDE.md 優先・Phase 2 lint で 3 面相互矛盾も検査）。設計方針 11・機能1・受け入れ条件・ディレクトリ図に反映
- 2026-05-17: 壁打ちセッションで以下を反映 — current-baseline.md 初期化を決定 イ（init が公式 GitHub 最新リリースを WebFetch、raw 保存して引用、失敗時のみ `claude --version` 対話フォールバック＋暫定/`stale` 記録、Phase 3 Tier A 自動更新と同一経路）として確定し設計方針 10・機能2・受け入れ条件に追加。決定追随漏れを修正（改訂 C1 を図コメントへ反映、「テンプレートリポジトリ」表現を知識ハブへ）。設計方針の採番を出現順 1〜10 へ整理。決定 A の CLAUDE.md 書き換えは commit 50232e9 で対応済みのため受け入れ条件・影響範囲に注記（残作業＝README 再構成）
- 2026-05-17: 壁打ちセッションで以下を反映 — スキル一本化（`/llm-wiki <操作>`、独立コマンド/同梱 hooks 廃止）、本プロジェクト限定配置＋`./wiki-vault` シンボリックリンク＋相対パス設定（B1）、`claude_code_version` を `current-baseline.md` 基準に（C1）、raw を取得スナップショット方式に（E1）、query を Web 検索フォールバック明示＋ingest 提案に（D2）、`/llm-wiki synthesize` を MVP・受け入れ条件に追加（F2）、ロードマップに Phase 4（ソース別取得ツール）追加、拡張スキーマに concept/entity/feature の使い分けを補足
- 2026-05-22: MVP 受け入れ条件の達成状況を検証し、Phase 1 対象 21 項目を [x] に更新（README 再構成は commit 942ca3c で完了済、ingest/synthesize はボールト実機で実行済）。Phase 2 対象 6 項目は予定通り未着手のまま [ ]
- 2026-05-22: Phase 2 開始ブレインストーミングを実施し、以下を反映 — Phase 2 を 2a（機械判定 7 検査・レポートのみ＋ practice/feature テンプレ＋ ingest 動線拡張）と 2b（意味解釈 4 検査・承認制）に分割。受け入れ条件は機械判定（#1/#2/#3/#4/#6/#7/#9）を 2a、意味解釈（#5/#8/#10/#11）を 2b に振り分け。決定 Z 二段目（#5 横断矛盾）は受け入れ条件上 Phase 2 だったが意味解釈系のため 2b へ下ろす。Phase 2a lint は不変条件「黙って上書きしない」と整合させて完全レポートのみ（`stale:true` 自動付与・index 自動補完もしない）。起動は一括＋ `--check=<csv>` 部分実行。severity 3 段。出力は対話全件＋ log.md サマリ追記。走査戦略はフロントマター集約と index.md 1 回読みでコンテキスト圧迫を回避。ingest 動線は非対称 2 引数 `--type=practice` ／ `--feature=<slug>` を追加（無指定時の既存挙動は不変）。実機 vault は MVP 規約に完全準拠していることを確認（着手前修正不要、ただし lint 動作確認用 fixture は実装計画段階で別途用意）
- 2026-05-23: Phase 2a を実装完了。schema v1.1.0→v1.2.0（practice/feature を ✅ に解禁、page-templates.md に本文スケルトン追記、co-evolution の repo A／ボールト両側を同期）／lint-rules.md に 7 検査の判定ロジック・しきい値表（30/60/90 日・0.7）・走査戦略・fixture カタログ（17 ケース）を明文化／SKILL.md モード L を Phase 2a 機械判定 7 検査に置換（log.md 追記のみで他書き込みなし）、モード B に `--type=practice` ／ `--feature=<slug>` の非対称 2 引数を追加。実機 vault で lint を 1 回実行（vault commit 4f270bb）— 警告 1 件（#3 version bg-detach-note-2-0-5）のみ発火・他検査は適切に検出なしを返却・log.md 追記以外の書き込み無しを git diff で確認。残り 6 検査の発火確認は fixture カタログでスペック検証済みとして扱う。Phase 2a 受け入れ条件 9 項目を [x] 化。
- 2026-05-23: Phase 2a 受け入れテスト完了（`.steering/20260522-llm-wiki-phase-2a/acceptance-test-report.md` 総合判定 PASS）。`lint-fixture-test` ブランチを切って fixture セット（`_fixture-orphan` / `_fixture-multi` / `_fixture-ghost` / baseline updated を 2026-02-15 へ一時書換）を仕込み、`/llm-wiki lint` 一括実行で 9 件検出（要対応 4 / 警告 4 / 情報 1、`orphan=1, updated=1, version=2, stale=1, confidence=1, index=2, baseline=1`）— 7 検査キーすべて発火確認（vault commit 9840f8d）。続いて `/llm-wiki lint --check=stale,baseline` で部分実行 2 件のみ発火・他 5 検査スキップを確認（vault commit 21e453d）。両実行で lint 起因の差分は `wiki/log.md` のみ＝不変条件遵守を `git status` で確認。確認完了後、ブランチ破棄＋作業ツリー残存分（git restore / rm）でボールトを MVP 規約完全準拠状態に復帰。requirements.md 26 項目すべて [x]、ボールトパス変更（ClaudeCodeWiki → claude-code-wiki）も .llm-wiki.json / wiki-vault シンボリックリンクおよび関連ドキュメントへ反映済み。Phase 2a の機能スコープは verified、Phase 2b 以降は未着手。
- 2026-05-23: Phase 2b を実装完了。schema 据置（co-evolution §5 を回さない判断＝決着注記は lint 出力フォーマットであり schema は ingest/synthesize データ規約の正という責務境界）／lint-rules.md に #5/#8/#10/#11 の判定ロジック実装節を昇格・`## 矛盾` セクションのパース仕様および決着注記の正規記法（`**決着（YYYY-MM-DD）**: 時系列解決（v_old→v_new、Tier X が新）`）を追加・fixture カタログを 22 ケース相当に拡張／SKILL.md モード L を 11 検査統合版に拡張・書き込み副作用境界の表追加・承認制 UX（AskUserQuestion `multiSelect: true` で 0 件選択=適用しない、5 件超は上位 4 件＋次回再検出）を明文化。実機 vault で lint 一括実行（vault commit 44897fb）— 警告 1 件（#3 version bg-detach-note-2-0-5）・情報 2 件（#5 cross-topic background-agent-operation 設定継承軸／#11 version-resolve background-agent-operation v2.0.5 Tier B→v2.1.143 Tier A）。#11 承認制 UX を 1 回成立（vault commit 0e83b3d、`## 矛盾` 末尾 1 行追記＋ log.md 決着行追記のみ、フロントマター不変・他ページ変更なし）。残る Phase 2a 6 検査 + Phase 2b 3 検査（#8/#10）の発火確認は fixture カタログでスペック検証済みとして扱う。受け入れ条件「/llm-wiki lint（Phase 2b）」5 項目を [x] 化。UX 上の発見: 候補が 1 件のみのケースは AskUserQuestion の options ≥ 2 制約により単独提示できないため、明示的に「適用しない」選択肢を併置して二択化（multiSelect は維持。0 件選択 = 適用しないの規約は 2 件以上の候補時に有効）。Phase 2b 以降の改善候補として記録。
