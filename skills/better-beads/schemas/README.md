# Better Beads Schemas

This directory contains portable JSON contract documentation for Better Beads
robot surfaces. These schemas document current output shapes only; they do not
change producer output, add fields, or require producers to emit schema fields
they do not already emit.

## Covered Contracts

| Contract | Schema | Producer commands | Status |
|---|---|---|---|
| `better-beads-route-v1` | `better-beads-route-v1.schema.json` | `skills/better-beads/scripts/bead_route.sh --json`; `skills/better-beads/scripts/bead_route.sh --plan PATH --json`; `skills/better-beads/scripts/better-beads route --json` | Implemented |
| `better-beads-dispatch-verdict-v1` | Deferred | `skills/better-beads/scripts/bead_gate_loop.sh --operator-dispatch --json` | Deferred |
| `bead-quality-gate-v1` | Deferred | `python3 skills/better-beads/scripts/bead_quality_gate.py --json` | Deferred |
| `better-beads-authoring-triage-v1` | Deferred | `skills/better-beads/scripts/better-beads authoring-triage --json` | Deferred |

## Deferred Contracts

The dispatch verdict, quality gate, and authoring triage contracts are listed so
callers can see the intended inventory, but this work item intentionally ships
only the route schema. Later schema work should add one contract at a time with
fixture-backed producer validation.

## Validation

Run the offline schema harness:

```bash
bash skills/better-beads/scripts/test_schemas.sh route
bash skills/better-beads/scripts/test_schemas.sh
```

The harness uses only bash and the Python 3 standard library. It validates the
schema file itself, rejects unsupported JSON Schema keywords in the supported
subset, creates isolated temporary route fixtures with fake `br`/`bv` shims,
and checks current `bead_route.sh --json` output for the covered cases.

