# Golden expected: create from a ready plan

## Route

- Recommended mode: `create-from-raw-plan`
- Reason: no relevant beads exist and the supplied plan contains all seven
  readiness gate signals.

## Minimum response assertions

- Mentions inspection for existing duplicates before creating beads.
- Proposes a parent closure contract plus independently verifiable child beads.
- Preserves the validation, failure behavior, non-goals, and dependency order
  from the input plan.
- Does not route to `improve-plan-first` unless semantic review identifies a
  concrete missing gate.
- Does not mutate beads before the readiness gates are checked.

## Harness note

Exact bead titles may vary. Compare mode, graph shape, gate coverage, and
dependency ordering before comparing prose.
