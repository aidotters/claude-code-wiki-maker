# LLM Wiki Skill for Claude Code（Claude Code 知識の第二の脳）

> 作成日: 2026-05-16
> ステータス: Phase 1 MVP verified（2026-05-22）/ Phase 2a verified（2026-05-23）/ Phase 2b verified（2026-05-23）/ Phase 3a 設計完了・前提検証スパイク PASS（2026-05-23・実装着手可）/ Phase 3b・4 未着手
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
12. **Phase 3a Tier A 自動更新の運用ポリシー（決定 エ）**: 自律 cron 実行＋自動書き込みを決定 6（単一エージェント書き込み前提）と整合させるため、以下を Phase 3a の設計原則とする。
    - **専用サブモード `/llm-wiki refresh-tier-a` を新設**（既存 `ingest` の非対話化フラグ追加ではなく独立モード）。理由: ingest の対話 UX（要点確認・矛盾追記の事前確認）を保ったまま、cron 用の非対話経路を分離するため。`--dry-run` と通常実行の 2 モードを持つ。
    - **競合制御はロックファイル方式**: ボールトに `.llm-wiki.lock`（PID＋timestamp、JSON 1 行）を作成し、**書き込みモード**（`ingest`/`synthesize`/`refresh-tier-a`／および書き込みを伴う lint 2b #11 承認制決着）が開始時に取得・終了時に解放する。**`query` は読み取り専用のためロック取得しない**（read-only モードは並行可。refresh 中に query が来ても整合性問題なし＝raw 追加と wiki 再コンパイルは atomic commit 単位で進む）。`lint` の通常実行（レポート＋log.md 追記のみ）は競合域が log.md のみなので Phase 3a 設計時点ではロック取得し、Phase 3a 実装時に「log.md 追記の append-only 性を確認できれば lint からは外す」余地として残す。スタールロック検出は **timestamp 経過（既定 1 時間）＋ macOS の `kill -0` PID liveness check** の両方が満たされた時のみ強制取得（誤奪取防止）。Ctrl-C で死んだセッションが残したロックもこの経路で回収される。ロックファイルはボールト側 `.gitignore` 対象。
    - **対象 Tier A ソース集合の決定**: 既存 raw のうちフロントマター `tier: A` を持ち `source_url` がセットされているものを「再取得対象」とする。シードリストの二重管理を避けるため、別途のクロール対象設定ファイルは持たない。新規 Tier A ページの追加は手動 `ingest` の責務（refresh は再取得のみ）。
    - **差分判定と発動条件**: WebFetch は要約（メモ「WebFetch raw 逐語性ポリシー」）で逐語比較できないため、要約ハッシュ比較は採らない。**毎回新しい取得スナップショットを `raw/<種別>/<取得日>-<slug>.md` として追加**し（E1「raw は追加のみ・削除なし」と整合）、wiki 側の再コンパイルは「該当 raw の最新取得日 > wiki ページの `updated`」で発動する。冪等性は失うが「過去を消さず履歴を残す」設計と一致する。
    - **自動書き込みの境界**: raw 追加・wiki 該当ページ更新（同一トピック [[wikilink]] 先のみ照合・矛盾は `## 矛盾` セクション追加）・`current-baseline.md` の baseline フィールド更新（`claude_code_version` / `updated` / `last_tier_a_refresh`）までを自動とする。**synthesis 再生成は自動化しない**。lint 2b #8（`引用元.updated > synthesis.updated` で検出）が refresh で進んだ引用元 `updated` を自然に拾うため、新規フラグの追加は不要（決定 3「黙って上書きしない」との整合）。
    - **`current-baseline.md` の schema pointer は不可触**: refresh は baseline フィールド（バージョン軸）のみ更新し、`schema_version` / repo-A commit ハッシュ / 規約サマリ（決定 ウ の軽量ポインタ）には**触れない**。schema 進化は repo A 側の co-evolution 経路で行うべき領域。
    - **301 リダイレクト処理**: 自動マイグレーションは決定 3 違反のため行わない。検出時は `current-baseline.md` フロントマター内に `migration_pending` 配列（`{ old_url, new_url, detected_on, source_slug }` の項目）を 1 ソース 1 回だけ追加し（`last_tier_a_refresh` と同居・単一ファイルにメタを集約）、以降の refresh は古い URL を使い続けるが log には「(suppressed: pending migration <slug>)」と短く記すに留める（毎日同じ警告で log を膨らませない）。次回対話セッションの ingest/lint 時に `AskUserQuestion` で URL マイグレーション提案を出し、承認後に該当 source ページの `source_url` を新 URL へ書き換える＋`migration_pending` エントリを `current-baseline.md` から削除する。`code.claude.com` ホスト移転（メモ「Claude Code docs ホスト移転」）が現実の先行事例。
    - **vault dirty-state 時の挙動**: cron 起動時に `git status --porcelain` が非空なら **refresh を実行せず log に skipped を記録**する（stash も自動 commit もしない）。利用者のドラフト編集を refresh の機械コミットと混ぜると履歴が壊れるため。
    - **失敗ハンドリング**: ソースごとに git commit を分割。WebFetch 失敗・再コンパイル例外はそのソースを skip し log.md にエラー記録（commit しない）。全体実行は完了/部分完了/全失敗のサマリを log.md に 1 行追記。**git push はしない**（既存モードと同様にローカル commit までで止める。リモート push は利用者の判断・経路に委ねる）。
    - **手動 force-run**: cron 設定前のドッグフーディング用に、`/llm-wiki refresh-tier-a` は対話シェルからもそのまま実行できる（cron からと同じコードパス、AskUserQuestion を出さない設計）。`--dry-run` は raw 追加・wiki 更新・commit を行わずレポートのみ。
    - **`launchd` plist 例の同梱**: `references/` に plist 例を置く。`launchctl load` は利用者の手動操作（自動配置はしない＝決定 6 と整合）。想定スケジュールは深夜帯（既定例: 03:00 ローカル）。
    - **refresh 停止監視（lint #12）**: refresh が停止すると baseline は更新されないが、`/llm-wiki lint` の #9 baseline 鮮度検査は「ファイル更新日」を見るため refresh 停止に気付けない。`current-baseline.md` フロントマターに `last_tier_a_refresh: YYYY-MM-DD` を追加し、lint #12 として「`last_tier_a_refresh` が N 日（既定 7 日）以上前」を警告する検査を新設する（機械判定系・レポートのみ）。
    - **想定 N と API コスト**: 想定再取得対象は Tier A docs 主要ページ＋公式 GitHub リリースで一桁〜十数件規模。日次 WebFetch の recurring cost が発生することを明記し、規模拡大時は schedule の間引き（例: ページごとに weekly/daily 切替メタ）を将来の選択肢として残す（Phase 3a では実装しない）。
    - **実装着手前の前提検証（gate）**: 本ポリシーは **Claude Code を launchd/cron から非対話実行できる** ことを load-bearing assumption とする。実装着手前に、(i) Claude Code CLI の非対話モード（`--print` 等）、(ii) cron 環境での WebFetch 権限・環境変数引き継ぎ（API キー伝播・macOS ネットワーク権限）、(iii) ボールトへの書き込み権限と git commit の実行可否、を最小スパイク（trivial cron entry で 1 ファイル書く）で確認する。**部分失敗時の方針**: (i) または (iii) が失敗したら論点 1（スケジューラ選択）を再オープンし、代替（schedule skill / GitHub Actions）を再評価する。(ii) のみ失敗（非対話起動と書き込みは成功、WebFetch だけ拒否）の場合は scheduler は維持し、fetch 経路の差し替え（API キー渡し方の修正・別ツール経由）を先に試す＝binary flip は避ける。

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
| 3a | `/llm-wiki refresh-tier-a` + ロック規約 + lint #12（refresh 停止監視） | **Tier A（公式 docs / 公式 GitHub）の日次自動再取得・再コンパイル・`current-baseline.md` 自動更新の先行解禁**。launchd/cron からの非対話実行を前提とした専用サブモード。 |
| 3b | session-start hook（設定例）、URL 自動取得、overview 自動更新 | 運用自動化の残り（未設計） |
| 4 | ソース別取得ツール（X / Medium / Notion / 公式サイト等） | 取り込み拡充 |

