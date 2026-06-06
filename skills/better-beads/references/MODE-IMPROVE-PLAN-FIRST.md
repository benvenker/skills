# Mode: improve-plan-first

Strengthen a raw or weak plan before creating beads. This mode does not mutate bead state.

## When to use

- Raw or weak plan that would produce broad surface buckets, checklist buckets, detail buckets, or mega-beads.
- Missing outcome, anchors, validation, failure behavior, non-goals, parent/child shape, or dependency order.
- Implementation agents would need to invent behavior, data contracts, failure handling, or verification.

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
