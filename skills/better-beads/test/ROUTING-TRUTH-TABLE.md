# Better Beads routing truth table

This table is a golden reference for `scripts/bead_route.sh` and
`better-beads route`. It records the mode selected from graph state, supplied
plan readiness, and explicit operator intent so future changes can be checked
against the current dispatch contract.

## Automatic route decisions

| Case | Graph state | Supplied plan readiness | Cycle state | Recommended mode | Required follow-up |
|------|-------------|-------------------------|-------------|------------------|--------------------|
| A1 | No `.beads` directory | Not checked | Not applicable | `create-from-raw-plan` | Read `MODE-CREATE-FROM-RAW-PLAN.md`; initialize beads only after plan gates pass. |
| A2 | No `.beads` directory | `weak` | Not applicable | `improve-plan-first` | Add missing readiness gates and rerun route with `--plan`. |
| A3 | No `.beads` directory | `structurally_ready` | Not applicable | `create-from-raw-plan` | Review semantics, then create the graph. |
| A4 | `.beads` exists with zero beads | Not checked or `structurally_ready` | `ok` | `create-from-raw-plan` | Create from the ready plan; use improve mode if semantic review finds gaps. |
| A5 | `.beads` exists with zero beads | `weak` | `ok` | `improve-plan-first` | Strengthen the supplied plan before any bead mutation. |
| A6 | All beads are `closed` | Not checked or `structurally_ready` | `ok` | `create-from-raw-plan` | Treat the prior graph as complete; create new work only from a ready plan. |
| A7 | One or more `open`, no `in_progress` | Not checked or `structurally_ready` | `ok` | `polish-existing-graph` | Inspect, repair, and confirm the true ready frontier before dispatch. |
| A8 | One or more `in_progress`, zero `open` | Not checked or `structurally_ready` | `ok` | `closeout` | Reconcile in-progress beads; close, reopen, or block with evidence. |
| A9 | One or more `in_progress` plus one or more `open` | Not checked or `structurally_ready` | `ok` | `polish-existing-graph` | Repair the active graph and consider closeout for completed in-progress beads. |
| A10 | Non-terminal active statuses other than `open` or `in_progress` | Not checked or `structurally_ready` | `ok` | `polish-existing-graph` | Inspect unknown active state before creating or dispatching work. |
| A11 | Any graph state that would otherwise route to create, polish, or closeout | `weak` | Any | `improve-plan-first` | Weak `--plan` is a hard override; do not mutate beads from it. |
| A12 | Existing graph has dependency cycles | Not checked or `structurally_ready` | `cycle_count > 0` | Graph-state mode plus warning | Resolve cycles before implementation dispatch. |
| A13 | Existing graph cycle inspection fails | Not checked or `structurally_ready` | `failed` | Graph-state mode plus warning | Resolve cycle inspection failure before implementation dispatch. |
| A14 | `br list --json` fails, emits malformed JSON, or emits an error envelope | Any | Unknown | No mode; exit `2` | Fail closed; do not treat output as dispatch authority. |

## Operator intent routing

The route helper only infers from graph state and optional plan readiness.
Operator instructions can still choose a mode directly when they are more
specific than automatic routing.

| Operator prompt shape | Graph state | Mode to use | Notes |
|-----------------------|-------------|-------------|-------|
| "Turn this raw plan into beads" | No relevant active graph and plan is ready | `create-from-raw-plan` | First verify the seven readiness gates and absence of duplicates. |
| "This plan is vague; make it bead-ready" | Any | `improve-plan-first` | Stay in plan space; do not mutate beads. |
| "Audit/repair this existing bead graph" | Relevant active graph exists | `polish-existing-graph` | Inspect with `br --json` and `bv --robot-*` before mutation. |
| "Close/reopen/block completed implementation work" | Relevant `in_progress` beads exist | `closeout` | Make status truthful and include closure evidence. |
| Direct question or documentation request unrelated to bead mutation | Any | No routing mutation | Answer the request; do not create, update, or close beads only because a graph exists. |

## Plan readiness gates

`--plan PATH` performs a shallow structural check for the create-mode gates.
The semantic review still belongs to the operator.

| Gate | Required signal |
|------|-----------------|
| Outcome | Concrete behavior or system truth that should become true. |
| Anchors | Files, commands, contracts, state transitions, or surfaces that ground the work. |
| Validation | Tests, smoke checks, contract checks, or manual verification. |
| Failure behavior | Invalid input, missing state, fallback, no-op, blocked, or fail-closed behavior. |
| Non-goals | Adjacent behavior, redesign, cleanup, or compatibility work excluded from scope. |
| Parent/child shape | Parents as closure contracts and children as independently verifiable behaviors. |
| Dependency order | Substrate before dependents and serialized single-owner surfaces. |

## Golden fixture map

The files under `test/golden/` seed future LLM and CLI evals. Each input file
describes a routing scenario and each expected file records the desired mode,
minimum evidence, and output shape.

| Fixture | Expected mode |
|---------|---------------|
| `create-from-plan.input.md` | `create-from-raw-plan` |
| `improve-plan-first.input.md` | `improve-plan-first` |
| `polish-existing.input.md` | `polish-existing-graph` |
| `closeout.input.md` | `closeout` |
