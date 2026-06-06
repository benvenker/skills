# Mode: create-from-raw-plan

Convert a raw plan, PRD, design note, or user request into a bead graph when no relevant beads exist.

## When to use

- No relevant existing beads after inspection, or explicit instruction to create a replacement graph.
- A raw plan is available with enough codebase/product context to ground implementation anchors.
- The plan passes the pre-mutation readiness gates below.

If the plan is raw, weak, or under-grounded, route to `improve-plan-first` instead.

## Inspection

Before creating anything, inspect for existing relevant beads:

```bash
br list --json
br show <id> --json     # for any potentially relevant beads
bv --robot-plan
```

Do not create duplicate beads until existing relevant beads have been ruled out.

## Actions

1. **Inspect** existing beads for relevance before creating anything.
2. **Design** the proposed graph in plan space first:
   - parent/epic closure contracts,
   - child implementation beads,
   - dependency order,
   - ready frontier labels,
   - deferred/non-goal work.
3. **Check** the pre-mutation readiness gates below.
4. **Create** beads and dependencies with `br` mutations if gates pass.
5. **Route** to `improve-plan-first` if gates fail instead of creating weak beads.

## Pre-mutation readiness gates

All of these must be satisfiable before running `br create`:

| Gate | Question |
|------|----------|
| **Outcome** | What behavior/system truth should become true? |
| **Anchors** | What current surfaces, contracts, key files/symbols, state transitions orient a fresh agent? |
| **Validation** | What behavior, contract, regression, smoke, or manual checks prove the outcome? |
| **Failure behavior** | What errors, blocked states, fallbacks, no-op behavior, or fail-closed behavior? |
| **Non-goals** | What adjacent work must the agent not absorb? |
| **Parent/child shape** | Are parents closure/dependency contracts? Are children independently verifiable functional behaviors? |
| **Dependency order** | Does substrate land before dependents? Are single-owner surfaces serialized? Is real parallelism preserved? |

If an implementation agent would need to **invent** behavior, data contracts, failure handling, or verification, the plan is not ready. Route to `improve-plan-first`.

## Post-mutation gates

After creating beads, run:

```bash
br dep cycles --json
bv --robot-plan
bv --robot-insights
scripts/bead_gate_loop.sh --operator-dispatch
```

Then run the semantic gate from `SEMANTIC-GATE.md` over all relevant active beads. The operator-dispatch deterministic gate can require split-review, but it does not replace semantic judgment.

## Outputs

- Created parent/child graph with dependency edges.
- `ready-for-agent` labels only on the true frontier.
- Gate summary and any deferred follow-up beads.
- Dispatch decision: ready for implementation agents, or routed back to polish/improve.
