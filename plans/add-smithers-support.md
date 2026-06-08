# Implementation Plan: Optional Smithers Strict-Polish Workflow + Evals Foundation

## Goal

Add one optional Smithers-backed experiment to Better Beads: **strict polish review for existing Beads graphs**, plus a lightweight Smithers eval foundation.

The main command remains:

```bash
skills/better-beads/scripts/better-beads smithers polish-graph --json
```

It should run a copyable Smithers workflow template when Smithers is available and return a structured recommendation for improving the current Beads graph.

The workflow must be **recommendation-only**. It must not mutate Beads, files, dependencies, labels, statuses, or Git state.

The eval foundation should add:

```text
- a schemaAdherenceScorer on the synthesis task;
- a copyable Smithers eval case file;
- documentation for dry-run and live eval commands;
- fake-bunx dry-run test coverage.
```

Normal Better Beads behavior must remain unchanged when Smithers is missing.

---

## Non-goals

Do not create Beads.

Do not mutate Beads.

Do not make Smithers required.

Do not run Smithers from `authoring-triage`.

Do not run `bunx smithers-orchestrator init`.

Do not auto-install Bun, Smithers, or dependencies.

Do not integrate Smithers Canvas.

Do not implement create-from-raw-plan, closeout, implementation, or lane-swarm workflows.

Do not use `GatherAndSynthesize` in v1.

Do not add LLM-judge scorers in v1.

Do not run live Smithers evals in CI.

Do not make evals part of `smithers polish-graph`.

Do not parse `scores` into the Better Beads JSON envelope in v1.

---

## Files to add or modify

```text
skills/better-beads/scripts/better-beads
skills/better-beads/references/SMITHERS-POLISH-GRAPH.md
skills/better-beads/smithers-templates/better-beads-polish-graph.tsx
skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl
skills/better-beads/schemas/better-beads-smithers-check-v1.schema.json
skills/better-beads/schemas/better-beads-smithers-polish-graph-v1.schema.json
skills/better-beads/scripts/test_schemas.sh
skills/better-beads/scripts/test_cli_robot_surfaces.sh
skills/better-beads/manifest.json
```

Also add `smithers` to the `KNOWN_COMMANDS` array in `scripts/better-beads`.

---

## CLI surface

Add:

```bash
scripts/better-beads smithers check --json
scripts/better-beads smithers polish-graph --json
```

Both commands must require `--json`. If omitted, print usage to stderr and exit `2`.

Both commands should support:

```bash
--repo PATH
```

`smithers polish-graph` should also support:

```bash
--request TEXT
```

When `--request` is provided, use it as the Smithers workflow input `request`. Otherwise use:

```text
Polish existing Better Beads graph before implementation dispatch.
```

Reject `--apply` in v1. If passed, exit `2` with:

```text
smithers polish-graph is recommendation-only in v1; apply mutations manually through br after review.
```

Do **not** add a `smithers eval-polish` Better Beads command in v1. Evals should be documented and test-smoked through fake `bunx`, but not exposed as another dispatcher surface yet.

---

## `smithers check --json`

This command is read-only. It should not call Smithers.

Check:

```text
- `bunx` exists on PATH;
- `.smithers/` exists in the target repo;
- `.smithers/workflows/better-beads-polish-graph.tsx` exists.
```

Unavailable output:

```json
{
  "tool": "better-beads",
  "schema": "better-beads-smithers-check-v1",
  "available": false,
  "repo": "/absolute/repo/path",
  "checks": {
    "bunx": false,
    "smithers_dir": false,
    "polish_graph_workflow": false
  },
  "commands": {
    "polish_graph": null
  },
  "setup_hint": "Install Bun, initialize Smithers explicitly, and copy the Better Beads polish workflow template into .smithers/workflows/."
}
```

Available output:

```json
{
  "tool": "better-beads",
  "schema": "better-beads-smithers-check-v1",
  "available": true,
  "repo": "/absolute/repo/path",
  "checks": {
    "bunx": true,
    "smithers_dir": true,
    "polish_graph_workflow": true
  },
  "commands": {
    "polish_graph": "scripts/better-beads smithers polish-graph --json"
  },
  "setup_hint": null
}
```

---

## `smithers polish-graph --json`

This command is read-only from Better Beads’ perspective.

It should:

