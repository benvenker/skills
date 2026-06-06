# Phase 0 Scope Decision — better-beads CLI-only pass

- Target: `skills/better-beads`
- Mode: `full`
- Scope: CLI tools and commands only. References/prose audited only where needed to expose CLI entrypoints.
- CASS mining: skipped by user choice.
- Branch policy: current branch `main`; no new branch created.
- Workspace: in-tree at `skills/better-beads/agent_ergonomics_audit/`.
- Preflight limitations: local macOS environment lacks GNU `flock` and `timeout`, so generic recursive inventory scripts were not used. Manual script-surface inventory was used instead.
