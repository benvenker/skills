# Authoring Prompts

Use this as the executable Better Beads operator-router prompt. It is written for agents that may inspect and mutate Beads state.

## Operator-router prompt

```text
Use better-beads as a workflow operator, not only a quality reference.

First inspect, then route. Use `br --json` and `bv --robot-*` for inspection. Never run bare `bv`. Use `br` mutations only after the selected mode permits mutation.

Determine relevant beads this way:
- If the user gives explicit bead IDs or labels, inspect those first.
- Otherwise inspect the active graph by title, labels, parents, dependencies, and the plan/request subject.
- Do not create duplicate beads until existing relevant beads have been ruled out.

Choose exactly one mode:
- `create-from-raw-plan`
- `improve-plan-first`
- `polish-existing-graph`
- `closeout`

Implementation agents must not use the graph until operator gates pass: relevant graph inspected, dependencies checked, ready labels verified, parent/child shape reviewed, `--operator-dispatch` clean, semantic readiness accepted, and closeout state clean.

Raw-plan mode may auto-create beads after readiness/gates pass. Do not add a default human approval pause unless the user or repo policy explicitly asks for one.
```

## Shared inspection commands

Use the commands that fit the local repo and available Beads version. Prefer JSON or robot-readable output.

```bash
br list --json
br dep cycles --json
bv --robot-plan
bv --robot-insights
br show <id> --json
```

For label or status scope, use the corresponding `br --json` filters supported by the repo's `br` version. Use `br` without JSON only for explicit mutations.

## Mode: `create-from-raw-plan`

### Inputs

- A raw plan, PRD, design note, or user request.
- No relevant existing beads after inspection, or explicit instruction to create a replacement graph.
- Enough codebase/product context to ground implementation anchors.

### Actions

1. Inspect existing beads for relevance before creating anything.
2. Convert the raw plan into a proposed graph in plan space first:
   - parent/epic closure contracts,
   - child implementation beads,
   - dependency order,
   - ready frontier labels,
   - deferred/non-goal work.
3. Apply the pre-mutation readiness checklist below.
4. If ready, create beads and dependencies with `br` mutations.
5. If not ready, route to `improve-plan-first` instead of creating weak beads.

### Pre-mutation readiness gates

Raw plans need all of these before `br create`:

- outcome: the behavior/system truth that should become true;
- anchors: current surfaces, contracts, key files/symbols, state transitions, or examples that orient a fresh agent;
- validation: behavior, contract, regression, smoke, or manual checks that prove the outcome;
- failure behavior: errors, blocked states, fallbacks, no-op behavior, or fail-closed behavior;
- non-goals: adjacent work the agent must not absorb;
- parent/child shape: parents are closure/dependency contracts; children are independently verifiable functional behaviors;
- dependency order: substrate before dependents, single-owner surfaces serialized, real parallelism preserved.

Route to `improve-plan-first` if an implementation agent would need to invent behavior, data contracts, failure handling, or verification.

### Post-mutation gates

After creating beads:

```bash
br dep cycles --json
bv --robot-plan
bv --robot-insights
.agents/skills/better-beads/scripts/bead_gate_loop.sh --operator-dispatch
```

Then run the semantic gate from `SEMANTIC-GATE.md` over all relevant active beads. The operator-dispatch deterministic gate can require split-review, but it still does not replace semantic judgment.

### Outputs

- Created parent/child graph with dependency edges.
- `ready-for-agent` labels only on the true frontier.
- Gate summary and any deferred follow-up beads.
- Dispatch decision: ready for implementation agents or routed back to polish/improve.

## Mode: `improve-plan-first`

### Inputs

- Raw or weak plan.
- Proposed graph would create broad surface buckets, checklist buckets, detail buckets, or mega-beads.
- Missing outcome, anchors, validation, failure behavior, non-goals, parent/child shape, or dependency order.

### Actions

1. Do not mutate Beads state.
2. Review the plan against `GOOD-BEAD-EXAMPLES.md`, `FAILURE-MODES.md`, and `QUALITY-RUBRIC.md`.
3. Produce a revised plan-space graph shape:
   - keep/split/merge/deepen/delete/defer decisions,
   - parents as closure contracts,
   - children as single functional behaviors,
   - validation and failure behavior per child,
   - dependency order and ready frontier.
4. Classify the result as `ready-to-create` or `needs-plan-improvement`.

### Gates

Block automatic creation if any child still requires invention of behavior, data contracts, failure handling, or verification, or if parent closure cannot be proved by child outcomes.

### Outputs

- Revised graph proposal, not Beads mutations.
- Missing-information list or concrete plan improvements.
- Route recommendation: `create-from-raw-plan` when ready, otherwise continue plan improvement.

## Mode: `polish-existing-graph`

### Inputs

- Relevant beads already exist.
- The graph needs split/merge/deepen/delete/defer work, dependency repair, label repair, or closure-contract repair before implementation.

### Actions

1. Inspect relevant beads with `br --json` and `bv --robot-*`.
2. Revise in plan space before mutating:
   - classify each weak bead as keep, split, merge, deepen, delete/defer;
   - identify broad surface buckets, checklist buckets, detail buckets, and mega-beads;
   - verify parent closure contracts and child dependency order;
   - decide the true `ready-for-agent` frontier.
3. Mutate only the clearly better graph with `br`.
4. Preserve final product and architecture decisions; discard dead intermediate debate.

### Gates

After mutation, run:

```bash
br dep cycles --json
bv --robot-plan
bv --robot-insights
.agents/skills/better-beads/scripts/bead_gate_loop.sh --operator-dispatch
```

Then run the semantic gate from `SEMANTIC-GATE.md` over the relevant active graph. Block dispatch if a child is not one independently verifiable functional behavior or if implementation agents would still need to invent behavior, contracts, failure handling, or verification.

### Outputs

- Mutated graph with evidence of changed titles/descriptions/dependencies/labels/status.
- Ready frontier and blocked/deferred work clearly separated.
- Dispatch decision, validation summary, and any `split-review-required.md` classification work.

## Mode: `closeout`

### Inputs

- Implementation or operator turn is ending.
- Any relevant bead is `in_progress`.
- User asks to close, reopen, block, or reconcile Beads state.

### Actions

1. Inspect `in_progress` and relevant active beads with `br --json`.
2. For each bead, choose exactly one truth outcome:
   - close completed work with evidence;
   - reopen incomplete work with the remaining work/reason;
   - block genuinely blocked work with exact blocker and evidence.
3. Close parent beads only after children are closed or explicitly closed as unnecessary with evidence.
4. Run closeout guard unless the user explicitly opted out.

### Gates

```bash
br sync --flush-only
.agents/skills/better-beads/scripts/bead_closeout_guard.sh
```

Do not end an operator or implementation turn with unexpected `in_progress` beads.

### Outputs

- Close/reopen/block mutations with evidence.
- Parent closure correctness checked.
- Closeout guard result.
- Follow-up beads or blockers, if any.

## Closure evidence prompt

```text
Before ending implementation work, make Beads state truthful automatically.

If validation passed and the bead contract is satisfied, close the bead yourself unless the user explicitly reserved closure for the operator. Do not leave completed work in `in_progress`.

Close the bead with:
- what changed;
- exact verification commands run;
- result summary;
- commit SHA or note that changes remain uncommitted;
- any deferred or rejected follow-up captured as another bead.

If the bead is not complete, reopen it with the remaining work or block it with the exact blocker and evidence.

Then run `bead_closeout_guard.sh` unless explicitly opted out.
```
