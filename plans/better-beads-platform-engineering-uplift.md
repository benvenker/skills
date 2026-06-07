# Plan: Better-Beads Platform Engineering Uplift

> Strengthen better-beads infrastructure, observability, portability, and eval
> coverage without touching the domain design, which is already best-in-class.

**Date**: 2026-06-07
**Author**: Assessment-driven (pi agent + web research synthesis)
**Revised**: 2026-06-07 (GPT Pro review pass 1 + pass 2)
**Status**: Draft
**Skill path**: `skills/better-beads/`

## Background

An independent assessment compared better-beads against 2025–2026 industry best
practices (Microsoft Agent Skills, Anthropic Agent Skills spec, OpenAI agent
patterns, MCP ecosystem, Augment Code pattern catalog). The skill scores A+ on
progressive disclosure, reference-driven execution, failure mode documentation,
and deterministic quality gates. It scores C/C+ on structured metadata,
observability, typed schemas, version compatibility, and portability.

This plan targets the platform engineering gaps without disturbing the domain
design, rubric, failure modes, reference library, or gate architecture.

## Goals

1. Publish formal JSON Schemas for structured outputs.
2. Declare tool dependencies and compatible versions.
3. Add structured telemetry hooks for gate and route events.
4. Build a minimal eval harness for routing and bead quality.
5. Improve metadata for cross-framework portability.

## Non-goals

- No changes to the quality rubric, failure modes, or reference library content.
- No changes to the gate architecture (deterministic → operator-dispatch → semantic).
- No adapter layer for non-Beads issue trackers (that is a separate product decision).
- No rewrite of existing scripts; only additive instrumentation.
- No breaking changes to existing `--json` output shapes.

## Execution Defaults

Use these defaults for every work item unless the work item explicitly says
otherwise.

- Work from `skills/better-beads/` as the skill root.
- Prefer Python stdlib and Bash only. Do not add package installation steps.
- All new scripts must be runnable from a clean checkout with `python3` and
  `bash`.
- All tests must create temporary repos/fixtures and must not depend on the
  caller's active `.beads` graph.
- New validation code must fail closed with actionable stderr when a producer is
  missing, returns malformed JSON, or emits an unsupported shape.
- Schemas describe current producer behavior. Do not change a producer's JSON
  shape merely to satisfy a schema.
- When a producer output lacks `tool`, `schema`, `version`,
  `contract_version`, or any other discriminator, the schema must model that
  absence rather than adding the field.
- Do not log, fixture, or baseline bead descriptions, plan text, prompts, or
  user-authored content unless the existing contract already emits them and the
  work item explicitly validates that existing contract.
- New artifacts should include enough local validation commands that an
  implementation agent can close the bead without asking for architectural
  judgment.

---

## Work Items

### WI-1: Publish JSON Schema files for the selected platform-uplift outputs

**Outcome**: The four JSON contracts named in this work item have
machine-validatable schemas that describe current behavior exactly.
This work item must not expand into schemas for every robot surface currently
advertised by `better-beads capabilities --json`.

**Scope**:
- Add `schemas/README.md` with:
  - the four contracts covered by this work item;
  - the command that emits each contract;
  - any advertised JSON contracts intentionally deferred from this uplift;
  - a note that schemas describe current output and do not authorize output
    shape changes.
- Create `schemas/better-beads-route-v1.schema.json` matching current `bead_route.sh --json` output.
- Create `schemas/better-beads-dispatch-verdict-v1.schema.json` matching current `bead_gate_loop.sh --operator-dispatch --json` output.
- Create `schemas/better-beads-quality-gate-v1.schema.json` matching current `bead_quality_gate.py --json` output.
- Create `schemas/better-beads-authoring-triage-v1.schema.json` matching current `better-beads authoring-triage --json` output.
- Do not create schemas for `frontier`, `triage`, `create-graph`,
  `semantic-pack`, `capabilities-v1`, or Markdown guide surfaces in this work item.

