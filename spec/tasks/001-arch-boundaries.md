# 001 — Architecture boundaries as tests

## Why

The team has agreed on a layering (`rest → service → domain ← persistence`) but nothing enforces
it. An executable definition means drift is caught by `./mvnw test`, not by a reviewer noticing an
import.

## Scope

**In:** an ArchUnit test suite for the layering rules in the `quarkus-architecture` skill; the
package skeleton `com.example.demo.{rest,service,domain,persistence}`; moving the generated
`GreetingResource` into `rest`.
**Out:** any business code; mutation testing (task 002); renaming `GreetingResourceTest` (task 002);
CI changes (the `verify` workflow already runs `mvn test`).

## Acceptance criteria

- [ ] AC1 — `com.tngtech.archunit:archunit-junit5` is a test-scoped dependency and
  `src/test/java/com/example/demo/ArchitectureTest.java` exists, annotated
  `@AnalyzeClasses(packages = "com.example.demo", importOptions = ImportOption.DoNotIncludeTests.class)`.
  *Layer:* build/test. *Proof:* `./mvnw -B test` lists `ArchitectureTest` in `target/surefire-reports`.
- [ ] AC2 — A `layeredArchitecture()` rule defines layers `Rest` (`..rest..`), `Service`
  (`..service..`), `Domain` (`..domain..`), `Persistence` (`..persistence..`) with:
  `Rest` accessed by nothing; `Service` only by `Rest`; `Domain` by `Service`, `Persistence`, `Rest`;
  `Persistence` by nothing. Uses `.withOptionalLayers(true)` so still-empty packages pass.
  *Layer:* build/test. *Proof:* `ArchitectureTest` passes on the current code.
- [ ] AC3 — A rule forbids classes in `..domain..` from depending on `jakarta..`, `io.quarkus..`,
  or `org.hibernate..`. *Layer:* build/test. *Proof:* `ArchitectureTest`.
- [ ] AC4 — A rule forbids classes in `..rest..` from depending on `..persistence..`.
  *Layer:* build/test. *Proof:* `ArchitectureTest`.
- [ ] AC5 — A rule requires classes in `..persistence..` that implement an interface from
  `..domain..` to have simple names ending in `Adapter` or `Repository`. *Layer:* build/test.
  *Proof:* `ArchitectureTest`.
- [ ] AC6 — The rules bite: with a temporary class `com.example.demo.domain.Smoke` that imports
  `jakarta.ws.rs.Path`, `./mvnw -B test` fails naming the violated rule. The class is deleted before
  committing; the failing output (rule name + violation line) is pasted in the PR body.
  *Layer:* build/test. *Proof:* PR body excerpt.
- [ ] AC7 — `GreetingResource` lives in `com.example.demo.rest`; the generated
  `GreetingResourceTest` still passes unchanged apart from the package. *Layer:* rest.
  *Proof:* existing `GreetingResourceTest`.

## Constraints

- No new runtime dependencies. Only `archunit-junit5` (test scope) may be added.
- Rules must match the `quarkus-architecture` skill exactly; do not add stricter rules "while at it".
- `ArchitectureTest` is a plain JUnit 5 test — no `@QuarkusTest`.

## Notes for the team

Use `com.tngtech.archunit.library.Architectures.layeredArchitecture().consideringOnlyDependenciesInLayers()`
so JDK and framework dependencies do not trip the layer rule; AC3 covers the framework ban
separately. Reviewer: confirm AC6's pasted failure is from the *layer* or *domain-import* rule, not a
compile error.
