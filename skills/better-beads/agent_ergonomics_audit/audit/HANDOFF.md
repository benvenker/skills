# HANDOFF — better-beads CLI agent-ergonomics pass 1

## What changed

- Added `scripts/better-beads` dispatcher as the first agent-readable CLI entrypoint.
- Added `capabilities --json`, `robot-docs guide`, `--robot-help`, and `--version` surfaces to the dispatcher and existing helper scripts.
- Added `triage --json` to return quick reference and recommended commands in one call.
- Added unknown-option/unknown-command suggestions with corrected-command breadcrumbs.
- Added `scripts/test_cli_robot_surfaces.sh` and audit regression test `audit/regression_tests/R-001__cli_robot_surfaces.test.sh`.

## Validation run

```bash
python3 -m py_compile skills/better-beads/scripts/bead_quality_gate.py skills/better-beads/scripts/test_bead_quality_gate.py
python3 skills/better-beads/scripts/test_bead_quality_gate.py
bash skills/better-beads/scripts/test_bead_gate_loop.sh
bash skills/better-beads/scripts/test_cli_robot_surfaces.sh
TARGET=skills/better-beads bash skills/better-beads/agent_ergonomics_audit/audit/regression_tests/R-001__cli_robot_surfaces.test.sh
```

All passed.

## Deferred proposals

- If the skills installer supports exposing per-skill scripts as bin shims, expose `better-beads` as the installed command name.
- Add CI coverage for `scripts/test_cli_robot_surfaces.sh`.
## Review follow-up

Oracle review flagged two issues before wrap-up: bare `better-beads` recommendations without a bin shim, and lossy corrected-command breadcrumbs. This pass fixed both by emitting path-qualified dispatcher commands from `triage --json` and rebuilding corrected commands around the exact unknown token. The smoke test now covers arbitrary-CWD dispatcher delegation.
