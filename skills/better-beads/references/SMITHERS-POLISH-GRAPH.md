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
```

`smithers check --json` reports local prerequisites without invoking `bunx` or Smithers. `smithers polish-graph --json` is recommendation-only: it rejects `--apply`, collects local read-only inspection, runs Smithers only when prerequisites are available, and returns a structured Better Beads envelope.

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

The workflow result is a recommendation, not an applied graph mutation. Review any suggested command or mutation before using `br`.

## Scores

For a completed polish run, inspect Smithers scores directly:

```bash
bunx smithers-orchestrator scores <run-id> --node synthesize-polish-plan
```

Smithers judge scores are normalized from `0` to `1`. They are separate from the manual Better Beads rubric, which uses 0-3 scoring per dimension. Treat Smithers scores as advisory evidence alongside route, quality-gate, BV, and human review.

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
- Apply any accepted graph change manually through reviewed `br` commands.
- Do not use this lane to create implementation code, mutate Beads, initialize Smithers, install dependencies, or replace the normal route, quality-gate, and dispatch gates.