> **Phase 2 を 2a/2b に分割した理由**: lint 検査 11 項目（`references/lint-rules.md`）のうち、フロントマター集約とファイル間突合で完結する機械判定系（#1/#2/#3/#4/#6/#7/#9）と、意味解釈が要る系（#5/#8/#10/#11）で実装難易度が大きく異なる。前者を 2a で先に出してドッグフーディングを開始し、後者は承認制 UX を含めて一括設計する（2b）。決定 Z 二段目（#5 横断矛盾）は受け入れ条件上 Phase 2 だったが、意味解釈系のため 2b に下ろす。

> **Phase 3 を 3a/3b に分割した理由**: 当初の Phase 3 は「session-start hook（設定例）」「URL 自動取得」「Tier A 日次自動更新」の 3 つを束ねていたが、Tier A 自動更新は **自律実行＋自動書き込みのため決定 6（単一エージェント書き込み前提）との競合制御が中核論点**で、独立した設計・受け入れ条件・リスクを持つ。他 2 つはこれと独立に設計でき、先に Tier A 自動更新だけを 3a として設計・実装する。session-start hook と URL 自動取得は 3b（未設計）として残置。

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

### 機能8: Tier A 日次自動更新（/llm-wiki refresh-tier-a・Phase 3a）

`launchd`（または `cron`）から `claude --print '/llm-wiki refresh-tier-a' ...` の形で非対話起動される専用サブモード。SKILL.md のモード分岐に新規追加。決定 6（単一エージェント書き込み前提）との整合のため、設計方針 12（決定 エ）に従う。

