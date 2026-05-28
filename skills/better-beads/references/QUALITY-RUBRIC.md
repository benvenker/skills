# Bead Quality Rubric

Score each bead 0–3 on the 10 quality dimensions, then apply the presentation gate.

## Quality dimensions

1. **Outcome clarity** — one concrete behavior or system truth becomes true when closed.
2. **Success criteria** — closure conditions are observable and behavior-based.
3. **Verification** — targeted tests, commands, scripts, or smoke observations prove the behavior.
4. **Scope boundaries** — scope and non-goals prevent adjacent work.
5. **Failure behavior** — important errors, partial success states, and side-effect limits are explicit.
6. **Grounding** — current anchors/surfaces, contracts, key fields, or likely seams are named without becoming a brittle edit script.
7. **Implementation sizing** — reviewable child-task-sized; not a mega-bead or checklist crumb.
8. **Dependency correctness** — blockers, ordering, and unblocks are explicit.
9. **Fungibility** — a fresh agent can implement it without the original chat/plan.
10. **Closure evidence** — the bead says what evidence should appear in comments/close reason.

## Presentation gate

A bead can be correct but still painful to use. Before calling it done, check BV readability:

- short sections,
- bullets instead of prose walls,
- grouped files/symbols,
- fenced commands,
- compact data contracts,
- no long inline lists.

## Hard score caps

These caps prevent rubric laundering.

- Max **16/30** if the bead lacks an outcome/goal.
- Max **18/30** if success criteria are not observable behaviors.
- Max **18/30** if the bead lacks scope boundaries or non-goals.
- Max **20/30** if it has no validation commands, behavior-test requirement, or smoke observations.
- Max **21/30** if failure behavior is absent for implementation work.
- Max **22/30** if it has no grounding in current surfaces, anchors, contracts, key fields, or likely seams.
- Max **24/30** if the author did not inspect enough context to name behavior, verification, failure behavior, and at least one current anchor/surface.
- Max **24/30** if every child uses only generic validation like `pnpm build`.
- Max **25/30** if dependencies are described in prose but not represented as explicit `br dep add` edges.
- Max **26/30** if the bead is implementable but parallel safety is unknown for a multi-agent graph.
- Max **26/30** if a child bead combines multiple high-diff-risk dimensions that could be reviewed as independent behavior atoms.
- Max **27/30** if the bead dictates exact implementation/test mechanics when behavior-level constraints would suffice.

A bead below **24/30** is not ready for a swarm.
A bead at **28–30/30** should feel boringly executable and easy to scan in `bv`.

## Parent / PR-slice bead must answer

- Why does this lane exist?
- What final decisions must be preserved?
- Is this a closure contract or directly implementable?
- What are the child beads and intended order?
- What closes the parent?
- What validation proves the lane works?
- What can run in parallel, and what must be single-owner?

## Child implementation bead must answer

- What behavior or system truth should become true?
- What observable success criteria prove it?
- What verification path should be used, ideally TDD/behavior-first?
- What is explicitly out of scope?
- What failure behavior or side-effect limits matter?
- What current anchors/surfaces/contracts/key fields should the agent inspect first?
- What should the close reason include?
- Will the likely PR/commit be reviewable without weakening tests?
- Will the description scan cleanly in a terminal or `bv` detail view?

## Review procedure

1. Read the bead as if you are a fresh agent with no chat history.
2. Try to start implementation mentally.
3. Mark every place where you would have to invent behavior, success criteria, failure handling, contracts, anchors, or verification.
4. Mark every child that combines multiple high-diff-risk dimensions: new module, data contract, security/access behavior, runtime route, response compatibility, parity/docs, or broad harness work.
5. Apply hard caps before assigning a score.
6. Check `BEAD-FORMATTING.md` for terminal/BV readability.
7. Revise until the graph is behaviorally executable, reviewable, and scannable, not merely well-formatted.
