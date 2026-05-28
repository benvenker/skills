---
name: smithers-workflow-authoring
description: "Author, revise, inspect, and operate Smithers TSX workflows using source-backed JSX components and durable workflow patterns. Use when editing `.smithers/workflows`, designing Smithers workflow graphs, choosing Smithers components, debugging Smithers runs, improving the Smithers viewer, or composing Beads-support workflows."
---

# Smithers Workflow Authoring

Use this skill when Smithers itself is part of the work: workflow TSX,
components, run inspection, Gateway/viewer behavior, or choosing components.
Treat the official local checkout as framework truth and these references as
Time Bandit doctrine-in-progress.

## Kernel

- Smithers is a React reconciler whose rendered JSX becomes the workflow plan.
- Durable state is persisted task output. React state is render-local only.
- Task ids are durability keys for resume, outputs, diffs, and time travel.
- Zod schemas are storage contracts, not prompt decoration.
- Components are the workflow language; check them before custom choreography.
- Structural control flow beats prompt-only instructions.
- Source docs/source code beat this skill when uncertain.
- Preview graph shape before model-backed runs; inspect runs instead of
  inferring from prompts.

## Required Source Check

Before using an unfamiliar component or runtime feature:

```bash
rg "<term>" reference-repos/smithers/docs reference-repos/smithers/packages
pnpm exec smithers docs
pnpm exec smithers docs-full --token-limit 12000
```

Highest-value sources under `reference-repos/smithers/`: `docs/llms-core.txt`,
`docs/components/`, `docs/recipes.mdx`, `packages/components/src/components/`,
and `packages/graph/src/types.ts`.

If `pnpm exec smithers ...` cannot find `bun`, run with:
`env PATH=$HOME/.bun/bin:$PATH pnpm exec smithers workflow doctor`

## Quick Workflow

1. Read `references/ORIENTATION.md`, `COMPONENTS.md`,
   `COMPONENT-CHOOSER.md`, and `COMPONENT-EXAMPLES.md`.
2. Inspect local workflow state:
   `pnpm exec smithers workflow doctor --format md`,
   `pnpm exec smithers workflow list --format md`,
   `pnpm exec smithers workflow inspect <workflow-id> --format md`.
3. Choose documented components before custom task choreography: `Task`,
   `Sequence`, `Parallel`, `Branch`, `DecisionTable`, `Loop`, `ReviewLoop`,
   `ScanFixVerify`, `Approval`, `HumanTask`, `Kanban`, `MergeQueue`,
   `Worktree`, `Sandbox`, `Subflow`, `Saga`, or another component.
4. Define schemas before prompts. Zod outputs are durable storage contracts.
5. Preview before running model-backed work:
   `pnpm exec smithers graph .smithers/workflows/<workflow-id>.tsx --format json`
   and `pnpm run smithers:view -- .smithers/workflows/<workflow-id>.tsx --open`.
6. Inspect runs instead of guessing:
   `pnpm exec smithers ps --all`,
   `pnpm exec smithers inspect <run-id>`,
   `pnpm exec smithers node <run-id> <node-id>`,
   `pnpm exec smithers output <run-id> <node-id> --pretty`.

## References

- `references/README.md`: source map and reading order.
- `references/ORIENTATION.md`: render loop, ctx, durable state, resume.
- `references/COMPONENTS.md`: component catalog with docs/source pointers.
- `references/COMPONENT-CHOOSER.md`: route workflow intent to components.
- `references/COMPONENT-EXAMPLES.md`: copyable examples and local exemplars.
- `references/OPERATORS.md`: cognitive operators for workflow design review.
- `references/VERIFICATION-FIRST.md`: source, graph, run, and mutation checks.
- `references/DATA-CONTRACTS.md`: schemas, descriptors, deps, retries, cache.
- `references/MUTATION-ISOLATION.md`: safe mutation, worktrees, sandboxes.
- `references/OPS-DEBUGGING.md`: CLI and run-state inspection.
- `references/TIME-BANDIT-PATTERNS.md`: repo-specific Smithers patterns.
- `references/MENTAL-MODEL.md` and `PRIMITIVES.md`: legacy compact notes.

## Anti-Patterns

- Prompt-only loops, approvals, branches, retries, or fanout when a component exists.
- Index, timestamp, random, or prompt-derived task ids.
- `useState` or memory for durable run state that belongs in task outputs.
- Giant untyped string blobs where downstream tasks need structured facts.
- Parallel shared writes without `MergeQueue`, `Worktree`, `Sandbox`, or serialization.
- Cached side-effect tasks.
- Approvals that pause but never branch on the persisted decision.
- Viewer code that invents semantics instead of reading graph descriptors.

## Repo Rules

- Do not mutate Beads except through `br`.
- Do not use Smithers memory as transactional run state; use persisted outputs.
- Do not put slow/model-backed Smithers runs in pre-commit hooks.
- Keep the local viewer source-first: derive visuals from `smithers graph`.
- Regenerate workflow skills when shape changes:
  `pnpm exec smithers workflow skills --output .smithers/skills --force`.