**入出力**:
- 入力: なし（対象は raw 内 Tier A メタを持つソースから自動収集）。オプションは `--dry-run` のみ。
- 出力: log.md への実行サマリ追記、各ソースの raw 追加、wiki 該当ページ更新、`current-baseline.md` の baseline フィールド＋`last_tier_a_refresh` 更新。

**実行フロー**:
1. **ロック取得**: ボールト `.llm-wiki.lock` を atomic に作成（既存ロックが stale = timestamp 経過＋`kill -0` で死活確認）。取得失敗時はエラー終了し log.md に「locked, skipped」を追記。
2. **dirty-state チェック**: `git -C wiki-vault status --porcelain` が非空ならスキップ＋log。
3. **対象ソース収集**: `wiki/sources/` 配下から `tier: A` ＋ `source_url` を持つページ集合を抽出。
4. **per-source ループ**:
   a. `WebFetch` で `source_url` 取得（301 検出時は `migration_pending` 処理に分岐）。
   b. 取得テキストを `raw/<種別>/<取得日>-<slug>.md` に追加保存（メタ: source_url・取得日時・取得手段・tier=A、`note: WebFetch 要約`）。
   c. 該当 wiki ページの `updated` と比較し、新 raw 取得日のほうが新しければ再コンパイル（既存 ingest と同じパス＝同一トピック [[wikilink]] 先のみ照合、矛盾は `## 矛盾` 追記）。
   d. ページに `claude_code_version` の更新が含まれる場合は `current-baseline.md` の baseline フィールドを更新（schema pointer 部分は不可触）。
   e. （synthesis 側へのフラグ追加は不要。引用元 wiki ページの `updated` が進めば lint 2b #8 の `引用元.updated > synthesis.updated` 検出が次回 lint 時に自動発火する。）
   f. ソース単位で git commit（コミットメッセージ `refresh(tier-a): <slug> at <取得日>`）。失敗時は skip＋log。**git push はしない**（リモート push は利用者の判断）。
5. **`last_tier_a_refresh` 更新**: 全ソース処理後、`current-baseline.md` フロントマターの `last_tier_a_refresh` を本日付に更新して 1 commit。
6. **サマリ追記**: log.md に `refresh-tier-a: ok=N skip=M fail=K (date)` を 1 行追加。
7. **ロック解放**: 正常終了時のロック削除。例外時もロック解放を試みる（`trap`/`defer` 相当）。

**`--dry-run` モード**: ステップ 1〜2 まで実行し、ステップ 3 以降は「対象一覧と判定結果（更新予定/差分なし/migration_pending/エラー予測）」をレポート表示するのみ。raw 追加・wiki 更新・git commit を一切行わない（ロックは取得・解放する）。

