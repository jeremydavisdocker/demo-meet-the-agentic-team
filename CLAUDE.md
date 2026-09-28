# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this directory is

Planning material for Jeremy Davis's conference talk *Meet the Agentic Development Team*
(`Meet_the_Agentic_Team.pdf` is the abstract). It contains no application code. The deliverable is
`SPEC.md`: a buildable spec for the demo's **team infrastructure** — a Hermes Agent coordinator in
Slack dispatching a Claude Code implementer and a Codex reviewer, each in its own Docker Sandbox,
working on a separate Quarkus repo.

## Layout

- `SPEC.md` — the spec; start here. §11 lists assumptions to verify before building.
- `spec/skills/*/SKILL.md` — agentskills.io skills, the single source of truth copied to Hermes
  (`~/.hermes/skills/`), Claude Code (`.claude/skills/`) and Codex (`.agents/skills/`).
- `spec/repo-files/` — files to drop into the Quarkus repo (`CLAUDE.md`, `AGENTS.md`, MCP configs, CI).
- `spec/scripts/` — host-side `bootstrap.sh`, `dispatch-*.sh`, `reset-demo.sh`. They target the
  demo host, not this sandbox; do not run them here.
- `spec/feature-spec-template.md` — shape of a task spec (`specs/NNN-slug.md` in the app repo).
- `spec/tasks/001–004` — the demo task specs (order-pricing domain: `Money`, `Order`, `OrderLine`).
  004 is deliberately thin on purpose; do not "improve" it.

## Conventions that must stay consistent across files

Slack handles (`@Coordinator`, `@Implementer`, `@Reviewer`), sandbox names (`team-implementer`,
`team-reviewer`), branch/PR naming (`task/NNN-slug`, `[NNN] title`), and the `STATUS:` handoff
vocabulary are defined once in `spec/skills/team-conventions/SKILL.md`. When changing any of them,
grep the whole `spec/` tree and `SPEC.md`.
