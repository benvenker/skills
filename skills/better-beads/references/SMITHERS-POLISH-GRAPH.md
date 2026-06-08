# Smithers Polish Graph Experiment

Optional strict-polish lane for Better Beads graph review.

Use it when:

- selected mode is `polish-existing-graph`;
- the user asks for strict, adversarial, multi-agent, durable, or Smithers-backed review;
- operator-dispatch gates warn or block;
- graph shape is ambiguous;
- repeated polish is producing prose churn instead of graph improvement.

Do not use it for:

- simple closeout;
- tiny graph edits;
- routine create-from-ready-plan work;
- repos without explicit Smithers setup.

## Better Beads Commands

These commands are optional. Normal Better Beads authoring, routing, quality, and closeout flows work without Smithers.

```bash
scripts/better-beads smithers check --json
scripts/better-beads smithers polish-graph --json
scripts/better-beads smithers review-export --run-id <run-id> --json
```

`smithers check --json` reports local prerequisites without invoking `bunx` or Smithers. `smithers polish-graph --json` is recommendation-only: it rejects `--apply`, collects local read-only inspection, runs Smithers only when prerequisites are available, and returns a structured Better Beads envelope.

`smithers review-export --json` is post-hoc: it reads completed Smithers polish runs and projects them into review/eval items. It gathers final output, Smithers `scores`, the advisory judge verdict, the current Beads snapshot, and exact inspection commands. It does not mutate Beads or write eval files.

## Setup

Copy the workflow template into a Smithers-enabled target repo:

```bash
mkdir -p .smithers/workflows
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.tsx \
  .smithers/workflows/better-beads-polish-graph.tsx
```

If working from this source checkout instead of an installed skill package, copy from:

```bash
skills/better-beads/smithers-templates/better-beads-polish-graph.tsx
```

Do not run `bunx smithers-orchestrator init` from Better Beads. Smithers setup is an explicit operator action in the target repo.

## Runtime

The Better Beads wrapper uses this Smithers pattern after availability checks pass:

```bash
bunx smithers-orchestrator up \
  .smithers/workflows/better-beads-polish-graph.tsx \
  --run-id <run-id> \
  --input '<json>'

bunx smithers-orchestrator output <run-id> synthesize-polish-plan --json
```

The stable final output node is:

```text
synthesize-polish-plan
```

If `output` returns `null`, the Better Beads wrapper falls back to structured
Smithers inspection instead of scraping pretty chat text:

```bash
bunx smithers-orchestrator node synthesize-polish-plan \
  --run-id <run-id> \
  --format json \
  --filter-output output

bunx smithers-orchestrator events <run-id> \
  --node synthesize-polish-plan \
  --type output \
  --json \
  --limit 100000
```

The events fallback reconstructs ordered `NodeOutput` stdout chunks and accepts
only the last schema-valid polish-plan JSON object. The wrapper reports
`result_source` as `output_row`, `node_validated`, `output_events`, or `none`.
Failures include exact `output`, `inspect`, `node`, `events`, `chat`, `logs`,
and `scores` commands for operator follow-up.

The workflow result is a recommendation, not an applied graph mutation. Review any suggested command or mutation before using `br`.

In the current v1 template, reviewer and synthesis `PiAgent`s load the
`better-beads` skill and allow only PI's read-only built-ins:

```ts
tools: ["read", "grep"]
skill: ["better-beads"]
noExtensions: true
```

The workflow does not allow PI's `write`, `edit`, or `bash` built-ins, so live
polish runs can inspect repo context and Better Beads references without editing
source files, mutating Beads, closing issues, committing, pushing, or
implementing Beads. Future applying polish should use a typed Beads mutation task
or custom tool that allows only reviewed `br update`, dependency, and label
mutations.

The wrapper also passes `localInspection.context_pack` into Smithers. That pack
contains full Bead IDs, titles, statuses, labels, dependency relationships, and
descriptions for the current open graph, plus parsed gate-loop artifact paths and
finding counts. Reviewer prompts treat this context pack as authoritative when
present and require full Bead IDs in recommendations.

