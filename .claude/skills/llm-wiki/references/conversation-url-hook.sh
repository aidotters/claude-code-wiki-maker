#!/bin/sh
# llm-wiki 会話 URL 検出 hook（UserPromptSubmit・Phase 3e）
#
# 会話プロンプト中の URL を vault 外 inbox（リポジトリルート直下 .llm-wiki-inbox.jsonl）に
# append する。検出のみ（スキル起動・vault 書き込み・lock 取得は伴わない）。
# 貯めた URL は後で `/llm-wiki review`（モード H）で triage して承認制 ingest する。
#
# 利用: project local .claude/settings.json の UserPromptSubmit hook から起動する
# （references/conversation-url-hook.example.json を hooks キーのみ手動マージ）。
# 安全側に倒し、何が起きても無音で exit 0（ユーザーのプロンプトを決して壊さない）。

# --- project guard: CWD=リポジトリルート前提・vault リンク不在なら無音終了 ---
# （settings が万一グローバルに漏れても無関係プロジェクトで append しないため）
[ -L ./wiki-vault ] || exit 0

# --- 依存ガード: jq 不在ならスキップ（プロンプトを壊さない） ---
command -v jq >/dev/null 2>&1 || exit 0

INBOX="./.llm-wiki-inbox.jsonl"
TODAY=$(date +%Y-%m-%d)

# stdin の UserPromptSubmit JSON から prompt 本文を取り出す
# （gate 確定 2026-05-30: プロンプト本文を運ぶフィールドは .prompt・生文字列。出典 code.claude.com/docs/en/hooks）
prompt=$(jq -r '.prompt // empty' 2>/dev/null)
[ -n "$prompt" ] || exit 0

# URL 抽出 → localhost 等を除外 → 重複畳み込み → inbox 既存と突合して新規のみ append
# 正規化はここでは行わない（authoritative な正規化 + 取り込み済み突合は mode H review 側）
printf '%s' "$prompt" \
  | grep -oE 'https?://[^[:space:]<>")]+' \
  | grep -vE '^https?://(localhost|127\.0\.0\.1|0\.0\.0\.0)([:/]|$)' \
  | sort -u \
  | while IFS= read -r url; do
      # within-file dedup: 既に inbox にある URL は append しない
      if [ -f "$INBOX" ] && grep -qF "\"url\":\"$url\"" "$INBOX"; then
        continue
      fi
      # %s 引数経由のため url 中の % やシェル特殊文字は解釈されない
      printf '{"url":"%s","detected_on":"%s"}\n' "$url" "$TODAY" >> "$INBOX"
    done

exit 0
