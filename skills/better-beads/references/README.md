# Better Beads References

Use these files before creating or polishing Beads. The top-level `SKILL.md` is intentionally short; the taste and examples live here.

## Reading order

1. `GOOD-BEAD-EXAMPLES.md` — copied examples of strong parent, epic, and child beads.
2. `FAILURE-MODES.md` — common ways Beads plans look good but fail agents.
3. `QUALITY-RUBRIC.md` — scoring rubric and hard caps.
4. `BEAD-FORMATTING.md` — BV/terminal-friendly formatting rules.
5. `QUALITY-GATES.md` — deterministic lint gate and hook/CI guidance.
6. `AUTHORING-PROMPTS.md` — prompts for creating, reviewing, and polishing Beads.
7. `PLAN-REVIEW-EXAMPLE.md` — example critique of a plausible but underpowered plan.

## Minimum context rule

Before declaring a bead graph “excellent,” read:

- at least one parent/PR-slice example from `GOOD-BEAD-EXAMPLES.md`, and
- at least one child implementation example from `GOOD-BEAD-EXAMPLES.md`,
- `FAILURE-MODES.md`, and
- `BEAD-FORMATTING.md`.

A good bead is outcome-first, not template-first. It must identify the behavior being targeted, observable success criteria, verification path, non-goals, and relevant current anchors/surfaces. Exact files and symbols are helpful when known, but they are anchors for agent search, not an edit script.

If you have not inspected enough context to name the relevant behavior, contracts/key fields or state transitions, failure behavior, validation approach, and at least one current surface/anchor, the graph cannot score above 24/30.
