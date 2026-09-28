#!/usr/bin/env bash
# One-shot host setup for the agentic development team demo.
# Idempotent: safe to re-run. Requires: sbx, gh (logged in), hermes, docker.
#
# Expects these variables in the environment or in ./team.env (see SPEC.md §9):
#   TEAM_REPO            e.g. jeremydavis/agentic-quarkus-demo
#   TEAM_REPO_DIR        host path of the local clone
#   SLACK_TEAM_ID        T0...
#   SLACK_CHANNEL_ID     C0...  (#agentic-team)
#   SLACK_IMPLEMENTER_BOT_TOKEN   xoxb-... (Implementer Slack app)
#   SLACK_REVIEWER_BOT_TOKEN      xoxb-... (Reviewer Slack app)
#   ANTHROPIC_API_KEY, OPENAI_API_KEY    (or use the OAuth variants noted below)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC_DIR="$(cd "$HERE/.." && pwd)"
[ -f "$HERE/team.env" ] && set -a && . "$HERE/team.env" && set +a

: "${TEAM_REPO:?}" "${TEAM_REPO_DIR:?}" "${SLACK_TEAM_ID:?}" "${SLACK_CHANNEL_ID:?}"
: "${SLACK_IMPLEMENTER_BOT_TOKEN:?}" "${SLACK_REVIEWER_BOT_TOKEN:?}"

MCP_ARGS=(docker run -i --rm -e SLACK_BOT_TOKEN -e SLACK_TEAM_ID -e SLACK_CHANNEL_IDS mcp/slack)

echo "== 1. Host credentials (proxy-injected, never visible inside sandboxes)"
sbx secret set github --command 'gh auth token'
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then printf '%s' "$ANTHROPIC_API_KEY" | sbx secret set anthropic; else echo "   (skip anthropic key; use 'sbx secret set anthropic' or /login in the sandbox)"; fi
if [ -n "${OPENAI_API_KEY:-}" ];    then printf '%s' "$OPENAI_API_KEY"    | sbx secret set openai;    else echo "   (skip openai key; use 'sbx secret set openai --oauth')"; fi

echo "== 2. Seed the repo with team files"
for f in CLAUDE.md AGENTS.md .mcp.json .codex/config.toml .github/workflows/ci.yml; do
  mkdir -p "$TEAM_REPO_DIR/$(dirname "$f")"
  cp "$SPEC_DIR/repo-files/$f" "$TEAM_REPO_DIR/$f"
done
mkdir -p "$TEAM_REPO_DIR/specs" "$TEAM_REPO_DIR/.claude/skills" "$TEAM_REPO_DIR/.agents/skills"
for s in team-conventions quarkus-architecture implementer; do rm -rf "$TEAM_REPO_DIR/.claude/skills/$s"; cp -R "$SPEC_DIR/skills/$s" "$TEAM_REPO_DIR/.claude/skills/$s"; done
for s in team-conventions quarkus-architecture reviewer;    do rm -rf "$TEAM_REPO_DIR/.agents/skills/$s"; cp -R "$SPEC_DIR/skills/$s" "$TEAM_REPO_DIR/.agents/skills/$s"; done
cp "$SPEC_DIR/feature-spec-template.md" "$TEAM_REPO_DIR/specs/000-template.md"
cp "$SPEC_DIR"/tasks/*.md "$TEAM_REPO_DIR/specs/"
echo "   Commit and push these to main before creating sandboxes (clone mode snapshots the repo)."

echo "== 3. Hermes coordinator skills"
mkdir -p "$HOME/.hermes/skills/agentic-team"
for s in team-conventions coordinator quarkus-architecture; do rm -rf "$HOME/.hermes/skills/agentic-team/$s"; cp -R "$SPEC_DIR/skills/$s" "$HOME/.hermes/skills/agentic-team/$s"; done
echo "   Ensure ~/.hermes/config.yaml has platforms.slack.extra.allow_bots: mentions (SPEC.md §9)."

echo "== 4. Worker sandboxes (clone mode, one per role)"
create_sandbox() { # name agent token
  local name="$1" agent="$2" token="$3"
  if sbx ls 2>/dev/null | grep -q "^$name\b\|[[:space:]]$name[[:space:]]"; then echo "   $name exists"; return; fi
  sbx create --clone --name "$name" \
    -e SLACK_BOT_TOKEN="$token" -e SLACK_TEAM_ID="$SLACK_TEAM_ID" -e SLACK_CHANNEL_IDS="$SLACK_CHANNEL_ID" \
    -e TEAM_REPO="$TEAM_REPO" \
    "$agent" "$TEAM_REPO_DIR"
}
create_sandbox team-implementer claude "$SLACK_IMPLEMENTER_BOT_TOKEN"
create_sandbox team-reviewer    codex  "$SLACK_REVIEWER_BOT_TOKEN"

echo "== 5. Register the Slack MCP server inside each sandbox (user scope, no trust prompt)"
sbx exec team-implementer claude mcp add --scope user slack -- "${MCP_ARGS[@]}" || true
sbx exec team-reviewer    codex  mcp add slack -- "${MCP_ARGS[@]}" || true

echo "== 6. Pre-warm: pull the MCP image and Maven dependencies so the first task is fast on stage"
for n in team-implementer team-reviewer; do
  sbx exec "$n" docker pull mcp/slack
  sbx exec "$n" bash -lc 'cd "$(git rev-parse --show-toplevel)" && ./mvnw -B -q dependency:go-offline && ./mvnw -B -q verify -DskipTests || true'
done

echo "== 7. Smoke test each hop"
sbx exec team-implementer bash -lc 'gh auth status && claude --version'
sbx exec team-reviewer    bash -lc 'gh auth status && codex --version'
echo "Done. Post in #agentic-team: '@Coordinator status?' to confirm Hermes is listening."
