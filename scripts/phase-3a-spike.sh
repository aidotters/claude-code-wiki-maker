#!/usr/bin/env bash
# Phase 3a 前提検証スパイク
# 詳細は .steering/20260523-llm-wiki-phase-3a-spike/spike-plan.md
#
# Usage:
#   scripts/phase-3a-spike.sh
#   env -i HOME=$HOME PATH=/usr/bin:/bin:/Users/tak/.local/bin scripts/phase-3a-spike.sh
#   (launchd からも同コマンドで呼ぶ)

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VAULT="${REPO_ROOT}/wiki-vault"
REPORT="${REPO_ROOT}/.steering/20260523-llm-wiki-phase-3a-spike/spike-report.json"
LOG="${REPO_ROOT}/.steering/20260523-llm-wiki-phase-3a-spike/spike-run.log"
CLAUDE="${CLAUDE_BIN:-/Users/tak/.local/bin/claude}"

mkdir -p "$(dirname "$REPORT")"
: > "$LOG"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '[%s] %s\n' "$(ts)" "$*" | tee -a "$LOG" >&2; }

gate_i_ok=0; gate_i_detail=""
gate_ii_ok=0; gate_ii_detail=""
gate_iii_ok=0; gate_iii_detail=""

# Gate (i): claude --print が応答するか
log "Gate (i): claude --print echo"
if [ ! -x "$CLAUDE" ]; then
  gate_i_detail="claude binary not found at $CLAUDE"
  log "  FAIL: $gate_i_detail"
else
  set +e
  out_i="$("$CLAUDE" --print --permission-mode=bypassPermissions "Reply with exactly the single word: SPIKE_OK" 2>&1)"
  rc_i=$?
  set -e
  log "  rc=$rc_i output_head=$(printf '%s' "$out_i" | head -c 200)"
  if [ $rc_i -eq 0 ] && printf '%s' "$out_i" | grep -q "SPIKE_OK"; then
    gate_i_ok=1
    gate_i_detail="ok (rc=0, SPIKE_OK in output)"
  else
    gate_i_detail="rc=$rc_i out=$(printf '%s' "$out_i" | head -c 400)"
  fi
fi

# Gate (ii): WebFetch が cron-like env で動くか
# example.com は安定して取得可能・ページに 'Example Domain' 文字列を含む
log "Gate (ii): claude --print + WebFetch"
if [ "$gate_i_ok" -ne 1 ]; then
  gate_ii_detail="skipped (gate i failed)"
  log "  SKIP: $gate_ii_detail"
else
  set +e
  # 注: --allowedTools は <tools...> variadic なので "=" 形式で単一値に固定し、
  # prompt 位置引数を食わないようにする
  out_ii="$("$CLAUDE" --print --permission-mode=bypassPermissions --allowedTools=WebFetch \
    "Use WebFetch to retrieve https://example.com/ and reply with exactly: WEBFETCH_<status> where <status> is OK if you see the phrase 'Example Domain' in the page and FAIL otherwise. Reply with only that single token." 2>&1)"
  rc_ii=$?
  set -e
  log "  rc=$rc_ii output_head=$(printf '%s' "$out_ii" | head -c 400)"
  if [ $rc_ii -eq 0 ] && printf '%s' "$out_ii" | grep -q "WEBFETCH_OK"; then
    gate_ii_ok=1
    gate_ii_detail="ok (rc=0, WEBFETCH_OK)"
  else
    gate_ii_detail="rc=$rc_ii out=$(printf '%s' "$out_ii" | head -c 600)"
  fi
fi

# Gate (iii): ボールト書き込み + git commit
# symlink 経由・shell で完結（claude を経由しない＝書き込み権限と git の素の動作を確認）
log "Gate (iii): vault write + git commit"
if [ "${SPIKE_SKIP_GATE_III:-0}" = "1" ]; then
  # 既に通過済みで再実行で commit を増やしたくない場合用。all_pass 計算では ok 扱い。
  gate_iii_ok=1
  gate_iii_detail="skipped via SPIKE_SKIP_GATE_III=1 (treated as pass for re-run; original verification stands)"
  log "  SKIP: $gate_iii_detail"
elif [ ! -L "$REPO_ROOT/wiki-vault" ] || [ ! -d "$VAULT" ]; then
  gate_iii_detail="vault symlink missing or target not a directory"
  log "  FAIL: $gate_iii_detail"
else
  MARKER="$VAULT/.spike-marker-$(date -u +%Y%m%d-%H%M%S).tmp"
  set +e
  printf 'phase-3a-spike at %s\n' "$(ts)" > "$MARKER"
  write_rc=$?
  if [ $write_rc -ne 0 ]; then
    gate_iii_detail="write failed rc=$write_rc"
    log "  FAIL: $gate_iii_detail"
  else
    # ボールト側 git で add/commit を試行。失敗ケースを潰しやすいよう -L で symlink を解決して -C する
    VAULT_REAL="$(cd "$VAULT" && pwd -P)"
    git -C "$VAULT_REAL" add "$(basename "$MARKER")" 2>>"$LOG"
    git -C "$VAULT_REAL" -c user.email=spike@local -c user.name=spike commit -m "spike: phase-3a marker $(ts)" 2>>"$LOG"
    commit_rc=$?
    if [ $commit_rc -eq 0 ]; then
      head_sha="$(git -C "$VAULT_REAL" rev-parse --short HEAD)"
      gate_iii_ok=1
      gate_iii_detail="ok (commit=$head_sha file=$(basename "$MARKER"))"
      log "  PASS: $gate_iii_detail"
    else
      gate_iii_detail="git commit failed rc=$commit_rc"
      log "  FAIL: $gate_iii_detail"
    fi
  fi
  set -e
fi

# JSON レポート出力
cat > "$REPORT" <<JSON
{
  "spike": "phase-3a-tier-a-refresh",
  "run_at": "$(ts)",
  "host": "$(hostname)",
  "env_minimal": ${SPIKE_ENV_MINIMAL:-false},
  "claude_path": "$CLAUDE",
  "vault_real": "$(readlink "$REPO_ROOT/wiki-vault" 2>/dev/null || echo unknown)",
  "gates": {
    "i_claude_print": { "pass": $([ $gate_i_ok -eq 1 ] && echo true || echo false), "detail": $(printf '%s' "$gate_i_detail" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))') },
    "ii_webfetch":    { "pass": $([ $gate_ii_ok -eq 1 ] && echo true || echo false), "detail": $(printf '%s' "$gate_ii_detail" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))') },
    "iii_vault_git":  { "pass": $([ $gate_iii_ok -eq 1 ] && echo true || echo false), "detail": $(printf '%s' "$gate_iii_detail" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))') }
  },
  "all_pass": $([ $gate_i_ok -eq 1 ] && [ $gate_ii_ok -eq 1 ] && [ $gate_iii_ok -eq 1 ] && echo true || echo false)
}
JSON

log "Report written: $REPORT"
[ $gate_i_ok -eq 1 ] && [ $gate_ii_ok -eq 1 ] && [ $gate_iii_ok -eq 1 ]
