# Bead Quality Gates

Prompts alone are not enough. Use gates to catch bad Beads before they become committed project state.

## Gate layers

### 1. Deterministic lint gate

Low-level script:

```bash
.agents/skills/better-beads/scripts/bead_quality_gate.py
```

Shell orchestrator loop:

```bash
.agents/skills/better-beads/scripts/bead_gate_loop.sh
```

The shell loop follows the same pattern as `swarm lint`: shell owns orchestration, Python owns deterministic checks, artifacts are written to a temp directory, and failures produce a concrete “fix this and rerun” prompt.

This catches hard contract failures:

- missing outcome/goal,
- required sections that exist but are too thin to answer the contract question,
- missing observable success criteria,
- missing scope boundary / non-goals,
- missing validation or verification detail,
- missing failure behavior on implementation beads,
- missing grounding in current anchors/surfaces/contracts/key fields,
- parent beads without closure contracts or addressable children/order.

It also reports advisory taste debt and graph-frontier warnings:

- missing referenced smoke scripts unless the bead explicitly says creating the script is in scope,
- `ready-for-agent` labels on beads with unresolved dependencies in normal lint mode,
- prose walls and long lines that render badly in `bv`,
- generic validation only,
- inline commands instead of fenced bash blocks,
- overlong child contracts that need split-testing before prose compaction,
- over-prescriptive test instructions,
- obvious weak phrases like “manual smoke is acceptable” or “or document alternate.”

It is dependency-free Python and safe for hooks.

### 2. Operator dispatch gate

Use this before implementation agents consume a new or polished graph:

```bash
.agents/skills/better-beads/scripts/bead_gate_loop.sh --operator-dispatch
```

This is stricter than the normal pre-commit hook. It checks all active beads by default, collects `br dep cycles --json`, `bv --robot-plan`, `bv --robot-insights`, deterministic findings, a dispatch verdict, and a split-review artifact when needed.

Dispatch is blocked when:

- inspection tooling exits nonzero,
- inspection tooling emits malformed JSON,
- inspection tooling emits valid JSON with the wrong top-level shape, such as an array instead of an object,
- inspection tooling exits zero but emits a top-level JSON error envelope such as `{ "error": "..." }`,
- dependency cycles are non-empty,
- deterministic errors remain, including `ready-label-blocked` in operator-dispatch mode,
- any deterministic finding is marked `operator_blocking`,
- split-review findings remain.

In operator-dispatch mode, structural child findings that are advisory in hook mode become dispatch blockers:

- `long-child-contract`,
- `too-many-child-sections`,
- `large-child`.

Those structural findings do not prove the bead is semantically wrong. They hard-trigger a split-review flow before implementation dispatch. By contrast, `ready-label-blocked` is an operator-dispatch blocker but not a split-review finding; remove the premature `ready-for-agent` label or close/reorder the unresolved dependency first.

Accepted split-review outcomes:

- keep one child with evidence that every section supports the same functional behavior;
- split into child beads and update dependencies, parent order, and labels;
- convert a broad bucket into a parent/epic closure contract;
- merge checklist crumbs into one functional behavior bead;
- defer, delete, or close unnecessary work with evidence.

### 3. Semantic review gate

Use an LLM/human review for judgment calls:

- Is the bead too large?
- Is the graph hiding unresolved architecture decisions?
- Are the validation commands meaningful?
- Does the dependency graph match the product slice?
- Would a fresh agent still have to invent contracts or module seams?

Do not put mandatory network/LLM calls in normal pre-commit hooks. Keep semantic review explicit or CI/advisory.

### 4. Closeout truth gate

Implementation and swarm runs need a different guard: make sure no completed or
abandoned work remains parked in `in_progress`.

```bash
.agents/skills/better-beads/scripts/bead_closeout_guard.sh
```

Run it after implementation panes finish, in operator closeout loops, or as a
local hook before reporting a swarm as done. The guard is intentionally not a
blind auto-close mechanism. It fails loudly and tells the operator to make each
bead truthful:

- close completed work with evidence,
- reopen incomplete work that can continue later,
- mark genuinely blocked work as blocked with the exact blocker.

## Recommended commands

