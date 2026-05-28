# Semantic Bead Review Gate

Use this after the deterministic gate when deciding whether a Beads graph is actually ready for implementation.

Do not run this as a mandatory normal pre-commit hook unless the project explicitly accepts slow/networked hooks. Prefer manual review, CI advisory, or a dedicated `beads-polish` command.

## Inputs to collect

```bash
br list --json > /tmp/beads-list.json
br dep cycles --json > /tmp/beads-cycles.json
bv --robot-plan > /tmp/bv-plan.json
bv --robot-insights > /tmp/bv-insights.json
python3 .agents/skills/better-beads/scripts/bead_quality_gate.py --json > /tmp/bead-quality-gate.json
```

## Judge prompt

```text
You are reviewing a Beads graph before fungible coding agents implement it.
Be blunt. Do not reward nice headings. Determine whether the graph is genuinely
ready or merely well-formatted.

Read these project artifacts:
- br list JSON
- br dep cycles JSON
- bv --robot-plan JSON
- bv --robot-insights JSON
- deterministic bead_quality_gate JSON

Use these references:
- GOOD-BEAD-EXAMPLES.md
- FAILURE-MODES.md
- QUALITY-RUBRIC.md
- BEAD-FORMATTING.md

Review questions:
1. Does each bead lead with a clear behavior/outcome rather than implementation ceremony?
2. Are success criteria observable and behavior-based?
3. Is verification strong enough to prove the behavior, not just compile the repo?
4. Does the bead state TDD/behavior-test intent where appropriate without writing the test implementation?
5. Are non-goals and side-effect limits clear enough to prevent adjacent work?
6. Are failure modes specific and actionable?
7. Are current anchors/surfaces/contracts/key fields named without becoming a brittle edit script?
8. Are any beads too large for one safe implementation pass?
9. Are any beads too small to be meaningful outcomes alone?
10. Does any bead depend on a script/test/artifact that does not exist but is not explicitly in scope to create?
11. Does the dependency graph reflect real implementation order?
12. Are blocked beads mislabeled as ready?
13. Would a fresh agent still have to invent behavior, contracts, failure handling, or verification?

Return JSON only:

{
  "verdict": "pass" | "pass_with_warnings" | "block",
  "summary": "short blunt summary",
  "graph_score": 0-30,
  "beads": [
    {
      "id": "...",
      "title": "...",
      "score": 0-30,
      "action": "keep" | "split" | "merge" | "deepen" | "defer" | "delete",
      "blockers": ["..."],
      "required_changes": ["..."]
    }
  ],
  "graph_changes": [
    {
      "type": "add_dependency" | "remove_dependency" | "split_bead" | "merge_beads" | "rename" | "relabel",
      "details": "..."
    }
  ],
  "ready_for_swarm": true | false
}
```

## Blocking criteria

Return `block` if any of these are true:

- A bead references a smoke script or verification artifact that does not exist and does not explicitly require creating it.
- A bead contains multiple independent implementation levers without clear reason.
- A child bead has no observable outcome or success criteria.
- A child bead would require the agent to design behavior, API/data contract, or failure handling from scratch.
- The graph claims ready-for-agent while key architecture decisions or dependency blockers remain unresolved.
- The only validation is generic build/test commands.
- The dependency graph allows parallel work on the same single-owner surface.

## Recommended policy

- Deterministic gate errors: block commit.
- Deterministic gate warnings: advisory by default; block only in explicit polish/strict workflows.
- Semantic gate verdict `block`: do not unleash agents.
- Semantic gate `pass_with_warnings`: okay for one careful agent, not a swarm.
- Semantic gate `pass`: okay for multi-agent implementation.