1. Parse `--repo PATH`, optional `--request TEXT`, and required `--json`.
2. Run the same availability checks as `smithers check`.
3. If unavailable, return a valid JSON envelope with `available: false`.
4. If available, collect local Better Beads inspection data.
5. Run the Smithers workflow with `bunx smithers-orchestrator up`.
6. Fetch the explicit final node output with:

```bash
bunx smithers-orchestrator output "$run_id" synthesize-polish-plan --json
```

7. Optionally run:

```bash
bunx smithers-orchestrator inspect "$run_id" --format json
```

8. Return local inspection, command statuses, parsed output, and any errors.

Smithers docs say `bunx smithers-orchestrator` is the standard invocation form, `up` starts/resumes workflow execution and accepts `--run-id` / `--input`, `--input` is capped at 1 MiB, and `output <runId> <nodeId>` prints a node output row with JSON enabled by default. ([Smithers][3]) ([Smithers][3]) ([Smithers][3])

The final node id is:

```text
synthesize-polish-plan
```

This node id must be explicitly defined in the workflow template.

---

## Smithers command pattern

Use:

```bash
bunx smithers-orchestrator up \
  .smithers/workflows/better-beads-polish-graph.tsx \
  --run-id "$run_id" \
  --input "$input_json"
```

Then:

```bash
bunx smithers-orchestrator output "$run_id" synthesize-polish-plan --json
```

Do not use `up --format json`.

If `output` exits nonzero:

```text
- set `smithers.output.stdout_json` to null;
- record exit code, stderr, stdout bytes, and parse error if any;
- still attempt `inspect`;
- set `result` to null unless the result can be safely extracted from `inspect`.
```

Implement a conservative extractor:

```text
extract_polish_result(stdout_json):
  - if stdout_json itself has verdict/summary/judge_scores, use it;
  - else if stdout_json.output has that shape, use stdout_json.output;
  - else if stdout_json.value has that shape, use stdout_json.value;
  - else if stdout_json.data has that shape, use stdout_json.data;
  - else return null and record "could not locate polish result in output row".
```

Exit code `3` is not expected because this workflow should not include `Approval`, `HumanTask`, timers, or wait nodes. Still handle it defensively as “run did not complete normally” and preserve diagnostics. Smithers’ CLI docs define exit code `3` as `up` ending in waiting-approval, waiting-event, or waiting-timer. ([Smithers][3])

---

## Smithers input

Build compact JSON input:

```json
{
  "request": "Polish existing Better Beads graph before implementation dispatch.",
  "repo": "/absolute/repo/path",
  "apply": false,
  "strict": true,
  "localInspection": {
    "authoringTriage": {},
    "gateLoop": {},
    "errors": []
  }
}
```

If `--request TEXT` is passed, it overrides the default `request`.

If local inspection is too large, truncate and mark it:

```json
{
  "truncated": true,
  "reason": "payload exceeded safe Smithers input size"
}
```

---

## Local inspection collection

Collect best-effort read-only context before invoking Smithers:

```bash
scripts/better-beads authoring-triage --repo "$repo" --json
scripts/better-beads gate-loop --repo "$repo" --operator-dispatch --json
```

This recursively calls the dispatcher and can spawn many subprocesses. That is acceptable for this optional strict lane; document the cost.

If either command fails, capture:

```text
- command;
- exit code;
- stdout byte count;
- stderr snippet;
- parse error;
- parsed JSON if available.
```

Continue if enough context exists.

Never run bare `bv`.

Never call `br create`, `br update`, `br close`, or mutation commands.

---

## `smithers polish-graph` return shape

Unavailable:

```json
{
  "tool": "better-beads",
  "schema": "better-beads-smithers-polish-graph-v1",
  "available": false,
  "repo": "/absolute/repo/path",
  "workflow_path": ".smithers/workflows/better-beads-polish-graph.tsx",
  "run_id": null,
  "inspect_command": null,
  "output_command": null,
  "scores_command": null,
  "local_inspection": {
    "authoring_triage": null,
    "gate_loop": null,
    "errors": []
  },
  "smithers": {
    "up": null,
    "output": null,
    "inspect": null
  },
  "result": null,
  "error": "Smithers unavailable: bunx missing, .smithers missing, or workflow template not installed."
}
```

Success:

