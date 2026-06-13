# llm-wiki cron 運用ランブック（このマシンの実構成・残作業）

> 2026-06-13 セットアップ。tak の Mac（夜間**スリープ**・`pmset sleep`=1分）向けの実構成と残作業。
> 背景と切り分けの詳細は本ファイル末尾「設計判断」と auto-memory（`claude-code-launchd-*`）参照。

## 実構成（稼働中）

- **vault 実体**: `~/claude-code-wiki`（旧 `~/Documents/claude-code-wiki` から移動。Documents は TCC で launchd から読み書き不可）。
  - `.llm-wiki.json` の `vault_absolute` と `./wiki-vault` symlink は更新済み。
- **launchd ジョブ**: `~/Library/LaunchAgents/local.llm-wiki-cron.plist`（**統合1ジョブ**）。
  - 毎朝 **06:00** に `caffeinate -i` で全モードを**連続実行**（すき間ゼロ）:
    `refresh-tier-a → refresh-watchlist → discover-watchlist --no-prompt`、**日曜のみ** `discover-tier-a --no-prompt` を追加。
  - 個別 4 plist（refresh-tier-a 等）は**撤去済み**（スリープ機では stagger が機能しないため統合した。テンプレは `references/` に残存）。
  - ログ: vault 直下 `.cron-out.log` / `.cron-err.log`（vault .gitignore 済み）。

## 残作業チェックリスト

- [x] **(必須) スリープ自動復帰を設定**（sudo 必要・未設定だと 06:00 に起きず実行されない）:
      ```
      sudo pmset repeat wake MTWRFSU 06:00:00
      ```
      確認 `pmset -g sched` / 解除 `sudo pmset repeat cancel`。**電源オフ運用では自動実行不可**（スリープ専用）。
- [ ] **Obsidian で `~/claude-code-wiki` を開き直す**（旧パスのまま開いていると見えない。ノート・設定は保持）。
- [ ] **(任意) Notion Medium DB 巡回を使うなら**: `~/Library/LaunchAgents/local.llm-wiki-cron.plist` の
      `REPLACE_WITH_NOTION_API_KEY` を実キーに差し替え → `launchctl unload && launchctl load`。
      未設定なら discover-watchlist の Notion ソースのみ clean-skip（他は正常）。
- [ ] **(任意) リポジトリ変更をコミット**: 4 plist 例・統合例テンプレ新規・`.llm-wiki.json`・README・本ファイル。
- [ ] **発見候補の取り込み（定期・対話）**: cron の discover 系は候補を貯めるだけ。対話で
      `/llm-wiki discover-tier-a` / `/llm-wiki discover-watchlist`（引数なし）を実行し承認制 ingest。

## 動作確認・運用

- **手動実行**（待たずに今すぐ走らせる）: `launchctl start local.llm-wiki-cron`
- **結果確認**: `git -C ~/claude-code-wiki log --oneline` ／ `tail ~/claude-code-wiki/.cron-out.log`
- **稼働監視**: 対話で `/llm-wiki lint` → heartbeat 検査 #12（tier-a refresh）/#14（watchlist）/#16（discover-watchlist）/#13（discover-tier-a）が当日付か確認。
- **正常な exit**: 平日は最後の Sunday gate が `if/fi` でスキップされ **exit 0**。日曜は discover-tier-a の exit を反映。

## 設計判断（なぜこの構成か・launchd 固有の4ブロッカー）

すべて実機で切り分け・検証済み（2026-06-13）。当初の同梱 plist（claude 直接起動・vault は ~/Documents・stagger 4本）は launchd 下で動かなかった。

1. **claude 直接 exec → exit 78 で即死** → `/bin/zsh -lc 'exec claude …'`（または caffeinate→zsh）でラップ。
2. **`--allowedTools=Bash` は分類器に通され遅い／拒否で停止** → `--permission-mode bypassPermissions`（信頼済みローカル前提・要ユーザー認可）＋ `--strict-mcp-config`（MCP 不使用）。
3. **`~/Documents` の TCC で vault アクセス不可** → vault を `~/claude-code-wiki` へ移動。
4. **`sleep`=1分のスリープ機で stagger 4本が後続不発** → **統合1ジョブ＋`caffeinate -i`＋`pmset repeat wake`（ジョブと同時刻）**。

実装上の注意: zsh は未クォート `$A` を単語分割しない（フラグは配列 `A=(...)`）。Sunday gate は `&&` だと非日曜にジョブ exit 1 になるため `if/fi`。

参考: 統合 plist テンプレ `.claude/skills/llm-wiki/references/llm-wiki-cron-combined.plist.example`、常時起動デスクトップ向けの個別 4 plist テンプレ（stagger）も同 `references/` に残存。