**Validation**:
- Add `scripts/test_schemas.sh` that is fully offline and deterministic.
- `scripts/test_schemas.sh` owns the validation strategy. It must use only
  `bash` and `python3` stdlib.
- The schema files must be limited to the JSON Schema keywords supported by the
  test runner: `$schema`, `$id`, `title`, `description`, `type`, `required`,
  `properties`, `items`, `enum`, `const`, `additionalProperties`, `anyOf`,
  `oneOf`, and nullable unions expressed as `type: ["string", "null"]`.
- If a schema uses an unsupported keyword, `scripts/test_schemas.sh` must fail
  with the schema path and keyword name instead of silently ignoring it.
- The runner should validate both:
  - the schema file is valid JSON and uses only the supported keyword subset;
  - the producer output fixture satisfies required fields, types, enums, and
    top-level additional-property rules.
- The test must create temporary repos/fixtures needed for each contract instead
  of depending on the caller's active `.beads` graph.
- Fixture setup must live inside `scripts/test_schemas.sh` or a clearly named
  temporary helper generated by that script. Do not require committed generated
  output files for WI-1.
- The test must create a temporary `bin/` directory and prepend it to `PATH`
  when fake `br` or `bv` behavior is required.
- For route schema validation, cover at least:
  - no `.beads` repo;
  - `.beads` repo with fake `br list --json`;
  - weak `--plan` route override.
  - graph-present with cycle-inspection-failed.
- For dispatch verdict validation, reuse the fake `br`/`bv` pattern from
  `scripts/test_bead_gate_loop.sh`.
- For quality-gate validation, use temporary `.beads/issues.jsonl` fixtures.
- For authoring-triage validation, validate both no-graph and graph-present
  successful outputs.
- For each covered contract, the test output should print one line per case:
  `ok schema=<schema-file> case=<case-name> producer=<command>`.
- Required WI-1 cases:
  - route/no-beads/no-plan;
  - route/no-beads/weak-plan;
  - route/graph-present/fake-br-list;
  - route/graph-present/cycle-inspection-failed;
  - dispatch/operator-dispatch/pass-or-block fixture using fake `br`/`bv`;
  - quality-gate/json fixture from temporary `.beads/issues.jsonl`;
  - authoring-triage/no-graph;
  - authoring-triage/graph-present using fake `br`/`bv`.
- The schema test must not install packages, call the network, or mutate the
  caller's repo.
- Do not require the third-party `jsonschema` Python package. If it is present
  locally, the test may optionally run it as an extra check, but the required
  passing path must not depend on it.
- Existing `--json` output must not change; schemas describe current behavior.

**Failure behavior**:
- If current output is inconsistent across modes, document the variance and pick the superset shape.
- If a field is optional in practice, mark it as such in the schema rather than forcing it.
- If a current JSON output lacks `schema`, `tool`, `version`, or
  `contract_version`, do not add those fields to the producer as part of this
  work item. The schema must describe the current output shape.
- A schema may use filename/version identity even when the payload itself does
  not contain a schema discriminator.
- Use strict top-level schemas for the four covered contracts:
  - required top-level fields must be explicit;
  - unexpected top-level fields should fail unless the current producer already
    emits mode-specific top-level variance.
- Use tolerant nested schemas by default:
  - set `additionalProperties: true` for nested objects that summarize `br`,
    `bv`, route output, command statuses, artifacts, findings, or other
    upstream/tool-derived data;
  - only set nested `additionalProperties: false` when the field is fully owned
    by the Better Beads producer and already stable across fixture modes.
- For arrays of findings, modes, next steps, and command statuses, validate the
  stable item keys and value types without over-constraining future harmless
  metadata.

