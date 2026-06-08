# Plan: Better Beads Smithers Verification Loop

**Date**: 2026-06-08
**Status**: Draft
**Branch**: `codex/smithers-plan-verification`
**Skill path**: `skills/better-beads/`

## Goal

Turn the successful Smithers runtime checkpoint into a useful Better Beads
operator loop:

```text
raw plan or existing graph
  -> deterministic Better Beads inspection
  -> Smithers strict polish recommendation
  -> reviewed graph mutation proposal
  -> dispatch readiness proof
```

The first live run proved that Smithers can render and execute the Better Beads
workflow in this repository. It did not prove the workflow improves an open
graph because the current Beads graph was already fully closed. This plan
creates a small verification lane that deliberately gives Smithers a weak,
open graph and checks whether it returns useful, schema-valid polish.

## Directional Read

Better Beads is already strong at:

- reference-driven bead authoring;
- deterministic routing and quality gates;
- JSON contracts and fake-tool evals;
- BV/BR graph inspection;
- strict dispatch posture for multi-agent swarms;
- packaging a semantic review bundle without making LLM review mandatory.

The next gap is not more prose guidance. The gap is an evidence loop that can
answer:

```text
Did the Better Beads + Smithers polish pass make a graph more dispatchable?
```

Right now the Smithers lane is optional and recommendation-only, which is the
right safety posture. It still needs a stronger harness around three things:

1. live run observability;
2. robust final-result extraction;
3. a realistic open-graph fixture that should produce `needs_mutation`.

## Choices Considered

### Choice A: Verification Harness First

Build a disposable plan/graph fixture, run deterministic gates plus Smithers,
and assert the workflow flags the intentional weaknesses.

This is the recommended path. It tests the product value of Smithers: whether
it finds better graph mutations than deterministic gates alone.

### Choice B: Wrapper UX First

Add `--follow` or `--stream` to `smithers polish-graph` so operators can watch
live task output without opening a second terminal.

This should happen soon, but by itself it only improves comfort. It does not
prove polish quality.

### Choice C: Graph Mutation Apply Path

Let the Smithers result drive `br` mutations automatically.

Do not do this yet. The workflow should remain recommendation-only until the
verification harness proves repeatable, high-signal recommendations and the
result extraction contract is stable.

## Recommended Slice

Implement Choice A, with the minimum Choice B/C substrate required for it to be
pleasant and inspectable:

1. Fix the null `tracks` bug that blocks all-closed or empty-active graphs.
2. Make Smithers final result extraction robust enough to use in tests.
3. Add a disposable weak open-graph fixture and a Smithers verification eval.
4. Add optional live-follow UX after the verification loop is reliable.

## Work Items

### WI-1: Fix Null Tracks Handling

**Outcome**: Better Beads robot surfaces handle `bv --robot-plan` returning
`plan.tracks: null`.

**Why now**: The first live Smithers run found `authoring-triage --json`
crashing on a fully closed graph. This is an ordinary CLI bug, but it also
poisons Smithers input with an avoidable local-inspection error.

**Scope**:

- Update `skills/better-beads/scripts/better-beads`.
- Treat `plan.get("tracks") or []` as the normalized tracks value wherever the
  script computes track counts or iterates tracks.
- Audit `frontier`, `authoring-triage`, and `semantic-pack` paths for the same
  explicit-null assumption.
- Add regression coverage for empty-active or all-closed Beads graphs.

**Validation**:

```bash
skills/better-beads/scripts/better-beads authoring-triage --json
skills/better-beads/scripts/better-beads frontier --json
bash skills/better-beads/scripts/test_cli_robot_surfaces.sh
bash skills/better-beads/evals/run_evals.sh
```

Expected: commands return JSON rather than `TypeError: object of type
'NoneType' has no len()`.

**Existing bead**:

```text
skills-add-authoring-triage-json-entrypoint-aos
```

### WI-2: Stabilize Smithers Result Extraction

**Outcome**: `smithers polish-graph --json` returns the final polish plan when
the Smithers run succeeds.

**Why now**: The live run finished successfully and schema scoring passed, but
`bunx smithers-orchestrator output <run-id> synthesize-polish-plan --json`
returned `null` in this environment. The structured JSON was visible in
`smithers chat`, which means the workflow produced the result but the wrapper
cannot reliably recover it.

**Scope**:

- Keep the workflow recommendation-only.
- Preserve the existing `better-beads-smithers-polish-graph-v1` envelope.
- Inspect Smithers output shapes from:
  - `output <run-id> synthesize-polish-plan --json`;
  - `chat <run-id>`;
  - `inspect <run-id> --format json`;
  - any durable DB/table output that Smithers documents or exposes.
- Extract the final plan only from a schema-valid `polishPlan` object.
- If final extraction fails, return a clear `result_error` and enough commands
  for a human to inspect the run.
- Add fake-bunx tests for direct output, nested output, `null` output, and
  malformed output.

**Validation**:

```bash
bash skills/better-beads/scripts/test_schemas.sh smithers
bash skills/better-beads/evals/run_evals.sh smithers
skills/better-beads/scripts/better-beads smithers polish-graph --json
```

Expected: successful fake runs return `result.verdict`; live runs either return
`result` or a precise extraction error with inspect/chat commands.

