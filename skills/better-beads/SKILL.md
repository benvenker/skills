---
name: better-beads
description: "Write, review, and polish better Beads task graphs. Use when converting plans/PRDs into beads, reviewing bead quality, fixing bad bead graphs, or preparing beads for multi-agent implementation. This skill is reference-driven: read the examples and failure modes before authoring."
---

# Better Beads

A bead is a **behavioral execution contract for a fungible coding agent**.

Lead with intent: what outcome should become true, what success looks like, what must not happen, and how the behavior will be verified. Do not turn beads into implementation scripts or long compliance documents.

## Strong Agent Question Test

Before calling a bead ready, ask:

> If I handed this to a stronger coding agent, would it need to ask a product or architecture question before coding?

Tactical discovery questions are fine:

- Where did this module move?
- What is the current test filename?
- Which helper does the repo already use?

Blocking specification questions mean the bead is not ready:

- What behavior should this have?
- What counts as success?
- Should this mutate state?
- What error should the user see?
- Is this in scope or not?
- How do I prove it?

A ready bead answers those blocking questions with outcome, success criteria, verification, non-goals, failure behavior, and current anchors/surfaces.

Do not optimize for “lots of granular beads.” Optimize for a clean PR-shaped dependency graph with execution packets that a fresh agent can implement without the original chat, PRD, or plan.

Also optimize for **reviewable atomicity**. A bead should be small enough that the implementing PR or commit can be reviewed in one sitting without hiding behavior changes in a giant diff. Never reduce test coverage to make a bead smaller; split the behavior so each smaller bead carries the tests that prove its contract.

## Required reference reading

Before creating or polishing beads, read:

1. `references/README.md`
2. `references/GOOD-BEAD-EXAMPLES.md`
3. `references/FAILURE-MODES.md`
4. `references/QUALITY-RUBRIC.md`
5. `references/BEAD-FORMATTING.md`

Use `references/AUTHORING-PROMPTS.md` for copy-pasteable prompts.
Use `references/PLAN-REVIEW-EXAMPLE.md` when reviewing a plausible but underpowered plan.
Use `references/POLISHING-CASE-STUDIES.md` when repeated polish or quality-gate warnings might require graph changes instead of wording changes.
Use `references/QUALITY-GATES.md`, `scripts/bead_gate_loop.sh`, and `scripts/bead_quality_gate.py` to gate bead quality in hooks, CI, audits, or agent rerun loops. For lane rescue, generate a report with `bead_quality_gate.py --label <lane> --include-closed --report markdown --fail-on never`.
Use `scripts/bead_closeout_guard.sh` at the end of implementation swarms,
operator ticks, or hooks so completed work cannot silently remain
`in_progress`.

## Core operating rules

- Use `br` for bead mutations.
- Use `br --json` and `bv --robot-*` for inspection.
- Never run bare `bv`.
- Do not create GitHub issues unless explicitly requested.
- Parent beads are closure contracts; do not close a parent until children are closed or explicitly closed as unnecessary with evidence.
- Do not create one bead per checklist bullet.
- Do not create vague sweep beads like “add tests,” “clean up,” or “polish UX.”
- Prefer behavior-first wording: outcome, success criteria, verification, non-goals, failure behavior.
- Use TDD intent: require behavior/contract/regression tests where appropriate, but do not write the tests inside the bead.
- Give agents starting anchors and known surfaces, not brittle edit scripts. Exact files/symbols are useful when known, but agents must verify current owners before editing.
- If a bead spans multiple independent levers, split it.
- If adjacent beads are not meaningful outcomes alone, merge them into a vertical slice.
- Split large work by reviewable behavior atoms: characterization, data/DTO contract, service behavior, one runtime route/surface, parity/docs, or final closeout.
- Do not shrink beads by saying “write fewer tests.” Keep the test intent and split the behavior under test.
- Preserve final product and architecture decisions; discard dead intermediate debate.

## Automatic implementation closeout

Bead state must converge automatically with implementation reality. A finished
implementation pane should not leave the operator to remember bookkeeping.

- Dispatch prompts for implementation agents should permit the agent to close
  its assigned bead after validation succeeds, unless the user explicitly
  requires operator-only closure.
- If agents are told not to close beads, the operator prompt must include a
  mandatory closeout sweep before ending the turn.
- Close completed beads with evidence: behavior changed, validation commands and
  results, commit SHA or note that changes remain uncommitted, and deferred
  follow-ups.
- Do not leave a bead `in_progress` as a parking state. If work stopped without
  meeting the closure contract, reopen it with a reason or mark it blocked with
  the exact blocker.
- Run `scripts/bead_closeout_guard.sh` after a swarm/operator pass. It should
  fail the closeout if any unexpected `in_progress` beads remain.