**301 リダイレクト処理（自動マイグレーション禁止）**:
- 検出時、`current-baseline.md` のメタブロックに `migration_pending: <old_url> → <new_url>` を 1 回だけ追記（既出ならスキップ）。
- 以降の refresh では古い URL で取得を継続し、log には `(suppressed: pending migration <slug>)` の短い行のみ。
- 次回の対話セッションで `/llm-wiki ingest` または `/llm-wiki lint` 起動時、`migration_pending` を `AskUserQuestion` で提示し、承認後に該当ソースページの `source_url` を新 URL へ書き換える。

**SKILL.md と references の追加事項**:
- `SKILL.md`: モード F として `refresh-tier-a` を記述。ロック規約・dirty-state 規約・301 規約を要約。
- `references/lint-rules.md`: #12 を追加（`last_tier_a_refresh > N 日`、既定 N=7、severity 警告、機械判定）。
- `references/schema.md`: `current-baseline.md` フロントマターに `last_tier_a_refresh: YYYY-MM-DD` を追加。`tier`・`source_url` の必須化が source ページに適用される旨を明記。
- `references/refresh-tier-a-launchd.plist.example`（新規）: 利用者が手動 `launchctl load` するためのテンプレ。

**実装着手前の前提検証 spike（gate）**:
- (i) `claude --print` 等で `/llm-wiki ...` を非対話起動できるか。
- (ii) cron 環境変数で WebFetch がブロックされないか（macOS ネットワーク権限、ANTHROPIC API キーの伝播）。
- (iii) launchd 起動の Claude プロセスからボールト（symlink 先）への読み書き・`git commit` が成功するか。
- いずれかが失敗したら **論点 1（スケジューラ選択）を再オープン**し、schedule skill / GitHub Actions を再評価する。

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

### /llm-wiki refresh-tier-a（Phase 3a・Tier A 自動更新）
- [ ] **前提検証 spike（実装着手前 gate）**: `claude --print` 等で `/llm-wiki refresh-tier-a` を launchd/cron から非対話起動でき、cron 環境で WebFetch・ボールト書き込み・git commit が成功することを最小実行で確認している（失敗時は論点 1 を再オープン）
- [ ] SKILL.md にモード F として `refresh-tier-a` のワークフローが記述され、`--dry-run` オプションを持つ
- [ ] ボールトに `.llm-wiki.lock`（PID＋timestamp）を取得・解放する規約が SKILL.md に記載され、書き込みモード（`ingest`/`synthesize`/`refresh-tier-a`／lint 2b #11 承認制決着）で適用される。読み取り専用の `query` はロック不要。`lint` 通常実行は Phase 3a 設計時点ではロック取得し、実装時に log.md append-only 性が確認できれば外す余地を残す。スタールロック判定は **timestamp 経過＋`kill -0` PID liveness** の両方が満たされた時のみ強制取得する
- [ ] `git status --porcelain` が非空（ボールトに未コミット変更）の時は refresh を実行せず log.md に skipped を記録する（stash・自動 commit はしない）
- [ ] 対象 Tier A ソース集合は既存 raw のフロントマター `tier: A` ＋ `source_url` から自動収集する（別途のシードリスト・クロール設定ファイルを持たない）
- [ ] 取得スナップショットは毎回 `raw/<種別>/<取得日>-<slug>.md` として追加保存され（E1 不変条件と整合）、wiki 再コンパイルは「raw 取得日 > wiki ページ `updated`」で発動する
- [ ] 矛盾は既存 ingest 同様に同一トピック [[wikilink]] 先のみ照合し `## 矛盾` セクションに追加する（横断矛盾は lint 2b #5 に委譲）
- [ ] `current-baseline.md` の baseline フィールド（`claude_code_version` / `updated` / `last_tier_a_refresh`）のみを自動更新し、`schema_version` / repo-A commit / 規約サマリ（決定 ウ の軽量ポインタ）には触れない
- [ ] synthesis 側に追加フラグは立てない（refresh で進んだ引用元 `updated` を lint 2b #8 の既存検出ロジック `引用元.updated > synthesis.updated` が次回 lint 時に自然に拾う）
- [ ] 301 リダイレクト検出時は自動マイグレーションせず、`current-baseline.md` フロントマター内の `migration_pending` 配列に `{old_url, new_url, detected_on, source_slug}` を 1 ソース 1 回だけ追加し、refresh は古い URL での取得を継続して log には `(suppressed: pending migration <slug>)` の短い行のみ追記する
- [ ] 次回対話セッションの `/llm-wiki ingest` または `/llm-wiki lint` 起動時、`migration_pending` を `AskUserQuestion` で URL マイグレーション提案として提示する
- [ ] ソース単位で git commit を分割し、失敗ソースは skip＋log.md にエラー記録（commit しない）。`git push` はしない（既存モード同様にローカル commit までで止める）
- [ ] 全体実行サマリ（ok/skip/fail カウント）を log.md に 1 行追記する
- [ ] `--dry-run` は raw 追加・wiki 更新・git commit を一切行わず、対象一覧と判定結果のレポートのみ表示する（ロックは取得・解放）
- [ ] `references/refresh-tier-a-launchd.plist.example` に launchd plist テンプレが同梱され、`launchctl load` は利用者の手動操作（自動配置はしない）
- [ ] `references/lint-rules.md` に #12 を追加し、`last_tier_a_refresh > N 日`（既定 N=7）を機械判定で警告する（レポートのみ）

