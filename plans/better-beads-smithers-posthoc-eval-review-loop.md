# Better Beads Post-Hoc Smithers Eval Review Loop

## Summary

Build a post-hoc review/eval loop for completed Better Beads Smithers polish runs. The normal Smithers run includes an advisory LLM judge signal. After the run, a local review UI lets Ben mark Pass, Fail, or Defer and leave text feedback. Human feedback is ground truth and wins over the LLM judge when they disagree.

## Scope

- Project completed Smithers polish runs into reviewable JSON.
- Show the final polish result, Smithers scores, advisory judge verdict, Bead snapshot, and inspect commands.
- Let the reviewer provide a label and free-text feedback after the workflow has finished.
- Promote reviewed items into Smithers eval-compatible JSONL with scalar annotations and richer `metadata.human_review`.
- Keep v1 post-hoc only; do not add mid-workflow `HumanTask` or `Approval`.

## Implementation Slices

1. Add `better-beads smithers review-export --json` for completed run projection.
2. Add an advisory `judge_verdict` field to the normal Smithers polish result.
3. Build a local static review UI for issue-list style review.
4. Export Pass/Fail/Defer plus notes as eval-compatible cases.
5. Document the operator workflow and Smithers verification surface.

## Data Contract

The review projection gathers:

- source run id, workflow path, and target node;
- final polish result from `output`, `node`, or ordered output events;
- Smithers `scores` output;
- advisory `judge_verdict` and workflow `judge_scores`;
- current Beads snapshot with full descriptions and dependencies;
- exact `inspect`, `output`, `node`, `events`, `chat`, `logs`, and `scores` commands;
- optional human review label, feedback, reviewer, and automatic `reviewed_at`;
- optional eval case where scalar fields live under `annotations` and structured review data lives under `metadata.human_review`.

## Human Review Rules

- `Pass`: the polished graph is good enough to use or the recommendations are precise enough to apply without product invention.
- `Fail`: the result is vague, unsafe, missing full Bead IDs, structurally wrong, or still requires product/architecture decisions.
- `Defer`: the reviewer cannot decide yet; keep the item out of Pass/Fail calibration.
- Human label is authoritative. If the judge says Pass and the human says Fail, the exported eval case records a disagreement for judge calibration.

## Test Plan

```bash
bash skills/better-beads/scripts/test_schemas.sh smithers
bash skills/better-beads/evals/run_evals.sh smithers
bunx smithers-orchestrator workflow doctor --format json
bunx smithers-orchestrator graph .smithers/workflows/better-beads-polish-graph.tsx --format json
ubs <changed files>
br dep cycles --json
```

## Assumptions

- V1 reviews completed runs after the workflow finishes.
- No Beads mutation applicator lands in this slice.
- Reviewer agents remain recommendation-only during polish runs.
- Smithers remains the durable run/eval source of truth; Better Beads only creates projections and promoted eval cases.