```json
{
  "tool": "better-beads",
  "schema": "better-beads-smithers-polish-graph-v1",
  "available": true,
  "repo": "/absolute/repo/path",
  "workflow_path": ".smithers/workflows/better-beads-polish-graph.tsx",
  "run_id": "better-beads-polish-graph-20260608-120102-a1b2c3",
  "inspect_command": "bunx smithers-orchestrator inspect better-beads-polish-graph-20260608-120102-a1b2c3 --format json",
  "output_command": "bunx smithers-orchestrator output better-beads-polish-graph-20260608-120102-a1b2c3 synthesize-polish-plan --json",
  "scores_command": "bunx smithers-orchestrator scores better-beads-polish-graph-20260608-120102-a1b2c3 --node synthesize-polish-plan",
  "local_inspection": {
    "authoring_triage": {},
    "gate_loop": {},
    "errors": []
  },
  "smithers": {
    "up": {
      "command": ["bunx", "smithers-orchestrator", "up", ".smithers/workflows/better-beads-polish-graph.tsx", "--run-id", "better-beads-polish-graph-20260608-120102-a1b2c3", "--input", "<redacted-or-shortened-json>"],
      "exit_code": 0,
      "stdout_bytes": 0,
      "stderr": ""
    },
    "output": {
      "command": ["bunx", "smithers-orchestrator", "output", "better-beads-polish-graph-20260608-120102-a1b2c3", "synthesize-polish-plan", "--json"],
      "exit_code": 0,
      "stdout_json": {},
      "stderr": "",
      "parse_error": null
    },
    "inspect": {
      "command": ["bunx", "smithers-orchestrator", "inspect", "better-beads-polish-graph-20260608-120102-a1b2c3", "--format", "json"],
      "exit_code": 0,
      "stdout_json": {},
      "stderr": "",
      "parse_error": null
    }
  },
  "result": {
    "verdict": "needs_mutation",
    "summary": "Short synthesis.",
    "recommended_mutations": [],
    "ready_frontier": [],
    "blocked_dispatch_reasons": [],
    "judge_scores": {
      "behavior_contract_quality": 0.8,
      "implementation_fungibility": 0.7,
      "dependency_correctness": 0.9,
      "reviewability": 0.8,
      "dispatch_readiness": 0.7
    }
  },
  "error": null
}
```

`score_command` is advisory only. Do not run it inside the wrapper in v1. Smithers docs expose `scores <runId>` for scorer results, and also allow filtering by node. ([Smithers][3])

Judge scores are normalized **0–1**, intentionally different from the manual Better Beads rubric’s 0–3 per-dimension scoring. Document this in the schema and `SMITHERS-POLISH-GRAPH.md`.

Use neutral bead id examples:

```json
"bead_id": "<bead-id>"
```

or:

```json
"bead_id": "42"
```

Do not use `bd-...`.

---

## Smithers workflow template

Add:

```text
skills/better-beads/smithers-templates/better-beads-polish-graph.tsx
```

Copy into target repos with:

```bash
mkdir -p .smithers/workflows
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.tsx \
  .smithers/workflows/better-beads-polish-graph.tsx
```

### Workflow design

Use explicit `Parallel` plus explicit `Task id="synthesize-polish-plan"`.

Do **not** use `GatherAndSynthesize` in v1. The reason is not that `GatherAndSynthesize` is bad; it is that the wrapper needs a stable node id for `smithers output`, and the generated synthesis child id of the composite component is not safe to assume in the first slice.

Workflow shape:

```text
Workflow
  Sequence
    Parallel id="polish-review"
      Task id="behavior-contract-review"
      Task id="implementation-agent-review"
      Task id="dependency-reviewability-review"
    Task id="synthesize-polish-plan"
```

The final task id must be:

```text
synthesize-polish-plan
```

### Required imports

The template should import the schema scorer:

```ts
import { schemaAdherenceScorer } from "smithers-orchestrator/scorers";
```

Smithers docs show `schemaAdherenceScorer` imported from `smithers-orchestrator/scorers` and attached through a `scorers` prop; scorers run after completion and do not block workflow execution. ([Smithers][1])

### Required Zod schemas

Define schemas before prompts.

Minimum schema sketch:

