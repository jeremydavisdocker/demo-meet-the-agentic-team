# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A small Quarkus service used as the shared workspace of an agentic development team (Coordinator,
Implementer, Reviewer). Work arrives as specs in `specs/NNN-slug.md`; it leaves as PRs. Team
procedures live in `.claude/skills/` — load `team-conventions` and `quarkus-architecture` before
touching code, and `implementer` when dispatched with a task id.

## Commands

```bash
./mvnw -B verify                     # the gate: compile, *Test (surefire), *IT (failsafe), ArchUnit, PIT threshold
./mvnw -B test                       # unit tests + ArchUnit only (fast)
./mvnw -B test -Dtest=OrderRulesTest # one unit test class
./mvnw -B verify -Dit.test=OrderResourceIT   # one integration test class (units still run)
./mvnw -B test-compile org.pitest:pitest-maven:mutationCoverage   # PIT alone; report in target/pit-reports/index.html
./mvnw quarkus:dev                   # dev mode on :8080 (not needed for tests)
```

## Architecture

Four packages under `com.example.demo`, dependencies flow `rest → service → domain ← persistence`.
`domain` and `service` are framework-free on purpose: they are unit-tested with plain JUnit and
mutation-tested with PIT. `rest` and `persistence` are thin adapters covered by `@QuarkusTest`
classes named `*IT`. `ArchitectureTest` (ArchUnit) enforces the arrows; PIT enforces that tests in
`domain`/`service` actually detect defects (threshold in `pom.xml`). Full rules and the reasoning are
in `.claude/skills/quarkus-architecture/SKILL.md`.

## Rules that are easy to get wrong

- Test class suffix decides the runner: `*Test` = plain JUnit, mutated; `*IT` = Quarkus, not mutated.
  A `@QuarkusTest` named `*Test` will make PIT crawl.
- A red PIT run is fixed by stronger tests, never by lowering `mutationThreshold`, adding
  exclusions, or moving code out of `domain`/`service`.
- Branch `task/NNN-slug`, commits `feat(NNN): …`, PR title `[NNN] …`. Never commit to `main`.
- Slack handoffs start with a `STATUS:` line and end with `@Coordinator` (see `team-conventions`).
