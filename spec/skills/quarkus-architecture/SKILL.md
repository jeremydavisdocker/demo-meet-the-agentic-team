---
name: quarkus-architecture
description: Layering rules and test conventions for the Quarkus demo repo — which packages may depend on which, why domain/service stay framework-free, how ArchUnit and PIT mutation testing are wired and why @QuarkusTest classes are excluded from mutation runs. Load when writing or reviewing any Java in the repo.
version: 1.0.0
metadata:
  hermes:
    tags: [quarkus, java, archunit, pitest]
    category: agentic-team
---

# Quarkus architecture rules

Base package: `com.example.demo` (replace consistently if the repo uses another).

## Layers and allowed dependencies

```
rest ──▶ service ──▶ domain ◀── persistence
```

| Package        | Contains                                              | May import                        |
|----------------|-------------------------------------------------------|-----------------------------------|
| `domain`       | entities/value objects, business rules, ports (interfaces) | JDK only. **No** `jakarta.*`, `io.quarkus.*`, `org.hibernate.*`, `com.example.demo.*` other packages |
| `service`      | use cases orchestrating domain objects via ports      | `domain`, `jakarta.inject`, `jakarta.transaction` |
| `persistence`  | Panache/JPA adapters implementing domain ports        | `domain`, `jakarta.persistence`, `io.quarkus.hibernate.*` |
| `rest`         | JAX-RS resources, DTOs, mapping                       | `service`, `domain` (read-only types), `jakarta.ws.rs`, `jakarta.validation` |

Rationale for the demo: keeping `domain` and `service` framework-free is what makes them cheap to
unit-test and therefore cheap to mutation-test. Every framework annotation that leaks into `domain`
is a test that has to boot Quarkus.

## ArchUnit (task 001 introduces this)

- Dependency: `com.tngtech.archunit:archunit-junit5` (test scope).
- One test class `ArchitectureTest` in `src/test/java/com/example/demo/`, annotated
  `@AnalyzeClasses(packages = "com.example.demo", importOptions = ImportOption.DoNotIncludeTests.class)`.
- Rules, each an `@ArchTest`:
  1. `layeredArchitecture()` with the four layers and the access rules in the table above.
  2. `noClasses().that().resideInAPackage("..domain..").should().dependOnClassesThat().resideInAnyPackage("jakarta..", "io.quarkus..", "org.hibernate..")`.
  3. `noClasses().that().resideInAPackage("..rest..").should().dependOnClassesThat().resideInAPackage("..persistence..")`.
  4. Classes in `..persistence..` implementing a domain port must have simple names ending in `Adapter` or `Repository`.
- It is a plain JUnit test: it runs under surefire in `mvn test` and therefore in `verify` and CI.
  No `@QuarkusTest`.

## Test naming and PIT (task 002 introduces this)

| Suffix   | Runner   | Boots Quarkus? | Mutated by PIT? |
|----------|----------|----------------|-----------------|
| `*Test`  | surefire | no (plain JUnit 5) | yes         |
| `*IT`    | failsafe | yes (`@QuarkusTest`, `@QuarkusIntegrationTest`) | no |

PIT configuration (`pitest-maven` + `pitest-junit5-plugin`, bound to the `verify` phase):

```xml
<plugin>
  <groupId>org.pitest</groupId>
  <artifactId>pitest-maven</artifactId>
  <version>${pitest.version}</version>
  <dependencies>
    <dependency>
      <groupId>org.pitest</groupId>
      <artifactId>pitest-junit5-plugin</artifactId>
      <version>${pitest.junit5.version}</version>
    </dependency>
  </dependencies>
  <configuration>
    <targetClasses>
      <param>com.example.demo.domain.*</param>
      <param>com.example.demo.service.*</param>
    </targetClasses>
    <targetTests>
      <param>com.example.demo.*Test</param>
    </targetTests>
    <excludedTestClasses>
      <param>com.example.demo.*IT</param>
    </excludedTestClasses>
    <mutators><mutator>STRONGER</mutator></mutators>
    <mutationThreshold>80</mutationThreshold>
    <timestampedReports>false</timestampedReports>
    <outputFormats><param>HTML</param><param>XML</param></outputFormats>
    <threads>4</threads>
    <timeoutConstant>4000</timeoutConstant>
  </configuration>
  <executions>
    <execution>
      <id>mutation-coverage</id>
      <phase>verify</phase>
      <goals><goal>mutationCoverage</goal></goals>
    </execution>
  </executions>
</plugin>
```

Use the current stable `pitest.version` / `pitest.junit5.version` at build time (the junit5 plugin
must be ≥ 1.2.3 for Quarkus projects). Reports: `target/pit-reports/index.html`.

## Interpreting a red PIT run

A surviving mutant means a behaviour change no test noticed. The fix is a stronger assertion or a
missing case in a `*Test`, never a lower `mutationThreshold`, an added exclusion, or moving the
class out of `domain`/`service`. Reviewers treat any of those three as a P0.

## Adding a feature (checklist)

1. Domain rule → `domain` class + `*Test`.
2. Use case → `service` class depending on a `domain` port + `*Test` with a hand-written fake (no
   mocking framework needed for ports).
3. Storage → `persistence` adapter + `*IT`.
4. Endpoint → `rest` resource + DTO + `*IT` using RestAssured.
5. `./mvnw -B verify` green, including ArchUnit and PIT.
