# Operations And Debugging

Do not guess at Smithers state. Inspect it.

## Discovery And Preview

```bash
pnpm exec smithers workflow doctor --format md
pnpm exec smithers workflow list --format md
pnpm exec smithers workflow inspect <workflow-id> --format md
pnpm exec smithers workflow path <workflow-id>
pnpm exec smithers graph .smithers/workflows/<workflow-id>.tsx --format json
pnpm run smithers:view -- .smithers/workflows/<workflow-id>.tsx --open
```

If Bun is missing from PATH:

```bash
env PATH=$HOME/.bun/bin:$PATH pnpm exec smithers workflow doctor
```

## Run Inspection

```bash
pnpm exec smithers ps --all
pnpm exec smithers inspect <run-id>
pnpm exec smithers logs <run-id> --tail 50 --follow
pnpm exec smithers chat <run-id>
pnpm exec smithers why <run-id>
pnpm exec smithers node <run-id> <node-id>
pnpm exec smithers output <run-id> <node-id> --pretty
pnpm exec smithers tree <run-id>
pnpm exec smithers timeline <run-id> --tree
pnpm exec smithers diff <run-id> <node-id>
```

## Control Plane

```bash
pnpm exec smithers approve <run-id> --node <node-id> --by <name>
pnpm exec smithers deny <run-id> --node <node-id> --by <name>
pnpm exec smithers cancel <run-id>
pnpm exec smithers retry-task <run-id> <node-id>
pnpm exec smithers supervise
```

## Time Travel

Use time travel when a run history matters:

```bash
pnpm exec smithers replay .smithers/workflows/<workflow-id>.tsx --run-id <run-id>
pnpm exec smithers fork .smithers/workflows/<workflow-id>.tsx --run-id <run-id>
pnpm exec smithers rewind <run-id> <frame-no>
```

Stable node ids and durable output schemas make time travel useful. Changing
ids or schemas casually makes old run history harder to reason about.

Official source:

- `reference-repos/smithers/docs/cli/overview.mdx`
- `reference-repos/smithers/docs/runtime/events.mdx`
- `reference-repos/smithers/docs/concepts/time-travel.mdx`
- `reference-repos/smithers/apps/cli/`
