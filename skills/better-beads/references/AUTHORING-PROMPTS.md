# Authoring Prompts

Use this as the executable Better Beads operator-router prompt. It is written for agents that may inspect and mutate Beads state.

## Operator-router prompt

```text
Use better-beads as a workflow operator, not only a quality reference.

First route, then act. Run `scripts/better-beads route --json` to inspect bead
state and get a mode recommendation. Use `br --json` and `bv --robot-*` for
additional inspection. Never run bare `bv`. Use `br` mutations only after the
selected mode permits mutation.

For a fresh agent that needs one stable first packet, run
`scripts/better-beads authoring-triage --json`. It wraps the route result with
graph inspection summary, selected-mode references, optional quickpack path,
mutation eligibility, required gates, and next commands. It is read-only and
must not replace the mode procedure; it tells the agent which mode procedure to
read next.

If a plan or PRD is available, run `scripts/better-beads route --plan PATH --json`.
The route helper performs a shallow readiness-gate check. If
`plan_readiness.status` is `weak`, use `improve-plan-first` before creating or
mutating beads from that plan.

Inspection commands are read-only surfaces. They must not dirty tracked files
such as `.gitignore`, `.beads/issues.jsonl`, or skill docs. If `bv --robot-*`
or another external helper initializes a local cache ignore stanza, stop and
isolate the command in a scratch workspace or make the ignore change explicit
before treating the graph as dispatch-ready.

Determine relevant beads this way:
- If the user gives explicit bead IDs or labels, inspect those first.
- Otherwise inspect the active graph by title, labels, parents, dependencies,
  and the plan/request subject.
- Do not create duplicate beads until existing relevant beads have been ruled out.

Choose exactly one mode:
- `create-from-raw-plan` → `references/MODE-CREATE-FROM-RAW-PLAN.md`
- `improve-plan-first` → `references/MODE-IMPROVE-PLAN-FIRST.md`
- `polish-existing-graph` → `references/MODE-POLISH-EXISTING-GRAPH.md`
- `closeout` → `references/MODE-CLOSEOUT.md`

The route command recommends a mode based on graph state. Override the
recommendation if the user's intent calls for a different mode.
`improve-plan-first` can be chosen either by explicit user intent or by failed
plan-readiness gates in route JSON.

Route JSON has schema `better-beads-route-v1`. `scripts/better-beads route`
delegates to `bead_route.sh`; it preserves the helper output and does not wrap
or stamp the JSON. Treat `graph_state.cycle_inspection: "failed"` or any
`graph_state.inspection_warnings` as dispatch blockers until inspected.

Implementation agents must not use the graph until operator gates pass: relevant
graph inspected, dependencies checked, ready labels verified, parent/child shape
reviewed, `--operator-dispatch` clean, semantic readiness accepted, and closeout
state clean.

Raw-plan mode may auto-create beads after readiness/gates pass. Do not add a
default human approval pause unless the user or repo policy explicitly asks for
one.
```

## Shared inspection commands

Use the commands that fit the local repo and available Beads version. Prefer JSON or robot-readable output.

```bash
scripts/better-beads authoring-triage --json
br list --json
br dep cycles --json
bv --robot-plan
bv --robot-insights
br show <id> --json
```

For label or status scope, use the corresponding `br --json` filters supported by the repo's `br` version. Use `br` without JSON only for explicit mutations.

Every advertised read mode must inherit the same no-mutation contract. When
adding surfaces such as `authoring-triage`, `frontier`, or `semantic-pack`, add
them to `scripts/test_cli_robot_surfaces.sh` so tracked-file drift fails the
robot smoke test.

## Mode procedures

Each mode has a dedicated reference file with When, Actions, Gates, and Outputs:

| Mode | Reference | When |
|------|-----------|------|
| `create-from-raw-plan` | `MODE-CREATE-FROM-RAW-PLAN.md` | No relevant beads exist; raw plan passes readiness gates |
| `improve-plan-first` | `MODE-IMPROVE-PLAN-FIRST.md` | Plan is raw, weak, or would make agents invent behavior |
| `polish-existing-graph` | `MODE-POLISH-EXISTING-GRAPH.md` | Relevant beads exist; need repair before dispatch |
| `closeout` | `MODE-CLOSEOUT.md` | Implementation ending; in_progress beads need truth repair |

Use `scripts/better-beads route --json` to get a mode recommendation based on current graph state.
Use `scripts/better-beads route --plan PATH --json` when checking raw-plan
readiness; weak plans route to `improve-plan-first`.

## Closure evidence prompt

```text
Before ending implementation work, make Beads state truthful automatically.

If validation passed and the bead contract is satisfied, close the bead yourself
unless the user explicitly reserved closure for the operator. Do not leave
completed work in `in_progress`.

Close the bead with:
- what changed;
- exact verification commands run;
- result summary;
- commit SHA or note that changes remain uncommitted;
- any deferred or rejected follow-up captured as another bead.

If the bead is not complete, reopen it with the remaining work or block it with
the exact blocker and evidence.

Then run `bead_closeout_guard.sh` unless explicitly opted out.
```
