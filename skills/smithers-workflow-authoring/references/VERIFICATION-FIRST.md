# Verification First

Use this protocol before running expensive/model-backed Smithers work and when
debugging a surprising workflow. The rule is simple: verify source, graph,
state, and side effects before trusting prose.

## 1. Source Verification

For unfamiliar behavior, inspect official docs and implementation:

```bash
rg "<ComponentName>" reference-repos/smithers/docs/components \
  reference-repos/smithers/packages/components/src/components
sed -n '1,220p' reference-repos/smithers/docs/components/<component>.mdx
sed -n '1,220p' reference-repos/smithers/packages/components/src/components/<Component>Props.ts
```

Prefer prop types for exact accepted fields. Prefer docs/examples for intended
composition. Prefer runtime source and graph types for viewer/debugger work.

High-value source paths:

- `reference-repos/smithers/docs/how-it-works.mdx`
- `reference-repos/smithers/docs/components/`
- `reference-repos/smithers/docs/examples/`
- `reference-repos/smithers/examples/`
- `reference-repos/smithers/packages/components/src/components/`
- `reference-repos/smithers/packages/graph/src/types.ts`
- `reference-repos/smithers/docs/runtime/`
- `reference-repos/smithers/apps/cli/`

## 2. Static Workflow Verification

```bash
pnpm exec smithers workflow doctor --format md
pnpm exec smithers workflow inspect <workflow-id> --format md
pnpm exec smithers graph .smithers/workflows/<workflow-id>.tsx --format json
pnpm run smithers:view -- .smithers/workflows/<workflow-id>.tsx --open
```

Inspect graph JSON for:

- stable node ids;
- `dependsOn`, `needs`, and `deps` shape;
- output table/schema names;
- `parallelGroupId` and concurrency caps;
- branch/loop/approval/wait metadata;
- retry, timeout, heartbeat, cache, memory, and scorer policy;
- worktree path/branch and sandbox boundary fields.

For viewer work, derive arrows, forks, loops, statuses, and labels from graph
descriptors. Do not parse task text when a descriptor field exists.

## 3. Run-State Verification

```bash
pnpm exec smithers ps --all
pnpm exec smithers inspect <run-id>
pnpm exec smithers logs <run-id> --tail 50 --follow
pnpm exec smithers node <run-id> <node-id>
pnpm exec smithers output <run-id> <node-id> --pretty
pnpm exec smithers tree <run-id>
pnpm exec smithers timeline <run-id> --tree
pnpm exec smithers diff <run-id> <node-id>
```

Use these before editing prompts in response to a failed run. The failure may
be a schema, dependency, approval, retry, cache, or resume issue rather than an
agent reasoning issue.

## 4. Human And Wait Verification

```bash
pnpm exec smithers ps --status waiting-approval
pnpm exec smithers approve <run-id> --node <node-id> --by <name>
pnpm exec smithers deny <run-id> --node <node-id> --by <name>
```

Check that approval decisions are persisted and downstream rendering branches
on them when the decision matters.

## 5. Mutation Verification

Before a workflow mutates shared state:

- Put read-only analysis before mutation.
- Put shared writes behind `MergeQueue maxConcurrency={1}`.
- Use `Worktree` for isolated file changes with explicit merge policy.
- Use `Sandbox` for risky execution boundaries.
- Do not cache side-effecting tasks.
- Ensure custom tools declare side effects and use idempotency keys.
- For Beads, mutate only with `br` commands; never edit `.beads` internals.

## 6. Resume And Time Travel Verification

```bash
pnpm exec smithers timeline <run-id> --tree
pnpm exec smithers replay .smithers/workflows/<workflow-id>.tsx --run-id <run-id>
pnpm exec smithers fork .smithers/workflows/<workflow-id>.tsx --run-id <run-id>
```

Check stable ids and schema compatibility before assuming resume or replay will
be meaningful. Resuming with different input or changed workflow source is not
the same run contract.

## 7. Final Pre-Run Checklist

- Component choice checked against docs/source.
- Stable ids reviewed.
- Schemas are structured and downstream-readable.
- Graph preview matches intended sequence/fanout/fanin/loops.
- Shared writes are serialized or isolated.
- Approval/wait nodes have an operator path.
- Beads mutations use only `br`.
- Viewer changes have graph JSON evidence.
