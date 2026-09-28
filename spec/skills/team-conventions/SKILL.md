---
name: team-conventions
description: Shared conventions for the agentic development team — naming, branches, PRs, Slack thread etiquette, and the STATUS handoff line every agent must emit. Load before any task on the Quarkus demo repo.
version: 1.0.0
metadata:
  hermes:
    tags: [team, conventions, slack, git]
    category: agentic-team
---

# Team conventions

Three agents share one repo and one Slack channel. These rules are what let a fresh agent with no
memory pick up exactly where another left off.

## Identities

| Role        | Runtime                     | Slack handle   | Sandbox name       |
|-------------|-----------------------------|----------------|--------------------|
| Coordinator | Hermes Agent (host laptop)  | `@Coordinator` | none (host)        |
| Implementer | Claude Code                 | `@Implementer` | `team-implementer` |
| Reviewer    | OpenAI Codex CLI            | `@Reviewer`    | `team-reviewer`    |

Humans are "the product owner". Only the product owner merges, unless they say `auto-merge` in the
task thread.

## Tasks and specs

- A task is a file `specs/NNN-slug.md` on `main` (three-digit `NNN`). Its first heading is the task
  title. It always contains an `## Acceptance criteria` checklist.
- The task id `NNN` appears in the branch, the PR title, every commit, and every STATUS line.

## Git

- Branch: `task/NNN-slug` (slug copied from the spec filename). Never commit to `main`.
- Commits: `feat(NNN): ...`, `test(NNN): ...`, `fix(NNN): ...`, `chore(NNN): ...`.
- PR title: `[NNN] <spec title>`. PR body: link to the spec, the acceptance-criteria checklist with
  boxes ticked, and the last 20 lines of `./mvnw -B verify` output.
- One PR per task. Review rounds push new commits to the same branch; never force-push.
- `./mvnw -B verify` must be green locally before a PR is opened or updated. Green means: compile,
  unit tests, `*IT` integration tests, ArchUnit tests, and (once task 002 lands) the PIT mutation
  threshold.

## Slack

- Channel: `#agentic-team`. Every task lives in exactly one thread, rooted at the product owner's
  request message. Never post task traffic at channel top level.
- Agents post to the thread identified by `SLACK_CHANNEL_ID` + `SLACK_THREAD_TS` in their
  environment. If those are missing, stop and report `STATUS: BLOCKED reason=no-thread`.
- Keep messages short: what happened, where to look (PR link, file path), what is needed next.
- Address the next actor with an @mention as the **last line**. `@Coordinator` is woken only by
  mentions, so a handoff message without it is a dropped handoff.

## STATUS line (machine-readable handoff)

The **first line** of every handoff message is a single STATUS line:

```
STATUS: <EVENT> key=value key=value ...
```

| EVENT             | Emitted by  | Required keys                                   |
|-------------------|-------------|-------------------------------------------------|
| `DISPATCHED`      | Coordinator | `task=NNN role=implementer|reviewer round=N`    |
| `STARTED`         | worker      | `task=NNN role=... round=N`                     |
| `PR_OPENED`       | Implementer | `task=NNN pr=#N round=N`                        |
| `PR_UPDATED`      | Implementer | `task=NNN pr=#N round=N`                        |
| `REVIEW_DONE`     | Reviewer    | `task=NNN pr=#N round=N verdict=APPROVE|REQUEST_CHANGES` |
| `BLOCKED`         | any         | `task=NNN role=... reason=<kebab-case>`         |
| `ESCALATED`       | Coordinator | `task=NNN reason=<kebab-case>`                  |
| `DONE`            | Coordinator | `task=NNN pr=#N`                                |

Example:

```
STATUS: PR_OPENED task=003 pr=#12 round=1
Opened https://github.com/<org>/<repo>/pull/12 — 4/4 acceptance criteria, verify green (PIT 84%).
@Coordinator
```

## Rounds and limits

- `round` starts at 1 and increments each time the Implementer is re-dispatched after
  `REQUEST_CHANGES`.
- Maximum 3 rounds per task. After round 3 the Coordinator emits `ESCALATED` and stops.
- A worker that has produced no Slack message for 20 minutes is considered stalled; the Coordinator
  checks the sandbox and reports.

## What lives where

| Knowledge                         | Location                                             | Read by            |
|-----------------------------------|------------------------------------------------------|--------------------|
| Task specs / acceptance criteria  | `specs/NNN-slug.md` in the repo                      | all                |
| Build, layering, test conventions | `CLAUDE.md`, `AGENTS.md` in the repo                 | Implementer, Reviewer |
| Role procedures                   | `.claude/skills/*`, `.agents/skills/*`, `~/.hermes/skills/agentic-team/*` | per role |
| Review rules for Codex            | `AGENTS.md` → `## Code Review Rules`                 | Reviewer           |
| Conversation state                | the Slack thread                                     | all                |
| Code state                        | the PR branch and its CI status                      | all                |
