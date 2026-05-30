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
- parent beads without closure contracts or addressable children/order,
- missing referenced smoke scripts,
- `ready-for-agent` labels on beads with unresolved dependencies.

It also reports advisory taste debt:

- prose walls and long lines that render badly in `bv`,
- generic validation only,
- inline commands instead of fenced bash blocks,
- overlong child contracts that need split-testing before prose compaction,
- over-prescriptive test instructions,
- obvious weak phrases like “manual smoke is acceptable” or “or document alternate.”

It is dependency-free Python and safe for hooks.

### 2. Semantic review gate

Use an LLM/human review for judgment calls:

- Is the bead too large?
- Is the graph hiding unresolved architecture decisions?
- Are the validation commands meaningful?
- Does the dependency graph match the product slice?
- Would a fresh agent still have to invent contracts or module seams?

Do not put mandatory network/LLM calls in normal pre-commit hooks. Keep semantic review explicit or CI/advisory.

### 3. Closeout truth gate

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

Emit a human-readable audit report for lane rescue or skill learning:

```bash
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py \
  --label pr-01 \
  --include-closed \
  --report markdown \
  --fail-on never
```

The report summarizes worst beads, recurring failure modes, ready/not-ready verdict, and suggested rewrite order so agents do not need to spelunk raw JSON.

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

The warning is advisory because some high-risk child beads need extra contract
detail. It is still useful because it forces a graph-shape decision before a
prose-polish decision.

## Important limitation

The deterministic gate catches obvious smells. Passing it does **not** prove the bead is good.

A bead can pass the script and still be too large, too fuzzy, or architecturally wrong. Use the semantic review prompt from `AUTHORING-PROMPTS.md` before unleashing a swarm.
