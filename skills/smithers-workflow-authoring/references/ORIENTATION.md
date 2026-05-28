# Orientation

Smithers is not a task runner with JSX syntax. It is a React reconciler whose
host elements are workflow components. A render emits a workflow plan, the
runtime extracts ready tasks, executes them, persists validated outputs, and
renders again from persisted state.

Official source:

- `reference-repos/smithers/docs/how-it-works.mdx`
- `reference-repos/smithers/docs/concepts/workflows-overview.mdx`
- `reference-repos/smithers/docs/concepts/execution-model.mdx`
- `reference-repos/smithers/docs/concepts/unidirectional-dataflow.mdx`
- `reference-repos/smithers/docs/concepts/workflow-state.mdx`
- `reference-repos/smithers/docs/concepts/reactivity.mdx`
- `reference-repos/smithers/docs/concepts/control-flow.mdx`
- `reference-repos/smithers/docs/concepts/data-model.mdx`
- `reference-repos/smithers/docs/concepts/human-in-the-loop.mdx`
- `reference-repos/smithers/docs/concepts/approvals.mdx`
- `reference-repos/smithers/docs/concepts/suspend-and-resume.mdx`
- `reference-repos/smithers/docs/concepts/caching.mdx`
- `reference-repos/smithers/docs/concepts/time-travel.mdx`
- `reference-repos/smithers/docs/concepts/evals.mdx`
- `reference-repos/smithers/docs/concepts/memory.mdx`
- `reference-repos/smithers/docs/concepts/agents-and-tools.mdx`

## The Loop

1. Render: Smithers calls the workflow builder and reconciles returned JSX.
2. Extract: host components become a `GraphSnapshot` of `TaskDescriptor`s.
3. Schedule: ready tasks are selected from deps, branches, loops, approvals,
   and concurrency caps.
4. Execute: task mode is agent, compute, static, wait, approval, sandbox, etc.
5. Persist: validated outputs and internal events are written to SQLite.
6. Re-render: `ctx` now sees persisted outputs and derives the next plan.

The frame is the unit of progress. Time travel, hot reload, run inspection, and
resume all reason about frame snapshots.

## Durable State

Durable state is task output, keyed by run id, node id, and iteration. React
state, refs, and memoized values are process-local rendering conveniences.
Anything a workflow must remember across crashes, restarts, replay, or
downstream branches belongs in a schema-backed task output.

```tsx
const analysis = ctx.outputMaybe(outputs.analysis, { nodeId: "analyze" });

return (
  <Workflow name="audit">
    <Task id="analyze" output={outputs.analysis} agent={analyst}>
      Inspect the target and return structured facts.
    </Task>
    {analysis ? (
      <Task id="recommend" output={outputs.recommendation} deps={{ analysis }}>
        {({ analysis }) => `Recommend next action from ${analysis.summary}`}
      </Task>
    ) : null}
  </Workflow>
);
```

Conditional mounting is control flow. A task that does not render is not part
of the plan for that frame.

## `ctx` Routing

- `ctx.input`: immutable run input.
- `ctx.outputMaybe(schema, { nodeId })`: nullable read for render-time routing.
- `ctx.output(schema, { nodeId })`: strict read when absence is a bug.
- `ctx.latest(schema, nodeId)`: latest loop iteration output.
- `ctx.iterationCount(schema, nodeId)`: completed loop count.
- `ctx.runId`, `ctx.iteration`, `ctx.auth`: identifiers and auth context.

Use `ctx` to route the graph. Do not ask an agent to rediscover state Smithers
already persisted.

## Task Modes

`<Task>` can be:

- Agent: children become a prompt, output is validated against Zod.
- Compute: children is a function executed by the runtime.
- Static: children is a literal persisted directly.

Agent validation failures feed repair attempts. Agents can also be fallback
chains. Always inspect `TaskProps.ts` before relying on advanced task behavior.

## IDs, Resume, And Time Travel

Completed tasks are not re-executed on resume. A changed node id looks like a
new task. Derive ids from durable data, not array indices, timestamps, random
values, prompt text, or mutable labels.

```tsx
{tickets.map((ticket) => (
  <TicketLane key={ticket.id} id={`ticket:${ticket.id}`} ticket={ticket} />
))}
```

The same rule powers output lookup, retries, replay, fork, diff, and viewer
navigation.

## Approvals And Human Work

`needsApproval` gates a task before execution. `<Approval>` is a decision node
that persists a typed decision row. Branch on the decision output after render:

```tsx
<Approval id="ship-decision" output={outputs.shipDecision} request={request} />
{ctx.outputMaybe(outputs.shipDecision, { nodeId: "ship-decision" })?.approved
  ? <Task id="ship" output={outputs.ship}>Ship it.</Task>
  : <Task id="hold" output={outputs.hold}>Hold release.</Task>}
```

Use `<HumanTask>` when the human must submit structured JSON, not just approve
or deny.

## Caching, Memory, And Evals

- Cache pure expensive tasks with explicit invalidation. Do not cache side
  effects.
- Memory is cross-run state. It is not transactional state for a run.
- Scorers/evals are post-completion observability unless a workflow explicitly
  persists their results into later control flow.

## Orientation Gotchas

- Component structure, not prompt prose, defines scheduling semantics.
- `Parallel` makes independence explicit but does not make shared writes safe.
- `Loop` writes iterations; use `ctx.latest` and stable ids.
- `Branch` and conditional rendering are not identical. Use the documented
  component when you need explicit branch semantics in descriptors.
- Viewer/devtool work should read graph descriptors and official types, not
  infer meaning from task labels.
