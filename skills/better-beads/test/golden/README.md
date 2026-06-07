# Better Beads golden eval seeds

These seed fixtures exercise the Better Beads routing modes. They are intended
for future golden evals where an agent or CLI runner receives an input prompt
plus graph summary and must produce the expected route, evidence, and next
steps.

Current seeds:

| Input | Expected |
|-------|----------|
| `create-from-plan.input.md` | `create-from-plan.expected.md` |
| `improve-plan-first.input.md` | `improve-plan-first.expected.md` |
| `polish-existing.input.md` | `polish-existing.expected.md` |
| `closeout.input.md` | `closeout.expected.md` |

The `.expected.md` files are intentionally compact. They define the minimum
assertions a future harness should check before it compares exact prose.

## Capturing a new golden

1. Start from the matching `*.input.md` scenario.
2. Run the mode with the current Better Beads instructions and robot surfaces.
3. Capture the observed route, evidence requirements, and next steps.
4. Update the matching `*.expected.md` with structural assertions rather than
   exact wording.
5. If a real run has not happened yet, leave an explicit
   `# TODO: capture from first real run` marker in the expected file.

## Using these fixtures

- Check the recommended mode first.
- Check that required evidence and safety gates are present.
- Allow wording differences when the same structure and constraints are
  preserved.
- Treat missing non-goals, validation, failure behavior, or dependency order as
  a failed eval even if the prose sounds plausible.