## スコープ外

### 今回対象外
- チーム利用向けの調整機構（レビューゲート、貢献者追跡、アクセス制御）
- セマンティック検索 / `qmd` 等 MCP 連携（200ページ・100ソース超で検討）
- 複数エージェント同時書き込みの競合解決
- ソース別取得ツール（X / Medium / Notion / 公式サイト等）の専用実装 → Phase 4

### 将来対応予定
- Tier A（公式サイト/公式 GitHub）の日次自動再取得・再コンパイル・`current-baseline.md` 自動更新（Phase 3a・設計済み・実装待ち）
- session-start hook による自動コンテキストロード（Phase 3b・未設計）
- URL 自動取得・overview 自動更新（Phase 3b・未設計）
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
| Tier A 日次自動再取得（スケジュール実行）と対話セッションの同時書き込み競合 | 中 | Phase 3a で `.llm-wiki.lock`（PID＋timestamp＋`kill -0`）方式を全モードに導入＋深夜帯（既定 03:00）実行を推奨（決定 エ） |
| Phase 3a 前提（`claude --print` を launchd/cron から非対話実行）が未検証 | 高 | 実装着手前に最小スパイクで (i) 非対話起動、(ii) WebFetch 権限、(iii) ボールト書き込み・git commit を確認。失敗時は論点 1（スケジューラ選択）を再オープン |
| refresh の cron 停止に気付けない（baseline が偽陽性で新鮮に見える） | 中 | `current-baseline.md` に `last_tier_a_refresh` を持たせ、lint #12（既定 7 日経過で警告）で検知 |
| 301 リダイレクト連発で log が膨らむ | 低 | `migration_pending` を 1 回だけ記録、以降の refresh は `(suppressed: pending migration)` のみ。次回対話で AskUserQuestion 提案 |
| cron 起動時にボールトに未コミット編集が残っている | 中 | `git status --porcelain` が非空なら refresh をスキップ＋log（stash・自動 commit はしない） |
| 日次 WebFetch の recurring cost | 低 | 想定対象は一桁〜十数件規模。規模拡大時は schedule の間引き（ページ別 weekly/daily）を将来の選択肢として残す（Phase 3a では実装しない） |
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
- 2026-05-23: Phase 2b 受け入れテスト完了（`.steering/20260523-llm-wiki-phase-2b/acceptance-test-report.md` 総合判定 PASS、受け入れ条件 28 件すべて PASS／FAIL 0／手動確認残 0）。スペック整合（lint-rules.md §183-350 の 4 検査判定ロジック・SKILL.md モード L の 11 検査統合と書き込み境界表）＋実機 1 回実行（vault commit 44897fb で 4 キーすべてが log 集計に出力、Phase 2a 7 キーと干渉なし）＋ #11 承認制決着の分離コミット（vault commit 0e83b3d）の 3 軸で検証完了。schema.md は Phase 2b で未改訂（最終変更 commit 985a39c で v1.2.0）の方針も維持。ステータス行を `Phase 2b implemented` → `Phase 2b verified（2026-05-23）` へ更新。
- 2026-05-23: Phase 3a 前提検証スパイクを実施し、3 gate すべて PASS を確認（spike-report.json: `all_pass: true`, run_at `2026-05-23T06:15:15Z`）。手順は `.steering/20260523-llm-wiki-phase-3a-spike/spike-plan.md`、検証スクリプトは `scripts/phase-3a-spike.sh`。検証経路は launchd-like sanitized env を `env -i` で模擬（軽量経路）。発見事項: **macOS keychain auth の解決には `HOME+PATH` だけでは不足し、`USER`/`LOGNAME`/`SHELL` も必要**（最初の試行で `HOME+PATH` のみだと `Not logged in · Please run /login` で gate (i) fail、これらを足すと PASS）。`spike-launchd.plist` の `EnvironmentVariables` に同 5 変数を明示する形に確定。gate (ii) は `--allowedTools=WebFetch` の `=` 形式で variadic 消費を回避してパス。gate (iii) はボールトに spike commit `96d6af7` が残るが検証直後に `git -C wiki-vault reset --hard HEAD~1` で巻き戻す。検証中の CLI 落とし穴 2 件を spike スクリプトに反映済み（`--allowedTools ""` を渡すと variadic で prompt を食う問題、`env -i` での USER/LOGNAME/SHELL 不足で keychain auth が読めない問題）。Phase 3a 実装計画（`.steering/<日付>-llm-wiki-phase-3a/`）の起こしに進める状態。
- 2026-05-23: Phase 3 設計ブレインストーミングを実施し、以下を反映 — Phase 3 を 3a（Tier A 自動更新・本セッションで設計）と 3b（session-start hook・URL 自動取得・未設計）に分割。3a の核となる 6 つの意思決定を確定 — 論点 1: スケジューラ＝ローカル launchd/cron、論点 2: 自動書き込みは矛盾セクション追記まで（synthesis 再生成は lint 2b #8 任せ）、論点 3: 実行モード＝専用サブモード `/llm-wiki refresh-tier-a`（既存 ingest と分離）、論点 4: 競合制御＝ロックファイル方式（`.llm-wiki.lock` PID+timestamp、スタール判定は timestamp 経過＋`kill -0` PID liveness の両方）、論点 5: 差分判定＝毎回新 raw 追加（E1 整合）＋wiki 更新は raw 取得日 > updated で発動、論点 6: refresh 停止監視を lint #12 として追加（`last_tier_a_refresh > N 日`、既定 7 日）。設計方針 12（決定 エ）として運用ポリシー 13 項目を明文化（vault dirty-state 時の skip、301 リダイレクトの非自動マイグレーション＋migration_pending サプレッション、schema pointer 不可触、想定 N と recurring cost、ソース単位 commit 分割、`--dry-run` 必須、launchd plist 例の手動 load 前提）。受け入れ条件「/llm-wiki refresh-tier-a（Phase 3a）」15 項目を新規追加。リスク表に 5 件追加（前提検証未済・refresh 停止検知・301 ログ膨張・dirty-state・recurring cost）。**実装着手前の gate** として `claude --print` を launchd/cron から非対話実行できる前提の最小スパイク検証を必須化（失敗時は論点 1 を再オープン）。Phase 3b は未設計のまま残置。advisor レビューを 2 ラウンド経て次の 5 点を最終反映: (a) `stale_due_to_source_update` フラグ案を撤回し既存 lint #8 の `引用元.updated > synthesis.updated` 検出に委ねる（過剰設計回避）、(b) ロック対象を書き込みモードに限定し `query` を carve-out（lint 通常実行は Phase 3a 実装時に再評価）、(c) `migration_pending` の格納先を `current-baseline.md` フロントマターの配列に一元化（`last_tier_a_refresh` と同居）、(d) `git push しない` を明示（既存モード踏襲）、(e) スパイク部分失敗時の方針を明記（(ii) WebFetch のみ失敗ならスケジューラ維持＋fetch 経路差し替えを先に試す、binary flip 回避）。
