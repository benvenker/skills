# Better Beads Evals

Executable evals exercise Better Beads operator contracts without network
access, LLM calls, or dependence on the caller's live `.beads` graph.

## Routing

Run the routing truth-table eval:

```bash
bash skills/better-beads/evals/run_evals.sh routing
```

The routing suite loads `evals/cases/routing_cases.json`, creates a temporary
repository for each A1-A14 case, prepends a fake `br` shim to `PATH`, and runs
`scripts/bead_route.sh --repo TMP --json` with optional plan files. It compares
the recommended mode, selected graph-state fields, plan-readiness status, and
required next-step or warning substrings.

Cases are data first. To update routing expectations, edit
`evals/cases/routing_cases.json` and keep the case IDs in A1-A14 order so the
runner can detect missing or duplicate truth-table coverage.

## Quality

Run the quality-gate drift eval:

```bash
bash skills/better-beads/evals/run_evals.sh quality
```

The quality suite loads `test/fixtures/example-graph.json`, writes a temporary
`.beads/issues.jsonl`, runs `scripts/bead_quality_gate.py --json`, and compares
deterministic summary fields against
`evals/baselines/quality_gate_baseline.json`.

The baseline tracks exit code, issue count, hard finding counts, operator
blocking counts, split-review counts, a sorted finding-code multiset, and
selected finding fields. It intentionally does not compute scores.

To intentionally accept quality-gate drift, regenerate the baseline directly:

```bash
python3 skills/better-beads/evals/quality_eval.py --update-baseline
```

`run_evals.sh` never updates baselines. With no suite argument it runs the
default evals: routing first, then quality.
