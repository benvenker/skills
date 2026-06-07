# Better Beads References

Use these files before creating or polishing Beads. The top-level `SKILL.md` is intentionally short; the taste and examples live here.

For the route helper's machine-readable contract, run:

```bash
scripts/better-beads route capabilities --json
scripts/better-beads route robot-docs guide
```

The route JSON schema is `better-beads-route-v1`. The dispatcher delegates route
output to `bead_route.sh`; it does not wrap or stamp the route JSON.

## Package status

These references are the durable package docs for the routing workflow. They
cover route selection, plan-readiness gates, route schema discovery, delegated
dispatcher identity, mode procedures, graph-draft helpers, semantic review
packaging, eval fixtures, and implementation closeout.

Historical scratch planning notes are intentionally not part of the installable
skill package. Agents should use these references and the local robot surfaces
as the source of truth, not private planning paths or stale transcript notes.

## Reading order

1. `GOOD-BEAD-EXAMPLES.md` — copied examples of strong parent, epic, and child beads.
2. `FAILURE-MODES.md` — common ways Beads plans look good but fail agents.
3. `QUALITY-RUBRIC.md` — scoring rubric and hard caps.
4. `BEAD-FORMATTING.md` — BV/terminal-friendly formatting rules.
5. `QUALITY-GATES.md` — deterministic lint gate and hook/CI guidance.
6. `AUTHORING-PROMPTS.md` — operator-router prompt and shared inspection commands.
7. `CREATE-FROM-RAW-PLAN-QUICKPACK.md` — compact first-pass aid for fresh graph creation.
8. Mode procedures (read the one matching your routed mode):
   - `MODE-CREATE-FROM-RAW-PLAN.md` — convert a raw plan into a bead graph.
   - `MODE-IMPROVE-PLAN-FIRST.md` — strengthen a plan before creating beads.
   - `MODE-POLISH-EXISTING-GRAPH.md` — repair an existing graph before dispatch.
   - `MODE-CLOSEOUT.md` — make bead state truthful at implementation end.
9. `PLAN-REVIEW-EXAMPLE.md` — example critique of a plausible but underpowered plan.
10. `POLISHING-CASE-STUDIES.md` — field examples of when polish should change the graph instead of only the prose.
11. `GRAPH-CONSTRUCTION-COOKBOOK.md` — current `br` graph construction semantics and dependency examples.
12. `GRAPH-DRAFT-SCHEMA.md` — reviewed draft schema for `better-beads create-graph`.
13. `SEMANTIC-GATE.md` — semantic review prompt and `semantic-pack` artifact collection.

## Minimum context rule

Before declaring a bead graph “excellent,” read:

- at least one parent/PR-slice example from `GOOD-BEAD-EXAMPLES.md`, and
- at least one child implementation example from `GOOD-BEAD-EXAMPLES.md`,
- `FAILURE-MODES.md`, and
- `BEAD-FORMATTING.md`.

A good bead is outcome-first, not template-first. It must identify the behavior being targeted, observable success criteria, verification path, non-goals, and relevant current anchors/surfaces. Exact files and symbols are helpful when known, but they are anchors for agent search, not an edit script.

If you have not inspected enough context to name the relevant behavior, contracts/key fields or state transitions, failure behavior, validation approach, and at least one current surface/anchor, the graph cannot score above 24/30.
