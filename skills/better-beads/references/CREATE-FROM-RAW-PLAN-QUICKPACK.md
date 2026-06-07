# Create From Raw Plan Quickpack

Use this when `bead_route.sh --plan PATH --json` reports a structurally ready
plan and no relevant bead graph already exists. It is a fast first-pass packet,
not a replacement for the full references.

## Start Here

```bash
scripts/better-beads route --plan path/to/plan.md --json
br list --json
bv --robot-plan
```

Proceed only when:

- relevant existing beads were ruled out;
- `plan_readiness.status` is not `weak`;
- the plan has enough context to answer blocking implementation questions.

Route to `improve-plan-first` instead when an agent would need to invent
behavior, data contracts, failure behavior, validation, or dependency order.

## Readiness Gates

Before any `br create`, the plan must answer:

- **Outcome:** what system truth becomes true?
- **Anchors:** what current surfaces, files, contracts, or state transitions
  orient a fresh agent?
- **Validation:** what commands or smoke checks prove the behavior?
- **Failure behavior:** what errors, fallbacks, blocked states, or no-ops are
  required?
- **Non-goals:** what adjacent work is excluded?
- **Parent/child shape:** which parents are closure contracts and which children
  are independently verifiable work?
- **Dependency order:** what must land before dependents, and what can run in
  parallel without file conflicts?

## Parent Template

```md
## Outcome
The full lane outcome that should be true after all children close.

## Background
- Final product or architecture decisions to preserve.
- Why this is a lane, not one implementation task.

## Closure contract
Do not close until all direct children are closed or explicitly closed as
unnecessary with evidence.

## Children / intended order
1. `<child title>` - why it lands first.
2. `<child title>` - what it consumes from the prior child.

## Scope / non-goals
- Included lane work.
- Adjacent work that must not be absorbed.

## Parent acceptance criteria
- All child closure evidence is present.
- Graph remains acyclic.

## Validation
```bash
br dep cycles --json
bv --robot-plan
bv --robot-insights
```

## Parallelization notes
- Single-owner surfaces and safe parallel tracks.
```

## Child Template

```md
## Outcome
One independently verifiable behavior or system truth.

## Parent / source of truth
- Parent: `<parent id/title>`.
- Preserves: final decision from the plan.

## Success criteria
- Observable behavior, data shape, state transition, or user-visible result.

## Scope / non-goals
- Do: included work.
- Do not: adjacent work, hidden refactors, or unsafe side effects.

## Failure behavior
- Required error, fallback, blocked, no-op, or partial-success behavior.

## Known anchors / surfaces
- User-visible surface or command.
- Current likely files, symbols, contracts, or fixtures.

## Validation
```bash
<targeted command>
```
Expected: passing output or observation.

## Dependency / parallel notes
- Depends on: `<id/title>` if applicable.
- Single-owner risk: `<file/surface>` if applicable.

## Closure evidence
Close with: changed behavior, validation commands/results, and follow-ups.
```

## Strong Parent Example

```md
## Outcome
Agents can create reviewed Better-Beads graphs from structured drafts.

## Background
- Raw-plan mode may create beads only after readiness gates pass.
- Parent-child edges express closure ownership; default `blocks` edges express
  implementation order.

## Closure contract
Do not close until cookbook docs, draft dry-run, apply behavior, and frontier
label checks are closed or explicitly closed as unnecessary with evidence.

## Children / intended order
1. `Publish graph construction cookbook` - establishes safe dependency shape.
2. `Add create-graph dry-run` - validates drafts before mutation.
3. `Add create-graph apply` - creates reviewed graphs deterministically.

## Parent acceptance criteria
- Child beads are closed with validation evidence.
- `br dep cycles --json` reports no cycles.
- Only true frontier children carry `ready-for-agent`.
```

## Strong Child Example

```md
## Outcome
`better-beads create-graph --dry-run graph.json` previews graph mutations
without writing Beads state.

## Parent / source of truth
- Parent: reviewed graph draft/apply lane.
- Preserves: mutation happens only after dry-run review and gates.

## Success criteria
- JSON output lists proposed issues, labels, priorities, and dependencies.
- Unknown dependency references fail before mutation.
- Parent-child and blocking edges are shown separately.

## Scope / non-goals
- Do: validate and render draft JSON.
- Do not: call `br create` or modify `.beads`.

## Failure behavior
- Invalid JSON exits nonzero with a field-specific message.
- Duplicate titles or unknown references fail closed.

## Known anchors / surfaces
- Dispatcher: `skills/better-beads/scripts/better-beads`.
- Existing route/gate style: `bead_route.sh`, `bead_gate_loop.sh`.

## Validation
```bash
skills/better-beads/scripts/better-beads create-graph --dry-run example.json
```
Expected: parseable JSON and no Beads state mutation.
```

## Top Failure Modes

- **Skipped routing:** creating beads before `route --plan` and graph inspection.
- **Checklist sludge:** one bead per checklist bullet instead of PR-shaped work.
- **Broad buckets:** child named for a surface but covering many behaviors.
- **Missing anchors:** no current files, commands, contracts, or state transitions.
- **Validation theater:** only broad build/test commands without behavior intent.
- **Parent as task:** parent lacks child order and closure contract.
- **Unsafe parallelism:** ready children fight over the same file or command table.

## Graph Recipe

Use `GRAPH-CONSTRUCTION-COOKBOOK.md` for exact `br` commands. The short rule:

- `br create --parent <parent>` creates child ownership.
- `br dep add <later-child> <earlier-child>` expresses implementation order.
- Do not use `parent-child` edges for child-to-child order.
- Run `br dep cycles --json` before dispatch.

## Post-Mutation Gates

```bash
br dep cycles --json
bv --robot-plan
bv --robot-insights
scripts/bead_gate_loop.sh --operator-dispatch
scripts/bead_closeout_guard.sh
```

- no cycles;
- ready labels only on true frontier children;
- parent closure shape is explicit;
- no unexpected `in_progress` beads;
- semantic review accepts that implementation agents will not need to invent
  behavior, contracts, failure handling, or verification.

## Fall Back To Full References

Read the full references when:

- the plan has multiple product lanes or unclear parent boundaries;
- a child triggers split-review or large-child warnings;
- validation, data contracts, or failure behavior are still vague;
- graph construction needs repaired dependencies;
- semantic readiness is uncertain.
