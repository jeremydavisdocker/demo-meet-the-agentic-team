# 003 — Order total with volume discount

## Why

Customers can create an order and see what it costs. Lines bought in volume (ten or more) get 10%
off that line. This is the first feature that touches all four layers.

## Scope

**In:** the `Order` aggregate in `domain`; an `OrderRepository` port in `domain`; an `OrderService`
in `service`; a Panache-backed adapter in `persistence`; `POST /orders` and
`GET /orders/{id}/total` in `rest`.
**Out:** tax (task 004); updating or deleting orders; listing orders; currencies; authentication.

## Acceptance criteria

- [ ] AC1 — `OrderLine(sku, unitPrice: Money, quantity)` rejects blank `sku` and `quantity < 1`
  with `IllegalArgumentException`. `Order` requires at least one line and is assigned an `OrderId`
  (UUID-based value object). *Layer:* domain. *Proof:* `OrderLineTest`, `OrderTest`.
- [ ] AC2 — `Order.totals()` returns `Totals(gross, discount, net)` where `gross` is the sum of
  `unitPrice × quantity` over lines, `discount` is 10% of each line whose `quantity >= 10`
  (using `Money.percent(10)`), and `net = gross − discount`. Given lines `[(500 cents × 10),
  (300 cents × 2)]` → gross 5600, discount 500, net 5100. Given `[(500 × 9)]` → discount 0.
  *Layer:* domain. *Proof:* `OrderTest`.
- [ ] AC3 — `OrderRepository` (in `domain`) declares `void save(Order)` and
  `Optional<Order> findById(OrderId)`. `OrderService.create(List<OrderLine>)` saves and returns the
  `OrderId`; `OrderService.totals(OrderId)` returns `Totals` or throws `OrderNotFoundException`
  (domain exception). *Layer:* service. *Proof:* `OrderServiceTest` using a hand-written in-memory
  `OrderRepository` fake (no mocking framework).
- [ ] AC4 — `PanacheOrderRepository` in `persistence` implements `OrderRepository` with JPA
  entities for order and line, mapping to and from the domain objects. Saving then finding an
  order returns an equal `Order`. *Layer:* persistence. *Proof:* `PanacheOrderRepositoryIT`.
- [ ] AC5 — `POST /orders` with body
  `{"lines":[{"sku":"A","unitPriceCents":500,"quantity":10},{"sku":"B","unitPriceCents":300,"quantity":2}]}`
  returns `201`, header `Location: /orders/{id}`, body `{"id":"<uuid>"}`. Empty `lines`,
  `quantity` < 1, blank `sku`, or negative `unitPriceCents` return `400` with a JSON body
  containing a `message`. *Layer:* rest. *Proof:* `OrderResourceIT`.
- [ ] AC6 — `GET /orders/{id}/total` returns `200` and
  `{"grossCents":5600,"discountCents":500,"netCents":5100}` for the order above; an unknown id
  returns `404`. *Layer:* rest. *Proof:* `OrderResourceIT`.
- [ ] AC7 — `./mvnw -B verify` is green: ArchUnit passes (the resource depends only on `service`
  and `domain`; the discount rule exists only in `domain`), and the PIT score stays ≥ 80%.
  *Layer:* build/test. *Proof:* verify output in PR body.

## Constraints

- Layering rules in `quarkus-architecture` apply. Allowed new dependencies:
  `quarkus-hibernate-orm-panache`, `quarkus-jdbc-h2` (Dev Services / in-memory for tests),
  `quarkus-rest-jackson` if not already present. Nothing else.
- The 10%/`>= 10` rule lives in `Order` (or `OrderLine`), nowhere else — not in the resource, not
  in the entity, not in the service.
- Money is always transported as integer cents in JSON.

## Notes for the team

Reuse `Money` from task 002 for all arithmetic. The tempting shortcut is to inject
`PanacheOrderRepository` (or the entity) straight into `OrderResource` and compute the discount
there; ArchUnit will fail the build if you do. Reviewer: read `OrderResource`'s imports first, then
check that `OrderTest` covers the `quantity == 10` boundary.