### WI-3: Add a Weak Open-Graph Verification Fixture

**Outcome**: Better Beads has a repeatable fixture that tests whether Smithers
can distinguish a dispatchable graph from a graph that needs mutation.

**Fixture shape**:

- One parent epic.
- Three child beads.
- One ready-looking child with missing failure behavior.
- One child with vague validation.
- One dependency ambiguity or shared single-owner surface conflict.
- At least one expected `ready_frontier` item after repair.

**Scope**:

- Add a fixture under `skills/better-beads/test/fixtures/`.
- Add a runner that creates a temporary Beads repo from the fixture.
- Run:

```bash
skills/better-beads/scripts/better-beads route --json
skills/better-beads/scripts/better-beads authoring-triage --json
skills/better-beads/scripts/better-beads gate-loop --operator-dispatch --json
skills/better-beads/scripts/better-beads smithers polish-graph --json
```

- Keep the runner offline by default with fake Smithers/Bun behavior.
- Optionally allow a live run with an explicit flag such as
  `--live-smithers`.

**Expected Smithers result**:

```json
{
  "verdict": "needs_mutation",
  "recommended_mutations": [
    {
      "kind": "update_description"
    }
  ],
  "ready_frontier": []
}
```

The exact mutation list can evolve, but the fixture should fail if Smithers
declares a deliberately weak graph ready.

**Validation**:

```bash
bash skills/better-beads/evals/run_evals.sh smithers
bash skills/better-beads/evals/run_evals.sh
```

Expected: default evals remain offline and deterministic; the new Smithers
fixture catches a too-permissive polish workflow.

### WI-4: Add Optional Live Streaming UX

**Outcome**: Operators can watch a Smithers polish run without opening a second
terminal.

**Scope**:

- Add `--follow` or `--stream` to:

```bash
skills/better-beads/scripts/better-beads smithers polish-graph --json
```

- Print the run id promptly.
- Tail `smithers chat <run-id> --follow` or lifecycle logs while the run is
  active.
- Preserve a machine-readable final JSON envelope. If streaming makes pure JSON
  stdout impossible, use one of these explicit contracts:
  - stream events on stderr, final envelope on stdout; or
  - JSONL events on stdout with a final `type: "final"` envelope.

**Validation**:

```bash
skills/better-beads/scripts/better-beads smithers polish-graph --json --follow
bash skills/better-beads/scripts/test_cli_robot_surfaces.sh
```

Expected: non-follow behavior is unchanged; follow mode exposes progress and
still ends with parseable final output.

**Existing bead**:

```text
skills-add-authoring-triage-json-entrypoint-ryh
```

### WI-5: Document the Operator Decision Policy

**Outcome**: Better Beads docs explain when Smithers is worth running and how
to interpret the result.

**Policy**:

- Deterministic gate errors still block dispatch.
- Smithers `blocked` blocks dispatch unless the only reason is "no open work."
- Smithers `needs_mutation` means mutate or explicitly reject the
  recommendation before dispatch.
- Smithers `ready` is advisory, not authority; human/operator still owns `br`
  mutation and final dispatch.
- Live Smithers runs are not pre-commit hooks.

**Files**:

```text
skills/better-beads/references/SMITHERS-POLISH-GRAPH.md
skills/better-beads/references/MODE-POLISH-EXISTING-GRAPH.md
skills/better-beads/evals/README.md
```

**Validation**:

```bash
rg -n "needs_mutation|--follow|live-smithers|recommendation-only" skills/better-beads/references skills/better-beads/evals
```

Expected: docs make the recommendation-only and dispatch-policy boundaries
obvious.

## Non-goals

- Do not make Smithers required for normal Better Beads use.
- Do not run live Smithers evals in default CI or pre-commit hooks.
- Do not auto-apply Smithers recommendations through `br`.
- Do not mutate real project Beads from evals.
- Do not create a broad Smithers workflow suite before the strict-polish loop is
  proven useful.
- Do not replace deterministic gates with model review.

## Success Criteria

This plan is successful when:

- `authoring-triage --json` and `frontier --json` work on empty-active graphs.
- A live Smithers run can be inspected without relying on messy copied chat
  output.
- The default eval suite includes a Smithers fixture that proves weak graphs are
  not marked ready.
- Operators have a clear command sequence for:

```text
inspect -> polish -> review recommendation -> mutate manually -> re-gate
```

- All default validation remains offline and deterministic.

## Suggested Implementation Order

1. `skills-add-authoring-triage-json-entrypoint-aos` - null tracks bug.
2. Smithers result extraction hardening.
3. Weak open-graph fixture and fake-Smithers eval.
4. `skills-add-authoring-triage-json-entrypoint-ryh` - live streaming UX.
5. Docs policy update.

## Open Questions

- Should live Smithers output use stderr progress plus stdout final JSON, or
  stdout JSONL events?
- Should the weak graph fixture live as a graph-draft JSON, a temporary Beads
  JSONL fixture, or both?
- Should Smithers scores be included in the Better Beads envelope after result
  extraction is stable?
- Should future Smithers workflows cover create-from-raw-plan, or should this
  one strict-polish workflow become excellent first?