- If a parent closure depends on children, close/reopen the child truth first;
  then let the parent reflect the child graph.

## Polishing loop discipline

Repeated polish rounds should improve the execution graph, not endlessly reword one bead.

- Treat new findings as one of two things:
  - **Contract detail** for the same outcome: add it to success criteria, failure behavior, validation, anchors, or non-goals.
  - **New independent behavior**: create or split into a bead only when it has its own observable outcome and reviewable PR/commit.
- Do not split because a bead became detailed. Split because two implementation outcomes can land, be reviewed, and be verified independently.
- When `long-child-contract` or a similar size warning fires, run the split
  test before compacting prose. If the length is caused by a separate observable
  behavior, create/split the bead and update dependencies, parent order, and
  `ready-for-agent` labels.
- Once a bead is strict-clean and fresh review finds only wording/readability changes, rotate to adjacent beads or graph-level review.
- Stop or rotate after two fresh passes that produce no new behavior, tests, failure cases, dependency edges, split/merge decisions, or labels.
- Keep the true frontier clear: polish blocked follow-ups, but reserve `ready-for-agent` for beads whose prerequisites and contracts are settled.

## Reviewability budget

Use this as a taste gate during creation and polish. Consider splitting a child bead when it combines two or more high-diff-risk dimensions:

- new abstraction or module,
- new data contract, DTO, or fixture harness,
- access/security/fail-closed behavior,
- runtime routing or public surface wiring,
- response-shape/backward-compatibility preservation,
- docs, inventory, wrapper, or generated parity,
- broad test-harness creation.

A good split is not “one bead per checklist item.” Each split child must still close with a meaningful behavior/system truth. Prefer sequences like:

1. characterize current behavior,
2. define/model the contract,
3. implement the service behavior,
4. route one public/runtime surface,
5. close parity and final validation.

## Non-negotiable quality gate

A bead must make the targeted behavior and verification path clear. Nice headings are not enough.

Hard failures should be reserved for true invariants:

- missing outcome/goal,
- missing success criteria or observable acceptance behavior,
- missing validation/verification path,
- missing scope boundary or non-goals,
- missing failure behavior for implementation beads,
- missing grounding in current surfaces, contracts, anchors, or key fields,
- parent beads without a closure contract and addressable children/order.

Everything else is taste debt: exact file lists, length, prose walls, section count, generic-but-present validation, and formatting should usually warn, not block normal commits.

A bead with correct content but long prose walls is not finished either. It must be readable in `bv`, `br show`, tmux panes, and narrow agent terminals.

## Minimal graph validation

After creation or mutation, run:

```bash
br dep cycles --json
bv --robot-insights
bv --robot-plan
.agents/skills/better-beads/scripts/bead_gate_loop.sh --changed-staged
.agents/skills/better-beads/scripts/bead_closeout_guard.sh
```

Use `--strict` for dedicated bead-polish passes, new-graph review, or when a repo explicitly wants warnings to block.

Check that:

- cycles are empty,
- ready beads are genuinely ready and `ready-for-agent` labels are only on the actual frontier,
- shared substrate lands before dependent vertical work,
- single-owner surfaces are called out,
- parallel tracks will not fight over the same files,
- each child bead is reviewable without weakening tests or creating checklist sludge.
- no completed or abandoned implementation bead is stuck in `in_progress`.

## Fast authoring prompt

```text
Use better-beads. Read the references first, especially
GOOD-BEAD-EXAMPLES.md, FAILURE-MODES.md, and QUALITY-RUBRIC.md.

Create or polish Beads as behavioral execution contracts for fungible coding agents.
Do not merely make the graph comprehensive and granular. Design a PR-shaped
implementation graph with reviewable atomic child beads. Lead with outcome,
success criteria, verification, non-goals, and failure behavior. Do not reduce
test coverage to reduce PR size; split behavior so each bead owns the tests that
prove its contract.

Inspect enough codebase context to provide current anchors: user-visible surfaces,
API/data contracts, key fields/state transitions, likely files or existing patterns,
and validation commands. Do not turn those anchors into brittle edit scripts; agents
should still verify current owners before editing.

Format bead descriptions for BV readability: short sections, bullets instead of
long paragraphs, fenced commands where helpful, grouped anchors/surfaces, and compact contracts.

Use br for mutations and br --json / bv --robot-* for inspection. Validate with
br dep cycles --json, bv --robot-insights, and bv --robot-plan.

For implementation dispatch, make closeout automatic: the owning agent should
close its bead with evidence after validation passes. If closure is reserved for
the operator, run a mandatory closeout sweep and `bead_closeout_guard.sh` before
ending the turn; close completed beads and reopen or block incomplete ones.
```