```ts
const inputSchema = z.object({
  request: z.string().default("Polish existing Better Beads graph before implementation dispatch."),
  repo: z.string().default("."),
  apply: z.boolean().default(false),
  strict: z.boolean().default(true),
  localInspection: z.unknown().optional(),
});

const reviewerKindSchema = z.enum([
  "behavior-contract",
  "implementation-agent",
  "dependency-reviewability",
]);

const reviewerFindingSchema = z.object({
  reviewer: reviewerKindSchema,
  summary: z.string(),
  blockers: z.array(z.string()).default([]),
  warnings: z.array(z.string()).default([]),
  recommendedChanges: z.array(z.object({
    kind: z.enum([
      "keep",
      "deepen",
      "split",
      "merge",
      "add_dependency",
      "remove_dependency",
      "add_label",
      "remove_label",
      "close_unnecessary",
      "defer",
    ]),
    beadId: z.string().optional(),
    titleOrScope: z.string().optional(),
    reason: z.string(),
  })).default([]),
});

const recommendedMutationSchema = z.object({
  kind: z.enum([
    "update_description",
    "split",
    "merge",
    "add_dependency",
    "remove_dependency",
    "add_label",
    "remove_label",
    "close_unnecessary",
    "defer",
  ]),
  bead_id: z.string().optional(),
  reason: z.string(),
  command: z.string().nullable().default(null),
});

const polishPlanSchema = z.object({
  verdict: z.enum(["ready", "needs_mutation", "blocked"]),
  summary: z.string(),
  recommended_mutations: z.array(recommendedMutationSchema).default([]),
  ready_frontier: z.array(z.string()).default([]),
  blocked_dispatch_reasons: z.array(z.string()).default([]),
  judge_scores: z.object({
    behavior_contract_quality: z.number().min(0).max(1),
    implementation_fungibility: z.number().min(0).max(1),
    dependency_correctness: z.number().min(0).max(1),
    reviewability: z.number().min(0).max(1),
    dispatch_readiness: z.number().min(0).max(1),
  }),
});
```

Register these with `createSmithers`.

The output key for the final synthesis task should be:

```ts
outputs.polishPlan
```

This matters for eval cases.

### Agent binding

Use one reviewer agent and one synthesizer agent.

Use a simple env-var model fallback:

```ts
const model =
  process.env.BETTER_BEADS_SMITHERS_MODEL ??
  process.env.SMITHERS_MODEL ??
  "anthropic/claude-sonnet-4.6";
```

Keep provider/model setup explicit. Do not require three different providers in v1.

### Reviewer prompts

Use three independent reviewer tasks.

```text
behavior-contract-review:
  Check outcome, success criteria, non-goals, failure behavior, validation, grounding, and closure evidence.

implementation-agent-review:
  Read as a fresh coding agent. Identify where implementation would require product, architecture, data-contract, failure-handling, or verification invention.

dependency-reviewability-review:
  Check parent closure contracts, child ordering, dependency correctness, ready-for-agent truth, reviewable atomicity, and unsafe parallelism.
```

Each reviewer returns `reviewerFindingSchema`.

### Synthesis task

`Task id="synthesize-polish-plan"` should read all three reviewer outputs and produce `polishPlanSchema`.

Attach the scorer to this task:

```tsx
<Task
  id="synthesize-polish-plan"
  output={outputs.polishPlan}
  agent={synthesizer}
  scorers={{
    schema: { scorer: schemaAdherenceScorer() },
  }}
>
  ...
</Task>
```

The synthesis prompt should say:

```text
Combine the three reviews into one Better Beads polish recommendation.

Prefer graph-shape fixes over prose churn.

Classify weak beads as keep, split, merge, deepen, defer, delete/close unnecessary, relabel, or dependency repair.

Do not mutate Beads.

Do not invent repo file changes.

Do not produce implementation code.

Return only JSON matching the polish plan schema.
```

---

## Smithers eval case template

Add:

```text
skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl
```

Copy into target repos with:

```bash
mkdir -p .smithers/evals
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl \
  .smithers/evals/better-beads-polish-graph.eval.jsonl
```

Use 2–3 smoke cases. These are **template cases**, not guaranteed CI gates. They should be simple enough to exercise the workflow and output shape.

Use output assertions keyed by output name:

