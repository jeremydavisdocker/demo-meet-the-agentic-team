#!/usr/bin/env bash
# Reset between rehearsals: close task PRs, delete task branches, and re-sync both sandboxes to
# origin/main. Keeps the sandboxes (and their warmed Maven cache) unless --recreate is given.
#
# usage: reset-demo.sh [--recreate]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/team.env" ] && set -a && . "$HERE/team.env" && set +a
: "${TEAM_REPO:?}"

echo "== Closing open task PRs and deleting task/* branches on $TEAM_REPO"
for pr in $(gh pr list --repo "$TEAM_REPO" --state open --json number,headRefName --jq '.[] | select(.headRefName|startswith("task/")) | .number'); do
  gh pr close "$pr" --repo "$TEAM_REPO" --delete-branch --comment "Demo reset."
done
for b in $(gh api "repos/$TEAM_REPO/branches" --jq '.[].name' | grep '^task/' || true); do
  gh api -X DELETE "repos/$TEAM_REPO/git/refs/heads/$b" >/dev/null && echo "   deleted $b"
done

if [ "${1:-}" = "--recreate" ]; then
  echo "== Recreating sandboxes"
  sbx rm --force team-implementer || true
  sbx rm --force team-reviewer    || true
  exec "$HERE/bootstrap.sh"
fi

echo "== Re-syncing sandbox clones to origin/main"
for n in team-implementer team-reviewer; do
  sbx exec "$n" bash -lc 'cd "$(git rev-parse --show-toplevel)" && git fetch origin --prune && git checkout -q main && git reset -q --hard origin/main && git branch | grep "task/" | xargs -r git branch -D'
done
echo "Done. Start a fresh Slack thread for the next run."
