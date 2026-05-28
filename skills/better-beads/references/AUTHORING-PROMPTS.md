# Authoring Prompts

## Create beads from a plan

```text
Create Beads as behavioral execution contracts for fungible coding agents.

Before creating beads, inspect enough of the codebase to name the targeted
behavior, observable success criteria, verification approach, failure behavior,
and current anchors/surfaces/contracts/key fields. If you have not done that,
do not claim the graph is excellent.

Read the Better Beads references first:
- GOOD-BEAD-EXAMPLES.md
- FAILURE-MODES.md
- QUALITY-RUBRIC.md
- BEAD-FORMATTING.md

Do not merely make the graph “comprehensive and granular.” Design a PR-shaped
implementation graph. Prefer vertical tracer-bullet beads for user-visible or
behavior-visible outcomes. Use foundation beads only when shared substrate is
truly required. Do not create one bead per checklist bullet.

Every bead must be self-contained enough that a fresh agent can implement it
without reading the original plan or chat.

For each parent/PR-slice bead, include outcome/background, closure contract,
addressable child beads and intended order, scope, non-goals, parent success
criteria, validation, and parallelization notes.

For each child/implementation bead, include outcome, success criteria, scope and
non-goals, failure behavior, validation, and current anchors/surfaces/contracts.
Use TDD intent where applicable: require behavior/contract/regression tests, but
do not write the test implementation inside the bead.

Use known files and symbols as starting anchors, not as brittle edit scripts.
Agents should verify current code owners before editing because surfaces may move.

Format descriptions for BV/terminal readability: short sections, bullets instead
of long paragraphs, grouped anchors/surfaces, fenced commands where useful,
compact contracts, and no long inline lists.

After mutation, validate with:
- br dep cycles --json
- bv --robot-insights
- bv --robot-plan

Use only br for mutations and br --json / bv --robot-* for inspection.
```

## Polish an existing graph

```text
Review this Beads graph as if you are about to unleash fungible agents on it.
Do not praise formatting. Find ambiguity that would cause implementation drift.

Use the hard caps in QUALITY-RUBRIC.md. In particular, cap any bead at 24/30 if
it lacks behavioral codebase evidence: current anchors/surfaces, contracts/key
fields or state transitions, failure behavior, and verification. Also apply
BEAD-FORMATTING.md so the bead is readable in BV.

Look for:
- checklist sludge
- mega-beads
- false verticality
- generic validation
- missing behavioral success criteria
- missing data contracts or key state transitions where relevant
- missing current anchors/surfaces
- unclear closure evidence
- unsafe parallelism
- parent beads that are not closure contracts

Revise the graph in plan space first. Then use br to mutate beads only after the
revised graph is clearly better.
```

## Review a proposed plan without mutating beads

```text
Give blunt feedback on this proposed Beads plan. Do not mutate the database.

Classify each bead as:
- keep
- split
- merge
- deepen
- delete/defer

For each weak bead, explain which failure mode it hits from FAILURE-MODES.md and
what concrete details are missing. Apply the QUALITY-RUBRIC.md hard caps. If the
plan claims 28–30/30, verify whether it earned that score.

End with the graph shape you would actually create.
```

## Closure evidence prompt

```text
Before closing the bead, add a short comment or close reason with:
- what changed
- exact verification commands run
- test/smoke result summary
- commit SHA or artifact path if available
- any deferred or rejected follow-up captured as another bead
```