```jsonl
{"id":"ready-graph-smoke","input":{"request":"Smoke case: inspect this already well-formed Better Beads graph and return ready if no blockers are present.","repo":".","apply":false,"strict":true,"localInspection":{"authoringTriage":{"selected_mode":{"name":"polish-existing-graph"},"graph_inspection":{"active_count":1,"ready_count":1,"blocked_count":0}},"gateLoop":{"verdict":"pass","findings":[]},"errors":[]}},"expected":{"status":"finished","outputContains":{"polishPlan":{"verdict":"ready"}}},"annotations":{"area":"better-beads","lane":"polish-graph","kind":"smoke"}}
{"id":"needs-mutation-smoke","input":{"request":"Smoke case: inspect this graph with a broad bucket and return needs_mutation with at least one recommended mutation.","repo":".","apply":false,"strict":true,"localInspection":{"authoringTriage":{"selected_mode":{"name":"polish-existing-graph"},"graph_inspection":{"active_count":3,"ready_count":1,"blocked_count":0}},"gateLoop":{"verdict":"block","findings":[{"code":"broad-surface-bucket","bead_id":"42","message":"Child bead covers multiple behaviors."}]},"errors":[]}},"expected":{"status":"finished","outputContains":{"polishPlan":{"verdict":"needs_mutation"}}},"annotations":{"area":"better-beads","lane":"polish-graph","kind":"smoke"}}
{"id":"blocked-dispatch-smoke","input":{"request":"Smoke case: inspect this graph with dependency-cycle risk and return blocked or needs_mutation.","repo":".","apply":false,"strict":true,"localInspection":{"authoringTriage":{"selected_mode":{"name":"polish-existing-graph"},"graph_inspection":{"active_count":4,"ready_count":0,"blocked_count":1}},"gateLoop":{"verdict":"block","blocked_reasons":["dependency-cycles-present"]},"errors":[]}},"expected":{"status":"finished"},"annotations":{"area":"better-beads","lane":"polish-graph","kind":"smoke"}}
```

The first two cases assert verdicts. The third only asserts `finished` because exact verdict may reasonably be `blocked` or `needs_mutation` depending on the model’s synthesis. This keeps the template useful without making it artificially brittle.

Smithers eval docs support JSONL case files with `id`, `input`, `expected`, and `annotations`, and supported expected checks include `status`, exact `output`, recursive `outputContains`, and `errorContains`. ([Smithers][2])

---

## Evals usage docs

Add an “Evals, optional” section to `references/SMITHERS-POLISH-GRAPH.md`.

Document:

```bash
mkdir -p .smithers/evals
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl \
  .smithers/evals/better-beads-polish-graph.eval.jsonl
```

Dry-run:

```bash
bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --dry-run
```

Live optional run:

```bash
bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --report .smithers/evals/better-beads-polish-smoke.json \
  --force \
  --format json
```

Scores for a completed polish run:

```bash
bunx smithers-orchestrator scores <run-id> --node synthesize-polish-plan
```

Document that evals are **advisory** and **not part of the default Better Beads path**.

Smithers eval docs say dry-run prints planned case IDs and run IDs without touching the database, live runs write a report by default to `.smithers/evals/<suite>.json`, `--format json` produces structured CI output, and exit codes are `0` for all pass, `1` for any failure, and `4` for invalid case files. ([Smithers][2])

---

## `authoring-triage` integration

Do **not** add a top-level `smithers` field.

When `selected_mode == "polish-existing-graph"`, add under `selected_mode`:

```json
{
  "smithers_recommendation": {
    "available_check_command": "scripts/better-beads smithers check --json",
    "recommended": true,
    "workflow": "better-beads-polish-graph",
    "command": "scripts/better-beads smithers polish-graph --json",
    "reason": "Selected mode is polish-existing-graph; use optional strict-polish lane for complex, ambiguous, adversarial, or dispatch-readiness review."
  }
}
```

When the selected mode is not `polish-existing-graph`, omit `smithers_recommendation`.

Do not check Smithers availability inside `authoring-triage`.

---

## Schemas

Add:

```text
schemas/better-beads-smithers-check-v1.schema.json
schemas/better-beads-smithers-polish-graph-v1.schema.json
```

Schema notes:

```text
- `result` is nullable.
- `scores_command` is nullable.
- `smithers.up`, `smithers.output`, and `smithers.inspect` allow diagnostic command status records.
- `smithers.output.stdout_json` can be null.
- `smithers.output.parse_error` can be null or string.
- `judge_scores` are normalized 0–1.
- Do not overfit to a single Smithers output-row shape.
```

