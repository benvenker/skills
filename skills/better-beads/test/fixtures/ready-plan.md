# Ready Plan Fixture

## Outcome

The authoring router reports a clear system truth before any bead mutation:
operators know whether a raw plan can become beads or must be strengthened.

## Anchors

- Surface: `skills/better-beads/scripts/bead_route.sh`.
- Contract: JSON route output for robot callers.
- State transition: weak plan input routes to `improve-plan-first`.

## Validation

- Run `bash skills/better-beads/test/test_bead_route.sh`.
- Verify weak and ready plan JSON with `python3 -m json.tool`.

## Failure behavior

- Missing plan paths exit 2 with a clear stderr error.
- Weak plans list missing readiness gates instead of mutating bead state.

## Non-goals

- Do not perform semantic LLM review.
- Do not create or update beads from `--plan`.

## Parent/child shape

The parent closes when child implementation beads provide evidence. Children
remain independently verifiable and do not make the parent directly implementable.

## Dependency order

Route inspection behavior lands before truth-table docs and schema registry
dependents. Single-owner route JSON surfaces are serialized before downstream
tests rely on them.
