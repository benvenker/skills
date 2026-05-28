# Operators

Operators are repeatable thinking moves for Smithers workflow design. Use them
as review lenses before editing a workflow and before running model-backed
tasks.

## Component-First

Definition: Express workflow semantics with existing Smithers components before
custom task choreography.

Use when: a prompt says "loop," "review," "approve," "fan out," "ticket
board," "merge," "sandbox," "wait," or "route."

Prompt module: "Which Smithers component already represents this shape, and
what docs/source prove its props and behavior?"

Failure modes: hand-rolled loops, hidden approvals in prose, custom fanout that
loses concurrency metadata, reinvented Kanban.

## Render-Trace

Definition: Trace what each render sees, what it mounts, and what output will
cause the next render to change.

Use when: a workflow uses `ctx.outputMaybe`, `ctx.latest`, conditional JSX,
loops, branches, or approvals.

Prompt module: "After this task persists, what new component appears on the
next frame?"

Failure modes: downstream tasks that never mount, tasks that mount too early,
branch conditions based on non-durable state.

## ID-Stabilize

Definition: Verify every task/component id is derived from durable input or
persisted data.

Use when: mapping arrays, tickets, files, Beads, features, reviewers, or loop
iterations.

Prompt module: "Would this id be identical after crash/resume, hot reload, and
the same input?"

Failure modes: ids based on index, timestamp, random values, display labels, or
current ordering.

## Schema-First

Definition: Design the Zod output row before writing prompts.

Use when: downstream tasks inspect an upstream result or a human/operator will
review run state.

Prompt module: "What exact fields must future render frames and agents read?"

Failure modes: giant strings, missing approval booleans, no issue ids, no
actionable severity, schema drift treated as a prompt problem.

## State-Route

Definition: Choose the correct state read: `outputMaybe`, `output`, `latest`,
`iterationCount`, deps, or needs.

Use when: a task depends on upstream data or a loop needs previous output.

Prompt module: "Is this value a nullable render signal, a guaranteed
dependency, or the latest loop iteration?"

Failure modes: agents re-reading files to recover stored state, strict reads
before outputs exist, stale loop values.

## Control-Flow-Lift

Definition: Lift scheduling semantics out of prompt text into JSX components.

Use when: an agent prompt includes sequencing, parallelism, branching, retries,
approvals, waits, or fanin/fanout.

Prompt module: "Which parts of this sentence are actually graph structure?"

Failure modes: prompt-only branching, no graph-visible dependencies, serial
work that should be parallel, parallel work that should be serialized.

## Side-Effect-Isolate

Definition: Put mutations behind explicit structural boundaries.

Use when: tasks write shared files, mutate Beads, merge branches, call external
APIs, deploy, or create durable external objects.

Prompt module: "Does this need `MergeQueue`, `Worktree`, `Sandbox`,
`Approval`, `Saga`, or an idempotent tool?"

Failure modes: parallel `br` writes, cached side effects, retry double-writes,
worktree changes with no merge policy.

## Resume-Proof

Definition: Check whether the workflow can survive crash, resume, replay, and
operator inspection.

Use when: adding loops, dynamic maps, approvals, timers, signals, memory, or
long-running components.

Prompt module: "If the process dies after this output, what happens on resume?"

Failure modes: unstable ids, process-local state, input mutation, source-change
resume assumptions, side effects outside Smithers knowledge.

## Graph-Preview

Definition: Render graph JSON and inspect descriptors before running agents.

Use when: editing workflow shape, viewer code, deps, branches, parallel lanes,
or approval/wait components.

Prompt module: "What does `smithers graph` say the runtime will schedule?"

Failure modes: trusting visual labels, missing deps, unexpected serial shape,
viewer arrows invented from layout rather than descriptors.

## Ops-Inspect

Definition: Debug runs through Smithers inspection surfaces.

Use when: tasks fail, outputs are missing, approvals wait, loops behave oddly,
or a viewer appears wrong.

Prompt module: "Which command can show the current source of truth: `ps`,
`inspect`, `node`, `output`, `tree`, `timeline`, `diff`, `logs`, `retry-task`,
`fork`, or `replay`?"

Failure modes: guessing from prompts, re-running instead of inspecting, losing
frame history, ignoring failed attempts.
