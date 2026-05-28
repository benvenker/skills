# Mental Model

For first-time orientation or nontrivial design work, read `ORIENTATION.md`.
This page is the compact reminder.

Smithers is a render-execute-persist loop. A workflow TSX file renders a graph
from current input plus persisted outputs. The scheduler runs ready nodes,
validates task outputs, persists rows keyed by run/node/iteration, then
re-renders. Normal TypeScript conditionals are therefore the control plane.

Official docs:

- `reference-repos/smithers/docs/how-it-works.mdx`
- `reference-repos/smithers/docs/concepts/unidirectional-dataflow.mdx`
- `reference-repos/smithers/docs/reference/types.mdx`
- `reference-repos/smithers/docs/llms-core.txt`

## Design Consequences

- Stable node ids are infrastructure. Resume, outputs, retry, time travel,
  diffs, and viewer layout all depend on them.
- A task that does not render is absent from the plan. Conditional mounting is
  a graph decision, not just UI syntax.
- Use `ctx.outputMaybe(...)` and `ctx.latest(...)` for render-time control
  flow. Use strict `ctx.output(...)` only when absence is a bug.
- Use `deps` or `needs` when a prompt needs upstream data. Do not make every
  agent rediscover every upstream result.
- Prefer coarse, meaningful task boundaries. A Smithers task is a durable
  context boundary; splitting one logical operation into too many tasks can
  remove useful reasoning context.
- Let Smithers model workflow state. Avoid encoding loops, approvals, sleeps,
  queues, fanout, retries, and branch semantics only in prompts.
- Build schemas first. Zod output schemas are the agent contract, persisted run
  database schema, and inspection surface.

## Authoring Heuristic

If an instruction says "then", "until", "unless", "wait for", "approve",
"retry", "fan out", "merge one at a time", or "run in isolation", first ask
whether a Smithers component should model that behavior structurally.
