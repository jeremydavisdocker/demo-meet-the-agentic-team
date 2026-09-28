# 002 — Mutation testing gate

## Why

Line coverage says a line ran; a mutation score says a test would notice if the line broke. Making
PIT part of `./mvnw verify` means every future PR must ship tests that actually detect defects.

## Scope

**In:** PIT (`pitest-maven` + `pitest-junit5-plugin`) bound to the `verify` phase with the
configuration in the `quarkus-architecture` skill; the `*Test` / `*IT` naming convention with
`maven-failsafe-plugin` running `*IT`; renaming `GreetingResourceTest` to `GreetingResourceIT`; a
first framework-free domain class, `Money`, so PIT has something to mutate.
**Out:** any order/pricing behaviour beyond `Money` (task 003); CI changes (the workflow already
uploads `target/pit-reports`); changing the threshold.

## Acceptance criteria

- [ ] AC1 — `./mvnw -B verify` runs PIT after the tests and fails the build when the mutation
  score is below 80% (`mutationThreshold` = 80). *Layer:* build/test. *Proof:*
  `target/pit-reports/index.html` is produced by `verify`; PR body quotes the score line.
- [ ] AC2 — PIT mutates only `com.example.demo.domain.*` and `com.example.demo.service.*`, runs
  only `com.example.demo.*Test`, excludes `com.example.demo.*IT`, uses the `STRONGER` mutator set,
  `timestampedReports=false`, HTML + XML output. *Layer:* build/test. *Proof:* `pom.xml` plus the
  `mutations.xml` report listing only those packages.
- [ ] AC3 — `maven-failsafe-plugin` runs `*IT` classes in `integration-test`/`verify`; surefire runs
  only `*Test`. `GreetingResourceTest` is renamed `GreetingResourceIT` (still `@QuarkusTest`) and
  passes under failsafe. *Layer:* rest. *Proof:* `target/failsafe-reports` lists `GreetingResourceIT`;
  `target/surefire-reports` does not.
- [ ] AC4 — `com.example.demo.domain.Money` is an immutable value object holding a `long` of cents:
  `Money.ofCents(long)`, `Money.ZERO`, `plus(Money)`, `times(int quantity)`, `percent(int pct)`
  (result rounded half-up to the cent), `cents()`, `isZero()`, value-based `equals`/`hashCode`/
  `toString`. Negative cents, negative quantity, and `pct` outside 0–100 throw
  `IllegalArgumentException`. *Layer:* domain. *Proof:* `MoneyTest` (plain JUnit).
- [ ] AC5 — `MoneyTest` yields a mutation score ≥ 80% on `Money` with the configuration above.
  *Layer:* domain. *Proof:* PIT report, `Money` row.
- [ ] AC6 — `./mvnw -B verify` is green end to end (compile, `*Test`, ArchUnit, `*IT`, PIT).
  *Layer:* build/test. *Proof:* verify output in PR body.

## Constraints

- Use current stable `pitest-maven` and `pitest-junit5-plugin` versions; the JUnit 5 plugin must be
  ≥ 1.2.3. Declare them as `pitest.version` / `pitest.junit5.version` properties.
- `Money` imports nothing outside `java.*`.
- The threshold is 80. Do not add `excludedClasses`, `avoidCallsTo`, or `excludedMutators`.

## Notes for the team

Half-up rounding in `percent` is where mutants survive: test 0%, 100%, an exact-cent result, a
result ending in .5 cents (rounds up), and one ending in .49 cents (rounds down). Reviewer: run
`./mvnw -B verify` yourself and compare the score you get with the one in the PR body.
