# Failure Modes: Bead Plans That Look Good But Fail

## 1. Checklist sludge

Symptoms:

- Many tiny beads, each mapping to one checklist bullet.
- Beads like “add tests,” “wire UI,” “update docs,” “clean up.”
- No child bead is a meaningful product or architecture outcome.

Fix:

- Merge checklist crumbs into PR-sized outcomes.
- Use child beads only when each child can close with a coherent result.

## 2. Mega-beads

Symptoms:

- One bead includes substrate, API, UI, data model, tests, migration, and polish.
- A child bead combines several diff-risk dimensions: new abstraction, new DTO, security/access behavior, runtime routing, response-shape preservation, docs/wrapper parity, and broad harness work.
- Acceptance criteria are broad enough to hide multiple PRs.
- A fresh agent would need to invent its own task split.
- The resulting PR is likely to be thousands of lines even if most of the diff is tests.

Fix:

- Split by dependency order, implementation risk, and reviewable behavior atoms.
- Good atoms include characterization, contract/model, service behavior, one runtime surface, parity/docs, and closeout validation.
- Do not reduce tests to reduce PR size; move the relevant tests with the smaller behavior slice.
- Use a parent closure bead plus child implementation beads.

## 3. Rubric laundering

Symptoms:

- Plan claims “28–30/30” without evidence.
- The bead has nice headings but little implementation truth.
- The rubric is used as decoration rather than as a gate.

Fix:

- Apply hard caps from `QUALITY-RUBRIC.md`.
- Do not score above 24/30 without concrete files, symbols, data contracts, failure modes, and verification commands.

## 4. Validation theater

Symptoms:

- Every bead says only `pnpm build` or `cargo test`.
- Manual smoke is mentioned but not specified.
- No expected output or failure behavior is described.
- The bead says “add tests” without naming the behavior those tests must prove.

Fix:

- Name the behavior to verify first.
- Require targeted behavior/contract/regression tests where appropriate, but do not write the test implementation in the bead.
- Name exact test commands, scripts, curl commands, or browser smoke observations.
- If no test runner exists, require adding a tiny smoke/verification script where practical.
- Manual smoke must include exact steps and expected observations.

## 5. Architecture amnesia

Symptoms:

- The plan ignores existing module seams and invents new abstractions.
- It says “add service” without naming the existing service/plugin/route shape.
- It fails to preserve final decisions from the source plan.
- It names a stale exact file list as if it were guaranteed truth.

Fix:

- Inspect the codebase first.
- Name current anchors/surfaces, contracts, and likely seams.
- Treat files/symbols as starting points for agent search, not as an edit script.
- State final architecture decisions explicitly in parent and child beads.

## 6. Data contract fog

Symptoms:

- API or service beads say “return metadata” or “structured shape” without defining fields.
- UI beads do not name state transitions.
- Error cases are left to the implementing agent.

Fix:

- Include draft request/response types or field lists.
- Define success, partial-success, and failure behavior.
- Include validation and sanitization rules.

## 7. False verticality

Symptoms:

- A “vertical slice” stops before the user-visible outcome.
- UI action and materialized result are separate even though neither is satisfying alone.
- The graph optimizes for layers, not user outcomes.

Fix:

- Collapse adjacent UI/canvas/API work when only the combined slice is meaningful.
- Keep foundation work separate only when it truly unblocks multiple consumers.

## 8. Unsafe parallelism

Symptoms:

- Multiple ready beads touch the same editor, schema, route table, or migration files.
- The graph says “parallelizable” without file ownership notes.

Fix:

- Mark single-owner surfaces.
- Add dependency edges when parallel work would conflict.
- Use file reservations in multi-agent implementation.

## 9. Closure ambiguity

Symptoms:

- Parent bead acceptance criteria do not say when the parent closes.
- Parent bead says “children” but does not name addressable child IDs/titles.
- Child beads do not say what evidence belongs in the close reason.
- Deferred/rejected work disappears.

Fix:

- Parent beads are closure contracts.
- Parents name addressable child beads and intended order.
- Children close with verification evidence.
- Deferred/rejected work is closed or captured with a reason, not deleted.

## 10. Prompt-template overfitting

Symptoms:

- Beads get longer but not clearer.
- Sections repeat the same idea under different headings.
- The bead dictates exact implementation or test mechanics that a competent agent should discover.
- Hook success is mistaken for quality.

Fix:

- Lead with outcome, success criteria, and verification.
- Keep only constraints that change behavior.
- Move reusable rationale to the parent or design doc.
- Use deterministic gates for must-haves and semantic review for taste.

## 11. Polish treadmill and split anxiety

Symptoms:

- Every fresh polish pass finds more details, so the agent keeps reworking the same bead indefinitely.
- The agent wants to split a bead mainly because it is long or test-heavy.
- The agent reacts to `long-child-contract` only by compacting prose, without
  asking whether the length reveals a missing dependency edge or child bead.
- Contract details, failure cases, smoke checks, and anchors get mistaken for separate work items.
- The graph churns without creating new behavior, dependency edges, labels, or implementation order clarity.

Fix:

- Classify each new finding before mutating:
  - Is this needed to implement or verify the same outcome? Keep it inside that bead.
  - Does it create a separate observable product/system truth? Split it or create a follow-up bead.
- For long-child warnings, split-test before prose compaction. If the warning
  reveals a separate behavior, update dependencies, parent order, and
  `ready-for-agent` labels as part of the split.
- Rotate after a bead is strict-clean and fresh review finds only wording or readability changes.
- Use a stop/rotate rule: two fresh passes with no new behavior, test obligation, failure mode, dependency edge, split/merge decision, or label means move to the next bead or graph-level review.
- Preserve comprehensive tests inside the behavior bead they prove. Do not split tests into standalone checklist beads.
