# Components

Smithers workflows are React components. Low-level pieces such as `Task` and
`Parallel` are components; so are higher-order workflow products like
`ReviewLoop`, `Kanban`, `MergeQueue`, and `SuperSmithers`. Before composing
custom task choreography, check whether Smithers already ships a component with
the semantics you need.

Official component docs live in `reference-repos/smithers/docs/components/`.
Implementations and precise prop types live in
`reference-repos/smithers/packages/components/src/components/`. Path fragments
below are relative to those directories.

## Core Graph Components

Use these to define the basic graph shape.

| Component | Use | Official files |
| --- | --- | --- |
| `Workflow` | Root durable graph. Direct children sequence in source order. | `workflow.mdx`, `Workflow.js`, `WorkflowProps.ts` |
| `Task` | Agent, compute, or static unit. `deps`/`needs`, tools, fallback agents, labels, metadata, retries, and schemas are first-class. | `task.mdx`, `Task.js`, `TaskProps.ts` |
| `Sequence` | Ordered children inside another component. | `sequence.mdx`, `Sequence.js`, `SequenceProps.ts` |
| `Parallel` | Concurrent children with optional `maxConcurrency`. | `parallel.mdx`, `Parallel.js`, `ParallelProps.ts` |
| `Branch` | Explicit if/then/else routing. | `branch.mdx`, `Branch.js`, `BranchProps.ts` |
| `DecisionTable` | Rule-based route selection. | `decision-table.mdx`, `DecisionTable.js`, `DecisionTableProps.ts`, `DecisionRule.ts` |
| `Loop` | Bounded repeated render/execution. | `loop.mdx`, `Loop.js`, `LoopProps.ts` |

```tsx
<Workflow name="review">
  <Sequence>
    <Task id="scan" output={outputs.scan} agent={scanner}>Scan.</Task>
    <Parallel maxConcurrency={3}>
      <Task id="review:a" output={outputs.review} agent={a}>Review.</Task>
      <Task id="review:b" output={outputs.review} agent={b}>Review.</Task>
    </Parallel>
  </Sequence>
</Workflow>
```

## Human, Event, And Time Components

Use these when work must pause durably instead of asking an agent to wait.

| Component | Use | Official files |
| --- | --- | --- |
| `Approval` | Typed approve/select/rank decision row. | `approval.mdx`, `Approval.js`, `ApprovalProps.ts`, `ApprovalMode.ts` |
| `ApprovalGate` | Conditional approval wrapper with auto-approved fallback. | `approval-gate.mdx`, `ApprovalGate.js`, `ApprovalGateProps.ts` |
| `HumanTask` | Human submits arbitrary JSON matching a schema. | `human-task.mdx`, `HumanTask.js`, `HumanTaskProps.ts` |
| `Task needsApproval` | Pause before a task executes; no rich decision row. | `task.mdx`, `TaskProps.ts` |
| `Signal` | Wait for an external signal. | `signal.mdx`, `Signal.js`, `SignalProps.ts` |
| `WaitForEvent` | Event-driven wait with optional correlation. | `wait-for-event.mdx`, `WaitForEvent.js`, `WaitForEventProps.ts` |
| `Timer` | Durable relative or absolute delay. | `timer.mdx`, `Timer.js`, `TimerProps.ts` |

```tsx
<Approval id="merge-ok" output={outputs.approval} request={request} />
{ctx.outputMaybe(outputs.approval, { nodeId: "merge-ok" })?.approved ? (
  <Task id="merge" output={outputs.merge}>Apply the approved change.</Task>
) : null}
```

## Quality And Review Components

Use these when the workflow is mainly "produce, critique, fix, verify."

| Component | Use | Official files |
| --- | --- | --- |
| `ReviewLoop` | Producer/reviewer loop until approved. | `review-loop.mdx`, `ReviewLoop.js`, `ReviewLoopProps.ts` |
| `ScanFixVerify` | Scan, fix, verify, and report loop. | `scan-fix-verify.mdx`, `ScanFixVerify.js`, `ScanFixVerifyProps.ts` |
| `CheckSuite` | Named checks with aggregate status. | `check-suite.mdx`, `CheckSuite.js`, `CheckSuiteProps.ts` |
| `LoopUntilScored` | Iterate until score target. | `loop-until-scored.mdx` |
| `Optimizer` | Iterative improvement. | `optimizer.mdx`, `Optimizer.js`, `OptimizerProps.ts` |
| `DriftDetector` | Detect changed assumptions or outputs. | `drift-detector.mdx`, `DriftDetector.js`, `DriftDetectorProps.ts` |

```tsx
<ReviewLoop
  id="bead-ready"
  produce={{ agent: writer, output: outputs.draft, prompt: "Polish the Bead." }}
  review={{ agent: reviewer, output: outputs.review, prompt: "Approve only ready work." }}
  maxIterations={4}
/>
```