The synthesized polish result includes an advisory `judge_verdict`:

```json
{
  "result": "Pass",
  "critique": "The recommendations are precise and use full Bead IDs.",
  "confidence": 0.82
}
```

Treat this as a production signal to calibrate, not as ground truth.

## Scores

This installed Smithers CLI version does not expose a top-level `verify`
command. Use the following verification surfaces instead:

```bash
bunx smithers-orchestrator workflow doctor --format json
bunx smithers-orchestrator graph .smithers/workflows/better-beads-polish-graph.tsx --format json
bunx smithers-orchestrator inspect <run-id> --format json
bunx smithers-orchestrator output <run-id> synthesize-polish-plan --json
bunx smithers-orchestrator node synthesize-polish-plan --run-id <run-id> --format json --filter-output output
bunx smithers-orchestrator events <run-id> --node synthesize-polish-plan --type output --json --limit 100000
bunx smithers-orchestrator scores <run-id> --node synthesize-polish-plan
```

For a completed polish run, inspect Smithers scores directly:

```bash
bunx smithers-orchestrator scores <run-id> --node synthesize-polish-plan
```

Smithers judge scores are normalized from `0` to `1`. They are separate from the manual Better Beads rubric, which uses 0-3 scoring per dimension. Treat Smithers scores as advisory evidence alongside route, quality-gate, BV, and human review.

## Post-Hoc Review

Export completed run projections:

```bash
scripts/better-beads smithers review-export --run-id <run-id> --json \
  > .smithers/evals/review-export.json
```

Open the local review surface:

```text
skills/better-beads/review-ui/posthoc-smithers-review.html
```

The UI loads `review-export.json`, shows one completed run at a time, and lets the reviewer mark `Pass`, `Fail`, or `Defer` with free-text feedback. The review timestamp is automatic. Failure categories are intentionally deferred for v1.

Human labels are authoritative. The exported eval JSONL stores simple scalar fields in `annotations`:

```json
{
  "human_label": "Fail",
  "judge_result": "Pass",
  "judge_disagreement": true
}
```

Richer review data lives under `metadata.human_review`, including feedback text, source run, target node, Bead IDs, and the original judge verdict. These disagreement cases are the calibration set for future judge tuning.

## Evals, Optional

Copy the eval cases into a Smithers-enabled target repo:

```bash
mkdir -p .smithers/evals
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl \
  .smithers/evals/better-beads-polish-graph.eval.jsonl
```

Dry-run the eval plan without executing model work:

```bash
bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --dry-run
```

The packaged Better Beads eval harness includes a fake-bunx dry-run smoke test
for this path:

```bash
skills/better-beads/evals/run_evals.sh smithers
```

Run the optional live smoke suite:

```bash
bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --report .smithers/evals/better-beads-polish-smoke.json \
  --force \
  --format json
```

Evals are advisory and opt-in. They are not part of the default Better Beads dispatcher path, and Better Beads does not expose a `smithers eval-polish` command in v1.

Post-hoc human review is also opt-in. It runs after Smithers completes; it does not use mid-workflow `HumanTask` or `Approval` in v1.

## Authoring Triage Hint

`authoring-triage --json` recommends this lane only under:

```json
{
  "selected_mode": {
    "name": "polish-existing-graph",
    "smithers_recommendation": {
      "available_check_command": "scripts/better-beads smithers check --json",
      "recommended": true,
      "workflow": "better-beads-polish-graph",
      "command": "scripts/better-beads smithers polish-graph --json"
    }
  }
}
```

Other modes omit `smithers_recommendation`. Authoring triage does not check Smithers availability and does not invoke Smithers.

## Safety

- Better Beads Smithers commands are read-only from the repo and Beads perspective.
- The Smithers workflow returns recommendations only.
- Evals are advisory and opt-in.
- Post-hoc human labels are authoritative eval labels.
- Apply any accepted graph change manually through reviewed `br` commands.
- Do not use this lane to create implementation code, mutate Beads, initialize Smithers, install dependencies, or replace the normal route, quality-gate, and dispatch gates.
