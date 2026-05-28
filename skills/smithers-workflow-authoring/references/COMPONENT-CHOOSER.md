# Component Chooser

Start from workflow intent, then choose the smallest existing component that
expresses the semantics. Only write custom task choreography after checking
docs and source for a suitable component.

## Intent Router

| Intent | Reach For | Verify |
| --- | --- | --- |
| One thing after another | `Workflow` or `Sequence` | `sequence.mdx`, `SequenceProps.ts` |
| Independent reviewer fanout | `Parallel`, `Panel`, `GatherAndSynthesize` | `parallel.mdx`, `gather-and-synthesize.mdx` |
| Bounded produce/review/fix | `ReviewLoop` or `Loop` | `review-loop.mdx`, `LoopProps.ts` |
| Scan, fix, verify repeatedly | `ScanFixVerify` | `scan-fix-verify.mdx`, `ScanFixVerify.js` |
| Route by condition | `Branch` | `branch.mdx` |
| Route by rules | `DecisionTable` | `decision-table.mdx`, `DecisionRule.ts` |
| Human approve/deny decision | `Approval` | `approval.mdx`, `ApprovalProps.ts` |
| Human submits JSON | `HumanTask` | `human-task.mdx`, `HumanTaskProps.ts` |
| Wait for external event | `Signal` or `WaitForEvent` | `signal.mdx`, `wait-for-event.mdx` |
| Durable delay | `Timer` | `timer.mdx` |
| Ticket-board workflow | `Kanban` | `kanban.mdx`, `KanbanProps.ts` |
| Serialize shared writes | `MergeQueue` | `merge-queue.mdx`, `MergeQueueProps.ts` |
| Isolate file changes | `Worktree` | `worktree.mdx`, `WorktreeProps.ts` |
| Isolate execution environment | `Sandbox` | `sandbox.mdx`, `SandboxProps.ts` |
| Transaction with compensation | `Saga` | `saga.mdx`, `SagaProps.ts` |
| Recover/cleanup after failure | `TryCatchFinally` | `try-catch-finally.mdx` |
| Child workflow | `Subflow` | `subflow.mdx`, `SubflowProps.ts` |
| Long-running rollover | `ContinueAsNew` | `continue-as-new.mdx` |

## Beads Quality Router

For converting a project plan into Beads or polishing one Bead, prefer a
quality-first serial flow:

1. Read-only intake and decomposition task.
2. Parallel semantic reviewers with distinct lenses.
3. Synthesis task that produces a concrete Beads mutation plan.
4. Optional `Approval` for human checkpoint.
5. `MergeQueue maxConcurrency={1}` around `br` mutation.
6. Strict gate task that validates the resulting Bead graph.

Use `ReviewLoop` when the main artifact is one draft that should iterate until
approved. Use `GatherAndSynthesize` when value comes from independent review
lenses. Use `ScanFixVerify` when there is a concrete verifier that can say what
remains broken, but verify current `ScanFixVerify.js` behavior before relying
on multiple fixers.

## Examples By Choice

### Review Loop

```tsx
<ReviewLoop
  id="requirements-polish"
  produce={{ agent: writer, output: outputs.draft, prompt: "Improve the Bead." }}
  review={{ agent: reviewer, output: outputs.review, prompt: "Return approved plus issues." }}
  maxIterations={3}
/>
```

Use when the output naturally has a producer and reviewer. The review output
must include the approval signal expected by the component.

### Parallel Lenses Plus Synthesis

```tsx
<GatherAndSynthesize
  id="bead-lenses"
  sources={[
    { id: "implementability", agent: implementer, output: outputs.finding, prompt: "Check implementability." },
    { id: "dependencies", agent: graphReviewer, output: outputs.finding, prompt: "Check dependencies." },
  ]}
  synthesize={{ agent: lead, output: outputs.synthesis, prompt: "Make one actionable plan." }}
/>
```

Use when independent analyses are useful even if they disagree.

### Decision Table

```tsx
<DecisionTable
  id="route-risk"
  rules={[
    { id: "needs-human", when: () => risk.level === "high", then: <Approval id="approve" output={outputs.approval} request={request} /> },
    { id: "auto", when: () => risk.level !== "high", then: <Task id="auto" output={outputs.next}>Proceed.</Task> },
  ]}
  strategy="first-match"
/>
```

Use when route rules are data, not one-off ternaries.

### Serialized Beads Mutation

```tsx
<MergeQueue id="beads-write" maxConcurrency={1}>
  <Task id="apply-with-br" output={outputs.mutation} agent={mutator}>
    Use br --json commands only. Do not edit .beads files directly.
  </Task>
</MergeQueue>
```

Use after read-only parallel analysis. Parallel lanes propose; the serial lane
mutates.

### Worktree Ticket Lane

```tsx
<Worktree id={`ticket:${ticket.id}:wt`} branch={`smithers/${ticket.id}`}>
  <Task id={`ticket:${ticket.id}:implement`} output={outputs.work} agent={implementer}>
    Implement this isolated ticket.
  </Task>
</Worktree>
```

Use for file changes. Avoid direct Beads graph mutation in worktrees until a
merge policy exists for shared Beads state.

### Approval Decision

```tsx
<Approval id="human-check" output={outputs.decision} request={request} />
{ctx.outputMaybe(outputs.decision, { nodeId: "human-check" })?.approved ? (
  <Task id="approved-next-step" output={outputs.next}>Continue.</Task>
) : null}
```

Use when the decision must be durable and visible in the run history.

## Decision Heuristics

- If an agent prompt says "then," consider `Sequence`.
- If it says "in parallel," consider `Parallel`, `Panel`, or
  `GatherAndSynthesize`.
- If it says "until approved," consider `ReviewLoop` or `Loop`.
- If it says "pick a path," consider `Branch`, `DecisionTable`, or
  `ClassifyAndRoute`.
- If it says "wait for me," consider `Approval`, `HumanTask`, `Signal`, or
  `WaitForEvent`.
- If it says "touch shared state," consider `MergeQueue`.
- If it says "make file changes independently," consider `Worktree`.
- If it says "run risky or remote work," consider `Sandbox`.