`ScanFixVerify` caveat: current docs and source appear to drift around fixer
arrays. The docs describe cycling fixers across issues; the source currently
normalizes fixers and uses only `fixers[0]` for one fix task. Verify
`ScanFixVerify.js` and `ScanFixVerifyProps.ts` before relying on multi-fixer
semantics.

## Multi-Agent Synthesis Components

Use these when independent agents should examine the same object through
different lenses and then converge.

| Component | Use | Official files |
| --- | --- | --- |
| `GatherAndSynthesize` | Parallel sources plus synthesis. | `gather-and-synthesize.mdx`, `GatherAndSynthesize.js`, `GatherAndSynthesizeProps.ts`, `SourceDef.ts` |
| `Debate` | Adversarial multi-agent exchange. | `debate.mdx`, `Debate.js`, `DebateProps.ts` |
| `Panel` | Panelist review. | `panel.mdx`, `Panel.js`, `PanelProps.ts` |
| `SuperSmithers` | Hot-reload-oriented source-code intervention. | `super-smithers.mdx`, `SuperSmithers.js`, `SuperSmithersProps.ts` |
| `ClassifyAndRoute` | Classify input and route to handlers. | `classify-and-route.mdx`, `ClassifyAndRoute.js`, `ClassifyAndRouteProps.ts` |
| `EscalationChain` | Human/agent escalation ladder. | `escalation-chain.mdx`, `EscalationChain.js`, `EscalationChainProps.ts` |

```tsx
<GatherAndSynthesize
  id="plan-review"
  sources={[
    { id: "risk", agent: riskAgent, output: outputs.review, prompt: "Find risks." },
    { id: "deps", agent: depsAgent, output: outputs.review, prompt: "Find dependencies." },
  ]}
  synthesize={{ agent: lead, output: outputs.synthesis, prompt: "Merge the findings." }}
/>
```

`SuperSmithers` caveat: treat it as advanced/experimental for auditable code
changes. Current source expands to read, propose, optional apply, and report,
but the apply task is coarse. Prefer explicit `Task` composition when you need
reviewable code mutation steps.

## Mutation And Isolation Components

Use these when tasks mutate files, shared state, external systems, or isolated
execution environments.

| Component | Use | Official files |
| --- | --- | --- |
| `MergeQueue` | Serialize merges/shared writes. | `merge-queue.mdx`, `MergeQueue.js`, `MergeQueueProps.ts` |
| `Worktree` | Run child work in isolated VCS worktree. | `worktree.mdx`, `Worktree.js`, `WorktreeProps.ts` |
| `Sandbox` | Provider-backed execution boundary. | `sandbox.mdx`, `Sandbox.js`, `SandboxProps.ts` |
| `Saga` | Forward steps with compensations. | `saga.mdx`, `Saga.js`, `SagaProps.ts` |
| `TryCatchFinally` | Error handling structure. | `try-catch-finally.mdx`, `TryCatchFinally.js`, `TryCatchFinallyProps.ts` |

```tsx
<MergeQueue id="serialized-beads-mutation" maxConcurrency={1}>
  <Task id="br-update" output={outputs.mutation} agent={mutator}>
    Use only br commands to update the approved Bead.
  </Task>
</MergeQueue>
```

Prefer sibling sandboxes over nested sandboxes. Use worktrees for isolated file
changes, not shared Beads graph writes unless a merge policy exists.

## Long-Running Orchestration Components

Use these for ticket boards, subflows, supervision, and durable runbooks.

| Component | Use | Official files |
| --- | --- | --- |
| `Kanban` | Ticket/column workflow board. | `kanban.mdx`, `Kanban.js`, `KanbanProps.ts`, `ColumnDef.ts` |
| `Subflow` | Invoke a child workflow. | `subflow.mdx`, `Subflow.js`, `SubflowProps.ts` |
| `ContinueAsNew` | Roll a long run forward. | `continue-as-new.mdx`, `ContinueAsNew.js`, `ContinueAsNewProps.ts` |
| `Poller` | Poll with durable outputs. | `poller.mdx`, `Poller.js`, `PollerProps.ts` |
| `Supervisor` | Supervise child work. | `supervisor.mdx`, `Supervisor.js`, `SupervisorProps.ts` |
| `Runbook` | Structured operations sequence. | `runbook.mdx`, `Runbook.js`, `RunbookProps.ts` |
| `ContentPipeline` | Ordered content stages. | `content-pipeline.mdx`, `ContentPipeline.js`, `ContentPipelineProps.ts` |
| `Aspects` | Cross-cutting budgets/tracking. | `aspects.mdx`, `Aspects.js`, `AspectsProps.ts` |
| `ExtractPrompt` | Extract/reuse prompt material. | `extract-prompt.mdx` |

```tsx
<Kanban
  id="ticket-board"
  columns={[
    { id: "implement", name: "Implement", agent: implementer, output: outputs.work },
    { id: "review", name: "Review", agent: reviewer, output: outputs.review },
  ]}
  useTickets={() => tickets}
  until={(state) => state.done}
/>
```
