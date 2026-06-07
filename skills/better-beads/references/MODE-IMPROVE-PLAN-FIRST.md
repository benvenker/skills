# Mode: improve-plan-first

Strengthen a raw or weak plan before creating beads. This mode does not mutate bead state.

## When to use

- Raw or weak plan that would produce broad surface buckets, checklist buckets, detail buckets, or mega-beads.
- Missing outcome, anchors, validation, failure behavior, non-goals, parent/child shape, or dependency order.
- Implementation agents would need to invent behavior, data contracts, failure handling, or verification.

## Inspection

Stay in plan-space during inspection. Do not create, update, close, or label
beads while deciding whether the plan is strong enough.

Check the raw plan against all seven create-mode readiness gates:

1. **Outcome** — what concrete behavior or system truth should become true?
2. **Anchors** — which current files, commands, docs, contracts, or user-visible surfaces ground the work?
3. **Validation** — which tests, smoke checks, contract checks, or manual verification prove the outcome?
4. **Failure behavior** — what should happen on invalid input, missing data, unsafe state, or tool failure?
5. **Non-goals** — what adjacent behavior, cleanup, compatibility shim, or redesign is out of scope?
6. **Parent/child shape** — are parents closure contracts and children independently verifiable functional behaviors?
7. **Dependency order** — what must land first, and which work can safely run in parallel?

If `.beads` exists, inspect existing work before strengthening the plan so the
proposal does not duplicate or contradict the active graph:

```bash
br list --json
bv --robot-plan
```

If `.beads` does not exist, record that no graph exists and keep the review
plan-only. A missing graph is not permission to create beads from a weak plan.

## Reference reading

Review the plan against these references before revising:

- `references/GOOD-BEAD-EXAMPLES.md` — what strong beads look like.
- `references/FAILURE-MODES.md` — common ways plans look good but fail agents.
- `references/QUALITY-RUBRIC.md` — scoring rubric and hard caps.
- `references/PLAN-REVIEW-EXAMPLE.md` — example critique of a plausible but underpowered plan.

## Actions

1. **Do not mutate** bead state. This mode is plan-space only.
2. **Review** the plan against the references above.
3. **Produce** a revised plan-space graph shape:
   - keep/split/merge/deepen/delete/defer decisions,
   - parents as closure contracts,
   - children as single functional behaviors,
   - validation and failure behavior per child,
   - dependency order and ready frontier.
4. **Classify** the result as `ready-to-create` or `needs-plan-improvement`.

## Gates

Block automatic creation if any child still requires invention of:

- behavior,
- data contracts,
- failure handling, or
- verification.

Also block if parent closure cannot be proved by child outcomes.

## Outputs

- Revised graph proposal (not bead mutations).
- Missing-information list or concrete plan improvements.
- Route recommendation: `create-from-raw-plan` when ready, otherwise continue plan improvement.
