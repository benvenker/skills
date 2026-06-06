# Mode: polish-existing-graph

Inspect and repair an existing bead graph before implementation dispatch: split, merge, deepen, delete, defer, fix dependencies, repair labels, fix closure contracts.

## When to use

- Relevant beads already exist in the graph.
- The graph needs structural or content repair before implementation agents can use it.
- Common triggers: broad surface buckets, missing dependencies, wrong `ready-for-agent` labels, parent beads without addressable children.

## Inspection

Inspect the relevant beads before any mutation:

```bash
br list --json
br show <id> --json     # for each relevant bead
br dep cycles --json
bv --robot-plan
bv --robot-insights
```

## Actions

1. **Inspect** relevant beads with `br --json` and `bv --robot-*`.
2. **Revise in plan space** before mutating:
   - classify each weak bead as keep, split, merge, deepen, delete/defer;
   - identify broad surface buckets, checklist buckets, detail buckets, and mega-beads;
   - verify parent closure contracts and child dependency order;
   - decide the true `ready-for-agent` frontier.
3. **Mutate** only the clearly better graph with `br`.
4. **Preserve** final product and architecture decisions; discard dead intermediate debate.

## Polishing loop discipline

Repeated polish rounds should improve the execution graph, not endlessly reword one bead:

- **Contract detail** for the same outcome → add to success criteria, failure behavior, validation, anchors, or non-goals.
- **New independent behavior** → create or split into a bead only when it has its own observable outcome and reviewable PR/commit.
- When size warnings fire, run the split test before compacting prose.
- Stop or rotate after two fresh passes that produce no new behavior, tests, failure cases, dependency edges, split/merge decisions, or labels.

See `references/POLISHING-CASE-STUDIES.md` for examples of when polish should change the graph instead of only the prose.

## Gates

After mutation, run:

```bash
br dep cycles --json
bv --robot-plan
bv --robot-insights
scripts/bead_gate_loop.sh --operator-dispatch
```

Then run the semantic gate from `SEMANTIC-GATE.md` over the relevant active graph. Block dispatch if:

- a child is not one independently verifiable functional behavior, or
- implementation agents would still need to invent behavior, contracts, failure handling, or verification.

## Outputs

- Mutated graph with evidence of changed titles/descriptions/dependencies/labels/status.
- Ready frontier and blocked/deferred work clearly separated.
- Dispatch decision, validation summary, and any split-review classification work.
