# Time Bandit Patterns

These are local names for Smithers shapes we expect agents to reuse.

## Clean-Context Polish Lanes

Use for repeated review/refinement where each pass should behave like a fresh
agent reading current state. This is the current Beads polish shape: baseline
snapshot, parallel target lanes, bounded loops, final gates, summary, and
`noSession: true`.

Local source: `.smithers/workflows/beads-polish-8-rounds.tsx`,
`docs/agents/smithers-beads-polish.md`.

## Validation Loop With Real Consensus

Use for implementation workflows where "one reviewer approved" is too weak.
The local `ValidationLoop` already implements -> validates -> reviews in a
loop; risky workflows should encode stricter consensus in `until`, such as
validation passing and every required reviewer approving.

Local source: `.smithers/components/ValidationLoop.tsx`,
`.smithers/components/Review.tsx`, `.smithers/workflows/implement.tsx`.

## Feature Map Audit Conveyor

Use `feature-enum` to build or refine a code-backed feature inventory, then
feed that inventory into `audit` for tests/docs/observability/maintainability
gaps.

Local source: `.smithers/components/FeatureEnum.tsx`,
`.smithers/components/ForEachFeature.tsx`, `.smithers/workflows/feature-enum.tsx`,
`.smithers/workflows/audit.tsx`.

## Ticket Board Worktree Swarm

Use `.smithers/tickets/*.md` plus `kanban` when many implementation tickets can
move through work/review/merge lanes. This is the natural bridge from polished
Beads to multi-agent implementation.

Local source: `.smithers/workflows/kanban.tsx`, `.smithers/ui/kanban.tsx`,
`.smithers/gateway.ts`, `.smithers/tickets/`.

## Serialized Merge Queue

Use `MergeQueue maxConcurrency={1}` for merges, shared `br` mutations, or any
shared state update after parallel work.

Reference source: `reference-repos/smithers/docs/components/merge-queue.mdx`,
`reference-repos/smithers/examples/parallel-tickets.jsx`.

## Gate-Then-Launch Mission

Use `mission` for long-horizon Beads-to-implementation arcs: plan, optional
approval, milestone work, validation, follow-up, and final report.

Local source: `.smithers/workflows/mission.tsx`,
`reference-repos/smithers/docs/workflows/mission.mdx`.

## Branch-Routed Risk Ladder

Use `Branch` or `DecisionTable` to classify risk, then route to inspect-only,
approval-required, or safe-mutation branches.

Reference source: `reference-repos/smithers/docs/examples/dynamic-plan.mdx`,
`reference-repos/smithers/examples/branch-doctor.jsx`.

## Beads Polish Upgrade Ideas

Safe near-term ideas:

- Split read-only critique, proposed mutation, serialized mutation, and strict
  gate into separate typed nodes.
- Use optional strict-gate stop conditions instead of only fixed `until={false}`
  loops.
- Put actual `br` mutations in `MergeQueue maxConcurrency={1}`.
- Use durable `Approval` before high-risk cross-bead or frontier-label changes.
- Add task `meta` such as phase, target, bead id, mutation risk, and command
  policy; teach the viewer to render descriptor fields and meta.
- Generate/update `.smithers/skills/` after workflow shape changes.

Keep out of scope unless deliberately designed:

- `Worktree` or `Sandbox` for direct Beads graph mutation.
- Smithers memory for transactional Beads polish state.
- Unbounded `Ralph`-style maintenance loops.
- Prompt-only approvals for real human decisions.
- A full Gateway or spatial authoring UI inside this repo.