**Known anchors**:
- `scripts/bead_route.sh` — route JSON producer
- `scripts/bead_gate_loop.sh` — dispatch verdict producer
- `scripts/bead_quality_gate.py` — quality gate JSON producer
- `scripts/better-beads` — dispatcher, authoring-triage producer
- `references/QUALITY-GATES.md` — documents `better-beads-dispatch-verdict-v1` shape
- `references/SEMANTIC-GATE.md` — documents judge prompt output shape
- `test/ROUTING-TRUTH-TABLE.md` — documents route contract

**Dependencies**: None. Can start immediately.

---

### WI-2: Enrich metadata.json with tool dependencies and compatibility

**Outcome**: `metadata.json` declares required tools, compatible versions, and skill capabilities so other frameworks can discover and validate prerequisites.

**Scope**:
- Add `required_tools` section with one object per tool:
  - `name`
  - `required_for`
  - `version_command`
  - `minimum_version` when known, otherwise `null`
  - `version_detection`: `supported` | `not_supported` | `unknown`
  - `failure_behavior`
- Required tools:
  - `br`: required for graph inspection/mutation when `.beads` exists.
  - `bv`: required for robot plan/insights gates.
  - `python3`: minimum `3.10`.
  - `bash`: minimum `4.0`.
- Add `test_tools` section:
  - `scripts/test_schemas.sh` as the required schema/contract validator;
  - third-party `jsonschema` as optional only if the harness detects and uses it
    as an extra local check;
  - optional `jq` only if an existing script actually uses it.
- Add `compatibility.tested_with` section that records observed `br`/`bv`
  versions when available, and records `unknown` without inventing a minimum
  when version detection is unavailable.
- Add `triggers` and `exclusions` fields matching SKILL.md frontmatter semantics.
- Add `required_capabilities`: `filesystem_read`, `filesystem_write`, `bash_execute`.
- Preserve existing fields (`version`, `organization`, `date`, `abstract`, `references`).
- Treat `metadata.json` as the canonical dependency contract. Other files may
  reference tools by name but must not duplicate minimum versions,
  version-detection semantics, or failure behavior.

**Implementation default**:
- Use these exact top-level sections:
  - `required_tools`
  - `test_tools`
  - `compatibility`
  - `triggers`
  - `exclusions`
  - `required_capabilities`
- Keep existing top-level fields unchanged unless the current file already
  contains stale or invalid JSON.

**Validation**:
- `metadata.json` parses as JSON.
- Every required tool object has `name`, `required_for`, `version_command`,
  `minimum_version`, `version_detection`, and `failure_behavior`.
- A caller can tell from metadata alone whether a missing tool is fatal,
  test-only, or optional.

**Failure behavior**:
- If a tool version cannot be reliably pinned (e.g., `bv` has no `--version`),
  record `version_detection: "not_supported"` and `minimum_version: null`
  rather than inventing a fake version pin.

**Known anchors**:
- `metadata.json` — current minimal metadata
- `SKILL.md` frontmatter — `name`, `description` fields
- `scripts/better-beads` — dispatcher that wraps tool calls

**Dependencies**: None. Can run in parallel with WI-1.

---

### WI-3: Add structured telemetry hooks

**Outcome**: Gate and route executions emit structured JSONL events that can be aggregated for operational insight.

**Scope**:
- Split implementation into two phases:
  - **WI-3a telemetry contract**: add the helper, schema, and docs without
    changing existing script behavior.
  - **WI-3b instrumentation**: add `--telemetry <path>` to
    `bead_quality_gate.py`, `bead_gate_loop.sh`, and `bead_route.sh`.
- Add one shared helper: `scripts/better_beads_telemetry.py`.
  - Python callers import it.
  - Shell callers invoke it as a tiny CLI.
  - It owns timestamp formatting, JSON serialization, atomic append, and
    telemetry failure handling.
