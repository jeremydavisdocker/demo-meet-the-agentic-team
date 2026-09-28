# AGENTS.md

Guidance for coding agents (Codex reads this file; Claude Code reads `CLAUDE.md`, which says the
same things). Role procedures live in `.agents/skills/` — `team-conventions`,
`quarkus-architecture`, and `reviewer`.

## Project

Quarkus service, Java 21, Maven wrapper. Packages under `com.example.demo`:
`rest → service → domain ← persistence`. `domain`/`service` are framework-free and mutation-tested;
`rest`/`persistence` are thin adapters tested with `@QuarkusTest` classes named `*IT`.

## Commands

- `./mvnw -B verify` — the gate: compile, `*Test`, `*IT`, ArchUnit, PIT mutation threshold.
- `./mvnw -B test` — unit tests + ArchUnit only.
- Reports: `target/surefire-reports/`, `target/failsafe-reports/`, `target/pit-reports/index.html`.

## Conventions

- Specs: `specs/NNN-slug.md` with an `## Acceptance criteria` checklist.
- Branch `task/NNN-slug`; commits `feat|test|fix|chore(NNN): …`; PR title `[NNN] <title>`.
- Slack messages start with a `STATUS:` line and end with an @mention of the next actor.

## Code Review Rules

- Every acceptance criterion in the linked spec must map to a code change **and** a test that would
  fail without it. An unproven criterion is P0.
- Any import from `domain` to `jakarta.*`, `io.quarkus.*`, or `org.hibernate.*`, or from `rest` to
  `persistence`, is P0 even if ArchUnit was not updated to catch it.
- Business logic in `rest` or `persistence` (conditionals on domain state, calculations) is P1;
  suggest the `domain`/`service` home.
- Lowering `mutationThreshold`, adding PIT exclusions, deleting or `@Disabled`-ing tests, or
  renaming a `*Test` to `*IT` to dodge mutation is P0 — call it out explicitly as threshold gaming.
- A test with no assertion on an outcome (only "does not throw", or only verifying a mock was
  called) is P1.
- Changes outside the spec's **Scope: In** list are P1 unless trivially required by the change.
- Do not comment on formatting, import order, or naming that the codebase already uses.
- Run `./mvnw -B verify` yourself before forming a verdict; report the PIT score in the review body.
- Verdict rule: no open P0/P1 → approve; otherwise request changes. Never approve "with nits to
  fix later" if any of them is P1.
