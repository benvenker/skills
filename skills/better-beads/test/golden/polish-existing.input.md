# Golden input: polish an existing graph

## Operator prompt

Audit the current Better Beads graph and repair it before implementation agents
claim more work.

## Graph state

- `.beads` directory: present
- Relevant beads:
  - `bb-101` open: Add routing docs
  - `bb-102` open: Add routing tests
  - `bb-103` in_progress: Wire routing helper
  - `bb-099` closed: Define mode docs
- Dependency cycles: none

## Known concerns

- The open beads may overlap on the same route documentation files.
- `bb-102` depends on output contracts from `bb-103`, but no dependency edge is
  recorded.
- The ready frontier label may be wrong because implementation substrate is
  still in progress.