- When the flag is set, append one JSONL event per invocation with:
  - `run_id` (opaque UUID or timestamp/PID-based id)
  - `timestamp` (ISO 8601)
  - `tool` (script name)
  - `tool_version`
  - `contract_version` when available
  - `mode` (route mode, gate mode, etc.)
  - `repo_id` (SHA-256 hex digest of the resolved repo root path, truncated to
    16 hex chars)
  - `repo_basename` (basename only, no parent directories)
  - `duration_ms`
  - `exit_code`
  - `verdict` (pass/fail/block/etc.)
  - `finding_counts` (errors, warnings, by category)
  - `schema_version` (`better-beads-telemetry-v1`)
- Do not log bead descriptions, plan text, prompt text, command stdout, or
  user-authored content. Telemetry is counts/status only.
- Do not log absolute paths. Artifact paths may appear in existing command
  output, but telemetry events must not add new absolute path leakage.
- `bead_gate_loop.sh --telemetry PATH` emits one gate-loop event and does not
  forward `--telemetry` to the inner `bead_quality_gate.py`; the gate-loop
  event summarizes quality findings from the existing JSON artifact.
- When the flag is absent, behavior is unchanged (no telemetry overhead).
- Add `schemas/better-beads-telemetry-v1.schema.json`.
- Document the telemetry contract in a short `references/TELEMETRY.md`.

**Validation**:
- Run gate with `--telemetry /tmp/bb-telemetry.jsonl`, verify JSONL is valid and schema-compliant.
- Run without `--telemetry`, verify no file is created and no stdout/stderr change.
- Existing test scripts must still pass.
- For each instrumented script, add a fixture test that runs the same command:
  - once without `--telemetry`;
  - once with `--telemetry "$TMP/telemetry.jsonl"`.
- The two runs must have byte-identical stdout and the same exit code.
- The telemetry-enabled run must append exactly one JSONL event that validates
  against `schemas/better-beads-telemetry-v1.schema.json`.
- A non-writable telemetry target must preserve stdout and exit code; stderr may
  contain exactly one telemetry warning line.

**Failure behavior**:
- If the telemetry path is not writable, warn to stderr and continue without telemetry (do not fail the gate).
- Telemetry must never change exit codes or stdout of the gate tools.
- Telemetry append must be a single best-effort append operation. Partial,
  malformed, or failed telemetry writes must not affect the primary command.
- In `--json` modes, telemetry warnings go to stderr only.

**Known anchors**:
- `scripts/bead_quality_gate.py` — Python entry, add `argparse` flag
- `scripts/bead_gate_loop.sh` — shell orchestrator, emit one outer event
- `scripts/bead_route.sh` — route helper, add duration/verdict logging
- `scripts/test_bead_quality_gate.py` — existing Python tests
- `scripts/test_bead_gate_loop.sh` — existing shell tests

**Dependencies**:
- WI-3a depends on WI-1.
- WI-3b depends on WI-3a and WI-4.
- Do not modify `bead_quality_gate.py`, `bead_gate_loop.sh`, or
  `bead_route.sh` until WI-4 evals pass on the current skill state.

---

### WI-4: Build minimal eval harness for routing and bead quality

**Outcome**: An automated eval pipeline that can detect routing drift and bead quality regression across model changes.

**Scope**:
- Create `evals/` directory.
- Create `evals/routing_eval.py`:
  - Defines executable routing cases in `evals/cases/routing_cases.json`.
  - Covers every automatic route decision from
    `test/ROUTING-TRUTH-TABLE.md` cases A1 through A14.
  - Treats `test/ROUTING-TRUTH-TABLE.md` as the human-readable reference, not
    as the runtime parser input.
  - For each case, creates a temporary repo with:
    - no `.beads`, empty `.beads`, or fixture `.beads/issues.jsonl`;
    - optional plan file text;
    - fake `br list --json` and `br dep cycles --json` when needed.
  - For every graph-present case, creates a temporary `bin/br` shim and prepends
    it to `PATH` so the eval never uses the caller's real Beads graph.
  - Runs `bead_route.sh --repo TMP_REPO [--plan PLAN] --json`.
  - Compares `recommended_mode`, `graph_state.has_beads_dir`,
    `graph_state.by_status`, `graph_state.cycle_inspection`,
    `plan_readiness.status`, and required `next_steps` substrings.
  - The existing `test/golden/*.input.md` files may remain as human-readable
    case notes, but they are not the only executable source of truth.
