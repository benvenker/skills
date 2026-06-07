# Golden expected: closeout an implementation turn

## Route

- Recommended mode: `closeout`
- Reason: relevant work is `in_progress` and no open beads remain.

## Minimum response assertions

- Inspects the in-progress bead before status mutation.
- Chooses exactly one truthful outcome: close, reopen, or block.
- If closing, includes what changed, verification command, result summary,
  commit SHA or explicit uncommitted note, and deferred follow-up if needed.
- Runs the closeout guard unless explicitly opted out.
- Does not leave the relevant bead in `in_progress` at turn end.

## Harness note

The expected action is close only if the supplied evidence satisfies the bead.
Otherwise, reopen or block with a concrete reason.
