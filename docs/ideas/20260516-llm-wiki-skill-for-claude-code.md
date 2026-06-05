# LLM Wiki Skill for Claude Code（Claude Code 知識の第二の脳）

> 作成日: 2026-05-16
> ステータス: Phase 1 MVP verified（2026-05-22）/ Phase 2a verified（2026-05-23）/ Phase 2b verified（2026-05-23）/ Phase 3a verified（2026-05-24・F-1 hotfix 2026-05-24）/ Phase 3b verified（2026-05-27）/ Phase 3d verified（2026-05-29・mode B step 3.5(i) の source_url 解決バグを 2026-05-30 に発見し PR #14 で是正済）/ Phase 3c verified（2026-05-30・本体 PR #13 merged・schema v1.4.1 patch は PR #12 merged・carve-out 実機検証で発見した G-4 / step 3.5(i) source_url 解決バグは PR #14 `c9d8843` で是正済）/ Phase 3e verified（2026-05-31・会話 URL hook + mode H review + URL 正規化フル仕様 + declined negative cache + mode G opt-out amend・実機受け入れテスト 6 項目 PASS）/ Phase 3f verified（2026-06-05・単一 URL watchlist・mode W refresh-watchlist + watch/fetch_status + lint #14/#15 + schema v1.7.0・PR #21 `9d7e299`→main `db39199`）/ Phase 3g implemented（2026-06-05・定点フィード Tier B・mode I discover-watchlist + feed_url + pending_feed_discoveries + lint #16 + schema v1.8.0）/ 4 未着手
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
| 3a | `/llm-wiki refresh-tier-a` + ロック規約 + lint #12（refresh 停止監視） | **Tier A（公式 docs / 公式 GitHub）の既知 URL の日次自動再取得・再コンパイル・`current-baseline.md` 自動更新の先行解禁**。launchd/cron からの非対話実行を前提とした専用サブモード。 |
| 3b | session-start hook（設定例・read-only context preload）＋ Phase 3a 軽微パッチ（F-5 のみ） | 運用自動化のうち read-only 側のみ（未設計） |
| 3c | `/llm-wiki discover-tier-a` — Tier A 公式 docs / 公式 GitHub の **未取り込み URL の自動発見＋初期登録** | 手動 `ingest` の初期登録コストを下げる。α scope（`code.claude.com/docs/en/*` + `anthropics/claude-code` の docs/CHANGELOG/README）＋承認制＋ `pending_discoveries[]` 永続化（schema v1.5.0 bump）＋ mode B 共通 surface 経由 ingest ＋ lint #13（last-discover-tier-a-run）。schema v1.4.1 先行 patch（`platform.claude.com` Tier A 追加）を着手前提とする（brainstorm 完了 2026-05-29）。**Phase 3e で承認 UX を amendment**: 現状の opt-in 上位 4 件提示を、Tier A は capped バッチ opt-out（既定取り込み・除外を選択・1 run N 件上限）＋各ページ概要を discover 時に軽量先取り、へ拡張（142 件 backfill の無人ダンプ回避） |
| 3d | F-4 migration 承認後 ingest フロー再定義・F-6 sources: append 明文化・C overview 自動更新・F-3 log.md append 規約見直し | 既存 mode B（ingest）拡張で `new raw を ingest して source ページの sources: を更新する` 共通 surface を確立し、overview 自動更新と F-3 dirty escalation 解消を束ねる（brainstorm 完了 2026-05-29） |
| 3e | 会話中 URL 自動取り込み（B・単一 URL 型）— UserPromptSubmit hook 検出 → inbox → 承認キュー → 共通 surface ingest | hook は会話中の URL を検出し**追記専用 inbox に append するだけ**（スキル起動・書き込み lock に触れない）。対話時に承認（Tier B 単一 URL は opt-in 個別承認）して mode B で ingest。**parked 項目を同梱**: URL 正規化フル仕様（tracking param/fragment 除去・allowlist）＋ stuck candidates 対策＋ 3c mode G の承認 UX amendment（Tier A を capped バッチ opt-out ＋概要先取り化）。`disable-model-invocation: true` は維持（hook はスキルを起動できないため壁を外す必要なし・公式 docs 実証済）（brainstorm 完了 2026-05-30） |
| 3f | ウォッチリスト型 Tier B 定点観測（**単一 URL 型のみ**）— Tier B 既知 URL の日次自動 refresh | `refresh-tier-a` の **Tier B 版**（mode `refresh-watchlist` 新設）。単一 URL 型＝登録＝承認 → cron 自動 refresh（raw 再取得＋再コンパイル＋`## 矛盾` 自動追記まで無人・baseline 提案は次回対話＝決定6厳守）。relevance フィルタ不要（個別承認済 URL の refresh のみ）。取得可否 gate 不要（registration＝ingest 時に当該 URL を一度実取得済＝fetchability が per-URL で opt-in 時点に実証される）。**設計論点決着（2026-05-31 brainstorm 2 本目）**: registry-vs-flag→flag（source ページ `watch: true`・走査＝`tier:B`＋`watch:true` Glob・URL は F-3 走査で raw から解決）・opt-in 既定→default-off・fetchability decay→受動的 lint surface（マーカー機構〔`stale` 再利用 vs 専用 `fetch_status`〕は plan 残点・self-heal しない）・baseline carrier→不要（lint #3 version 乖離が自己記述を再検出・新 array 不採用）・lint #14 停止監視は #12/#13 同型で確定。次は `.steering/` 起こし（2026-05-31 brainstorm で 3f/3g 分割・要件確定） |
| 3g | ウォッチリスト型 Tier B 定点観測（**定点フィード型**）— サイト登録 → 新着 URL 発見 → relevance フィルタ → 承認キュー経由 ingest | `discover-tier-a` の **Tier B 版**。定点フィード型＝サイト登録＝1回承認 → 新着 URL を RSS/sitemap で発見 → **relevance フィルタ（2 段＝キーワード前段→モデル判定後段・確定）通過分のみ**承認キュー経由 ingest（**完全無人にしない**＝Tier A mode G と同じ capped バッチ opt-out surface へ合流・確定）。非関連は negative cache（`declined` 同様）。X は公開 RSS 無し＝**Phase 4 ソース別 fetcher 依存**のため当面 RSS/sitemap 取得可能ソースに限定。取得可否 spike を着手前 gate に（要件のみ記録・設計は次回 brainstorm/plan） |
| 4 | ソース別取得ツール（X / Medium / Notion / 公式サイト等） | 取り込み拡充。**Phase 3g 定点フィード（特に X）の前提依存**（sequencing inversion: 3g-feed は Phase 4 fetcher と前後して着地） |

> **Phase 2 を 2a/2b に分割した理由**: lint 検査 11 項目（`references/lint-rules.md`）のうち、フロントマター集約とファイル間突合で完結する機械判定系（#1/#2/#3/#4/#6/#7/#9）と、意味解釈が要る系（#5/#8/#10/#11）で実装難易度が大きく異なる。前者を 2a で先に出してドッグフーディングを開始し、後者は承認制 UX を含めて一括設計する（2b）。決定 Z 二段目（#5 横断矛盾）は受け入れ条件上 Phase 2 だったが、意味解釈系のため 2b に下ろす。

> **Phase 3 を 3a/3b に分割した理由**: 当初の Phase 3 は「session-start hook（設定例）」「URL 自動取得」「Tier A 日次自動更新」の 3 つを束ねていたが、Tier A 自動更新は **自律実行＋自動書き込みのため決定 6（単一エージェント書き込み前提）との競合制御が中核論点**で、独立した設計・受け入れ条件・リスクを持つ。他 2 つはこれと独立に設計でき、先に Tier A 自動更新だけを 3a として設計・実装する。session-start hook と URL 自動取得は 3b（未設計）として残置。

> **Phase 3b を 3b/3d に分割した理由（2026-05-24）**: Phase 3b 当初スコープ「session-start hook（A）/ 会話中 URL 自動取り込み（B）/ overview 自動更新（C）/ Phase 3a 持ち越し F-3〜F-6」のうち、**B と F-4 は同じ surface**（`new raw を ingest して source ページの sources: を更新する`）を共有し、**C は B の下流**（ingest が成功した後 overview を更新する）であることが Phase 3b brainstorm で判明。A（read-only context preload）と軽微パッチ F-5 は独立かつ trivial で、B+C+F-4+F-6 の「会話駆動 write」クラスタとは設計の重さ・リスクが大きく異なる。**F-3 は log.md append 規約のトレードオフで F-4 が同じ規約に触れるため Phase 3d 先送り（Phase 3b では status quo 維持）**。よって **A + F-5** を **Phase 3b**（軽量 read-only）に絞り、**B + C + F-3 + F-4 + F-6** を **Phase 3d**（会話駆動 write + log.md append 規約見直し）として新設し連番に組み込む。Phase 3c は `/llm-wiki discover-tier-a` で予約済のため命名は 3d に進める。F-1 は本決定前に hotfix で先行解消済（PR #6 merged）。

> **Phase 3d を 3d/3e に分割した理由（2026-05-29）**: Phase 3d brainstorm で advisor レビューを経て、**B（会話中 URL 自動取り込み）は共通 surface への trigger 経路**であって surface 自体ではないと再認識。surface（= ingest 内部処理: URL → raw → source ページ更新）は F-4 だけで確立され、3c の cron 自動 ingest も 3d の surface をそのまま流用できる。一方 B の trigger 設計は (a) UserPromptSubmit hook 追加 / (b) SessionStart hook 拡張（Phase 3b 境界破り）/ (d) `disable-model-invocation: true` を外して SKILL.md autoload 化、のいずれも **書き込み制御方針との緊張を伴う固有論点**で、F-4/F-6/C/F-3 の「既存ギャップ修正＋仕様明文化＋規約見直し」クラスタとは設計の重さが段違い。よって **F-4 + F-6 + C + F-3** を **Phase 3d**（共通 surface 確立＋下流の overview/log 規約整理）に絞り、**B**（trigger 設計と auto-ingest 経路）を **Phase 3e** として新設し連番に組み込む。**F-3 と F-4 を旧フレーミング（2026-05-24）で「同じ log.md append 規約として束ねた」点は本 brainstorm で訂正**: F-3 は cron dirty escalation の特殊事象、F-4 は通常 ingest と同じ append 規約で独立論点。F-3 は (iv) F-2 dirty check から log.md を除外（git pathspec `-- ':!wiki/log.md'`）で単独解消、F-4 は通常 ingest の延長で扱う。

> **Phase 3e を 3e/3f に分割した理由（2026-05-30）**: Phase 3e 開始 brainstorm で「会話中 URL 自動取り込み（B）」の本質を掘ると、ユーザーの本意は **(い) ウォッチリスト型の毎日自動更新**で、会話 URL はその副次だった。さらに hook の能力を公式 docs（`code.claude.com/docs/en/{hooks,skills}.md`）で実証した結果、**(1) UserPromptSubmit hook はスキルを起動できない**（できるのは additionalContext 注入・block・hook 自身のシェル実行のみ）、**(2) `disable-model-invocation` はスキル単位**で mode 別切替不可、と確定。これにより「auto-ingest」は **検出（hook で決定的）と取り込み（書き込み = 承認 or cron）に分離**され、`disable-model-invocation: true` を外す（決定6/7 と衝突）必要は無いと判明。設計の重さで割ると、**会話 URL hook（検出器を 1 つ足して既存 3c キューに流すだけ・新規書き込み経路ゼロ）**＝軽量と、**ウォッチリスト型 Tier B 定点観測（refresh-tier-a/discover-tier-a の Tier B 版・新モード・relevance フィルタ・X は Phase 4 fetcher 依存）**＝重量、が段違い。よって **会話 URL hook ＋ parked 項目（URL 正規化フル仕様・stuck candidates・3c 承認 UX amendment）**を **Phase 3e**、**ウォッチリスト型 Tier B**を **Phase 3f**（要件のみ記録・設計は次回）として連番分割。**承認モデルは ① Tier A=capped バッチ opt-out（概要先取り・1 run N 件上限・無人 discover ＋軽量バッチ承認）② Tier B 単一/会話 URL=opt-in 個別承認 ③ Tier B 定点フィード=サイト登録＝1回承認→新着は relevance フィルタ通過分のみ cron 自動 ingest、に集約**。advisor レビューで (a) 3c Tier A の 142 件 backfill 無人ダンプ問題 → capped バッチ opt-out で解消、(b) inbox は新規 dirty state のため F-2/mode G の dirty-check pathspec 除外リストに追加必須、(c) URL 正規化フル化は 3c/3d の dedup キー（正規化後 url）・source_url との整合/移行が必要、(d) 会話 URL の承認 surface は discover-tier-a が「今回 discover 分」だけ提示か「キュー全体」提示かが未決、を指摘・記録。