- Create `evals/quality_eval.py`:
  - Reads `test/fixtures/example-graph.json`.
  - Runs `bead_quality_gate.py` against each bead.
  - Compares deterministic output against
    `evals/baselines/quality_gate_baseline.json`.
  - Baseline fields:
    - command exit code;
    - `issue_count`;
    - `error_count`;
    - `warning_count`;
    - `operator_blocking_count`;
    - `split_review_required_count`;
    - sorted multiset of finding `code` values;
    - selected finding fields: `severity`, `issue_id`, `code`,
      `operator_blocking`, `requires_split_review`.
  - Reports finding drift, not score drift.
  - `quality_eval.py --update-baseline` may rewrite only
    `evals/baselines/quality_gate_baseline.json` and must sort issue IDs,
    finding codes, and selected finding fields deterministically.
- Create `evals/run_evals.sh` as the single entry point.
- Add `evals/baselines/quality_gate_baseline.json` with current deterministic
  findings.
- Add `evals/README.md` documenting how to run and update baselines.

**Validation**:
- `bash evals/run_evals.sh` exits 0 when baselines match.
- Intentionally breaking a fixture (e.g., changing expected mode) causes exit 1.
- The eval harness does not require network access or LLM calls.

**Failure behavior**:
- If `bead_route.sh` or `bead_quality_gate.py` is missing or broken, the eval reports the tool error rather than silently passing.
- Any change to exit code, error count, operator-blocking count, split-review
  count, or finding-code multiset is a failure unless the baseline is
  intentionally updated.
- Warning-count-only drift may be reported as a warning if the command verdict
  and finding-code multiset remain unchanged.
- Baseline-update mode must never run by default from `evals/run_evals.sh`.

**Known anchors**:
- `test/golden/` — 4 input/expected fixture pairs
- `test/fixtures/` — example graph and plan fixtures
- `test/ROUTING-TRUTH-TABLE.md` — expected routing behavior
- `scripts/bead_route.sh` — route tool under test
- `scripts/bead_quality_gate.py` — quality tool under test

**Dependencies**: WI-1 (schema validation can be part of eval checks).

---

### WI-5: Cross-framework portability improvements

**Outcome**: The skill can be discovered and partially consumed by non-Pi agent frameworks without requiring ACFS infrastructure.

**Scope**:
- Add a top-level `manifest.json` following the emerging Agent Skills spec shape:
  - `name`, `version`, `description`, `author`
  - `triggers`, `exclusions`
  - `required_tools` (referencing metadata.json)
  - `surfaces`, each with:
    - `command`
    - `description`
    - `mutates_repo`: true | false
    - `requires_tools`
    - `stdout_schema` when covered by WI-1
    - `stdout_schema_status`: `covered` | `deferred` | `markdown`
  - `risk_level`: `low` (read-only inspection) to `medium` (bead mutation)
  - `resources` listing reference files
  - `scripts` listing executable tools
- `required_tools` entries in `manifest.json` must reference tool names from
  `metadata.json` and must not duplicate version constraints.
- Ensure `SKILL.md` can be consumed standalone (it already can, but verify no broken relative paths when the skill is installed outside the skills monorepo).
- Add a `PORTABILITY.md` note documenting what works without `br`/`bv` (the rubric, failure modes, formatting guide, and examples are all portable; the scripts and gates require the toolchain).

**Validation**:
- Validate `manifest.json` with Python stdlib `json`.
- All paths referenced in `manifest.json` exist.
- SKILL.md relative references resolve correctly when the skill dir is symlinked elsewhere.
- Every `stdout_schema` marked `covered` must point to a schema created by WI-1.
- Every advertised but uncovered JSON surface must be marked `deferred`, not
  silently omitted.
