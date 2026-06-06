# Pass 1 Playbook — better-beads CLI surfaces

Applied recommendations:

1. **R-001** Add `scripts/better-beads` as the first-try dispatcher with `capabilities --json`, `triage --json`, and `robot-docs guide`.
2. **R-002** Add robot self-documentation surfaces to `bead_quality_gate.py`, `bead_gate_loop.sh`, and `bead_closeout_guard.sh`.
3. **R-003** Add useful near-miss hints for unknown flags/commands.

Deferred/proposed for future pass:

- Optionally package `scripts/better-beads` as an installable bin name when the public skills installer supports per-skill script shims.
- Add CI wiring that runs `scripts/test_cli_robot_surfaces.sh` for this skill package.