> **Phase 3f を 3f/3g に分割した理由（2026-05-31）**: Phase 3f 設計 brainstorm で、当初の「ウォッチリスト型 Tier B（単一 URL 型＋定点フィード型）」を掘ると **重さが段違いの 2 塊**が同居していると判明。**単一 URL 型 refresh（軽量）**＝既存 `refresh-tier-a`（mode F）の**書き込み機械**（lock 規約・log.md pathspec 除外・空 commit ガード・per-source ループ・エラーハンドリング表）を再利用・relevance フィルタ不要（個別承認済 URL の refresh のみ）・取得可否は per-URL で opt-in 時点に実証済＝gate 不要。**ただし「新規書き込み経路ゼロ」ではない**＝独自の走査対象集合（Tier B watchlist）と別 cron entry を持つ **mode `refresh-watchlist` の新設**であり、mode F に条件分岐を足すと verified 3a/3d の Tier A baseline 自動更新振る舞いを汚染するため別モードにする（advisor 3 名一致の表現是正＝「足すだけ」は実装量の過少評価）。「軽量」の主張は relevance/gate/feed 巡回が無い点で生き残る。**定点フィード型 discover→ingest（重量）**＝relevance フィルタ・cron ingest・X の Phase 4 fetcher 依存・取得可否 spike が集中。3a→3e で繰り返した「重さで割って連番分割」を踏襲し、**単一 URL 型を Phase 3f**、**定点フィード型を Phase 3g**（要件のみ記録・設計は次回）に分割。**ユーザー対話での確定事項**: (1) 単一 URL refresh は **mode `refresh-watchlist` 新設**（mode F〔Tier A〕は不可触＝verified 3a/3d を壊さない・Tier B 固有の baseline 振る舞いを混ぜない）、(2) 無人範囲は **raw 再取得＋再コンパイル＋`## 矛盾` 自動追記まで cron 無人・baseline 提案は次回対話**（決定6＝Tier B バージョン乗離は承認制を厳守。Tier A の `migration_pending` に相当する durable carrier が必要）、(3) **3g relevance フィルタ＝2 段（キーワード前段→モデル判定後段）**・**3g 承認＝relevance 通過分も承認キュー経由（完全無人にしない・Tier A mode G の capped バッチ opt-out surface に合流）**。**advisor レビュー指摘を記録**: (#2) 単一 URL に**別途 watchlist registry は不要かもしれない**＝3e で source ページが正規化URLの正本になったため、`refresh-watchlist` は「`tier: B` ＋ `source_url` ＋ opt-in フラグの source ページを走査」で済む可能性（source ページ＝registry・source_url＝既正規化キーで dedup/migration 問題を回避）。当初要件の「schema bump + watchlist 構造（url/type/label/added）」は継承せず**設計時に再導出**（registry-vs-flag を design 論点として開く）。(#3) 「登録＝承認」には **ingest 時の明示 opt-in マーカー**が要る（一度きりの記事を永久 refresh しない）＝default-off〔source 毎 opt-in〕vs default-on〔全 Tier B を除外なき限り refresh〕の決定が必要。(#4) `refresh-watchlist` は書き込み mode＝3a ロック規約・3d log.md pathspec 除外（`:!wiki/log.md`）・3b 空 commit ガードを**再利用**（再導出しない）。別 cron entry にすると refresh-tier-a と同一 `.llm-wiki.lock` を争うため**起動時刻をずらす**（lock が衝突 skip しないよう stagger）。(#5) deferred baseline 提案の **durable carrier が要る**（なければ提案が消える）。ただし `current-baseline.md` は既に `migration_pending`/`pending_discoveries[]` を持つため、3 つ目の array を切る前に**既存の決定6 対話提案に相乗りできないか**を design で先に検討（専用 carrier は不可時の明示決定）。(#7) 3f は取得可否 gate を**継承しない**。論拠は「同一 WebFetch 経路」ではなく **registration＝ingest 時に当該 URL を一度実取得済＝fetchability が per-URL で opt-in 時点に実証される**（取れない URL は ingest できず watchlist に載らない）。任意 Tier B host の WebFetch hostile 懸念は feed 巡回＝3g 固有として spike gate に残す。**実装後 advisor 3 名一致の追加指摘 3 件を反映**: (#8 最優先) **fetchability decay = t=0 実証は t=n を保証しない**。Tier B（Medium/個人ブログ/Substack 等）は Tier A 公式 docs より消滅率が桁違いで、daily refresh の**ドミナント運用障害**が「watchlist URL の 404/ドメイン失効/恒久リダイレクト」。`refresh-watchlist` の挙動（永続リトライ→log spam / stale フラグ付与→lint / 自動 opt-out 提案→承認制）を **design 論点として必ず開く**（取得可否 gate 不要≠ refresh ループのエラー扱い不要・mode F の Tier A 想定では桁が違う）。(#9) **lint #14 相当（`refresh-watchlist` 停止監視）が必要**＝mode F に #12・mode G に #13 がある通り、別 cron entry の停止を検知する lint を #12/#13 同型で要件化（明示的省略決定でない限り設計欠陥）。(#10) **deferred baseline 提案は sync/async の参照先を取り違えない**＝決定6 は同一 ingest ターン内の同期提案、3f cron は非同期。正しい先例は `migration_pending`。検討すべき fork は「cron 再コンパイル時点で vault が乖離を自己記述する（lint が再検出できる）か」＝YES なら carrier 不要で lint 再検出に委譲、NO なら `migration_pending` クラスの durable carrier 新設。この fork を先に潰す。あわせて (#11) ingest 時 opt-in 登録の UI/フロー（`--watch` 引数 / ingest 後 AskUserQuestion / 別コマンド後付け）未定義、(#12) 論点5 更新判定（raw 取得日 > updated で再コンパイル発動）の 3f 継承確認、(#13) 走査対象集合の列挙方法（flag 方式なら `tier:B`＋`watch:true` のフロントマター Glob・件数増時のコンテキスト圧迫）、(#14) `## 矛盾` 無人追記が「自動上書き禁止」に抵触しない論拠（append-only＋同一トピック限定＝決定Z／不変条件3 を mode F から継承）の一行注記、も design 論点に追加。

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
- [x] **前提検証 spike（実装着手前 gate）**: `claude --print` 等で `/llm-wiki refresh-tier-a` を launchd/cron から非対話起動でき、cron 環境で WebFetch・ボールト書き込み・git commit が成功することを最小実行で確認している（失敗時は論点 1 を再オープン）
- [x] SKILL.md にモード F として `refresh-tier-a` のワークフローが記述され、`--dry-run` オプションを持つ
- [x] ボールトに `.llm-wiki.lock`（PID＋timestamp）を取得・解放する規約が SKILL.md に記載され、書き込みモード（`ingest`/`synthesize`/`refresh-tier-a`／lint 2b #11 承認制決着）で適用される。読み取り専用の `query` はロック不要。`lint` 通常実行は Phase 3a 設計時点ではロック取得し、実装時に log.md append-only 性が確認できれば外す余地を残す。スタールロック判定は **timestamp 経過＋`kill -0` PID liveness** の両方が満たされた時のみ強制取得する
- [x] `git status --porcelain` が非空（ボールトに未コミット変更）の時は refresh を実行せず log.md に skipped を記録する（stash・自動 commit はしない）
- [x] 対象 Tier A ソース集合は既存 raw のフロントマター `tier: A` ＋ `source_url` から自動収集する（別途のシードリスト・クロール設定ファイルを持たない）
- [x] 取得スナップショットは毎回 `raw/<種別>/<取得日>-<slug>.md` として追加保存され（E1 不変条件と整合）、wiki 再コンパイルは「raw 取得日 > wiki ページ `updated`」で発動する
- [x] 矛盾は既存 ingest 同様に同一トピック [[wikilink]] 先のみ照合し `## 矛盾` セクションに追加する（横断矛盾は lint 2b #5 に委譲）
- [x] `current-baseline.md` の baseline フィールド（`claude_code_version` / `updated` / `last_tier_a_refresh`）のみを自動更新し、`schema_version` / repo-A commit / 規約サマリ（決定 ウ の軽量ポインタ）には触れない
- [x] synthesis 側に追加フラグは立てない（refresh で進んだ引用元 `updated` を lint 2b #8 の既存検出ロジック `引用元.updated > synthesis.updated` が次回 lint 時に自然に拾う）
- [x] 301 リダイレクト検出時は自動マイグレーションせず、`current-baseline.md` フロントマター内の `migration_pending` 配列に `{old_url, new_url, detected_on, source_slug}` を 1 ソース 1 回だけ追加し、refresh は古い URL での取得を継続して log には `(suppressed: pending migration <slug>)` の短い行のみ追記する
- [x] 次回対話セッションの `/llm-wiki ingest` または `/llm-wiki lint` 起動時、`migration_pending` を `AskUserQuestion` で URL マイグレーション提案として提示する
- [x] ソース単位で git commit を分割し、失敗ソースは skip＋log.md にエラー記録（commit しない）。`git push` はしない（既存モード同様にローカル commit までで止める）
- [x] 全体実行サマリ（ok/skip/fail カウント）を log.md に 1 行追記する
- [x] `--dry-run` は raw 追加・wiki 更新・git commit を一切行わず、対象一覧と判定結果のレポートのみ表示する（ロックは取得・解放）
- [x] `references/refresh-tier-a-launchd.plist.example` に launchd plist テンプレが同梱され、`launchctl load` は利用者の手動操作（自動配置はしない）
- [x] `references/lint-rules.md` に #12 を追加し、`last_tier_a_refresh > N 日`（既定 N=7）を機械判定で警告する（レポートのみ）

### /llm-wiki Phase 3b（session-start hook 設定例 + F-5 ガード）
- [x] `.claude/skills/llm-wiki/references/session-start-hook.example.json` が同梱され、`jq` で parse 成功する有効な JSON である
- [x] 設定例は `hooks.SessionStart` 配列を含み、`matcher: "*"`、`hooks[0].type: "command"`、`hooks[0].command` は `[ -L ./wiki-vault ] && cat ./wiki-vault/wiki/current-baseline.md 2>/dev/null || true`
- [x] 設定例ファイルに `_comment` / `_notes` フィールドで (i) **project local 推奨・グローバル登録非推奨**、(ii) **CWD = リポジトリルート前提**、(iii) **vault 不在時は無音終了** の 3 点が明記される
- [x] SKILL.md モード A に「session-start hook 設定例の案内」step が追加され、`references/session-start-hook.example.json` への明示的リンクと、自動マージしない方針・project local 推奨が記載される
- [x] SKILL.md モード F の F-5 step が **値変化ガード付き**仕様（`last_tier_a_refresh` 本日付同値の場合は Edit / commit skip ＋ log `unchanged` 行追記、`--dry-run` でも分岐レポートのみ）に書き換えられている
- [x] SKILL.md モード F のエラーハンドリング表に「`last_tier_a_refresh` 既に本日付（同日 2 回目以降の force-run）」行が追加されている
- [x] idea.md ロードマップ表・F-1〜F-6 振り分け・Phase 3 分割理由・ステータス行が Phase 3b/3d 分割を反映している（brainstorm commit `bf8a2fc` で対応）
- [x] idea.md 更新履歴に Phase 3b 実装エントリ（2026-05-24）が追加される

### /llm-wiki Phase 3d（F-4 migration ingest フロー + F-6 sources: 明文化 + C overview 自動更新 + F-3 log.md 規約）

**共通 surface（F-4 / F-6・既存 mode B ingest 拡張）**:
- [x] SKILL.md mode B（ingest）が「migration_pending 承認後 ingest」を内包する（専用モード追加なし・既存 ingest フローを拡張）
- [x] SKILL.md §2.5 (i) `migration_pending` 提案フローが「URL 書き換え」から「new_url で新規 raw を ingest して既存 source ページを更新（sources: append、source_url を new_url に書き換え、migration_pending エントリ削除、updated 進行、title 等の手動編集領域は不可触）」に再定義される
- [x] 同一 source 判定ロジックが SKILL.md mode B に明文化される: (i) 正規化後 source_url 完全一致 → 既存 source ページに統合 / (ii) `current-baseline.md.migration_pending[].new_url` と一致 → 旧 source ページに統合＋ migration_pending エントリ削除 / (iii) どちらでもなければ新規 source ページ作成
- [x] URL 正規化規約（3d 用最小ルール）: lowercase host ＋末尾スラッシュ除去のみが SKILL.md mode B に明文化される。フル仕様（tracking param 除去・フラグメント除去・Tier A allowlist 等）は Phase 3e で再開する旨を脚注で明記
- [x] Tier A 自動判定は 3d では不要（migration_pending 由来は元 source の Tier をそのまま継承）。SKILL.md / schema.md に host allowlist を持たない
- [x] migration case の旧 raw（old_url）は不変保持（決定 E1 整合）、新 raw のみ `sources:` 末尾に append（時系列保証）
- [x] 矛盾検出は既存 ingest 規約踏襲（同一トピック [[wikilink]] 先のみ即時照合、矛盾は `## 矛盾` セクション末尾に自動追記）
- [x] migration case ingest は `.llm-wiki.lock` を取得（書き込みモード）、ソース単位で git commit、`git push` はしない
- [x] F-6: SKILL.md mode B / mode F 該当箇所に「再コンパイル時、新 raw を source ページの `sources:` 末尾に append（時系列保証）」が明文化される（既存実装の仕様化のみ）

**overview 自動更新（C）**:
- [x] vault `wiki/overview.md` に `## 現状` セクション（agent 完全所有・自動更新領域）が定義され、上部の説明文は手動編集領域として保持される
- [x] `## 現状` セクションは統計値（ソース数 / concept 数 / synthesis 数 / practice 数 / feature 数）・最終 ingest 日付・最終更新日付（YYYY-MM-DD）を保持する
- [x] overview 更新は書き込みモード操作（mode B ingest / mode F refresh-tier-a / mode D synthesize）の同一 commit 内で inline 実行される（別 commit にしない）
- [x] 値変化ガード付き（同値なら Edit / commit skip ＋ log に `overview unchanged` 行追記）— Phase 3b F-5 と同じ流儀
- [x] lint #11 承認制決着では overview を更新しない（source ページ統計に変化なし）
- [x] schema.md に overview.md の構造（agent 所有領域 vs 手動編集領域・統計フィールドの定義）が明記される
- [x] 統計値の取得は SKILL.md mode B に明文化（`Glob` で wiki/<type>/*.md を count、index.md 1 回読みは不要）

**F-3 log.md append 規約見直し（(iv) F-2 dirty check から log.md 除外）**:
- [x] SKILL.md mode F の F-2 dirty-state 判定式が `git -C wiki-vault status --porcelain -- ':!wiki/log.md'` 非空に変更される（log.md は agent 完全所有領域のため dirty check 対象から除外）
- [x] F-2 skip 時の log.md append + commit が成功するようになり、dirty escalation ループが解消される（既存の skip + log append 動線はそのまま、commit が新たに通る）
- [x] schema.md §3 / SKILL.md に「log.md は agent 完全所有・追記のみ規約のため dirty 状態でも append + commit 可」が明記される
- [x] F-3 と F-4 を旧フレーミング（2026-05-24）で「同じ log.md append 規約として束ねた」点が訂正済と SKILL.md / idea.md で読み取れる（F-3 は cron dirty 特殊事象・F-4 は通常 ingest と独立論点）

**schema co-evolution / idea.md**:
- [x] schema.md の `schema_version` を v1.3.0 → v1.4.0 に bump（overview.md 構造化セクション追加・dirty check 規約改訂）
- [x] `current-baseline.md` フロントマターの `schema` ポインタを更新（ボールト側 log.md にも 1 行追記）
- [x] idea.md 更新履歴に Phase 3d 実装エントリが追加される
- [x] CLAUDE.md ステータス行（"MVP（Phase 1）＋…実装済み"）が Phase 3d 実装完了時点で更新される

**実機反映（vault co-evolution）**:
- [x] vault `wiki/overview.md` の初回構造変換 commit が落ちる（既存内容を `## 現状` セクション形式へ移行、agent 所有領域の初回反映）
- [x] vault `wiki/current-baseline.md` の `schema` ポインタ更新 commit が落ちる
- [x] SKILL.md / schema.md の repo A 編集と vault co-evolution が同一 PR 範囲内で完結する

### /llm-wiki Phase 3c（discover-tier-a 機能追加）

**schema §4 v1.4.1 patch（Phase 3c 着手前提・独立 PR で先行 merge）**:
- [x] schema.md §4 tier 自動判定ルール表に `platform.claude.com`（Anthropic API + Agent SDK docs の移転先ホスト・brainstorm 中の verify で `docs.anthropic.com/en/api/*` → 301 → `platform.claude.com/docs/en/*` を確認）が Tier A 条件として追加される
- [x] schema.md `schema_version` が v1.4.0 → v1.4.1 に bump（後方互換の判定拡張＝patch）
- [x] 本リポジトリ直下 `.llm-wiki.json` の `schema_version` を v1.4.1 に更新
- [x] vault `current-baseline.md` schema ポインタ更新 commit が落ちる
- [x] vault `log.md` に `schema v1.4.0→v1.4.1: platform.claude.com Tier A 追加` 1 行追記される
- [x] v1.4.1 patch は独立 PR で先行 merge してから Phase 3c 本体に着手（tasklist 先頭タスク）

**discovery 層（L0 / L1 / L2）**:
- [x] SKILL.md mode G に discovery scope = α（`code.claude.com/docs/en/*` ＋ `anthropics/claude-code` の `docs/` + `CHANGELOG.md` + `README.md`）が明文化される
- [x] docs 発見手段がライブ sitemap 全列挙（`Bash('curl -s https://code.claude.com/sitemap.xml')` → `<loc>` 抽出 → `https://code.claude.com/docs/en/` prefix フィルタ）として SKILL.md mode G に明文化される（WebFetch 経路は sitemap.xml を要約してしまうため使わない）
- [x] GitHub 発見手段が `gh api repos/anthropics/claude-code/git/trees/main?recursive=1` → `docs/*.md` + `CHANGELOG.md` + `README.md` 抽出として SKILL.md mode G に明文化される
- [x] 翻訳版 11 言語が除外される（`https://code.claude.com/docs/en/` prefix で英語のみ通すフィルタ・sitemap 全 1605 URL のうち英語 142 件のみ対象）
- [x] GitHub 側の URL 構築規約 `https://github.com/anthropics/claude-code/blob/main/{path}` が SKILL.md mode G に明文化される（`main` 決め打ち・α scope は `anthropics/claude-code` 1 repo 固定）
- [x] URL 正規化規約は Phase 3d 最小ルール（host lowercase + 末尾スラッシュ除去）を踏襲する旨が SKILL.md mode G に記載される（mode B step 3.5 を参照）
- [x] 突合キーは `wiki/sources/*.md.source_url` + `current-baseline.md.migration_pending[].new_url` の両方を見ることが SKILL.md mode G に明文化される
- [x] discovery scope ≠ refresh scope（Y 案）が SKILL.md mode G に明示される。refresh-tier-a §F-3 は不可触で cost amplification ゼロ
- [x] sitemap / gh api tree のキャッシュは持たず毎回 fetch する旨が明示される

**filtering 層（L3 / L7 / L8 + advisor gap 1 / gap 2）**:
- [x] L3 承認制：AskUserQuestion で利用者選択 → 承認分のみ ingest（auto-ingest しない・migration_pending 流儀踏襲）
- [x] L7 永続化先：`current-baseline.md.pending_discoveries[]`（schema v1.5.0 bump）
- [x] pending_discoveries エントリ構造は `{url, source_kind: docs|github, detected_on}` の 3 キー
- [x] **advisor gap 1 dedup ルール**：append 時、dedup キー = 正規化後 `url`。既存エントリありなら append skip（`detected_on` は古い方を保持＝最初に発見した日付）。cron 連続起動でリスト爆発しないことが SKILL.md mode G に明文化される
- [x] L8 UI：上位 4 件 1 ラウンド `multiSelect: true`、優先度ソート = `detected_on` ASC → URL ASCII 昇順 fallback、残り（5 件目以降）は次回 discover-tier-a 起動時に再候補化
- [x] negative cache（明示却下フラグ）は 3c では持たない（migration_pending 流儀踏襲・未選択 = 残置 = 次回再候補化）
- [x] **advisor gap 2 stuck candidates**：3c では既知の限界として放置（3e 以降で再検討）。SKILL.md mode G に「興味のない候補が首位に居座る場合は手動で pending_discoveries エントリを削除する」と注記

**ingestion 層（L4 / L5 + advisor gap 4）**:
- [x] L4 既定モード：対話。`AskUserQuestion` 承認 → 共通 surface 経由 ingest
- [x] `--no-prompt` フラグ：cron/launchd 用。AskUserQuestion 不発火、discovery + pending_discoveries append のみ実行（ingest なし）
- [x] `--dry-run` フラグ：副作用ゼロ。discovery レポートのみ、pending_discoveries 更新も skip、`last_discover_tier_a_run` 更新も skip
- [x] L5 既存 surface 合流：承認分は mode B step 3 以降を呼び出す（共通 surface 経由・Phase 3d 設計流用）。mode B 内の AskUserQuestion 系（既出チェック step 4・要点確認 step 5）はそのまま発火
- [x] mode G は `.llm-wiki.lock` を取得（書き込みモード・Phase 3a §0.6 ロック規約踏襲）。ingest 中も lock を保持する
- [x] **advisor gap 4 cron commit 単位**：`--no-prompt` の append は 1 commit `chore: discover-tier-a: N new candidates (YYYY-MM-DD)` に集約（per-URL commit にしない）

**lint #13（L6）**:
- [x] lint-rules.md に #13 `last-discover-tier-a-run` が追加される（`current-baseline.md.last_discover_tier_a_run` が N 日（既定 14）以上前なら警告。launchd 停止監視・#12 last-tier-a-refresh と同型）
- [x] SKILL.md mode L が 12 検査 → 13 検査に拡張され、書き込み副作用境界表に #13 行が追加される（lock 不要・lint レポート追記のみ）
- [x] lint-rules.md 走査戦略に Phase 3c 追加項（`current-baseline.md` Read 再利用＝追加 0 回）が新設される

**SKILL.md mode G（L9 + advisor gap 3）**:
- [x] SKILL.md にモード G `/llm-wiki discover-tier-a [--no-prompt|--dry-run]` が新設される（mode F の次・SKILL.md 内蔵・mode F 同流儀）
- [x] mode G の step 構成が明確（G-1 lock 取得 / G-2 discovery（sitemap + gh api fetch）/ G-3 突合 + 正規化 / G-4 pending_discoveries append（dedup）/ G-5 AskUserQuestion 承認（既定モード）/ G-6 共通 surface ingest（mode B 呼び出し）/ G-7 last_discover_tier_a_run 更新 / G-8 lock 解放）
- [x] **advisor gap 3 エラーハンドリング表**：mode G エラーハンドリング表が SKILL.md に追加される（`.llm-wiki.lock` 競合・スタール・vault dirty 扱い・`curl` sitemap 5xx/timeout・sitemap XML パース失敗・`gh api` 失敗（auth/404）・`gh: command not found`・pending_discoveries YAML 破損・共通 surface (mode B) 呼び出し失敗・AskUserQuestion 0 件選択）
- [x] AskUserQuestion「適用しない」の実装は SKILL.md 0.b の migration_pending 流儀を verify してから mode G に転写

**schema co-evolution（Phase 3c 本体・v1.4.1 → v1.5.0）**:
- [x] schema.md §2.1 に `last_discover_tier_a_run`（`YYYY-MM-DD`・直近 discover-tier-a 成功日）と `pending_discoveries`（既定 `[]`・配列）フィールドを追加（`refresh-tier-a` 関連フィールドと並べる）
- [x] schema.md §2.1 refresh の編集境界の記述を更新（mode G が `last_discover_tier_a_run` / `pending_discoveries` を更新可・mode F は引き続き `last_tier_a_refresh` / `migration_pending` のみ更新可、§6 schema 軽量ポインタは両モードとも不可触）
- [x] schema.md `schema_version` を v1.4.1 → v1.5.0 に bump（後方互換のフィールド追加＝minor）
- [x] 本リポジトリ直下 `.llm-wiki.json` の `schema_version` を v1.5.0 に更新
- [x] vault `current-baseline.md` schema ポインタ更新 commit が落ちる
- [x] vault `log.md` に `schema v1.4.1→v1.5.0: pending_discoveries + last_discover_tier_a_run 追加` 1 行追記される

**idea.md / CLAUDE.md / 補助同梱**:
- [x] idea.md 更新履歴に Phase 3c 実装エントリが追加される
- [x] CLAUDE.md ステータス行が Phase 3c 実装完了時点で更新される
- [x] CLAUDE.md「主役機能: `/llm-wiki`（単一スキル・モード分岐）」表に mode G の行が追加される
- [x] `references/discover-tier-a-launchd.plist.example`（mode F の plist 例と同型・`--no-prompt` フラグ起動・`--allowedTools=` 形式必須・5 環境変数）が同梱される（任意・利用者が手動 install）

### /llm-wiki Phase 3e（会話 URL hook ＋ parked 項目 ＋ 3c 承認 UX amendment）

> **実装時の reconcile（2026-05-31）**: brainstorm 時点の一部条件を実装判断で refine（A/B 群: inbox は **vault 内→vault 外**＝dirty-check 除外不要・**pending_discoveries 吸い上げ→inbox-as-queue**・承認 surface は **mode H `review` 新設**に確定／E 群: 概要は **discover 時先取り→承認時に提示 4 件だけ遅延取得**）。条件文を実装に合わせて更新し [x] 化。詳細は `.steering/20260530-llm-wiki-phase-3e/design.md`。

**A 群: 会話 URL hook（検出器）**
- [x] UserPromptSubmit hook 設定例が `references/`（`conversation-url-hook.example.json` + `.sh`）に同梱される（`session-start-hook.example.json` と同流儀・利用者が `.claude/settings.json` に手動マージ・project local 推奨・POSIX shell 互換）
- [x] hook は会話中の URL を正規表現で検出し、**vault 外 inbox（`.llm-wiki-inbox.jsonl`）に append するだけ**（スキル起動なし・lock 取得なし・公式 docs `hooks.md`/`skills.md` で hook がスキル起動不可・additionalContext/block/シェル実行のみと実証済・gate で stdin `.prompt` 確定）
- [x] hook の URL フィルタ（localhost/127.0.0.1/0.0.0.0 除外・within-file dedup）が定義される（既取り込み `source_url`・既キューとの authoritative 突合は drain 時 mode H に委譲＝hook は vault を読まず安価）

**B 群: inbox → mode H review → 承認 → ingest**
- [x] inbox ファイルの所在が **vault 外 repo ルート `.llm-wiki-inbox.jsonl`（gitignore）**に確定（vault dirty を生まず F-2/G-2 dirty-check 問題を構造的に回避＝brainstorm の「vault 内＋pathspec 除外」案を上回る）
- [x] （vault 外採用により）inbox を F-2/G-2 dirty-check 除外に追加する必要が**ない**ことが確認される
- [x] 会話 URL は `pending_discoveries[]` に入れず **inbox を queue として mode H が直接 drain** する（Tier A opt-out / Tier B 会話 opt-in の承認 semantics 分離）
- [x] Tier B 単一 URL（会話 URL 含む）は **opt-in 個別承認**（`AskUserQuestion`）→ 承認分のみ共通 surface（mode B）で ingest
- [x] 会話 URL の承認 surface が **mode H `/llm-wiki review` 新設**に確定（H-1〜H-6・対話専用・`--dry-run`）

**C 群: URL 正規化フル仕様（parked・line 349 / 旧 3d 送り）**
- [x] 正規化ルールが 3d 最小（lowercase host ＋末尾スラッシュ除去）から**フル仕様**（fragment 除去・tracking param の **curated denylist** 除去＝strip-all-query 不採用・Tier A host allowlist 正準化）に拡張され SKILL.md mode B step 3.5（単一正本）に明文化される
- [x] 既存データの**再正規化/移行方針**が定義される: raw `source_url` は normalize-on-compare で移行不要、`pending_discoveries[].url` のみ mode G G-4 冒頭で一度きり再正規化（idempotent・N=0 でも commit）
- [x] 3c の dedup キー（正規化後 url）・3d mode B の同一 source 判定が mode B step 3.5 単一正本を参照しフル仕様に追随する

**D 群: stuck candidates 対策（parked・line 410 / 3c で 3e 送り）**
- [x] `pending_discoveries[]` エントリに `declined: true`（negative cache）を導入し解消: G-6 で除外した候補に `declined` を立て、以後 G-4 dedup（再 append しない）と G-6 提示（表示しない）から除外。手動解除の escape hatch も明記

**E 群: 3c mode G 承認 UX amendment（Tier A・142 件 backfill 対策）**
- [x] `discover-tier-a` G-6 の承認を opt-in 上位 4 件提示から **capped バッチ opt-out**（既定=取り込み・除外を選択）に変更。`AskUserQuestion` opt-in 仕様のため「**除外する候補を選択**」と反転提示。G-8 で declined を明示（操作ミス可視化）
- [x] 各候補ページの概要を**承認時に提示バッチ（≤4 件）だけ遅延取得**して表示する（idea.md「discover 時先取り」から逸脱＝142 件先取り回避・design §5.2 記録・`pending_discoveries` に summary フィールド追加不要）
- [x] **1 run あたり ingest 件数上限 N（既定 20・機械的ペース制限）**を導入し、未取り込み ~142 件 backfill を複数 run に分割する
- [x] backfill（初回大量）と継続差分が**同一経路**で処理される（特別扱いの分岐を作らない）

**F 群: schema / SKILL.md / CLAUDE.md co-evolution**
- [x] schema version bump（v1.5.0→v1.6.0・`declined`・正規化所在ポインタ）／ `.llm-wiki.json` 1.6.0 追随。**ボールトポインタ・`log.md` 改訂行は vault co-evolution（実装 tail・T8）で実施**
- [x] SKILL.md に hook 連携・mode H・amendment 後の mode G UX が追記される
- [x] CLAUDE.md ステータス行・「主役機能」表が Phase 3e 実装時点で更新される

**G 群: 本 brainstorm 成果（idea.md 反映）**
- [x] idea.md ロードマップで 3e 行が「会話 URL hook（単一 URL）」に絞り込まれ、3f 行（ウォッチリスト Tier B）が新設される
- [x] idea.md「Phase 3e を 3e/3f に分割した理由（2026-05-30）」節と承認モデル集約が記録される
- [x] idea.md「将来対応予定」に 3e（brainstorm 完了）・3f（要件のみ）エントリが反映される
- [x] リスク表に backfill blast radius・inbox dirty・正規化 migration・relevance フィルタ等が追加される
- [x] idea.md 更新履歴に本 brainstorm エントリが追加される

### /llm-wiki Phase 3f（単一 URL watchlist・要件確定／設計は次回 brainstorm・plan）

> 2026-05-31 brainstorm で 3f/3g 分割。3f は **単一 URL 型のみ**。定点フィード型は Phase 3g（下記スタブ）。

- [x] mode `refresh-watchlist` を新設する（mode F〔refresh-tier-a・Tier A〕は不可触。cron 非対話起動・`--dry-run` 副作用ゼロ）
- [x] **単一 URL 型**: Tier B URL の ingest 時 opt-in 登録＝承認 → cron 自動 refresh（`refresh-tier-a` の Tier B 版・同一 WebFetch 経路）
- [x] **無人範囲**: raw 再取得＋再コンパイル＋同一トピック `## 矛盾` 自動追記までは cron 無人。**baseline 提案は次回対話**（Tier B バージョン乗離は決定6＝承認制を厳守・自動上書きしない）
- [x] deferred baseline 提案の durable carrier が定義され、次回対話 ingest/lint 起動時に AskUserQuestion で提示される（Tier A `migration_pending` フローに相当）。**※ 新 array を増やす前に検討**: `current-baseline.md` は既に `migration_pending`（301）と `pending_discoveries[]`（3c）を持つ。3 つ目の "pending" array は cognitive load・lint カバレッジ増。**まず既存の決定6 対話提案（ingest 時バージョン乖離検知→対話提案）に相乗りできないか**を design で検討し、専用 carrier 新設はそれが不可な場合の明示決定とする（default で `baseline_pending[]` を切らない）
- [x] **【決定 2026-05-31 → flag 採用】registry-vs-flag**: source ページ frontmatter に opt-in `watch: true` フラグを足す（別 registry は持たない）。走査対象集合＝`Glob("wiki/sources/*.md")` を `tier: B`＋`watch: true` で絞り、URL は **mode F F-3 走査**（`sources:` 末尾 raw → その raw の `source_url`）で解決（source ページ自身に `source_url` は無いため必ず raw を辿る）。**決定根拠**: source_url は raw が正本（schema §3・3c carve-out で確定）＝別 registry に URL を持つと二重化し 3e で解消した dedup/migration を再導入する。当初要件の schema bump + watchlist 構造は不採用（共通フィールドに任意 `watch` を足す最小 bump のみ）
- [x] **【決定 2026-05-31 → default-off】opt-in 既定**: 「登録＝承認」の明示マーカーは default-off（source 毎 opt-in・一度きり記事を永久 refresh しない）。flag-on-source-page（上の決定）の帰結＝既存ページに無い `watch` フィールドを default-on にはできないため default-off が唯一整合。registry-vs-flag と矛盾ペアにならないことを確認済
- [x] 書き込み mode 規約の再利用: 3a ロック規約・3d log.md pathspec 除外（`:!wiki/log.md`）・3b 空 commit ガード（再導出しない）。別 cron entry なら refresh-tier-a と同一 `.llm-wiki.lock` を争うため**起動時刻を stagger**（衝突 skip 回避）
- [x] 取得可否 gate は**不要**（理由は「同一 WebFetch 経路」**ではなく**、**registration＝ingest 時にその URL を一度実取得済＝fetchability が per-URL で opt-in 時点に実証される**ため。任意 Tier B host〔Medium/個人ブログ/Substack 等〕は WebFetch hostile があり得るが、取れなかった URL はそもそも ingest できず watchlist に載らない。feed/X 固有の取得可否懸念は 3g の spike gate へ）
- [x] **【一部決定 2026-05-31・残点 OPEN】fetchability decay = 404/URL 消滅時の `refresh-watchlist` 挙動**: t=0 の実証は t=n を保証しない（Tier B は消滅率が Tier A 公式 docs より桁違い＝daily refresh のドミナント運用障害）。**決定＝受動的に lint で surface**（cron は失敗時 1 回 skip・永続リトライ spam しない・自動 opt-out も自動上書きもしない）。**トレードオフ明記**: 死んだ URL は手動 opt-out まで 1 日 1 回リトライされ続ける（self-heal しない。閾値 opt-out 提案は必要なら plan-feature で再訪）。**OPEN な design 残点＝マーカー機構**: 既存 `stale: true`（lint #4 が surface）の再利用は「内容が古い」と「URL が死んでいる」を #4 上で混同する意味的 overload になるため、専用 `fetch_status`/fail-count フィールド新設と未決（plan で決着）
- [x] **lint #14 相当（`refresh-watchlist` 停止監視）**を #12/#13 同型で追加する（別 cron entry の停止検知。明示的省略でない限り必須）
- [x] **【決定 2026-05-31 → carrier 不要】deferred baseline carrier の sync/async fork**: fork は **YES（自己記述）側に倒れる**＝`refresh-watchlist` は mode F の書き込み機械を再利用し再コンパイルで source ページの `claude_code_version` を進めるため、baseline 乖離は vault に自己記述される。これを **lint #3（version 乖離・各ページ `claude_code_version` vs `current-baseline.md` を既に比較）が次回対話で再検出** → 決定6 の「Tier B＝手動主体＋ Phase 2 lint 監査」モデルに合流する（cron は提案を発火しない＝決定6 の同期提案とは別経路）。よって 3 つ目の pending array（`baseline_pending[]`）は不採用
- [x] **【決定 2026-05-31 → `--watch` 引数】ingest 時 opt-in 登録の UI/フロー**: `/llm-wiki ingest <url> --watch` で明示登録（非対話/cron 安全）。**共通 surface 呼び出し側（mode G/H/F migration）は `--watch` を渡さない**＝default-off 維持で誤発火なし。retrofit（既存 source の後付け登録）は frontmatter に `watch: true` を手動追記すれば足りるため 3f では別コマンドを新設しない。ingest 後 AskUserQuestion 案は共通 surface での毎回 prompt・誤発火リスクで不採用
- [x] 論点5 **更新判定（raw 取得日 > `updated` で再コンパイル発動）**の 3f 継承を確認・走査対象集合の列挙方法（flag 方式なら `tier:B`＋`watch:true` のフロントマター Glob・件数増時のコンテキスト圧迫対処）を確定

### /llm-wiki Phase 3g（定点フィード Tier B・**実装済み 2026-06-05**）

> 2026-05-31 brainstorm で 3f から分離。relevance フィルタ機構と承認モデルは下記で**確定済**（設計は `.steering/20260605-llm-wiki-phase-3g/design.md`）。

- [x] mode `discover-watchlist`（`discover-tier-a` の Tier B 版）を新設する（cron 非対話・`--dry-run` 副作用ゼロ）
- [x] **定点フィード型**: サイト登録＝1回承認（購読モデル）→ 新着 URL を RSS/Atom で発見（`ingest --feed=<rss_url>` でフィード登録・source ページに `feed_url` を立てる）
- [x] **relevance フィルタ（確定: 2 段）**: a=タイトル/URL キーワード前段（cron 内・API コスト 0・粗ふるい）→ 通過分のみ b=軽量モデル判定後段で精査。非関連は `declined: true, declined_reason: relevance` で negative cache（stage-2 auto-decline）
- [x] **承認モデル（確定: 承認キュー経由・完全無人にしない）**: relevance 通過分も Tier A mode G と同じ capped バッチ opt-out surface に合流（無人 ingest しない）。Tier B バージョン乖離は決定6・矛盾は `## 矛盾` 自動追記で吸収・フィード単位 cap（N=50・全体 M=200）＋ eviction で暴走防止
- [x] **X 自動巡回は Phase 4 ソース別 fetcher 依存**として記録（X は公開 RSS 無し。当面は単一 URL 型〔3f〕に留め、自動巡回は RSS/Atom 取得可能ソースに限定）
- [x] 取得可否（特に非公式ソースの RSS/Atom/fetcher）の最小 spike を**着手前 gate** にする（3a 同様）→ **PASS（2026-06-05 spike 完了: simonwillison.net / oneusefulthing.org / huyenchip.com 3 サイト全て成功**）

## スコープ外

### 今回対象外
- チーム利用向けの調整機構（レビューゲート、貢献者追跡、アクセス制御）
- セマンティック検索 / `qmd` 等 MCP 連携（200ページ・100ソース超で検討）
- 複数エージェント同時書き込みの競合解決
- ソース別取得ツール（X / Medium / Notion / 公式サイト等）の専用実装 → Phase 4

### 将来対応予定
- Tier A（公式サイト/公式 GitHub）の既知 URL の日次自動再取得・再コンパイル・`current-baseline.md` 自動更新（**Phase 3a・verified 2026-05-24**）
- session-start hook による自動コンテキストロード（**Phase 3b・verified 2026-05-27**・read-only context preload）
- F-4 migration 承認後 ingest フロー再定義＋ F-6 sources: append 明文化＋ C overview 自動更新＋ F-3 log.md append 規約見直し（**Phase 3d・brainstorm 完了 2026-05-29**・既存 mode B ingest 拡張で共通 surface 確立）
- 会話中の URL 自動取り込み（B・単一 URL 型）— UserPromptSubmit hook 検出 → 追記専用 inbox → 承認キュー → 共通 surface（mode B）ingest（**Phase 3e・brainstorm 完了 2026-05-30**・Phase 3d brainstorm 2026-05-29 で 3d から切り出し → さらに 2026-05-30 brainstorm で 3e/3f に分割）。hook は会話中 URL を正規表現検出し inbox に append するだけ（スキル起動不可・書き込み lock 非接触・公式 docs 実証済）。inbox は対話時にキューへ吸い上げ、Tier B 単一 URL は opt-in 個別承認して ingest。**同梱 parked 項目**: (i) URL 正規化フル仕様（tracking param/fragment 除去・Tier A allowlist・3c/3d dedup キーとの整合/移行）、(ii) stuck candidates 対策（承認しない候補が首位に居座る failure mode・3c で 3e 送りにした分）、(iii) 3c mode G 承認 UX amendment（Tier A を capped バッチ opt-out ＋概要先取り化）。**未決設計論点**: inbox の vault 内/外と F-2/mode G dirty-check pathspec 除外への追加、会話 URL の承認 surface（discover-tier-a がキュー全体提示か専用 review surface 新設か）。`disable-model-invocation: true` は維持
- ウォッチリスト型 Tier B 定点観測・**単一 URL 型**（**Phase 3f・要件確定／設計は次回 brainstorm/plan**・2026-05-30 brainstorm で 3e から分離 → 2026-05-31 brainstorm で 3f/3g に分割）。`refresh-tier-a` の **Tier B 版**＝mode `refresh-watchlist` 新設（mode F は不可触）。Tier B URL の ingest 時 opt-in 登録＝承認 → cron 自動 refresh。**無人範囲は raw 再取得＋再コンパイル＋`## 矛盾` 自動追記まで・baseline 提案は次回対話**（決定6＝承認制厳守・durable carrier 必要）。**design 論点 2 件**: (a) registry-vs-flag（別 registry か source ページの `watch: true` フラグか・3e で source が正規化URL正本のため registry 冗長の可能性）、(b) opt-in 既定（default-off vs default-on）。書き込み mode 規約（3a lock・3d log.md pathspec 除外・3b 空 commit ガード）を再利用、別 cron entry は refresh-tier-a と lock を争うため起動時刻 stagger。取得可否 gate 不要（ingest/refresh-tier-a と同一 WebFetch 経路で実証済）
- ウォッチリスト型 Tier B 定点観測・**定点フィード型**（**Phase 3g・要件のみ記録／設計は次回 brainstorm/plan**・2026-05-31 brainstorm で 3f から分離）。`discover-tier-a` の **Tier B 版**を新設。**定点フィード型**（X プロフィール・会社ブログ等）＝サイト登録＝1回承認（購読モデル）→ 新着 URL を RSS/sitemap で発見 → **relevance フィルタ（確定: 2 段＝キーワード前段→モデル判定後段）通過分のみ**承認キュー経由 ingest（**確定: 完全無人にしない**＝Tier A mode G の capped バッチ opt-out surface に合流）。非関連は negative cache（3e `declined` 再利用）。Tier B バージョン乖離は決定6・矛盾は `## 矛盾` 自動追記で吸収・フィード単位 cap で暴走防止。**X は公開 RSS 無し・WebFetch 困難＝Phase 4 ソース別 fetcher 依存**のため当面は単一 URL 型（3f）に留め、自動フィード巡回は RSS/sitemap 取得可能ソースに限定（sequencing inversion: 3g-feed は Phase 4 と前後して着地）。取得可否 spike を着手前 gate にする（3a 同様）
- **Phase 3a 受け入れテスト発見事項 F-1〜F-6 の Phase 3b / 3d 割り当て**:
  - **F-1（最優先）**: SKILL.md F-4a に **github.com URL → `gh api` 経路への routing** を追加。現状 GitHub blob URL は WebFetch では本文取得不能で `claude-code-changelog-verbatim` 系の Tier A ソースが毎回 fail し続けるため、Phase 3b で最優先解消。**→ 2026-05-24 hotfix で先行解消（ブランチ `hotfix/llm-wiki-f1-github-blob-routing` / PR #6 merged）。SKILL.md F-4a に URL routing・F-4b に WebFetch 経路限定の注記・F-4c のフロントマター文言を gh api 経路用に分岐・エラーハンドリング表に gh CLI 3 行を追加。fetched_via / note は既存 verbatim raw の文言を踏襲。**
  - **F-3（Phase 3d）**: F-2 dirty skip 時の log.md append が vault dirty を拡大するトレードオフ。Phase 3b brainstorm（2026-05-24）で 3d 先送り＋ F-4 と束ねたが、**Phase 3d brainstorm（2026-05-29）で訂正**: F-3 は cron dirty escalation の特殊事象、F-4 は通常 ingest と同じ append 規約で独立論点。**(iv) F-2 dirty check から log.md を除外**（git pathspec `git -C wiki-vault status --porcelain -- ':!wiki/log.md'`）で単独解消する方針に確定。log.md は schema §3 で「追記のみ」の agent 完全所有領域で、利用者編集との競合懸念なし。
  - **F-4（重要・Phase 3d）**: migration_pending 承認後も refresh が old URL で取得を継続する設計ギャップ。SKILL.md §2.5 (i) を「URL 書き換え」から「new_url で新規 raw を ingest して source ページ更新」に再定義（F-1 hotfix で導入された gh api routing と WebFetch routing の分岐をそのまま流用できる）。**Phase 3d brainstorm（2026-05-29）で確定**: 共通 surface = 既存 mode B（ingest）拡張、migration case は (a) 既存 source ページに追加 ingest（new raw を sources: append、source_url 書き換え、migration_pending エントリ削除、updated 進行、旧 raw は E1 で不変保持）。
  - **F-5（軽微・Phase 3b）**: F-5 last_tier_a_refresh 更新で空 commit が発生し得る。`if 新値 ≠ 既存値 then commit` のガード追加。
  - **F-6（軽微・Phase 3d）**: SKILL.md F-4e に「再コンパイル時に新 raw を source ページの `sources:` 末尾に append する」記述が明文化されていない。実装は Phase 3a 受け入れテストで append している（`claude-code-overview.md` の `sources:` に 2026-05-17 と 2026-05-24 の両 raw が並ぶことで確認）が、仕様としては F-3 step 3「`sources:` 末尾を最新 raw として解決」の前提を担保するため明記すべき。**Phase 3d brainstorm（2026-05-29）で確定**: 共通 surface 設計の付随仕様として SKILL.md mode B / mode F に「sources: 末尾 append・時系列保証」を明文化する。
  - 詳細根拠は `.steering/20260523-llm-wiki-phase-3a/acceptance-test-report.md` §サマリーの発見事項表を参照。
- Tier A 公式 docs / 公式 GitHub の **未取り込み URL の自動発見＋初期登録**（**Phase 3c・brainstorm 完了 2026-05-29**・Phase 3a 設計時に切り出し。手動 `ingest` の初期登録コスト削減が目的。Phase 3a の lock 規約・migration_pending 流儀・Phase 3d 共通 surface（mode B 拡張）をそのまま流用して承認制 ingest を実装。**α scope = `code.claude.com/docs/en/*` (142 URL・英語のみ・`agent-sdk/*` 含む) ＋ `anthropics/claude-code` repo の `docs/` + `CHANGELOG.md` + `README.md`**。discovery 結果は `current-baseline.md.pending_discoveries[]` に永続化（schema v1.5.0 bump）。承認は `AskUserQuestion` 上位 4 件 1 ラウンド（migration_pending 流儀。**→ Phase 3e で opt-out capped バッチ〔除外を選択・cap N=20・遅延概要・`declined` negative cache〕に amend 済**）。実行モードは既定対話 ＋ `--no-prompt`（cron 用）＋ `--dry-run`（副作用ゼロ）。lint #13 = `last-discover-tier-a-run`（#12 同型・launchd 停止監視）。**schema §4 への `platform.claude.com` Tier A 追加（v1.4.0 → v1.4.1）は Phase 3c 着手前に独立 patch で先行する**（brainstorm 中の verify で `docs.anthropic.com/en/api/*` → `platform.claude.com/docs/en/*` 移転を発見）。discovery scope ≠ refresh scope を維持し、refresh-tier-a §F-3 は不可触で cost amplification ゼロ）
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
| Tier A 承認ゲート緩和で初回 ~142 件 backfill が一晩で無人 ingest（コスト集中・矛盾大量自動追記・vault 肥大） | 高 | Phase 3e で 3c mode G を **capped バッチ opt-out**（既定取り込み・除外を選択）＋ **1 run 件数上限 N**（ペース制限）＋概要先取りに amendment。backfill を複数バッチに分割し無人ダンプを回避（人間ゲートは復活させない・除外のみ選択） |
| 会話 URL hook の inbox が新規 dirty state を生み、夜間 refresh/discover の dirty-check を silent block | 中 | inbox path を `refresh-tier-a` F-2 と `discover-tier-a` mode G の dirty-check pathspec 除外（`:!...`）両方に追加（3d で log.md を除外した規約と同型） |
| URL 正規化フル化で 3c/3d の dedup キー（正規化後 url）・既存 source_url と不整合（phantom dup / missed match） | 中 | Phase 3e で既存 `pending_discoveries[]`・`source_url` の再正規化/移行方針を定義し、3c dedup・3d 同一 source 判定を同時追随させる |
| Phase 3g 定点フィード（特に X）の取得が技術的に困難（X は公開 RSS 無し・WebFetch 困難） | 中 | X は当面 Tier B 単一 URL 型（3f）に留め、自動巡回は RSS/sitemap 取得可能ソースに限定。X 自動巡回は Phase 4 ソース別 fetcher 依存として sequencing inversion を記録・取得可否 spike を着手前 gate に |
| Phase 3g 定点フィード ingest が Claude Code 無関係記事を取り込む（X/会社ブログは他トピックも投稿） | 中 | relevance フィルタを必須化（確定: 2 段＝キーワード前段→モデル判定後段）＋承認キュー経由（完全無人にしない）。非関連は negative cache。false negative は会話 hook/手動 ingest で救済、false positive はフィード単位で除去 |
| Phase 3f cron で refresh-watchlist と refresh-tier-a が同一 `.llm-wiki.lock` を争い毎回 skip し合う | 低 | 別 cron entry の起動時刻を stagger（時間差）させる。lock のスタール判定（timestamp 1h ＋ `kill -0`）は維持 |
| Phase 3f で Tier B URL を全件 refresh 対象にすると一度きり記事を永久再取得する | 中 | ingest 時 opt-in マーカー（`watch: true` 等）で登録＝承認を明示化。default-off を基本線として design で確定 |
| Phase 3f watchlist URL が時間経過で 404/ドメイン失効/恒久リダイレクト（Tier B は Tier A より消滅率が桁違い・daily refresh のドミナント障害） | 高 | fetchability decay を design 最優先論点に。永続リトライ回避（log spam）／stale フラグ＋lint／自動 opt-out 提案（承認制）のいずれかを確定。mode F の Tier A 想定エラー扱いを無検証流用しない |
| Phase 3f `refresh-watchlist` cron が停止しても気付けない | 中 | lint #14 相当（停止監視）を #12（refresh-tier-a）/#13（discover-tier-a）同型で追加。明示的省略でない限り必須 |
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
- 2026-05-23: Phase 3a 実装計画（`.steering/20260523-llm-wiki-phase-3a/` に design.md / requirements.md / tasklist.md）を起こし、対象集合決定を **A 案で確定**（wiki/sources/ の `tier: A` ページ → 最新 raw の `source_url` を辿る = source ページが refresh の単位、孤立 raw は対象外で lint #1 と責務分離）。あわせて「Tier A 公式 docs の **未取り込み URL の自動発見＋初期登録**」を **Phase 3c として新規切り出し**（Phase 3b の「URL 自動取得」とは別物 — 3b は会話中の URL 自動取り込みを想定。3c は手動 `ingest` の初期登録コスト削減が動機で Phase 3a の lock 規約・migration_pending・schema フィールドを流用予定。未設計）。ロードマップ表・将来対応予定・ステータス行を 3 箇所更新。
- 2026-05-23: Phase 3a を実装完了。schema v1.2.0→v1.3.0（`current-baseline.md` 専用フィールド `last_tier_a_refresh` / `migration_pending` を §2.1 として追加、§3 raw 引用記法に Tier A 必須キー `source_url` を明文化、§6 schema 軽量ポインタの refresh 不可触を明記、co-evolution の repo A／ボールト両側を同期）／`references/lint-rules.md` に #12 `last-tier-a-refresh` の判定ロジック・走査戦略（既存 baseline Read 再利用で追加 0 回）・fixture 3 ケース・エラー処理を追加（計 29 ケース）／SKILL.md にモード F `refresh-tier-a [--dry-run]` を新設（F-1 lock 取得 / F-2 dirty-state / F-3 対象集合決定 / F-4 per-source ループ / F-5 last_tier_a_refresh 更新 / F-6 サマリ追記 / F-7 lock 解放、AskUserQuestion 不発火）、ステップ 0.6 lock 規約節を新設（atomic 取得・スタール判定 timestamp 1h ＋ `kill -0` の AND、書き込みモード B/D/F/lint #11 のみ取得、query/通常 lint は不要）、モード A に vault `.gitignore` 整備、モード B/D に lock 取得・解放、モード L を 11→12 検査拡張（書き込み副作用境界表に `lock` 列追加・対話モード `migration_pending` 提案フローを 2.5 として新設）／`references/refresh-tier-a-launchd.plist.example` を新規同梱（`--allowedTools=` の `=` 形式・5 環境変数の理由をコメント明記）。主要 commit: schema `f43c7cf` / lint-rules `8a61403` / SKILL.md `125ef01` / plist 例 `a14ba4b`、vault co-evolution commit `3591ec4`。Phase 3a 受け入れ条件 15 項目を [x] 化。動作確認は方針 (B) スペック検証を採用（design.md §9 推奨）— T5-2〜T5-9 は user 受け入れテストに引き渡し（`(pending acceptance test)` マーク）。設計時に確定した carve-out: 通常 lint は lock 不要（log.md append-only）、`--allowedTools=` の `=` 形式必須（variadic 罠回避）、launchd `EnvironmentVariables` に HOME/PATH/USER/LOGNAME/SHELL の 5 変数を明示（keychain auth 解決必須）。発見事項: SKILL.md 行数が 375→539 行（目安 400 を超過）— モード F の per-source ループ詳細を SKILL.md 単一所有とした design §7 表の規約に沿い意図的に内蔵、references/ に切り出すと単一所有が崩れるため許容範囲とした。
- 2026-05-24: Phase 3a 受け入れテスト完了（`.steering/20260523-llm-wiki-phase-3a/acceptance-test-report.md` 総合判定 PASS、自動検証 47 PASS／実機検証 8 項目 PASS（T5-2〜T5-9）／FAIL 0／CAVEAT は数値表記の軽微な乖離 2 件のみで情報レベル）。実機 force-run で vault commit `0e44ead`（per-source claude-code-overview）/ `1e8e834`（baseline last_tier_a_refresh=2026-05-24）/ `b715d2c`（summary）の 3 段＋ T5-9 同日 2 回目で `dbdb16c`（raw `-2` 連番）/ `ce9061b`（summary 2nd）、lint 全件回帰で `aae9128`、lint #12 単独で `0720e81`、vault `.gitignore` 修正で `ff27e37` を残す（全て `git push しない`）。受け入れテスト発見事項 5 件を Phase 3b 持ち越し論点として記録: **F-1**（最優先）GitHub blob URL の WebFetch は本文取得不能 → SKILL.md F-4a に `gh api` routing 追加、**F-3** F-2 dirty skip 時の log.md append が dirty 拡大（3 案から運用観察で選択）、**F-4**（重要）migration_pending 承認後も refresh が old URL で取得継続するギャップ → SKILL.md §2.5 (i) を「URL 書き換え」から「new_url で新規 raw を ingest」へ再定義、**F-5**（軽微）F-5 last_tier_a_refresh で空 commit 可能性 → 値変化ガード追加。**F-2** vault `.gitignore` の `.llm-wiki.lock` 未登録は本セッション内で commit `ff27e37` で解消済。ステータス行を `Phase 3a implemented` → `Phase 3a verified（2026-05-24）` へ更新。
- 2026-05-24: F-1（最優先持ち越し）を hotfix で先行解消。`hotfix/llm-wiki-f1-github-blob-routing` ブランチ → PR #6 merged（commit `1476b94` → main `bb62f8b`）。SKILL.md F-4a に `https://github.com/{owner}/{repo}/blob/{ref}/{path}` URL pattern detection → `gh api repos/{owner}/{repo}/contents/{path}?ref={ref} --jq .content | base64 -d` 経路 routing を追加。F-4b 301 検出は WebFetch 経路限定であることを明記、F-4c のフロントマター文言（`fetched_via` / `note`）を取得経路で分岐（gh-api 側は既存 `2026-05-17-claude-code-release-verbatim.md` の precedent 踏襲）、エラーハンドリング表に gh CLI 未インストール / auth 切れ / 404 の 3 行追加。実機検証は `gh api` 単独叩きで CHANGELOG 2.1.150 まで逐語取得できることを確認、`/llm-wiki refresh-tier-a` の force-run は次回 launchd 起動 or 手動運用で観察に委ねた（Phase 3a verified を覆さない方針）。新規発見 F-6（SKILL.md F-4e の `sources:` append が実装はされているが明文化されていない）を Phase 3b 持ち越しに追加（その後 Phase 3d に再分類）。
- 2026-05-24: Phase 3b 開始 brainstorm を実施し、Phase 3b を 3b/3d に分割。Phase 3b 当初スコープ「A=session-start hook 設定例・B=会話中 URL 自動取り込み・C=overview 自動更新・F-3〜F-6 持ち越し」のうち、advisor レビューを経て **B と F-4 が同じ surface（new raw を ingest して source ページの sources: を更新する）を共有**・**C は B の下流**・**F-6 の sources: append 明文化も F-4 §2.5 (i) 再定義と同じ surface** と判明。一方 **A（read-only context preload）と F-3 / F-5 は独立かつ trivial** で設計の重さが大きく異なるため、**Phase 3b = A + F-3 + F-5**（軽量 read-only クラスタ）、**Phase 3d = B + C + F-4 + F-6**（会話駆動 write クラスタ）として連番分割（Phase 3c は `discover-tier-a` 予約済）。F-3 は brainstorm 2 ラウンド目で「log.md append 規約は F-4 と同じ surface のため Phase 3d 先送り」として Phase 3d に再分類し、Phase 3b は最終的に **A + F-5** に確定。ロードマップ表に Phase 3d 行を新設し、Phase 3b 行の概要を「read-only context preload + 軽微パッチ」に絞り込み。Phase 3 分割理由節に 3b/3d 分割の経緯を追記。F-1〜F-6 の Phase 振り分けセクションを更新。
- 2026-05-24: Phase 3b を実装完了。`.claude/skills/llm-wiki/references/session-start-hook.example.json` を新規同梱（`matcher: "*"`・`command: [ -L ./wiki-vault ] && cat ./wiki-vault/wiki/current-baseline.md 2>/dev/null || true`・`_comment` / `_notes` で project local 推奨・CWD 前提・vault 不在時無音終了を明記、Claude Code SessionStart hook 仕様に整合）／SKILL.md モード A に step 10「session-start hook 設定例の案内（参考・自動インストールしない）」を追加（references への明示参照、project local 推奨を明文化）／SKILL.md モード F の F-5 step を**値変化ガード付き**仕様に書き換え（`last_tier_a_refresh` 本日付同値の場合は Edit/commit を skip し log に `unchanged` 行追記、`--dry-run` でも分岐レポートのみ）／エラーハンドリング表に「`last_tier_a_refresh` 既に本日付」1 行を追加。検証は方針 (B) スペック検証を採用（design.md §6 推奨）— jq parse 成功・hook spec 値の照合・SKILL.md / idea.md 手動レビューで合格判定。実機 hook 動作と F-5 ガードの force-run 検証は利用者環境差異・Phase 3a verified を覆さない方針で deferred。Phase 3b 受け入れ条件 8 項目を [x] 化。設計ドキュメントは `.steering/20260524-llm-wiki-phase-3b/` の design.md / requirements.md / tasklist.md（gitignored）。
- 2026-05-27: Phase 3b 受け入れテスト完了（`.steering/20260524-llm-wiki-phase-3b/acceptance-test-report.md` 総合判定 PASS、自動検証 7 PASS／手動レビュー 7 PASS／FAIL 0）。検証対象は `feat/llm-wiki-phase-3b` HEAD = `643020f`（PR #7 merged → main `911e9fc`）。A 群 8 項目（hook 設定例 JSON の存在・jq parse・hook spec 値・3 点注釈）／B 群 4 項目（SKILL.md モード A step 10 追加・F-5 値変化ガード・エラーハンドリング表行・全体構造の齟齬なし）／C 群 2 項目（idea.md「将来対応予定」直下 Phase 3b セクション 8 項目 [x] 化・更新履歴エントリ）すべて PASS。実機 hook 動作と F-5 force-run は requirements の明示的 carve-out として判定対象外。ステータス行を `Phase 3b implemented（2026-05-24・受け入れテスト pending）` → `Phase 3b verified（2026-05-27）` へ更新。
- 2026-05-29: Phase 3d 開始 brainstorm を実施し、以下を反映 — 論点 1（共通 surface）から順番に 4 論点を確定。**論点 1.1**: migration_pending case は (a) 既存 source ページに追加 ingest（new raw を sources: append・source_url 書き換え・migration_pending エントリ削除・updated 進行・旧 raw は E1 で不変保持）。**論点 1.2**: 共通 surface は (β) 既存 mode B（ingest）拡張で構成（専用 internal mode 追加なし）。**論点 1.3/1.4**: advisor 指摘を反映して 3d 用 URL handling を最小ルールに scope down — lowercase host + 末尾スラッシュ除去のみ、Tier A 自動判定は 3d では不要（migration_pending 由来は元 source の Tier 継承）、フル仕様（tracking param 除去・フラグメント除去・allowlist 4 host）は Phase 3e で再開。**論点 1.5/1.6/1.7**: 矛盾検出は既存 ingest 規約踏襲（`## 矛盾` 自動追記）・書き込み境界 lock / commit 単位は既存規約踏襲・F-6 sources: append 末尾規約を SKILL.md に明文化。**論点 2**: advisor レビューで「B（会話中 URL auto-detection）は共通 surface への trigger 経路であって surface 自体ではない」と再認識し、**B を Phase 3e として 3d から切り出し**（Phase 3d brainstorm 2026-05-29 で確定）。Phase 3d は **F-4 + F-6 + C + F-3** に絞り込む。**論点 3**: overview 自動更新は (i) `## 現状` セクションの構造化フィールド（統計値 + 最終 ingest 日付）のみ・(ii) 書き込みモード操作の同一 commit に inline・(iii) 完全自動（値変化ガード付き）。**論点 4**: F-3 は (iv) F-2 dirty check から log.md を除外（git pathspec `-- ':!wiki/log.md'`）で解消。advisor が `grep -v` の false negative を指摘し pathspec exclusion に確定。**重要な訂正**: 2026-05-24 brainstorm の「F-3 と F-4 は同じ log.md append 規約として束ねる」フレーミングを本 brainstorm で訂正 — F-3 は cron dirty escalation の特殊事象・F-4 は通常 ingest と同じ append 規約で独立論点。F-3 は (iv) 単独解消、F-4 は通常 ingest の延長で扱う。ロードマップ表に Phase 3e 行を新設し、Phase 3d 行の概要・スコープを更新。Phase 3 分割理由節に 3d/3e 分割の経緯を追加。F-1〜F-6 振り分けセクションを更新（F-3 を 3d 独立論点・F-4 を 3d 共通 surface・F-6 を 3d 仕様明文化に再分類）。受け入れ条件「/llm-wiki Phase 3d」27 項目を新規追加。次回作業は `.steering/20260529-llm-wiki-phase-3d/` に design.md / requirements.md / tasklist.md を起こす。
- 2026-05-29: Phase 3d を実装完了。schema v1.3.0→v1.4.0（§3 raw 引用記法直下に「log.md は dirty 状態でも append + commit 可」を 1 行明記＝F-3 解消の前提規約／§8 として `overview.md` の `## 現状` セクション構造定義（agent 完全所有領域 vs 手動編集領域・統計フィールド 5 件 + 2 日付・`_fixture-*` 除外・値変化ガード semantics・更新タイミング表）を新設、co-evolution の repo A／ボールト両側を同期）／SKILL.md mode B（ingest）を共通 surface 拡張（step 3.5 として同一 source 判定 3 段ロジック + URL 正規化最小ルール、step 6 共通 surface 追記事項として sources: 末尾 append + (ii) ケースの source_url 書き換え + migration_pending エントリ削除 anchor 戦略、step 8.5 として overview 自動更新を新設・値変化ガード付き、step 0.b 括弧内も新仕様へ同期）／mode L §2.5 (i) を「URL 書き換え単独」から「共通 surface 経由で new_url を mode B に渡して新規 raw ingest」に再定義（anchor 戦略は mode B 側に移動）／mode F の F-2 dirty check 判定式を `:!wiki/log.md` 除外形に変更（F-3 解消）＋ F-3/F-4 独立論点訂正、F-4e に sources: 末尾 append 仕様再掲、F-4g として overview 自動更新を新設、F-5 last_tier_a_refresh 更新に overview inline 更新を追加、F-4g → F-4h（旧 F-4g）にリネーム／mode D の synthesize に step 3.5 として overview 自動更新を inline 追加。idea.md 27 項目を [x] 化、CLAUDE.md ステータス行・主役機能表・不変条件 5 を Phase 3d 実装に整合させて更新。動作確認は方針 (B) スペック検証を採用（design.md §9 推奨）— SKILL.md / schema.md diff の手動レビュー＋自動 grep（A-4-1 / C-1 / D-1〜D-3 / B-7-1）で合格判定。実機 deferred 項目: F-4 migration_pending 承認後 ingest の force-run・F-3 dirty escalation の実機再現・overview 値変化ガードの二重 ingest 実機検証は requirements の明示的 carve-out として受け入れテスト時に判断。設計ドキュメントは `.steering/20260529-llm-wiki-phase-3d/` の design.md / requirements.md / tasklist.md（gitignored）。

- 2026-05-29: Phase 3d 受け入れテスト完了（`.steering/20260529-llm-wiki-phase-3d/acceptance-test-report.md` 総合判定 PASS、自動検証 18 PASS／半自動レビュー 12 PASS／手動レビュー 12 PASS／FAIL 0）。検証対象は `feat/llm-wiki-phase-3d` HEAD = `07de9f9`（PR #9 merged → main `7246a34`）。A 群 16 項目（共通 surface F-4/F-6・mode B step 3.5 同一 source 判定 3 段・URL 正規化最小ルール・Tier 自動判定 carve-out・旧 raw 不変保持・矛盾検出既存規約踏襲・lock/commit 単位・sources: append 明文化）／B 群 14 項目（overview.md `## 現状` セクション領域境界・統計 5 件 + 2 日付・mode B/F/D inline 更新・値変化ガード・lint #11 不可触・schema co-evolution・vault 初回構造変換 commit `6e3654f`）／C 群 4 項目（F-2 pathspec exclusion `:!wiki/log.md`・log.md dirty append 規約・F-3/F-4 独立論点訂正）／D 群 5 項目（schema v1.4.0 bump・current-baseline ポインタ・vault log.md 改訂行・idea.md 更新履歴・CLAUDE.md ステータス）／E 群 3 項目（main=37c288e 分岐・PR 同一範囲・PR #9 description で design.md/requirements.md 参照と deferred 3 項目明示）すべて PASS。実機 deferred 項目（F-4 force-run・F-3 dirty escalation 実機再現・overview 値変化ガード実機検証）は requirements の明示的 carve-out として判定対象外で受け入れテスト時の利用者裁量に委ねた。ステータス行を `Phase 3d 実装済み` → `Phase 3d verified（2026-05-29）` へ更新。

- 2026-05-29: Phase 3c 開始 brainstorm を実施し、advisor レビュー 2 ラウンドを経て **discovery / filtering / ingestion の 3 層分離軸**で 10 論点（L0〜L9）を確定。**L0 scope**: α 厳格（CLI 中心）= `code.claude.com/docs/en/*` 142 URL（英語のみ・brainstorm 中の sitemap verify で `agent-sdk/*` 含むと判明）＋ `anthropics/claude-code` の `docs/` + `CHANGELOG.md` + `README.md`。**discovery scope ≠ refresh scope（Y 案）** を採用し refresh-tier-a §F-3 を不可触に維持（cost amplification ゼロ）。**重要 verify**: `docs.anthropic.com/en/api/*` → 301 → `platform.claude.com/docs/en/*` 移転を発見し、**schema §4 v1.4.1 patch（`platform.claude.com` を Tier A 条件に追加）を Phase 3c 着手前の独立 PR で先行 merge する方針**に確定。**L1**: docs はライブ sitemap 全列挙（`curl` ベース・WebFetch は sitemap.xml 要約のため不可）、GitHub は `gh api git/trees/main?recursive=1`、キャッシュなし。**L2**: URL 正規化は Phase 3d 最小ルール踏襲、突合キーは `wiki/sources/*.md.source_url` + `current-baseline.md.migration_pending[].new_url` の両方、GitHub URL 構築は `blob/main/{path}` 固定。**L3/L7/L8**: 承認制（AskUserQuestion 上位 4 件 1 ラウンド `multiSelect: true`）、永続化先は `current-baseline.md.pending_discoveries[]`（schema v1.5.0 bump）、優先度ソートは `detected_on` ASC → URL ASCII 昇順 fallback、negative cache 無し。**L4/L5/L6**: 両モード対応（既定対話＋`--no-prompt`＋`--dry-run`）、共通 surface (mode B) 内部呼び出し、lint #13 = `last-discover-tier-a-run`（#12 同型・launchd 停止監視）。**L9**: mode G として F の次・SKILL.md 内蔵（mode F 同流儀）。**advisor 指摘 gap 1〜4**: (1) pending_discoveries の dedup ルール（dedup キー = 正規化後 url、`detected_on` は古い方保持）、(2) stuck candidates failure mode は 3c では既知の限界として放置（3e 以降再検討）、(3) mode G エラーハンドリング表を mode F と同型で SKILL.md に同梱、(4) `--no-prompt` の commit 単位は 1 commit `chore: discover-tier-a: N new candidates` に集約。受け入れ条件「/llm-wiki Phase 3c」を schema §4 v1.4.1 patch / discovery / filtering / ingestion / lint #13 / SKILL.md mode G / schema v1.5.0 co-evolution / idea.md・CLAUDE.md 補助同梱の 8 群で計 **45 項目**（当初本エントリで「33 項目」と表記したが、schema 2 群 12 項目を誤除外した数。実数は 45。2026-05-30 advisor 指摘で是正）を新規追加。次回作業は (1) schema §4 v1.4.1 patch（`platform.claude.com` Tier A 追加）を独立 PR で先行 merge、(2) `.steering/20260529-llm-wiki-phase-3c/` に design.md / requirements.md / tasklist.md を起こす。

- 2026-05-30: schema §4 v1.4.1 patch を独立 PR #12（`adb3366` → main `dfe92ab`）で先行 merge（`platform.claude.com` を Tier A 条件に追加・vault co-evolution `bf2d67d`）。あわせて Phase 3c brainstorm 記録を PR #11（`08cb653` → main `971a076`）で merge。

- 2026-05-30: Phase 3c 設計・実装。`.steering/20260529-llm-wiki-phase-3c/` に design.md（11 章・mode G step G-1〜G-8・3 層分離・リスク表）/ requirements.md（A〜I 群 63 検証細目）/ tasklist.md（T0〜T12）を起こし、advisor レビュー 1 ラウンドで 3 点是正: (1) **G-6 lock 再入防止**（mode G は mode B の ingest 本体 step 3〜9 のみ呼び step 0 lock / step 10 解放は呼ばない＝自己デッドロック回避。pending_discoveries 削除は mode B step 9 の付随変更同梱枠組みに乗せる）、(2) **受け入れ条件件数を 45 に統一**（「33」は schema 2 群 12 の誤除外）、(3) **GitHub scope を実態補正**（`gh api` 実測で `anthropics/claude-code` に `docs/` は存在しない＝code.claude.com 移管済と判明 → repo ルートの `CHANGELOG.md` + `README.md` 2 ファイルに確定、`plugins/**`/`examples/**` は将来拡張候補）。実装: schema v1.4.1→v1.5.0（§2.1 に `last_discover_tier_a_run` / `pending_discoveries[]` 追加・編集境界を mode F/G の 2 モードに分離明文化）／SKILL.md にモード G `discover-tier-a [--no-prompt|--dry-run]` を新設（G-1 lock〜G-8 サマリ+解放・discovery scope α 厳格・dedup ルール・stuck candidates 注記・エラーハンドリング表・lock 再入防止境界）＋ステップ 0.6 lock 規約に G 追加＋ mode L を 12→13 検査拡張（#13 行・書き込み境界表）＋使用方法/モード分岐に G 登録／lint-rules.md に #13 `last-discover-tier-a-run`（既定 14 日・#12 同型・走査 Phase 3c 項追加 Read 0 回・しきい値表・判定ロジック・エラー・fixture 24→32 ケース）／`.llm-wiki.json` schema_version 1.4.1→1.5.0／`references/discover-tier-a-launchd.plist.example` 同梱（`--no-prompt` 起動・`=` 形式・5 環境変数・日曜 04:00 で refresh 03:00 と lock 競合回避）。idea.md 45 項目 [x] 化・本履歴追加・ステータス行更新、CLAUDE.md ステータス行・主役機能表に mode G 追加。動作確認は方針 (B) スペック検証。実機 deferred 6 項目（discover 対話 force-run・`--no-prompt` launchd 実行・`--dry-run` 副作用ゼロ・lint #13 停止監視発火・stuck candidates 手動再現・dedup 2 回起動）は requirements §carve-out として受け入れテスト時に判断。vault co-evolution（current-baseline.md 専用フィールド初期化 + schema ポインタ v1.5.0 + log.md 改訂行）は同一 PR 範囲で実施。

- 2026-05-30: Phase 3c 受け入れテスト完了（`.steering/20260529-llm-wiki-phase-3c/acceptance-test-report.md` 総合判定 **PASS**、自動検証 63 PASS／FAIL 0）。検証対象は `feat/llm-wiki-phase-3c` HEAD = `2dc1cf7`（PR #13 OPEN・base main `971a076`）。A 群 8 項目（schema §4 v1.4.1 patch・`platform.claude.com` Tier A・PR #12 `MERGED` 2026-05-29 22:39 を `gh pr view 12` で直接確認・`adb3366` は本体 7 commits に含まれず main base 存在＝先行着地。`schema_version` ピン項 A-2-1/A-3-1/A-4-1 は v1.5.0 へ co-evolution で前進＝superseded PASS）／B 群 12 項目（discovery scope α 厳格・curl sitemap・gh api trees・URL 正規化 mode B 3.5 参照・両集合突合・F-3 不可触・キャッシュなし）／C 群 10 項目（承認制・`pending_discoveries[]` 3 キー・dedup ルール・上位 4 件 multiSelect・negative cache なし・stuck candidates 注記）／D 群 9 項目（既定対話・`--no-prompt`・`--dry-run`・共通 surface 内部呼び出し・lock 保持・1 commit 集約）／E 群 3 項目（lint #13 検査表・mode L 13 検査・走査追加 Read 0 回）／F 群 5 項目（mode G 新設・G-1〜G-8・エラーハンドリング表・0.b 流儀参照・lock 規約 G 追記）／G 群 6 項目（schema v1.5.0 co-evolution）／H 群 5 項目（idea.md 履歴・45 項目 [x]・CLAUDE.md ステータス/表・plist 同梱。H-3 は CLAUDE.md 集約ステータス規約が intent を満たすと明示裁定）／I 群 5 項目（main 分岐・同一 PR 範囲・PR #13 description で design/requirements 参照 + deferred 6 項目明示 + vault commit `315cf74` 記載・PR #12 先行 merge）すべて PASS。実機 deferred 6 項目（discover 対話 force-run・`--no-prompt` launchd 実行・`--dry-run` 副作用ゼロ・lint #13 停止監視発火・stuck candidates 手動再現・dedup 2 回起動）は requirements §carve-out として Phase 3a / 3d と同じくスペック検証のみで verified に上げ、runtime 確認は merge 後の利用者裁量に委ねた。ステータス行を `Phase 3c implemented（受け入れテスト pending）` → `Phase 3c verified（2026-05-30）` へ更新。

- 2026-05-30: **Phase 3c carve-out 実機検証で core-path defect を発見し fix**（`fix/llm-wiki-g4-source-url-traversal`）。PR #13 merge 後に carve-out（discover-tier-a discovery 実走）を実機確認したところ、突合（dedup）の核心バグを発見: SKILL.md G-4 と **mode B step 3.5 (i)** がいずれも「既存 source ページの**フロントマター** `source_url` と突合」と記述していたが、`source_url` は **raw のフロントマターキー**（schema §3）で **source ページには存在しない**（schema §2 共通フィールドに無い・実機 3 ページで不在確認）。文字どおり実装すると既存 URL 集合が常に空になり、(1) discover-tier-a が取り込み済み URL を未取り込みと誤検出して再候補化、(2) mode B step 3.5 が (i) 統合に決して入らず (iii) 新規作成へ落ちて重複 source ページを生成。後者は **Phase 3d（merged・verified）の手動 `ingest <url>` 経路にも潜在**していた同一根因。スペック検証では検出不能（スペック自身が誤っていたため）で、carve-out 実機検証が拾った。**Option A で是正**（schema 変更なし）: G-4 step 1 と step 3.5 (i) を **mode F F-3 step 3〜4 と同じ走査**（source ページ → `sources:` 末尾 raw → その raw の `source_url`、`source_url` を欠く raw は skip）に修正。requirements B-5-1 / design.md §7.1 G-4 の文言も同一 fix で整合。実機再検証（host のみ lowercase 正規化）: discovery で en docs **142 件**を確認（= 設計値「142 URL」と一致＝設計値検証）。F-3 走査で既存集合 = {overview, CHANGELOG} を解決し、候補 144（docs 142 + github 2）との突合で**未取り込み = 141 docs（142 − overview）+ 1 github（README）= 142 件**（overview / CHANGELOG 除外・README 残存）を確認（「en docs 総数 142」と「未取り込み 142」は別集合がたまたま同値）。受け入れレポートに本経緯を追記。**fix は PR #14（`fix/llm-wiki-g4-source-url-traversal` → main `c9d8843`・2026-05-30 05:30 MERGED）で着地し、`Phase 3c verified` / `Phase 3d verified` を無限定に確定**（dedup fix 適用済）。残る carve-out 4 項目（force-run 実 ingest commit・launchd 実行・lint #13 発火・stuck/dedup の commit 伴う再現）は副作用・システム設定変更を伴うため利用者裁量に委ねる。
- 2026-05-30: Phase 3e 開始 brainstorm を実施し、**Phase 3e を 3e/3f に分割**。当初の「会話中 URL 自動取り込み（B）」を掘ると、ユーザーの本意は **(い) ウォッチリスト型の毎日自動更新**で会話 URL は副次と判明。`claude-code-guide` サブエージェントで公式 docs を実証し **(1) UserPromptSubmit hook はスキルを起動できない**（additionalContext 注入・block・hook 自身のシェル実行のみ）、**(2) `disable-model-invocation` はスキル単位で mode 別切替不可**を確定 → 「auto-ingest」は**検出（hook で決定的）と取り込み（書き込み = 承認 or cron）に分離**でき、`disable-model-invocation: true` を外す（決定6/7 と衝突）必要なしと判明。設計の重さで **会話 URL hook（検出器 1 つを既存 3c キューに足すだけ・新規書き込み経路ゼロ）= Phase 3e** と **ウォッチリスト型 Tier B 定点観測（refresh/discover-tier-a の Tier B 版・新モード・relevance フィルタ・X は Phase 4 fetcher 依存）= Phase 3f（要件のみ記録）** に分割。**承認モデルを集約**: ① Tier A=capped バッチ opt-out（概要先取り・1 run N 件上限・無人 discover ＋軽量バッチ承認）② Tier B 単一/会話 URL=opt-in 個別承認 ③ Tier B 定点フィード=サイト登録＝1回承認→新着は Claude Code relevance フィルタ通過分のみ cron 自動 ingest。Phase 3e に **parked 項目 3 件を同梱**（URL 正規化フル仕様 line 349・stuck candidates line 410・3c mode G 承認 UX amendment）。**ユーザー対話での確定事項**: 公式は選別の手間を避けたい → 承認は「概要付き capped バッチで一括・不要なものだけ opt-out」で合意（完全無人 ingest ではなく無人 discover ＋軽量バッチ承認・`AskUserQuestion` opt-in 仕様のため「除外を選ぶ」反転提示）。X/会社ブログは定点フィード型、単独記事は単一 URL 型、refresh は自動。**advisor レビュー指摘を記録**: (a) 3c Tier A 承認緩和の初回 ~142 件 backfill 無人ダンプ問題 → capped バッチ opt-out ＋ 1 run 件数上限で解消、(b) inbox は新規 dirty state のため F-2/mode G dirty-check pathspec 除外に追加必須、(c) URL 正規化フル化は 3c/3d dedup キー・source_url との整合/移行が必要、(d) 会話 URL 承認 surface は discover-tier-a がキュー全体提示か専用 review surface 新設かが未決。ロードマップ表（3e 絞り込み・3f/4 行更新）・3c 行 amendment 注記・「Phase 3e を 3e/3f に分割した理由」節・将来対応予定（3e/3f）・受け入れ条件「Phase 3e」G 群相当 + 「Phase 3f」要件スタブ・リスク表 5 件・ステータス行を更新。次回作業は Phase 3e の `.steering/` design.md / requirements.md / tasklist.md 起こし（3f は別 brainstorm/plan）。
- 2026-05-31: Phase 3e 設計・実装。`.steering/20260530-llm-wiki-phase-3e/` に design.md（11 章・mode H step H-1〜H-6・X 案採用根拠・正規化フル仕様・advisor 反映 §11.4）/ requirements.md（GATE + A〜G 群 + carve-out 6 項目）/ tasklist.md（T0〜T12）を起こし、advisor 2 ラウンドで **X 案を確定**（mode G G-6 を in-place で opt-out amend ＋ 会話用 mode H `review` 新設。Y 案＝G-6 削除一元化は verified 3c 破壊・利得ゼロで却下）。**実装前 gate（T0）PASS**: `claude-code-guide` で公式 docs を確認し UserPromptSubmit hook stdin のプロンプト本文は **`prompt` フィールド**（生文字列・引用 JSON 例付き）と確定、抽出パイプライン（`jq -r .prompt | grep -oE`）を doc スキーマ通りの合成ペイロードで決定的検証。実装: SKILL.md mode B step 3.5 URL 正規化フル化（host lowercase + fragment 除去 + 末尾スラッシュ + tracking param **curated denylist** 除去〔strip-all-query 不採用〕+ Tier A host allowlist 正準化・normalize-on-compare で source_url 移行不要・単一正本）／ mode G amendment（G-4 に `pending_discoveries.url` 再正規化 migration〔idempotent・N=0 でも commit〕＋ `declined` dedup、G-6 を **opt-out capped バッチ**〔除外を選択・cap N=20・遅延概要 ≤4 件・G-8 で declined 明示〕に変更＋除外候補に `declined` negative cache で stuck candidates 解消）／ **mode H `/llm-wiki review [--dry-run]` 新設**（H-1 lock 〜 H-6 inbox 書き直し〔現ファイルから処理済除去〕・vault 外 `.llm-wiki-inbox.jsonl` を queue として drain→フル正規化→取り込み済み突合→opt-in 個別承認→共通 surface ingest・対話専用・エラー表）／ mode A init に repo `.gitignore` inbox 追記＋会話 hook 案内 step 11／ schema v1.5.0→v1.6.0（`pending_discoveries[].declined` + 正規化所在ポインタ）／ `.llm-wiki.json` 1.6.0／ `references/conversation-url-hook.example.{json,sh}` 同梱（project guard・jq 依存ガード・localhost 除外・within-file dedup・機能テスト合格）／ CLAUDE.md ステータス・mode H 行・ロードマップ 3e/3f。主要 commit: brainstorm `ce11abf` / SKILL.md `8578163` / schema+json `304fb35` / hook example `261ea99`（docs commit + vault co-evolution は後続）。**実装後 advisor 指摘 4 点反映**: (1) opt-out 反転 × `declined` 永続化の footgun を G-8 declined 明示で可視化、(2) H-6 の snapshot 減算の誤りを「現ファイルから処理済除去」に是正、(3) 再正規化 N=0 dangling dirty を「N=0 でも commit」で回避、(4) inter-queue 二重トラッキングを既知の限界として mode H に記録。受け入れ条件「/llm-wiki Phase 3e」A〜F 群を実装に合わせ reconcile して [x] 化（inbox vault 内→外・pending_discoveries 吸い上げ→inbox-as-queue・先取り→遅延の refine を明記）。動作確認は方針 (B) スペック検証（requirements behavioral 細目を grep walk 全 PASS）。実機 deferred 6 項目（hook 発火→inbox append・mode H 通し・G-6 opt-out force-run・declined 2 回起動再現・正規化 denylist 実 URL・再正規化 migration）は受け入れテスト時の利用者裁量。vault co-evolution（current-baseline.md ポインタ v1.6.0 + log.md 改訂行）と push/PR は別途確認。`.steering/` は gitignore のため本 commit には含まれない。
- 2026-05-31: Phase 3e 実機受け入れテスト完了（**6 項目すべて PASS**・実 vault で通し検証）。**item 1 hook live fire**: UserPromptSubmit hook 設置→URL 含むプロンプト送信で vault 外 `.llm-wiki-inbox.jsonl` に append を確認（無差別検出＝プロンプト中の全 URL を拾い人間が review で取捨、を実例で確認）。**item 2 mode H review 通し**: opt-in 個別承認 1 件 ingest→新規 source 作成・per-source commit + log review summary の 2 commit 分離・取り込み済のみ inbox 除去/未選択は残置・overview `## 現状` inline 更新（値変化ガード通過）。**item 3 mode G opt-out capped バッチ**: 「除外を選択」反転提示・cap N=20・4 件×ラウンド。**item 4 declined negative cache**: 除外 20 件に `declined: true`・G-8 で declined URL 一覧を log 明示（opt-out 反転の操作ミス可視化＝advisor fix #1）・再実行 dry-run で `would-append=0`（declined が G-4 dedup から除外され再候補化せず＝stuck candidates 解消を定義的に確認）。**item 5 URL 正規化フル仕様**: `utm_*`/`ref`/fragment 除去・`id`/`page` 等の意味ある param 保持（denylist 方式＝strip-all-query でない）・公式 host を Tier A 判定。**item 6 再正規化 migration**: 旧形 pending（`mcp?utm…&ref`/`slash-commands#…`）をフル正規化して実 Edit+commit・idempotent（2 回目 `would-renormalize=0`）・再正規化後 `mcp` が discovery と一致して dedup＝**phantom duplicate 防止を実機確認**。空 commit ガード（同日 `last_discover_tier_a_run` unchanged）も確認。すべての書き込みモードで `--dry-run` 副作用ゼロ（vault HEAD/dirty/pending/inbox 不変）を git で検証。テスト痕は cleanup 済（vault commit `0f16b19`: テスト declined 18 件解除・fixture 2 件のみ declined 維持・pending 144 保持／inbox は noise 3 件除去で 2 行）。実機検出の副次事例: X 告知（@ClaudeDevs dynamic workflows）は Tier B/Phase 4 依存で X URL 直接取り込みは見送り、正本 `code.claude.com/docs/en/workflows` が既に discover 候補にあり Tier A で取れる＝3e ループ（告知→公式 docs を Tier A）が機能（Phase 3f/4 の動機事例として記録）。ステータス行を `Phase 3e implemented（受け入れテスト pending）` → `Phase 3e verified（2026-05-31）` に更新。
- 2026-05-31: Phase 3f 設計 brainstorm を実施し、**Phase 3f を 3f/3g に分割**。当初の「ウォッチリスト型 Tier B（単一 URL 型＋定点フィード型）」を掘ると **重さが段違いの 2 塊**が同居と判明: **単一 URL 型 refresh（軽量＝既存 refresh-tier-a に Tier B 対象を足すだけ・relevance 不要・取得可否実証済）** と **定点フィード型 discover→ingest（重量＝relevance フィルタ・cron ingest・X の Phase 4 依存・取得可否 spike 集中）**。3a→3e の「重さで割って連番分割」を踏襲し **単一 URL 型を Phase 3f**（要件確定）、**定点フィード型を Phase 3g**（要件のみ記録）に分割。**ユーザー対話での確定事項**: (1) 3f は **mode `refresh-watchlist` 新設**（mode F〔Tier A〕不可触＝verified 3a/3d 非破壊・Tier B 固有 baseline 振る舞いを混ぜない）、(2) 無人範囲は **raw 再取得＋再コンパイル＋`## 矛盾` 自動追記まで cron 無人・baseline 提案は次回対話**（決定6 厳守）、(3) 3g relevance フィルタ＝**2 段（キーワード前段→モデル判定後段）**・3g 承認＝**relevance 通過分も承認キュー経由（完全無人にしない・Tier A mode G capped バッチ opt-out surface に合流）**。**advisor レビュー 7 点を反映**: #1 命名整合（roadmap 表・分割理由節・status 行・将来対応予定・リスク表をすべて 3f/3g に揃える）、#2 単一 URL に別途 registry 不要の可能性（3e で source ページが正規化URL正本＝`refresh-watchlist` は `tier:B`＋`source_url`＋opt-in フラグ走査で済む可能性＝registry-vs-flag を design 論点に・当初の schema bump 要件は継承せず再導出）、#3「登録＝承認」に ingest 時 opt-in マーカー必須（default-off vs default-on を決定要に）、#4 書き込み mode 規約（3a lock・3d log.md pathspec 除外・3b 空 commit ガード）再利用＋別 cron entry の lock 競合を起動時刻 stagger で回避、#5 deferred baseline 提案の durable carrier 命名（`baseline_pending[]` 等）、#6 relevance 2 段＋承認キューの確定回答を 3g 要件スタブに配置（3f に残さない）、#7 3f は取得可否 gate を継承しない（feed/X 固有＝3g）。ロードマップ表（3f 単一URL絞り込み・3g 新設・4 行更新）・「Phase 3f を 3f/3g に分割した理由（2026-05-31）」節・ステータス行・受け入れ条件（3f 要件確定 8 項目＋3g スタブ 6 項目）・将来対応予定（3f/3g 2 エントリ）・リスク表（3g 改称 2 件＋3f 新規 2 件）を更新。**brainstorm 後に独立レビュアー 3 名で追加レビューを実施し一致指摘 4 件を idea.md に反映**: (#8 最優先) fetchability decay = watchlist URL の 404/失効/恒久リダイレクト時の `refresh-watchlist` 挙動が完全な見落とし（Tier B は消滅率が Tier A より桁違い＝daily refresh のドミナント運用障害）＝design 最優先論点＋リスク表（高）に追加、(#9) lint #14 相当（`refresh-watchlist` 停止監視）が #12/#13 同型で欠落＝受け入れ条件＋リスク表に追加、(#10) deferred baseline 提案の sync/async 取り違え（決定6＝同期・正しい先例は `migration_pending`）＝「cron 再コンパイル時点で vault が乖離を自己記述するか」の fork を先に潰す形に受け入れ条件を是正、(#11) 「足すだけ・新規書き込み経路ゼロ」は実装量の過少評価＝「mode F の書き込み機械を再利用するが mode `refresh-watchlist` 新設（条件分岐で混ぜると verified 3a/3d の Tier A baseline 振る舞いを汚染）」に表現是正。あわせて ingest 時 opt-in 登録 UI/フロー・更新判定（raw 取得日 > updated）継承・走査対象集合の列挙方法・`## 矛盾` 無人追記が上書き禁止に抵触しない論拠の一行注記、を design 論点に追加。次回作業は Phase 3f の `.steering/` design.md/requirements.md/tasklist.md 起こし（registry-vs-flag・opt-in 既定・fetchability decay・lint #14・baseline carrier sync/async fork の決着含む。3g は別 brainstorm/plan）。
- 2026-05-31: **Phase 3f 設計論点を決着**（同日 2 本目の brainstorm・先行「3f/3g 分割」の後続）。残っていた 5 つの design 論点を deep-dive 壁打ちで決定: **(1) registry-vs-flag → flag 採用**（source ページ frontmatter に opt-in `watch: true`・走査＝`Glob wiki/sources/*.md` を `tier:B`＋`watch:true` で絞り URL は mode F F-3 走査で raw から解決・別 registry 不採用。根拠: source_url は raw が正本〔schema §3・3c carve-out 確定〕＝別 registry は二重化し 3e で解消した dedup/migration を再導入）、**(2) opt-in 既定 → default-off**（flag の帰結＝既存ページに無い `watch` を default-on にできない・唯一整合）、**(3) fetchability decay → 受動的 lint surface**（cron 失敗時 1 回 skip・永続リトライ spam しない・自動上書きも自動 opt-out もしない。トレードオフ＝死んだ URL は手動 opt-out まで日次リトライ continues・self-heal しない。**マーカー機構は OPEN な plan 残点**＝既存 `stale:true` 再利用は「内容が古い」と「URL が死んでいる」を lint #4 上で混同する意味的 overload のため専用 `fetch_status`/fail-count と未決）、**(4) opt-in 動線 → `ingest --watch` 引数**（共通 surface 呼び出し側 G/H/F は渡さず default-off 維持で誤発火なし・retrofit は frontmatter 手動編集・別コマンド不要・post-ingest prompt 案は誤発火リスクで不採用）、**(5) baseline carrier → 不要・lint #3 再検出委譲**（`refresh-watchlist` は mode F 機械を再利用し再コンパイルで source ページ `claude_code_version` を進める＝乖離が vault に自己記述される → 既存 lint #3〔version 乖離・各ページ vs current-baseline を既に比較〕が次回対話で再検出 → 決定6「Tier B＝手動主体＋ lint 監査」モデルに合流。cron は提案を発火しない＝3 つ目の pending array `baseline_pending[]` 不採用）。**lint #14**（refresh-watchlist 停止監視）は #12/#13 同型で確定踏襲。**grounding 確認**: source ページに `source_url` 無し（raw のみ・F-3 走査で解決）＝flag を倒す決定打、lint #3（version 乖離）/#4（stale 監査）が既存の再検出スロットとして実在（lint-rules.md:15-16,48,58）。**advisor 反映 3 点**（決定は不変・記録の精緻化）: (a) チェックボックスは `[ ]` 維持〔`refresh-watchlist` 等が未実装で `[x]` は done 誤発信〕で決定の正本は本 changelog に置く、(b) fetchability の `stale` 再利用を確定にせず受動 lint surface までを決定としマーカー機構は OPEN・self-heal しないトレードオフ明記、(c) baseline carrier は「lint #3 が決定6 の手動主体＋lint 監査モデルに合流」（cron は自動提案を発火しない）と精密化。受け入れ条件 5 項目に決定マーカーを埋め込み・ステータス行・ロードマップ表 3f 行を更新。次回作業は Phase 3f の `.steering/` design.md/requirements.md/tasklist.md 起こし（`/plan-feature`・OPEN 残点＝fetchability マーカー機構を含む。3g は別 brainstorm/plan）。
- 2026-06-02: **Phase 3f 設計・実装**（単一 URL watchlist・mode W `refresh-watchlist`）。`.steering/20260531-llm-wiki-phase-3f/` の design.md（per-step マッピング表 §4・F-4f 省略・fetchability decay §3）/ requirements.md（A〜J 群）/ tasklist.md（T1〜T9）に基づき実装。**schema v1.6.0 → v1.7.0**（§2 共通フィールドに任意 `watch`〔bool・`tier:B` opt-in マーカー〕と `fetch_status`〔enum `failed`・mode W のみ更新〕、§2.1 に `last_refresh_watchlist_run`〔run heartbeat・**version baseline ではない**〕、編集境界表に mode W 列〔`last_refresh_watchlist_run` のみ更新可・version 系は 🚫 不可触＝W-4f 省略〕・additive minor）／ `.llm-wiki.json` 1.7.0。**SKILL.md**: mode B に `--watch` 引数（`tier:B` 専用・tier=A は警告して立てず・**`--watch` 非伝播**〔mode G G-6 / mode H H-5 / mode F migration は渡さない〕・retrofit は frontmatter 手動追記）／ **mode W 新設**（W-1〜W-7 ↔ F-1〜F-7 per-step マッピング表・W-3 走査を `tier:B`＋`watch:true` に改変・W-4a Tier B = WebFetch 既定＋取得失敗で `fetch_status:failed` を Edit+log+**commit**〔mode F 非 commit 失敗扱いから逸脱〕・W-4b 取得成功で受動回復・**W-4f 🚫 省略**〔current-baseline.md version 系を触らない・lint #3 が次回対話で再検出＝carrier 不要の成立条件〕・W-5 heartbeat・`--dry-run`・エラー表）／ ステップ0/0.6 分岐・lock mode 値に `refresh-watchlist`／ mode L を 13 → **15 検査**（#14/#15 追加・`--check` キー・log.md サマリ文字列・書き込み境界表）／ グローバルエラーディスパッチ表に mode W 行。**lint-rules.md**: #14 `last-refresh-watchlist-run`（既定 7 日・#12 同型・追加 Read 0 回）／ #15 `watch-fetch-failed`（`fetch_status:failed` 列挙・#4 stale 非相乗り理由）／ 検査表 15 化・しきい値表・走査戦略 Phase 3f 追加 0 回・fixture カタログ #14/#15・「37 ケース」。**plist**: `references/refresh-watchlist-launchd.plist.example`（refresh-tier-a 同型・**起動 03:30 で stagger**〔同一 `.llm-wiki.lock` 競合回避〕・5 環境変数・`--allowedTools=` 形式・`launchctl load` 手動）。**設計の肝**: mode F の per-source 機械を再利用しつつ **F-4f だけ省略**（W-4e は source ページの `claude_code_version` を更新〔継承〕／W-4f は current-baseline.md の version を触らない〔省略〕＝同じフィールド名・別ファイルで決定6 を成立）。idea.md 受け入れ条件「Phase 3f」13 項目を [x] 化・ステータス行・CLAUDE.md ステータス/主役機能表/ロードマップ・README 含まれるもの表/推奨ワークフローを更新。動作確認は方針 (B) スペック検証（requirements A〜J 群 grep walk）。実機 deferred 6 項目（`ingest --watch` 登録通し・mode W force-run 通し〔version 系不変の実機確認〕・fetchability decay 再現〔404 → fetch_status:failed → lint #15 → 受動回復〕・lint #14 停止監視・cron stagger・`--watch` 非伝播）は requirements §carve-out として Phase 3a/3c/3e と同じく受け入れテスト時の利用者裁量。vault co-evolution（current-baseline.md ポインタ v1.7.0 + log.md 改訂行）は実装 tail で実施。主要 commit: roadmap sync `574a1ef` / Phase 3f 本体 `9d7e299`（PR #21 → main `db39199`）。受け入れテスト PASS（2026-06-05・55 件全 PASS・carve-out 6 項目は利用者裁量）。
- 2026-06-05: **Phase 3g 設計・実装**（定点フィード型 Tier B・mode I `discover-watchlist`）。`.steering/20260605-llm-wiki-phase-3g/` の design.md（14 章・mode I step I-1〜I-8・spike GATE §2・queue cap §4.2・stage-2 統合 §4.4）/ requirements.md（A〜K 群）/ tasklist.md（T0〜T9）に基づき実装。**取得可否 spike GATE PASS（2026-06-05）**: simonwillison.net / oneusefulthing.org / huyenchip.com 3 サイトで curl RSS/Atom 取得 + entry URL 抽出 + stage-1 keyword フィルタを実証。**schema v1.7.0 → v1.8.0**（§2 共通フィールドに任意 `feed_url`〔url 文字列・`--feed` mode B が立てる・mode I 走査対象マーカー〕、§2.1 に `last_discover_watchlist_run`〔run heartbeat・version baseline ではない〕と `pending_feed_discoveries[]`〔mode I 専用 Tier B フィード発見 URL 保留配列・`declined_reason` 3 値含む〕、編集境界表に mode I 列・additive minor）／ `.llm-wiki.json` 1.8.0。**SKILL.md**: mode B に `--feed=<rss_url>` 引数（source ページに `feed_url` を立てる・`--watch` と併用可・**`--feed` 非伝播**〔mode G/H/I/F migration は渡さない〕・retrofit は frontmatter 手動追記）／ **mode I 新設**（I-1 lock 〜 I-8 サマリ+解放・I-3 フィード巡回〔curl 逐語 fetch・WebFetch 不使用・RSS/Atom 両形式 bash 抽出〕・I-4 突合+stage-1 keyword フィルタ〔hardcoded keyword セット・LLM コスト 0〕・I-5 `pending_feed_discoveries` append+cap/eviction〔per-feed N=50・全体 M=200〕・I-6 capped バッチ opt-out+stage-2 LLM 統合〔WebFetch JSON relevance 判定・confidence<0.7 → auto-decline〕・I-7 heartbeat・`--no-prompt`〔stage-1+append のみ・stage-2 不実行〕・`--dry-run`・エラー表）／ ステップ0/0.6 分岐・lock mode 値に `discover-watchlist`／ mode L を 15 → **16 検査**（#16 追加・`--check` キー・log.md サマリ文字列・書き込み境界表）／ グローバルエラーディスパッチ表に mode I 行。**lint-rules.md**: #16 `last-discover-watchlist-run`（既定 14 日・#13 同型・追加 Read 0 回）／ 検査表 16 化・しきい値表・走査戦略 Phase 3g 追加 0 回・fixture カタログ #16・「40 ケース」。**plist**: `references/discover-watchlist-launchd.plist.example`（refresh-watchlist 同型・**起動 04:00 で 3 系統 stagger**〔03:00/03:30/04:00〕・`--no-prompt` 起動・5 環境変数）。`feed_url` / `pending_feed_discoveries[]` / `declined_reason` discriminator は schema.md §2/§2.1 が単一正本（SKILL.md で再定義せず）。idea.md Phase 3g 受け入れ条件を [x] 化・ステータス行・CLAUDE.md ステータス/主役機能表/ロードマップ・README 含まれるもの表/推奨ワークフローを更新。動作確認は方針 (B) スペック検証。実機 deferred 8 項目（`ingest --feed` 登録通し・mode I `--no-prompt` cron 通し・stage-2 LLM 判定通し・declined キャッシュ動作・lint #16 停止監視・cron 3 系統 stagger 実機・`--feed` 非伝播・queue cap eviction 実機）は requirements §carve-out として受け入れテスト時の利用者裁量。vault co-evolution（current-baseline.md ポインタ v1.8.0 + log.md 改訂行）は実装 tail で実施。