Do not add an eval JSON schema in v1 because there is no Better Beads eval command surface.

---

## Documentation

Add:

```text
references/SMITHERS-POLISH-GRAPH.md
```

Include:

````md
# Smithers Polish Graph Experiment

Optional strict-polish lane for Better Beads.

Use when:
- selected mode is `polish-existing-graph`;
- user asks for strict, adversarial, multi-agent, durable, or Smithers-backed review;
- operator-dispatch gates warn or block;
- graph shape is ambiguous;
- repeated polish is producing prose churn instead of graph improvement.

Do not use for:
- simple closeout;
- tiny graph edits;
- routine create-from-ready-plan work;
- repos without explicit Smithers setup.

Commands:
```bash
scripts/better-beads smithers check --json
scripts/better-beads smithers polish-graph --json
````

Setup:

```bash
mkdir -p .smithers/workflows
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.tsx \
  .smithers/workflows/better-beads-polish-graph.tsx
```

Runtime pattern:

```bash
bunx smithers-orchestrator up .smithers/workflows/better-beads-polish-graph.tsx --run-id <run-id> --input '<json>'
bunx smithers-orchestrator output <run-id> synthesize-polish-plan --json
```

Stable output node:

* `synthesize-polish-plan`

Scores:

```bash
bunx smithers-orchestrator scores <run-id> --node synthesize-polish-plan
```

Score scale:

* Smithers judge scores are normalized 0–1.
* This is separate from the manual Better Beads 0–3-per-dimension rubric.

Evals, optional:

```bash
mkdir -p .smithers/evals
cp .agents/skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl \
  .smithers/evals/better-beads-polish-graph.eval.jsonl

bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --dry-run
```

Safety:

* The Better Beads command is read-only.
* The Smithers workflow returns a recommendation only.
* Evals are advisory and opt-in.
* Apply any mutation manually through `br` after review.

````

Update `manifest.json` resources:

```json
{
  "path": "references/SMITHERS-POLISH-GRAPH.md",
  "description": "Optional Smithers-backed strict polish lane for Better Beads graph review."
},
{
  "path": "smithers-templates/better-beads-polish-graph.tsx",
  "description": "Copyable Smithers workflow template for strict Better Beads graph polish review."
},
{
  "path": "smithers-templates/better-beads-polish-graph.eval.jsonl",
  "description": "Copyable Smithers eval case template for the Better Beads strict polish workflow."
}
````

---

## Tests

Add tests that pass without Bun or Smithers, plus fake-`bunx` happy-path and eval-dry-run tests.

### Unavailable tests

1. `scripts/better-beads smithers check --json` returns valid JSON when `bunx` is missing.
2. `scripts/better-beads smithers check --repo <temp repo> --json` returns `available: false` when `.smithers/` is missing.
3. `scripts/better-beads smithers polish-graph --json` returns valid JSON with `available: false` when workflow is missing.
4. Missing `--json` exits `2` for both new commands.
5. Existing schema tests still pass.
6. Existing robot-surface no-mutation tests still pass.

### Fake-`bunx` happy path

Follow the existing fake-binary style used for `br` and `bv` in `test_schemas.sh`.

Generate schema-test payloads dynamically by running the actual commands against temp repos and fake binaries. Do not add static fixture JSON unless that is already the local test style.

Fake `bunx` should handle:

```bash
bunx smithers-orchestrator up .smithers/workflows/better-beads-polish-graph.tsx --run-id <id> --input <json>
```

Return exit `0`.

It should handle:

```bash
bunx smithers-orchestrator output <run-id> synthesize-polish-plan --json
```

Return a row-shaped wrapper so the extractor is tested:

```json
{
  "runId": "<run-id>",
  "nodeId": "synthesize-polish-plan",
  "output": {
    "verdict": "ready",
    "summary": "Fake Smithers polish review passed.",
    "recommended_mutations": [],
    "ready_frontier": [],
    "blocked_dispatch_reasons": [],
    "judge_scores": {
      "behavior_contract_quality": 1,
      "implementation_fungibility": 1,
      "dependency_correctness": 1,
      "reviewability": 1,
      "dispatch_readiness": 1
    }
  }
}
```

It should handle:

```bash
bunx smithers-orchestrator inspect <run-id> --format json
```

Return:

```json
{
  "runId": "<run-id>",
  "status": "finished"
}
```

