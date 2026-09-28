#!/usr/bin/env bash
# Dispatch the Reviewer (Codex CLI in sandbox team-reviewer) for one PR review round.
# Called by the Coordinator (Hermes) in the background; returns when the agent run ends.
#
# usage: dispatch-reviewer.sh <task-id> <pr-number> <slack-channel-id> <slack-thread-ts> <round>
set -euo pipefail

TASK_ID="${1:?task id}"; PR="${2:?pr number}"; CHANNEL="${3:?channel id}"; THREAD="${4:?thread ts}"; ROUND="${5:?round}"
SANDBOX=team-reviewer
LOG_DIR="${HOME}/.agentic-team/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/reviewer-${TASK_ID}-pr${PR}-r${ROUND}-$(date +%Y%m%d-%H%M%S).log"
MODEL_FLAG=(); [ -n "${REVIEWER_MODEL:-}" ] && MODEL_FLAG=(-m "$REVIEWER_MODEL")

PROMPT="You are the Reviewer. Follow the 'reviewer' skill in .agents/skills exactly and the Code Review Rules in AGENTS.md.
TASK_ID=${TASK_ID} PR_NUMBER=${PR} ROUND=${ROUND}
Slack: SLACK_CHANNEL_ID=${CHANNEL} SLACK_THREAD_TS=${THREAD} (reply in this thread only, via the slack MCP tools).
Do not modify any file. Run ./mvnw -B verify yourself. Post the GitHub review with gh pr review, then the STATUS: REVIEW_DONE line ending in @Coordinator."

echo "[dispatch-reviewer] task=$TASK_ID pr=$PR round=$ROUND log=$LOG"
sbx exec \
  -e TASK_ID="$TASK_ID" -e ROUND="$ROUND" -e PR_NUMBER="$PR" \
  -e SLACK_CHANNEL_ID="$CHANNEL" -e SLACK_THREAD_TS="$THREAD" \
  "$SANDBOX" bash -lc '
    set -e
    cd "$(git rev-parse --show-toplevel)"
    git fetch origin --prune
    git checkout -q main && git reset -q --hard origin/main
    gh pr checkout "$1"
    shift
    codex exec --dangerously-bypass-approvals-and-sandbox "$@"
  ' _ "$PR" ${MODEL_FLAG[@]+"${MODEL_FLAG[@]}"} "$PROMPT" >"$LOG" 2>&1 || {
    rc=$?
    echo "[dispatch-reviewer] exited rc=$rc; see $LOG"
    exit $rc
  }
echo "[dispatch-reviewer] finished; see $LOG"
