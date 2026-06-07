# Golden expected: polish an existing graph

## Route

- Recommended mode: `polish-existing-graph`
- Reason: a relevant active graph exists with both open and in-progress work.

## Minimum response assertions

- Inspects with `br --json` and `bv --robot-*` before mutation.
- Identifies split, merge, dependency, label, or closure-contract repairs in
  plan space before applying them.
- Treats `bb-103` as substrate for docs/tests if its outputs are required.
- Avoids dispatching implementation agents until dependencies and ready
  frontier labels are truthful.
- Considers closeout only for in-progress beads that are actually complete.

## Harness note

Accept either a concrete mutation plan or a blocked result if the graph cannot
be safely repaired without more information.
