# Polishing Case Studies

Use these when a polish pass is producing more text but not more graph truth.
The goal is to decide whether a finding is contract detail for the current bead
or a new independently reviewable behavior.

## Case: long child warning that revealed a missing split

### Signal

A child implementation bead was strict in substance but triggered
`long-child-contract`. The extra length came from adding a detailed failure
contract discovered during code/context review:

- custom backend cleanup must not reject an otherwise successful search;
- cleanup failure should emit a stable warning;
- cleanup failure alone must not masquerade as an all-sources search failure;
- the original search/create error should stay primary if both search and
  cleanup fail.

The first instinct was to compress wording until the gate stopped warning.
That would have made the bead shorter while leaving the execution graph less
true.

### Split test

Before compacting, ask:

- Does the long section describe a separate observable system truth?
- Can that behavior land, be reviewed, and be verified before the original
  child?
- Does splitting it reduce the original child to a clearer behavior atom?
- Would the split change dependency edges, parent ordering, or the true
  `ready-for-agent` frontier?

In this case, every answer was yes. Cleanup failure handling was a standalone
behavior contract, not just more prose for the fanout implementation bead.

### What changed

Before:

```text
parent search-pipeline lane
- fanout implementation (ready, long, also owns cleanup failure behavior)
- source coverage gap (ready)
```

After:

```text
parent search-pipeline lane
- backend cleanup failure handling (ready)
- fanout implementation (depends on cleanup, no longer ready)
- source coverage gap (ready)
```

The polishing pass made material graph changes:

- created a new child bead for backend cleanup failure handling;
- added parent-to-new-child and fanout-to-new-child dependency edges;
- moved the cleanup warning/error-preservation contract into the new bead;
- reduced the fanout bead to its own concurrency, merge, cap, and warning
  behavior;
- updated the parent child order so cleanup lands before fanout;
- removed `ready-for-agent` from the now-blocked fanout bead;
- ran graph validation so the frontier showed the new cleanup bead and the
  independent coverage bead, not the blocked fanout work.

### Result

The important improvement was not satisfying a character threshold. The
important improvement was that the graph now told the truth:

- cleanup failure handling was independently implementable and reviewable;
- fanout implementation had a smaller, clearer contract;
- the parent closure contract named the actual order of work;
- `ready-for-agent` labels matched the real implementation frontier.

## Rule of thumb

For long-child warnings, split-test first and compact second.

Compact when the bead is long because sections repeat, examples are verbose, or
anchors can be grouped more cleanly.

Split when the length is caused by an independently observable behavior,
failure contract, data contract, runtime surface, or dependency edge that can
land and be verified on its own.
