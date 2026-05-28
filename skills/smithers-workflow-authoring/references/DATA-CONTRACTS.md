# Data Contracts

Smithers workflows are easier to operate when outputs and dependencies are
treated as durable contracts, not prompt decoration.

Official source:

- `reference-repos/smithers/docs/components/task.mdx`
- `reference-repos/smithers/docs/reference/types.mdx`
- `reference-repos/smithers/packages/components/src/components/TaskProps.ts`
- `reference-repos/smithers/packages/graph/src/types.ts`
- `reference-repos/smithers/packages/db/src/zodToTable.js`

## Outputs

- `createSmithers({ ...schemas })` turns Zod schemas into typed output targets
  and SQLite/Drizzle tables.
- Output rows include standard keys such as `runId`, `nodeId`, and `iteration`.
- Agent JSON must match the declared schema. Structured-output repair is
  separate from task retry policy.
- Schema changes are migration decisions. Added columns can be safe; type
  changes or removals need care.

## Dependencies

- `dependsOn`: scheduling dependency by node id.
- `needs`: alias-to-node dependency wiring.
- `deps`: typed render-time dependency values passed into function children.
- `ctx.outputMaybe(...)`: nullable read for graph rendering.
- `ctx.output(...)`: strict read when absence is a bug.
- `ctx.latest(...)`: latest output for loop-style tasks.

Use `deps`/`needs` when a task consumes upstream data. Avoid making downstream
agents re-run inspection just to recover information Smithers already stored.

## TaskDescriptor

`TaskDescriptor` is the runtime contract extracted from JSX. It includes:

- node id, ordinal, iteration;
- dependencies and needs;
- worktree path/branch;
- output table/schema;
- parallel group id and concurrency;
- approval/waiting fields;
- skip/retry/timeout/heartbeat/cache policy;
- agent, prompt, static payload, compute function;
- label, metadata, scorers, memory config.

Viewer and tooling work should prefer descriptor fields over parsing node ids
or labels.

## Retries, Cache, Tools, Scorers, Memory

- Retry defaults may be active for agent tasks. Specify retry policy
  deliberately for side effects.
- Cache keys include workflow context and upstream needs; version cache policy
  when semantics change.
- Tool allowlists are workflow safety boundaries. Match tools to role.
- Custom side-effect tools should declare side-effect/idempotency metadata and
  use runtime idempotency keys.
- Scorers are useful for evaluation/observability after task completion; do
  not rely on them as critical control-flow outputs.
- Smithers memory is cross-run state. Use persisted run outputs for
  transactional workflow state.
