# NNN — <Task title>

<!-- File name: specs/NNN-<slug>.md. Keep this header block; agents parse the title and the
     acceptance criteria. Replace every <angle-bracket> placeholder. Delete these comments. -->

## Why

<One or two sentences: the user or system need this task serves. Not how.>

## Scope

**In:** <bullet list of what changes — endpoints, rules, config>
**Out:** <what is explicitly not part of this task, so the implementer does not "help">

## Acceptance criteria

<!-- Each criterion must be observable and testable. Name the layer it lives in and the kind of
     test that proves it. The Implementer maps each box to a test; the Reviewer maps each box to
     evidence in the diff. Vague criteria ("works correctly", "is fast") are rejected. -->

- [ ] AC1 — <Given/When/Then statement>. *Layer:* <domain|service|persistence|rest>. *Proof:* <plain `*Test` | `*IT`>.
- [ ] AC2 — ...
- [ ] AC3 — ...

## Constraints

- Layering rules in `quarkus-architecture` apply; no new dependencies unless listed here: <none | list>.
- <Any behaviour that must not change; any performance/compat constraint that is testable.>

## Notes for the team

<Optional hints: relevant existing classes, edge cases worth a test, what the reviewer should look
at first. Keep it short — this is context, not instructions.>
