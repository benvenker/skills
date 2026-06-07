# Golden input: create from a ready plan

## Operator prompt

Turn the following implementation plan into a bead graph. No relevant beads
currently exist.

## Graph state

- `.beads` directory: absent
- Relevant open beads: none
- Relevant in-progress beads: none
- Dependency cycles: not applicable

## Plan

Outcome: The CLI should expose `better-beads inspect-plan --json`, returning a
stable JSON envelope that reports whether a plan is ready to become beads.

Anchors: Implement through `skills/better-beads/scripts/better-beads` and the
existing `references/MODE-CREATE-FROM-RAW-PLAN.md` readiness gates. Keep output
compatible with robot callers that already consume JSON surfaces.

Validation: Add shell tests that run the command on a ready fixture and a weak
fixture. Verify exit codes, top-level JSON keys, and missing gate names.

Failure behavior: Missing or unreadable plan paths exit non-zero with stderr
only. Malformed input should report `ready=false` rather than creating beads.

Non-goals: Do not create beads, rewrite existing route logic, or add an
interactive UI.

Parent/child shape: Parent closes when the CLI command, fixtures, tests, and
docs all land. Children should be independently verifiable for command wiring,
JSON envelope, fixture coverage, and documentation.

Dependency order: Land the JSON envelope and fixtures before docs that cite
them; command wiring depends on the envelope shape.