Lint all active beads:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py
```

Run the full shell gate on staged bead changes. Default recommendation for normal pre-commit is error-only: block true contract failures, not every taste warning.

```bash
.agents/skills/better-beads/scripts/bead_gate_loop.sh --changed-staged
```

Dedicated polish pass or new-graph review:

```bash
.agents/skills/better-beads/scripts/bead_gate_loop.sh --changed-staged --strict
```

Pre-implementation operator dispatch over the active graph:

```bash
.agents/skills/better-beads/scripts/bead_gate_loop.sh --operator-dispatch
```

Use `--operator-dispatch`, not a staged hook check, before handing beads to implementation agents.

Lint only staged bead changes with the low-level Python helper:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py \
  --changed-only --staged --fail-on error
```

Fail on warnings too, useful for a dedicated polish pass. `--strict` is an alias for `--fail-on warning`:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py \
  --changed-only --staged --strict
```

Lint one bead:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py \
  --id <bead-id>
```

Emit JSON for agent/CI parsing:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py \
  --changed-only --staged --json
```

Run deterministic gate tests after changing gate behavior:

```bash
python3 .agents/skills/better-beads/scripts/test_bead_quality_gate.py
bash .agents/skills/better-beads/scripts/test_bead_gate_loop.sh
```

Emit a human-readable audit report for lane rescue or skill learning:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py \
  --label pr-01 \
  --include-closed \
  --report markdown \
  --fail-on never
```

The report summarizes worst beads, recurring failure modes, ready/not-ready verdict, split-review requirements, and suggested rewrite order so agents do not need to spelunk raw JSON.

Check for forgotten in-progress beads after implementation:

```bash
.agents/skills/better-beads/scripts/bead_closeout_guard.sh
```

Allow a known still-running bead while failing any other stale in-progress work:

```bash
.agents/skills/better-beads/scripts/bead_closeout_guard.sh --allow bd-123
```

## Pre-commit hook example

Use this after `br sync --flush-only` and after staging `.beads/`.

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -d .beads ] && [ -x .agents/skills/better-beads/scripts/bead_gate_loop.sh ]; then
  .agents/skills/better-beads/scripts/bead_gate_loop.sh --changed-staged
fi
```

## Closeout hook example

Use this in swarm/operator closeout scripts, or as a local pre-push guard when a
repo wants to prevent forgotten in-progress beads from leaving the machine.

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -d .beads ] && [ -x .agents/skills/better-beads/scripts/bead_closeout_guard.sh ]; then
  .agents/skills/better-beads/scripts/bead_closeout_guard.sh
fi
```

## Policy recommendation

For normal pre-commit hooks, use error-only mode:

```bash
bead_gate_loop.sh --changed-staged
```

For deliberate bead-polish work, new graph review, or CI advisory jobs, use strict mode:

```bash
bead_gate_loop.sh --changed-staged --strict
```

For implementation dispatch, use the operator gate:

```bash
bead_gate_loop.sh --operator-dispatch
```

The operator gate writes:

- `bead-quality-gate.json` for deterministic findings,
- `br-dep-cycles.json` for dependency cycle inspection,
- `bv-robot-plan.json` and `bv-robot-insights.json`,
- `split-review-required.md` when oversized/detail-heavy children need classification,
- `dispatch-verdict.json` with `dispatch_allowed`, blocked reasons, `parse_failures`, `schema_failures`, `operator_blocking_count`, and `inspection_error_envelopes` for rc-0 JSON inspection errors.

For small/new repos where the graph is intentionally kept clean, consider `--all --strict` as an explicit project choice, not the default.

## Long-child warning triage

When `long-child-contract` fires, do not immediately shorten the bead. First
run the semantic split test:

- If the length comes from an independently observable behavior, failure
  contract, data contract, runtime surface, or dependency edge, split/create a
  bead and update parent ordering, dependency edges, and `ready-for-agent`
  labels.
- If the length comes from repeated rationale, long inline lists, or overlapping
  sections for the same outcome, compact for BV readability.

The warning is advisory in normal hook mode because some high-risk child beads need extra contract detail. In `--operator-dispatch` mode it blocks dispatch and writes a split-review artifact because implementation agents should not receive unresolved mega-beads, broad surface buckets, or detail buckets.

## Important limitation

The deterministic gate catches obvious smells. Passing it does **not** prove the bead is good.

A bead can pass the script and still be too large, too fuzzy, or architecturally wrong. Use `--operator-dispatch` plus the semantic review prompt from `SEMANTIC-GATE.md` before unleashing a swarm.
