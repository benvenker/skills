# Current br Graph Construction Cookbook

Use this recipe when building a Better-Beads graph from a plan. It reflects the
installed `br` CLI behavior verified with:

```bash
br create --help
br dep add --help
br dep list --help
```

## Mental Model

`br dep add <issue> <depends-on>` means:

- `<issue>` waits on `<depends-on>`.
- The default dependency type is `blocks`.
- `--type parent-child` is for roll-up ownership/closure shape.
- Plain/default `blocks` is for implementation order.

Parents are closure contracts. Children are addressable work. A parent is not
ready for implementation just because it appears in `br ready`; close it only
after its children are closed or explicitly closed as unnecessary with evidence.

## Safe Pattern

Prefer this sequence for a parent with ordered children:

```bash
parent_id=$(br create \
  --title "Improve Better-Beads graph authoring ergonomics" \
  --type epic \
  --priority 1 \
  --labels "better-beads,authoring-ergonomics" \
  --description "$PARENT_BODY" \
  --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')

child_a=$(br create \
  --parent "$parent_id" \
  --title "Publish br graph construction cookbook" \
  --type task \
  --priority 1 \
  --labels "better-beads,docs,ready-for-agent" \
  --description "$CHILD_A_BODY" \
  --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')

child_b=$(br create \
  --parent "$parent_id" \
  --title "Add safe graph draft/apply helper" \
  --type feature \
  --priority 2 \
  --labels "better-beads,cli" \
  --description "$CHILD_B_BODY" \
  --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')

br dep add "$child_b" "$child_a" --json
br dep list "$parent_id" --direction up --type parent-child --json
br dep list "$child_b" --direction down --json
br dep cycles --json
br ready --json
br sync --flush-only
```

Notes:

- `br create --parent "$parent_id"` creates the parent-child relationship.
- `br dep add "$child_b" "$child_a"` expresses order: B waits for A.
- Keep `ready-for-agent` only on children that are truly unblocked and scoped.
- Run `br dep cycles --json` before dispatching agents.

## When To Use Each Command

Use `br create --parent <parent-id>` when creating a child that belongs under a
roll-up parent.

Use `br dep add <child> <parent> --type parent-child` only when you need to add
or repair that parent-child relationship after creation. Prefer `--parent` at
creation time because it keeps the child creation command self-contained.

Use plain `br dep add <later> <earlier>` for implementation order. Since the
default dependency type is `blocks`, this says the later bead waits for the
earlier bead to close.

Use `br dep list <id> --json` to verify the down edges for one bead. Add
`--direction up` when checking what waits on a parent or blocker.

## Parent Example

```md
## Outcome
Fresh agents can create and dispatch a strong Better-Beads authoring graph.

## Background
- Parent-child edges define closure ownership, not implementation order.
- Implementation order belongs in explicit blocking dependencies.

## Closure contract
Do not close until every direct child is closed or explicitly closed as
unnecessary with evidence.

## Children / intended order
1. `Publish br graph construction cookbook` - establishes the graph recipe.
2. `Add safe graph draft/apply helper` - implements the documented recipe.
3. `Add frontier JSON command` - exposes ready-label truth after read-side
   inspection is fenced.

## Parent acceptance criteria
- Child beads are closed with validation evidence.
- `br dep cycles --json` reports no cycles.
- `bv --robot-triage` shows only genuinely actionable ready children.
```

Final shape:

- Child cookbook bead has a `parent-child` relationship to the parent.
- Helper bead has a `parent-child` relationship to the parent.
- Frontier bead has a `parent-child` relationship to the parent.
- Helper bead also has a default `blocks` dependency on the cookbook bead.
- Frontier bead also has default `blocks` dependencies on its prerequisites.

## Child Example

```md
## Outcome
Agents can dry-run a graph draft before any bead mutation happens.

## Parent / source of truth
- Parent: Better-Beads authoring ergonomics graph.
- Preserves: graph mutations must follow the documented cookbook recipe.

## Success criteria
- Dry-run reports issue titles, labels, priorities, and dependency edges.
- Invalid references fail before creating any bead.
- Apply creates parent-child edges and blocking edges in deterministic order.

## Scope / non-goals
- Do: implement the draft parser and dry-run output.
- Do: add targeted tests for invalid references.
- Do not: create beads from unreviewed LLM output.

## Validation
```bash
skills/better-beads/scripts/better-beads create-graph --dry-run example.json
bash skills/better-beads/scripts/test_cli_robot_surfaces.sh
```
```

The child says what to build and how to validate it. It does not rely on the
parent to carry hidden implementation requirements.

## Combinations To Avoid

Do not use both of these to express the same parent relationship:

```bash
br create --parent "$parent_id" ...
br dep add "$child_id" "$parent_id" --type parent-child
```

Pick one. Duplicate parent-child edges create confusing review evidence and may
be rejected depending on the current graph state.

Do not express child order with `parent-child`:

```bash
br dep add "$later_child" "$earlier_child" --type parent-child
```

Use default `blocks` instead:

```bash
br dep add "$later_child" "$earlier_child"
```

Do not mix parent-child and default `blocks` edges between the same parent and
child merely to force closure order. That creates confusing readiness signals.
Use parent-child edges for ownership, child-to-child `blocks` edges for order,
and parent prose for the closure contract.

Do not put `ready-for-agent` on a child whose prerequisites are still open.
`br ready --json` and `bv --robot-triage` should agree with the ready label.

## Dispatch Check

Before launching workers:

```bash
br dep cycles --json
br ready --json
bv --robot-triage
```

Expected:

- No cycles.
- Ready output contains only work that can start now.
- Parents are treated as roll-up contracts unless deliberately scoped as a
  concrete implementation bead.