- Manifest validation must compare `surfaces` against advertised robot surfaces
  from:
  - `scripts/better-beads capabilities --json`;
  - `scripts/bead_route.sh capabilities --json`;
  - `scripts/bead_gate_loop.sh capabilities --json`;
  - `scripts/bead_quality_gate.py capabilities --json`.
- The manifest may omit Markdown-only guide surfaces only when it records them
  under `resources` or marks their `stdout_schema_status` as `markdown`.

**Failure behavior**:
- If manifest validation fails, the manifest is malformed and must be fixed before merge.

**Known anchors**:
- `metadata.json` — current metadata
- `SKILL.md` — current entrypoint
- `references/README.md` — reading order and package status

**Dependencies**: WI-1 (schemas referenced in manifest), WI-2 (tool deps referenced in manifest).

---

## Dependency Graph

```
WI-1 (schemas) ──┬──→ WI-4 (eval harness) ──→ WI-3a (telemetry contract) ──→ WI-3b (script instrumentation)
                  └──→ WI-5 (portability)
WI-2 (metadata)  ────→ WI-5 (portability)
```

WI-1 and WI-2 can run in parallel. WI-4 depends on WI-1. WI-3a depends on
WI-1 and should run after WI-4 unless intentionally limited to helper/schema
files only. WI-3b must run after WI-4 and WI-3a. WI-5 depends on WI-1 and
WI-2.

## Recommended Implementation Order

1. **WI-1** + **WI-2** in parallel (foundation, no cross-dependencies)
2. **WI-4** (eval harness, needs schemas from WI-1)
3. **WI-3a** (telemetry helper, schema, and docs; no existing script behavior changes)
4. **WI-3b** (telemetry instrumentation, protected by evals)
5. **WI-5** (portability, needs both WI-1 and WI-2)

## Sizing Estimates

| Item | Estimated effort | Files touched | New files |
|------|-----------------|---------------|-----------|
| WI-1 | Small-medium | 0 existing | 4–5 schema files + 1 test script |
| WI-2 | Small | 1 (metadata.json) | 0 |
| WI-3a | Small | 0 existing | 1 helper + 1 schema + 1 reference doc |
| WI-3b | Medium | 3 (gate scripts) | 0 |
| WI-4 | Medium | 0 existing | 4–6 eval files + baselines |
| WI-5 | Small | 0–1 existing | 2 (manifest.json + PORTABILITY.md) |

## Beadization Guidance

Convert this plan into one epic plus the following child beads. Do not merge
children just because they are in the same work item. Each child bead must
include outcome, scope, non-goals, known anchors, implementation notes,
validation commands, and close evidence.

1. **UPLIFT.1 Schema inventory and route schema**
   - Blocks: UPLIFT.2, UPLIFT.4, UPLIFT.5, UPLIFT.6, UPLIFT.10.
   - Add `schemas/README.md`.
   - Add route schema and route schema fixture validation only.
   - Validation:
     - `bash scripts/test_schemas.sh route`
     - `bash scripts/test_schemas.sh`

2. **UPLIFT.2 Gate/quality/triage schemas**
   - Depends on: UPLIFT.1.
   - Add dispatch verdict, quality gate, and authoring-triage schemas.
   - Extend `scripts/test_schemas.sh` fixtures for those contracts.
   - Validation:
     - `bash scripts/test_schemas.sh`

3. **UPLIFT.3 Metadata dependency contract**
   - Can run in parallel with UPLIFT.1.
   - Update `metadata.json`.
   - Validate required/test/optional tool records.
   - Validation:
     - `python3 -m json.tool metadata.json >/dev/null`
     - `python3 -` metadata structural assertion from the bead

4. **UPLIFT.4 Routing eval harness**
   - Depends on: UPLIFT.1.
   - Add executable routing cases using temporary repos/fake tools.
   - Validate against the routing truth table.
   - Validation:
     - `bash evals/run_evals.sh routing`

