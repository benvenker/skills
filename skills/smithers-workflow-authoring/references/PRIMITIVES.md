# Core Components Pointer

This page remains for older links. The skill now uses component-first language
because Smithers' value is reusable React workflow components, not just
low-level primitives.

Start here instead:

- `COMPONENTS.md`: catalog of official components with docs/source pointers.
- `COMPONENT-CHOOSER.md`: choose components from workflow intent.
- `COMPONENT-EXAMPLES.md`: copyable JSX examples and local exemplars.

The short reminders below are still useful, but verify unfamiliar details
against official component docs/source.

## Legacy Primitive Notes

Official docs live under `reference-repos/smithers/docs/components/`.

### Root And Execution

- `Workflow`: root durable graph. Direct children are sequential. Use `cache`
  when completed nodes should be skipped on resume.
- `Task`: one executable unit. It can emit static output, run a compute
  function, or call an agent. Deliberately set `output`, `agent`, dependencies,
  retry/timeouts, labels, metadata, and tool policy.
- `Sequence`: ordered children inside another component. `Workflow` already
  sequences direct children.

### Control Flow

- `Parallel`: concurrent fanout with optional `maxConcurrency`. Use for
  independent reviewers, feature groups, probes, or read-only lanes.
- `Branch`: mounts one element based on render-time state. Wrap multi-task
  branches in `Sequence` or `Parallel`.
- `DecisionTable`: declarative routing when nested branches become unreadable.
  `first-match` is ordered if/else; `all-match` runs matches in parallel.
- `Loop`: bounded refinement until a concrete persisted boolean becomes true
  or `maxIterations` is hit. Prefer measurable stop conditions.
- `ContinueAsNew`: close the current run and start a fresh one with explicit
  JSON state when history needs bounding.

### Human And External Waits

- `Approval`: durable human approve/select/rank decision. Use when downstream
  graph behavior depends on the decision.
- `ApprovalGate`: conditional approval wrapper that can auto-emit an approval
  decision when no human gate is needed.
- `HumanTask`: durable structured JSON submission by a human.
- `Signal`: typed wrapper around `WaitForEvent`; signal name equals node id.
- `WaitForEvent`: push-based external event wait with optional correlation id.
- `Timer`: durable relative or absolute wait; restarts do not reset it.

### Mutation And Isolation

- `MergeQueue`: caps descendants, defaulting to one lane. Use for shared
  writes, merges, rate-limited APIs, or serialized `br` mutations.
- `Worktree`: runs descendants in a separate JJ worktree. Good for
  implementation swarms; risky for shared Beads state without a merge policy.
- `Sandbox`: runs a child workflow through a provider boundary and returns
  output/artifacts/diffs. Prefer sibling sandboxes over nested sandboxes.

### Higher-Order Components

- `ReviewLoop`: producer/reviewer loop until approved.
- `ScanFixVerify`: scan issues, fix in parallel, verify, retry, report.
- `GatherAndSynthesize`: parallel research sources then one synthesis.
- `Debate` / `Panel`: structured multi-agent opinions.
- `Kanban`: process dynamic items through ordered columns.
- `Saga`: forward steps with reverse compensations on failure.
- `TryCatchFinally`: workflow-scoped error handling.
- `Subflow`: invoke a child workflow as a boundary or inline subtree.
- `CheckSuite`: named parallel checks with aggregate status.
- `ClassifyAndRoute`: classify once, then route to a handler.
- `ContentPipeline`: ordered content stages with explicit outputs.
- `Aspects`: cross-cutting budgets/tracking for a subtree.
- `Runbook`, `Supervisor`, `Poller`: operational workflows.
