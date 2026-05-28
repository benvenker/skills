# Composition Patterns

Use patterns as starting points, not universal best practices. Check the
official component docs when adapting them.

## Fanout / Fanin

Shape:

```tsx
<Sequence>
  <Task id="split" output={outputs.split} agent={splitter}>...</Task>
  {split ? (
    <Parallel maxConcurrency={5}>
      {split.items.map((item) => (
        <Task key={item.id} id={`process-${item.id}`} output={outputs.process} agent={worker}>...</Task>
      ))}
    </Parallel>
  ) : null}
  <Task id="merge" output={outputs.merge} agent={merger}>...</Task>
</Sequence>
```

Use for independent analysis, file groups, feature groups, or model review.
Reference: `reference-repos/smithers/examples/fan-out-fan-in.jsx`.

Authoring and viewer expectations:

- A `Parallel` followed by the next sibling task is a fanout/fanin shape. Do
  not describe that downstream task as merely "next" for only one branch.
- Every branch that exits to the same downstream task should be rendered as one
  shared merge/fanin connector.
- Use `MergeQueue` only when the downstream work itself must be concurrency
  capped or serialized, such as shared `br` writes or branch merges. A normal
  synthesis task after `Parallel` is enough for read-only reviewer fanin.
- If the visual graph makes branches look like they have different routing
  semantics, fix the structure or viewer before running model-backed work.

## Review / Validation Loop

Use `Loop` or `ReviewLoop` where `until` reads a strict persisted boolean.

Good loop exits:

- all tests passing;
- every required reviewer approved;
- strict gate passed;
- no remaining high-severity findings.

Avoid vague exits like "until it looks good".

## Scan / Fix / Verify

Use `ScanFixVerify` or an explicit `Loop` when scanner, fixer, and verifier
roles are distinct. Keep verifier outputs boolean enough to drive `until`.

## Read-Only Gather -> Synthesis -> Controlled Mutation

Use this when many agents can inspect safely but mutation must be centralized:

```tsx
<Sequence>
  <GatherAndSynthesize ... />
  <Approval ... />         {/* optional */}
  <MergeQueue maxConcurrency={1}>
    <Task id="mutate" ... />
  </MergeQueue>
</Sequence>
```

This is the preferred shape for broad Beads graph analysis before `br` writes.

## Branch-Routed Risk Ladder

Use `Branch` or `DecisionTable` to route work into inspect-only,
approval-required, or safe-mutation branches. Do not bury risk policy only in a
prompt.

## Human Checkpoints

Use durable `Approval` for high-risk branch points: broad mutation, merge,
ready-for-agent frontier changes, external side effects, or ambiguous
architecture decisions.

## Subflows

Use `Subflow` when a reusable workflow is already a complete unit. Prefer this
over copy-pasting its internals unless the parent needs to inspect every child
task as part of the same graph.