Happy-path assertions:

```text
- available is true;
- run_id is present;
- result.verdict is "ready";
- scores_command is present;
- smithers.up.exit_code is 0;
- smithers.output.exit_code is 0;
- smithers.output.stdout_json is not null;
- output_command includes synthesize-polish-plan;
- no tracked repo files are mutated.
```

### Fake-`bunx` eval dry-run test

Add a test helper that directly invokes the documented Smithers eval dry-run command with fake `bunx`; do not add a Better Beads dispatcher command.

Fake `bunx` should handle:

```bash
bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --dry-run
```

Return exit `0` and print a small fake dry-run response, for example:

```json
{
  "suite": "better-beads-polish-smoke",
  "dryRun": true,
  "cases": [
    {
      "id": "ready-graph-smoke",
      "runId": "better-beads-polish-smoke-ready-graph-smoke-fake"
    }
  ]
}
```

The test should assert:

```text
- the eval case template exists;
- fake eval dry-run exits 0;
- the command includes `--dry-run`;
- the command does not mutate tracked files.
```

### Robot surface smoke

Add:

```bash
scripts/better-beads smithers check --json
scripts/better-beads smithers polish-graph --json
```

to `scripts/test_cli_robot_surfaces.sh`.

Do not add the raw Smithers eval command to robot surface smoke because it is not a Better Beads robot surface.

### Schema tests

Update `scripts/test_schemas.sh` to validate dynamically generated payloads for:

```text
better-beads-smithers-check-v1 unavailable
better-beads-smithers-polish-graph-v1 unavailable
better-beads-smithers-polish-graph-v1 fake-success
```

No schema test is needed for eval dry-run because the eval command is not a Better Beads JSON surface.

---

## Acceptance criteria

The work is complete when:

```text
- `scripts/better-beads smithers check --json` works in any repo.
- `scripts/better-beads smithers polish-graph --json` degrades gracefully without Bun/Smithers.
- `scripts/better-beads smithers polish-graph --json` has a fake-`bunx` happy-path test.
- Smithers invocation uses `up`, then `output <run-id> synthesize-polish-plan --json`.
- The workflow template uses explicit `Parallel` + explicit `Task id="synthesize-polish-plan"`.
- The synthesis task has `schemaAdherenceScorer`.
- The workflow template defines Zod schemas for reviewer findings and final polish plan.
- A copyable Smithers eval JSONL template exists.
- The eval JSONL template uses `outputContains` keyed by `polishPlan`.
- The fake-`bunx` test covers `eval ... --dry-run`.
- `authoring-triage --json` adds Smithers recommendation metadata under `selected_mode` only for `polish-existing-graph`.
- `smithers` is added to `KNOWN_COMMANDS`.
- New schemas validate unavailable and fake-success payloads.
- New robot surfaces pass no-mutation smoke.
- No Beads are created or mutated.
- Better Beads works exactly as before without Smithers.
```

## Suggested validation commands

Run from the skills repo:

```bash
bash skills/better-beads/scripts/test_schemas.sh
bash skills/better-beads/scripts/test_cli_robot_surfaces.sh
bash skills/better-beads/scripts/better-beads smithers check --json
bash skills/better-beads/scripts/better-beads smithers polish-graph --json
```

In a Smithers-ready test repo:

```bash
mkdir -p .smithers/workflows .smithers/evals

cp /path/to/skills/skills/better-beads/smithers-templates/better-beads-polish-graph.tsx \
  .smithers/workflows/better-beads-polish-graph.tsx

cp /path/to/skills/skills/better-beads/smithers-templates/better-beads-polish-graph.eval.jsonl \
  .smithers/evals/better-beads-polish-graph.eval.jsonl

/path/to/skills/skills/better-beads/scripts/better-beads smithers check --json
/path/to/skills/skills/better-beads/scripts/better-beads smithers polish-graph --json

bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
  --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
  --suite better-beads-polish-smoke \
  --dry-run
```

Final instruction to Codex: keep this deliberately boring. The experiment is **one optional strict-polish workflow plus a light eval foundation**, not a general Smithers substrate.

[1]: https://smithers.sh/how-it-works "How It Works - Smithers"
[2]: https://smithers.sh/guides/evals-quickstart "Eval Suites Quickstart - Smithers"
[3]: https://smithers.sh/cli/overview "CLI - Smithers"
