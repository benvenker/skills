# Mutation And Isolation

Smithers can make concurrency easy; shared state can still make concurrency
dangerous. Model the dangerous part structurally.

## Serial Shared Writes

Use `MergeQueue maxConcurrency={1}` for:

- `br` mutations after parallel Beads analysis;
- Git merges after parallel worktrees;
- writes to shared files;
- rate-limited or non-idempotent external API calls;
- global labels or dependency rewrites.

Parallel lanes should inspect and propose. A serial lane should mutate.

## Beads

Repo rules:

- Only mutate Beads with `br`.
- Use `br --json` and `bv --robot-*` for inspection.
- Never run bare `bv`.
- Do not hand-edit `.beads/issues.jsonl` or `.beads/beads.db`.
- Use persisted Smithers outputs for run state, not Smithers memory.

For Beads polish, prefer:

```tsx
<Parallel maxConcurrency={N}>{/* read-only critique */}</Parallel>
<MergeQueue maxConcurrency={1}>{/* br updates */}</MergeQueue>
<Task id="strict-gate" ... />
```

## Worktrees

Use `Worktree` for implementation tickets that need isolated file changes.
Do not use worktrees for direct Beads graph mutation until there is an explicit
merge policy for shared Beads state.

## Sandboxes

Use `Sandbox` for risky or remote child workflows that return output,
artifacts, or diffs. Keep direct Beads mutation out of sandboxes; Beads should
stay `br`-mediated in the main repo context.

Prefer sibling sandboxes under `Parallel` or `MergeQueue` over nested
sandboxes.

## Side-Effect Tools

When adding custom tools:

- declare side effects and idempotency;
- use the runtime idempotency key for external creates/updates;
- restrict tools per task role with `allowTools`;
- avoid caching side-effecting tasks.
