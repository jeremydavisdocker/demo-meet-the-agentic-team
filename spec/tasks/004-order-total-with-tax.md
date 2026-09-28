# 004 — Order total including tax

## Why

Customers must see the price they will actually pay. Add 20% tax to the order total.

## Scope

**In:** tax on the discounted order total; two new fields in the `GET /orders/{id}/total` response.
**Out:** multiple tax rates, per-line or per-country tax, tax-exempt SKUs, changes to `POST /orders`.

## Acceptance criteria

- [ ] AC1 — `Order.totals()` additionally returns `tax` (20% of `net`) and `total` (`net + tax`).
  *Layer:* domain. *Proof:* `OrderTest`.
- [ ] AC2 — `GET /orders/{id}/total` returns the two new fields `taxCents` and `totalCents`
  alongside the existing ones. *Layer:* rest. *Proof:* `OrderResourceIT`.
- [ ] AC3 — `./mvnw -B verify` is green, including the PIT threshold. *Layer:* build/test.
  *Proof:* verify output in PR body.

## Constraints

- Layering rules in `quarkus-architecture` apply; no new dependencies.
- The tax rate is a single constant in `domain` for now.
- Amounts are rounded to whole cents.

## Notes for the team

Tax is computed on `net` (after discount), not on `gross`.
