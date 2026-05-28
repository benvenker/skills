# Component Examples

Use this page when prose is not enough. The goal is to point agents at actual
JSX shapes in official docs, official examples, and this repo's Smithers
workflows/components.

## Official Examples

### Minimal Workflow And Task

Source:

- `reference-repos/smithers/docs/components/workflow.mdx`
- `reference-repos/smithers/docs/components/task.mdx`
- `reference-repos/smithers/packages/components/src/components/TaskProps.ts`

```tsx
/** @jsxImportSource smithers-orchestrator */
import { createSmithers } from "smithers-orchestrator";
import { z } from "zod";

const { smithers, outputs } = createSmithers({
  analysis: z.object({ summary: z.string(), risks: z.array(z.string()) }),
});

export default smithers((ctx) => (
  <Workflow name="plan-audit">
    <Task id="analyze" output={outputs.analysis} agent={analyst}>
      Analyze {ctx.input.planPath} and return structured findings.
    </Task>
  </Workflow>
));
```

### Task Dependencies

Source:

- `reference-repos/smithers/docs/components/task.mdx`
- `reference-repos/smithers/packages/graph/src/types.ts`

```tsx
<Task id="scan" output={outputs.scan} agent={scanner}>Scan the plan.</Task>
<Task
  id="write"
  output={outputs.draft}
  agent={writer}
  deps={{ scan: outputs.scan }}
  needs={{ scan: "scan" }}
>
  {({ scan }) => `Write from these findings: ${JSON.stringify(scan)}`}
</Task>
```

Prefer `deps`/`needs` to asking downstream agents to rediscover upstream state.

### Approval As A Decision Node

Source:

- `reference-repos/smithers/docs/how-it-works.mdx`
- `reference-repos/smithers/docs/components/approval.mdx`
- `reference-repos/smithers/docs/examples/approval-gate.mdx`

```tsx
<Approval
  id="apply-approval"
  output={outputs.approval}
  request={{ title: "Apply Beads mutation?", summary }}
  onDeny="continue"
/>

{ctx.outputMaybe(outputs.approval, { nodeId: "apply-approval" })?.approved ? (
  <Task id="apply" output={outputs.mutation} agent={mutator}>Apply it.</Task>
) : null}
```

If the approval does not influence later rendering, it is only a pause.

### HumanTask

Source:

- `reference-repos/smithers/docs/components/human-task.mdx`
- `reference-repos/smithers/packages/components/src/components/HumanTaskProps.ts`

```tsx
<HumanTask
  id="product-answer"
  output={outputs.humanAnswer}
  request={{ title: "Clarify acceptance criteria", fields: ["criteria"] }}
/>
```

Use when a human must submit structured JSON, not only approve or deny.

### ReviewLoop

Source:

- `reference-repos/smithers/docs/components/review-loop.mdx`
- `reference-repos/smithers/packages/components/src/components/ReviewLoopProps.ts`

```tsx
<ReviewLoop
  id="ready-lane"
  produce={{ agent: author, output: outputs.draft, prompt: "Improve the Bead." }}
  review={{ agent: reviewer, output: outputs.review, prompt: "Approve only if implementation-ready." }}
  maxIterations={4}
/>
```

Use when the artifact is a single evolving draft and the review schema has an
approval signal.

### ScanFixVerify

Source:

- `reference-repos/smithers/docs/components/scan-fix-verify.mdx`
- `reference-repos/smithers/packages/components/src/components/ScanFixVerify.js`
- `reference-repos/smithers/packages/components/src/components/ScanFixVerifyProps.ts`

```tsx
<ScanFixVerify
  id="test-hardening"
  scan={{ agent: scanner, output: outputs.scan, prompt: "Find gaps." }}
  fix={{ agent: fixer, output: outputs.fix, prompt: "Patch the gaps." }}
  verify={{ agent: verifier, output: outputs.verify, prompt: "Verify the patch." }}
  report={{ agent: reporter, output: outputs.report, prompt: "Summarize." }}
  maxRetries={3}
/>
```

Current caveat: verify source before relying on multiple fixers. The docs
describe richer fixer behavior than the current source appears to implement.

### Kanban

Source:

- `reference-repos/smithers/docs/components/kanban.mdx`
- `reference-repos/smithers/packages/components/src/components/KanbanProps.ts`
- `.smithers/workflows/kanban.tsx`

```tsx
<Kanban
  id="tickets"
  columns={[
    { id: "implement", name: "Implement", agent: implementer, output: outputs.implementation },
    { id: "review", name: "Review", agent: reviewer, output: outputs.review },
  ]}
  useTickets={() => tickets}
  until={(board) => board.done}
/>
```

Use for long-running ticket boards and column semantics. Inspect local
`.smithers/workflows/kanban.tsx` for the repo's worktree-based ticket pattern.

### MergeQueue And Worktree

Source:

- `reference-repos/smithers/docs/components/merge-queue.mdx`
- `reference-repos/smithers/docs/components/worktree.mdx`
- `.smithers/workflows/kanban.tsx`
- `.smithers/workflows/beads-ready-lane.tsx`

```tsx
<Parallel maxConcurrency={4}>
  {tickets.map((ticket) => (
    <Worktree key={ticket.id} id={`ticket:${ticket.id}:wt`} branch={`ticket/${ticket.id}`}>
      <Task id={`ticket:${ticket.id}:implement`} output={outputs.work} agent={implementer}>
        Implement one ticket in isolation.
      </Task>
    </Worktree>
  ))}
</Parallel>

<MergeQueue id="merge-results" maxConcurrency={1}>
  <Task id="merge-summary" output={outputs.merge} agent={integrator}>
    Merge or summarize the isolated lanes.
  </Task>
</MergeQueue>
```

Worktrees isolate file changes. Merge queues serialize the shared boundary.

### GatherAndSynthesize

Source:

- `reference-repos/smithers/docs/components/gather-and-synthesize.mdx`
- `reference-repos/smithers/packages/components/src/components/GatherAndSynthesizeProps.ts`
- `reference-repos/smithers/packages/components/src/components/SourceDef.ts`

```tsx
<GatherAndSynthesize
  id="multi-model-review"
  sources={[
    { id: "requirements", agent: reqAgent, output: outputs.finding, prompt: "Review requirements." },
    { id: "execution", agent: execAgent, output: outputs.finding, prompt: "Review implementability." },
  ]}
  synthesize={{ agent: lead, output: outputs.synthesis, prompt: "Create one final recommendation." }}
/>
```

Use for parallel semantic lenses and one synthesis output.

### DecisionTable

Source:

- `reference-repos/smithers/docs/components/decision-table.mdx`
- `reference-repos/smithers/packages/components/src/components/DecisionTableProps.ts`
- `reference-repos/smithers/packages/components/src/components/DecisionRule.ts`

```tsx
<DecisionTable
  id="risk-route"
  rules={[
    { id: "human", when: () => risk.high, then: <Approval id="approve" output={outputs.approval} request={request} /> },
    { id: "auto", when: () => !risk.high, then: <Task id="auto-next" output={outputs.next}>Continue.</Task> },
  ]}
  strategy="first-match"
/>
```

Use when routing policy is a table of rules rather than a hidden prompt.

### Sandbox

Source:

- `reference-repos/smithers/docs/components/sandbox.mdx`
- `reference-repos/smithers/examples/freestyle/workflow.tsx`
- `reference-repos/smithers/docs/examples/freestyle-sandbox-provider.mdx`

```tsx
<Sandbox
  id="generate"
  provider="remote-vm"
  workflow={childWorkflow}
  output={outputs.sandboxResult}
/>
```

The public component is provider-first. Children do not become parent-run
tasks; the sandbox boundary returns output, artifacts, diffs, or provider
results according to the provider contract.

## Time Bandit Local Examples

Use these as copy/reference points before inventing new local patterns.

- `.smithers/components/ValidationLoop.tsx`: reusable `Loop` plus `Sequence`
  for implement, validate, review, feedback injection, timeouts, and
  `onMaxReached`.
- `.smithers/components/Review.tsx`: compact `Parallel` reviewer fanout with
  stable task ids and `continueOnFail`.
- `.smithers/components/ForEachFeature.tsx`: dynamic item construction,
  `Parallel maxConcurrency`, empty-state static output, and merge via deps.
- `.smithers/components/FeatureEnum.tsx`: conditional first scan, sequential
  refinement, memory use, and final pass-through task.
- `.smithers/components/GrillMe.tsx`: wrapper component that interviews until
  vague requirements are actionable.
- `.smithers/workflows/write-a-prd.tsx`: `GrillMe` composed with a nested PRD
  task and history-based stop logic.
- `.smithers/workflows/research-plan-implement.tsx`: research -> plan ->
  implementation loop with `ctx.outputMaybe` and feedback synthesis.
- `.smithers/workflows/kanban.tsx`: filesystem ticket discovery, parallel
  ticket execution, per-ticket `Worktree`, and merge summary.
- `.smithers/workflows/beads-ready-lane.tsx`: parallel semantic lenses,
  synthesis, durable `Approval`, serialized `MergeQueue`, and strict gate.
- `.smithers/workflows/beads-plan-to-graph.tsx`: plan snapshot, bounded review,
  optional approval, serialized `br` mutation, final gate, and summary.
- `.smithers/workflows/beads-polish-8-rounds.tsx`: repeated fresh-context Beads
  polish lanes using `Parallel` over targets and per-target `Loop`.
- `.smithers/workflows/mission.tsx`: advanced dynamic rendering, optional
  `Worktree`, milestone deps, approvals, and follow-up branches.

When a local example conflicts with official docs/source, trust official
Smithers semantics and update the local pattern.
