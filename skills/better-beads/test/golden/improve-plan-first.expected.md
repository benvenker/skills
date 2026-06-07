# Golden expected: improve a weak plan first

## Route

- Recommended mode: `improve-plan-first`
- Reason: the plan lacks concrete outcome, anchors, validation, failure
  behavior, non-goals, parent/child shape, and dependency order.

## Minimum response assertions

- Stays in plan space and does not create, update, close, or label beads.
- Names the missing readiness gates.
- Produces specific questions or a revised plan shape that would make creation
  safe.
- Blocks automatic bead creation until implementation agents would no longer
  need to invent behavior, contracts, failure handling, or verification.

## Harness note

The response may strengthen the plan directly or request missing details, but
it must not claim the plan is ready as written.
