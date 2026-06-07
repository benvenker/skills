# Better Beads Schemas

This directory contains portable JSON contract documentation for Better Beads
robot surfaces. These schemas document current output shapes only; they do not
change producer output, add fields, or require producers to emit schema fields
they do not already emit.

## Covered Contracts

| Contract | Schema | Producer commands | Status |
|---|---|---|---|
| `better-beads-route-v1` | `better-beads-route-v1.schema.json` | `skills/better-beads/scripts/bead_route.sh --json`; `skills/better-beads/scripts/bead_route.sh --plan PATH --json`; `skills/better-beads/scripts/better-beads route --json` | Implemented |
| `better-beads-dispatch-verdict-v1` | `better-beads-dispatch-verdict-v1.schema.json` | `skills/better-beads/scripts/bead_gate_loop.sh --operator-dispatch --json` | Implemented |
| `bead-quality-gate-v1` | `better-beads-quality-gate-v1.schema.json` | `python3 skills/better-beads/scripts/bead_quality_gate.py --json` | Implemented |
| `better-beads-authoring-triage-v1` | `better-beads-authoring-triage-v1.schema.json` | `skills/better-beads/scripts/better-beads authoring-triage --json` | Implemented |

## Deferred Contracts

The frontier, triage, create-graph, semantic-pack, and capabilities contracts
remain deferred. Later schema work should add one contract at a time with
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