5. **UPLIFT.5 Quality eval harness**
   - Depends on: UPLIFT.2.
   - Add deterministic quality baselines for counts and finding codes.
   - Do not introduce score concepts.
   - Validation:
     - `bash evals/run_evals.sh quality`
     - `bash evals/run_evals.sh`

6. **UPLIFT.6 Telemetry helper, schema, and docs**
   - Depends on: UPLIFT.2, UPLIFT.4, UPLIFT.5.
   - Add shared telemetry helper.
   - Add telemetry schema and `references/TELEMETRY.md`.
   - No existing script behavior changes yet.
   - Validation:
     - `bash scripts/test_schemas.sh telemetry`
     - helper self-test command documented in the bead

7. **UPLIFT.7 Route telemetry instrumentation**
   - Depends on: UPLIFT.6.
   - Add `--telemetry` to `bead_route.sh`.
   - Prove stdout and exit codes are unchanged with telemetry enabled.
   - Validation:
     - `bash evals/run_evals.sh routing`
     - `bash scripts/test_schemas.sh telemetry`

8. **UPLIFT.8 Quality-gate telemetry instrumentation**
   - Depends on: UPLIFT.6.
   - Add `--telemetry` to `bead_quality_gate.py`.
   - Prove JSON and markdown report stdout are unchanged with telemetry enabled.
   - Validation:
     - `python3 scripts/test_bead_quality_gate.py`
     - `bash evals/run_evals.sh quality`
     - `bash scripts/test_schemas.sh telemetry`

9. **UPLIFT.9 Gate-loop telemetry instrumentation**
   - Depends on: UPLIFT.7, UPLIFT.8.
   - Add `--telemetry` to `bead_gate_loop.sh`.
   - Emit one outer event; do not double-log inner quality-gate execution.
   - Validation:
     - `bash scripts/test_bead_gate_loop.sh`
     - `bash evals/run_evals.sh`
     - `bash scripts/test_schemas.sh telemetry`

10. **UPLIFT.10 Portability manifest and notes**
    - Depends on: UPLIFT.2, UPLIFT.3.
    - Add `manifest.json` and `PORTABILITY.md`.
    - Validate referenced paths and covered/deferred schema surfaces.
    - Validation:
      - manifest validation command from `PORTABILITY.md`
      - `python3 -m json.tool manifest.json >/dev/null`

## Success Criteria

- All 4 JSON Schema files validate against current tool output.
- `metadata.json` declares tool dependencies that can be checked programmatically.
- Gate/route telemetry is opt-in, zero-overhead when disabled, and schema-compliant when enabled.
- `evals/run_evals.sh` passes on the current skill state and catches intentional regressions.
- `manifest.json` is valid and all referenced paths exist.
- No existing test, gate, or script behavior changes.
- No changes to domain content (rubric, failure modes, examples, formatting rules).
- `scripts/test_schemas.sh` passes in a clean temporary environment.
- Existing tests continue to pass:
  - `python3 scripts/test_bead_quality_gate.py`
  - `bash scripts/test_bead_gate_loop.sh`
  - `bash scripts/test_cli_robot_surfaces.sh`
- For each telemetry-instrumented script, the same fixture command with and
  without writable telemetry produces byte-identical stdout and the same exit
  code.
- For each telemetry-instrumented script, telemetry failure writes only stderr
  diagnostics and does not alter the primary command result.
- Eval baselines are deterministic, offline, and do not depend on the caller's
  active `.beads` graph.
- Every implementation bead closes with evidence containing:
  - files changed;
  - validation commands run;
  - pass/fail result for each command;
  - any intentionally deferred surfaces;
  - confirmation that no domain content was changed unless the bead explicitly
    allowed docs for the new platform artifact.
- Telemetry instrumentation beads must include before/after command evidence
  showing primary stdout and exit-code preservation for their target script.
- Schema and manifest beads must include the exact generated/validated contract
  names and any intentionally deferred advertised surfaces.
