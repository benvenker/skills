# better-beads CLI Agent-Ergonomics Scorecard — Pass 1

Scope: CLI/script surfaces only. Generic skill-package discovery found no binary, so this pass manually inventoried the executable script commands.

| Surface | Status | Weighted score | Key uplift |
|---|---:|---:|---|
| `scripts/better-beads` | added | 882 | First-try dispatcher, `triage --json`, `capabilities --json`, robot docs |
| `scripts/bead_quality_gate.py` | hardened | 841 | Capabilities, robot docs, exit-code help, typo hints |
| `scripts/bead_gate_loop.sh` | hardened | 832 | Capabilities, robot docs, exit-code help, typo hints |
| `scripts/bead_closeout_guard.sh` | hardened | 833 | Capabilities, robot docs, exit-code help, typo hints |

## Pre-pass findings

- No unified `better-beads` CLI entrypoint existed.
- Existing scripts had `--help`, but not `capabilities --json` or `robot-docs guide`.
- Unknown flag errors did not teach likely intended flags/commands.
- Help omitted explicit examples/exit-code contracts for shell scripts.

## Post-pass result

- Added a unified dispatcher plus robot triage JSON.
- Added machine-readable capability contracts and in-tool robot guides to every helper command.
- Added near-miss suggestions and corrected-command breadcrumbs.
- Added script-level and in-tree audit regression tests.
## Review follow-up

Oracle review flagged two issues before wrap-up: bare `better-beads` recommendations without a bin shim, and lossy corrected-command breadcrumbs. This pass fixed both by emitting path-qualified dispatcher commands from `triage --json` and rebuilding corrected commands around the exact unknown token. The smoke test now covers arbitrary-CWD dispatcher delegation.

