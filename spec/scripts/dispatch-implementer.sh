#!/usr/bin/env bash
# Dispatch the Implementer (Claude Code in sandbox team-implementer) for one task round.
# Called by the Coordinator (Hermes) in the background; returns when the agent run ends.
#
# usage: dispatch-implementer.sh <task-id> <slack-channel-id> <slack-thread-ts> <round> [pr-number]
set -euo pipefail

TASK_ID="${1:?task id}"; CHANNEL="${2:?channel id}"; THREAD="${3:?thread ts}"; ROUND="${4:?round}"; PR="${5:-}"
SANDBOX=team-implementer
LOG_DIR="${HOME}/.agentic-team/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/implementer-${TASK_ID}-r${ROUND}-$(date +%Y%m%d-%H%M%S).log"
MODEL="${IMPLEMENTER_MODEL:-claude-opus-5-5}"

PROMPT="You are the Implementer. Follow the 'implementer' skill in .claude/skills exactly.
TASK_ID=${TASK_ID} ROUND=${ROUND} PR_NUMBER=${PR:-none}
Slack: SLACK_CHANNEL_ID=${CHANNEL} SLACK_THREAD_TS=${THREAD} (reply in this thread only, via the slack MCP tools).
Start by posting your STATUS: STARTED line. Finish with a STATUS: PR_OPENED, PR_UPDATED or BLOCKED line ending in @Coordinator."

echo "[dispatch-implementer] task=$TASK_ID round=$ROUND pr=${PR:-none} log=$LOG"
sbx exec \
  -e TASK_ID="$TASK_ID" -e ROUND="$ROUND" -e PR_NUMBER="$PR" \
  -e SLACK_CHANNEL_ID="$CHANNEL" -e SLACK_THREAD_TS="$THREAD" \
  "$SANDBOX" bash -lc '
    set -e
    cd "$(git rev-parse --show-toplevel)"
    git fetch origin --prune
    claude -p "$1" --model "$2" --output-format json --max-turns 200 --dangerously-skip-permissions
  ' _ "$PROMPT" "$MODEL" >"$LOG" 2>&1 || {
    rc=$?
    echo "[dispatch-implementer] exited rc=$rc; see $LOG"
    exit $rc
  }
echo "[dispatch-implementer] finished; see $LOG"
