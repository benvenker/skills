# Smithers Workflow Authoring References

Read these references progressively. Start with `ORIENTATION.md` for the render
loop, then use the component references to choose concrete JSX before opening
topic-specific docs.

## Official Source Map

Framework truth lives in the local official checkout:

- `reference-repos/smithers/docs/llms-core.txt`: generated core docs bundle.
- `reference-repos/smithers/docs/components/`: one page per JSX component and
  higher-order workflow component.
- `reference-repos/smithers/docs/recipes.mdx`: compact workflow recipes.
- `reference-repos/smithers/docs/examples/`: documented examples.
- `reference-repos/smithers/examples/`: runnable examples.
- `reference-repos/smithers/docs/workflows/`: seeded workflow-pack docs.
- `reference-repos/smithers/docs/runtime/`: run state, render frames, events.
- `reference-repos/smithers/docs/rpc/`: Gateway/RPC surface.
- `reference-repos/smithers/packages/components/src/components/`: component
  props and implementation.
- `reference-repos/smithers/packages/graph/src/types.ts`: `TaskDescriptor`.
- `reference-repos/smithers/packages/engine/`: execution internals.
- `reference-repos/smithers/apps/cli/`: CLI implementation and tests.

## Reference Files

- `ORIENTATION.md`: how Smithers thinks: render, extract, execute, persist,
  re-render, ctx, stable ids, and durable outputs.
- `COMPONENTS.md`: component catalog with docs/source/props pointers.
- `COMPONENT-CHOOSER.md`: route workflow intent to existing components.
- `COMPONENT-EXAMPLES.md`: concrete JSX examples and local exemplars.
- `OPERATORS.md`: reusable workflow-design thinking moves.
- `VERIFICATION-FIRST.md`: source, graph, run-state, and mutation checks.
- `MENTAL-MODEL.md`: compact legacy mental-model notes.
- `PRIMITIVES.md`: compatibility pointer to component-first references.
- `DATA-CONTRACTS.md`: typed state and scheduler contracts.
- `COMPOSITION-PATTERNS.md`: reusable workflow shapes.
- `MUTATION-ISOLATION.md`: shared-write and isolation rules.
- `OPS-DEBUGGING.md`: operational commands.
- `TIME-BANDIT-PATTERNS.md`: local patterns and upgrade ideas.

## Reading Routes

- New to Smithers: `ORIENTATION.md` -> `COMPONENTS.md` ->
  `COMPONENT-EXAMPLES.md`.
- Choosing workflow shape: `COMPONENT-CHOOSER.md` -> `COMPONENTS.md` ->
  relevant official component docs/source.
- Reviewing a workflow: `OPERATORS.md` -> `VERIFICATION-FIRST.md` ->
  `DATA-CONTRACTS.md`.
- Mutating Beads or files: `MUTATION-ISOLATION.md` ->
  `COMPONENT-CHOOSER.md` -> `VERIFICATION-FIRST.md`.
- Debugging a run/viewer: `OPS-DEBUGGING.md` -> `VERIFICATION-FIRST.md` ->
  graph/runtime source.

## Useful Searches

```bash
rg "type TaskProps" reference-repos/smithers/packages/components/src
rg "TaskDescriptor" reference-repos/smithers/packages/graph reference-repos/smithers/docs
rg "parallelGroupId" reference-repos/smithers
rg "ReviewLoop" reference-repos/smithers/docs reference-repos/smithers/packages
rg "MergeQueue" reference-repos/smithers/docs reference-repos/smithers/examples
rg "Worktree" reference-repos/smithers/docs reference-repos/smithers/examples
rg "workflow skills" reference-repos/smithers/apps/cli reference-repos/smithers/docs
```
