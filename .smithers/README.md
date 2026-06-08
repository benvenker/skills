# Smithers Runtime

This directory contains the local Smithers runtime setup for the Better Beads
polish workflow experiment in `/data/projects/skills`.

Install pinned dependencies:

```bash
bun install
```

Preview the workflow graph from the repository root:

```bash
bunx smithers-orchestrator graph .smithers/workflows/better-beads-polish-graph.tsx --format json
```

Run the Better Beads wrapper from the repository root:

```bash
skills/better-beads/scripts/better-beads smithers polish-graph --json
```

`smithers-orchestrator` is pinned locally here because running from Bun's
temporary `bunx` install can split React between caches and trigger invalid hook
calls while rendering workflow components.
