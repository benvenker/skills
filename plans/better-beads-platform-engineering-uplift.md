# Plan: Better-Beads Platform Engineering Uplift

> Strengthen better-beads infrastructure, observability, portability, and eval
> coverage without touching the domain design, which is already best-in-class.

**Date**: 2026-06-07
**Author**: Assessment-driven (pi agent + web research synthesis)
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
- The test must create temporary repos/fixtures needed for each contract instead
  of depending on the caller's active `.beads` graph.
- For route schema validation, cover at least:
  - no `.beads` repo;
  - `.beads` repo with fake `br list --json`;
  - weak `--plan` route override.
- For dispatch verdict validation, reuse the fake `br`/`bv` pattern from
  `scripts/test_bead_gate_loop.sh`.
- For quality-gate validation, use temporary `.beads/issues.jsonl` fixtures.
- For authoring-triage validation, validate both no-graph and graph-present
  successful outputs.
- The schema test must not install packages, call the network, or mutate the
  caller's repo.
- Existing `--json` output must not change; schemas describe current behavior.

**Failure behavior**:
- If current output is inconsistent across modes, document the variance and pick the superset shape.
- If a field is optional in practice, mark it as such in the schema rather than forcing it.
- If a current JSON output lacks `schema`, `tool`, `version`, or
  `contract_version`, do not add those fields to the producer as part of this
  work item. The schema must describe the current output shape.
- A schema may use filename/version identity even when the payload itself does
  not contain a schema discriminator.

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
  - one JSON Schema validator chosen by the test harness;
  - optional `jq` only if an existing script actually uses it.
- Add `compatibility.tested_with` section that records observed `br`/`bv`
  versions when available, and records `unknown` without inventing a minimum
  when version detection is unavailable.
- Add `triggers` and `exclusions` fields matching SKILL.md frontmatter semantics.
- Add `required_capabilities`: `filesystem_read`, `filesystem_write`, `bash_execute`.
- Preserve existing fields (`version`, `organization`, `date`, `abstract`, `references`).

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
- Add an optional `--telemetry <path>` flag to `bead_quality_gate.py`, `bead_gate_loop.sh`, and `bead_route.sh`.
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
  - `project` (repo root or `.beads` path)
  - `duration_ms`
  - `exit_code`
  - `verdict` (pass/fail/block/etc.)
  - `finding_counts` (errors, warnings, by category)
  - `schema_version` (`better-beads-telemetry-v1`)
- Do not log bead descriptions, plan text, prompt text, command stdout, or
  user-authored content. Telemetry is counts/status only.
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

**Dependencies**: WI-1 (schemas should exist before defining telemetry schema),
WI-4 (eval harness should exist before risky script instrumentation).

---

### WI-4: Build minimal eval harness for routing and bead quality

**Outcome**: An automated eval pipeline that can detect routing drift and bead quality regression across model changes.

**Scope**:
- Create `evals/` directory.
- Create `evals/routing_eval.py`:
  - Defines explicit routing cases from `test/ROUTING-TRUTH-TABLE.md`.
  - For each case, creates a temporary repo with:
    - no `.beads`, empty `.beads`, or fixture `.beads/issues.jsonl`;
    - optional plan file text;
    - fake `br list --json` and `br dep cycles --json` when needed.
  - Runs `bead_route.sh --repo TMP_REPO [--plan PLAN] --json`.
  - Compares `recommended_mode`, `graph_state.has_beads_dir`,
    `graph_state.by_status`, `graph_state.cycle_inspection`,
    `plan_readiness.status`, and required `next_steps` substrings.
  - The existing `test/golden/*.input.md` files may remain as human-readable
    case notes, but they are not the only executable source of truth.
- Create `evals/quality_eval.py`:
  - Reads `test/fixtures/example-graph.json`.
  - Runs `bead_quality_gate.py` against each bead.
  - Compares deterministic output against expected baselines in `evals/baselines/`.
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
- Create `evals/run_evals.sh` as the single entry point.
- Add `evals/baselines/` with current deterministic findings.
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
- Add a top-level `manifest.yaml` following the emerging Agent Skills spec shape:
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
- Ensure `SKILL.md` can be consumed standalone (it already can, but verify no broken relative paths when the skill is installed outside the skills monorepo).
- Add a `PORTABILITY.md` note documenting what works without `br`/`bv` (the rubric, failure modes, formatting guide, and examples are all portable; the scripts and gates require the toolchain).

**Validation**:
- Manifest parsing is deterministic:
  - either add PyYAML to WI-2 `test_tools` and validate with it;
  - or use a JSON-compatible manifest format that can be parsed by Python stdlib.
- All paths referenced in manifest.yaml exist.
- SKILL.md relative references resolve correctly when the skill dir is symlinked elsewhere.
- Every `stdout_schema` marked `covered` must point to a schema created by WI-1.
- Every advertised but uncovered JSON surface must be marked `deferred`, not
  silently omitted.

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
WI-1 (schemas) ──┬──→ WI-4 (eval harness) ──→ WI-3 (telemetry)
                  └──→ WI-5 (portability)
WI-2 (metadata)  ────→ WI-5 (portability)
```

WI-1 and WI-2 can run in parallel. WI-4 depends on WI-1. WI-3 should run
after WI-4 so script instrumentation is protected by schema/eval checks.
WI-5 depends on WI-1 and WI-2.

## Recommended Implementation Order

1. **WI-1** + **WI-2** in parallel (foundation, no cross-dependencies)
2. **WI-4** (eval harness, needs schemas from WI-1)
3. **WI-3** (telemetry, edits existing scripts and should be protected by evals)
4. **WI-5** (portability, needs both WI-1 and WI-2)

## Sizing Estimates

| Item | Estimated effort | Files touched | New files |
|------|-----------------|---------------|-----------|
| WI-1 | Small-medium | 0 existing | 4–5 schema files + 1 test script |
| WI-2 | Small | 1 (metadata.json) | 0 |
| WI-3 | Medium | 3 (gate scripts) | 1 schema + 1 reference doc |
| WI-4 | Medium | 0 existing | 4–6 eval files + baselines |
| WI-5 | Small | 0–1 existing | 2 (manifest.yaml + PORTABILITY.md) |

## Beadization Guidance

Convert this plan into implementation beads using the following slices. Do not
merge slices just because they are in the same work item.

1. **Schema inventory and route schema**
   - Add `schemas/README.md`.
   - Add route schema and route schema fixture validation only.

2. **Gate/quality/triage schemas**
   - Add dispatch verdict, quality gate, and authoring-triage schemas.
   - Extend `scripts/test_schemas.sh` fixtures for those contracts.

3. **Metadata dependency contract**
   - Update `metadata.json`.
   - Validate required/test/optional tool records.

4. **Telemetry helper and schema**
   - Add shared telemetry helper.
   - Add telemetry schema and `references/TELEMETRY.md`.
   - No existing script behavior changes yet.

5. **Route telemetry instrumentation**
   - Add `--telemetry` to `bead_route.sh`.
   - Prove stdout, stderr, and exit codes are unchanged when telemetry is absent.

6. **Quality-gate telemetry instrumentation**
   - Add `--telemetry` to `bead_quality_gate.py`.
   - Prove JSON and markdown report stdout are unchanged when telemetry is absent.

7. **Gate-loop telemetry instrumentation**
   - Add `--telemetry` to `bead_gate_loop.sh`.
   - Emit one outer event; do not double-log inner quality-gate execution.

8. **Routing eval harness**
   - Add executable routing cases using temporary repos/fake tools.
   - Validate against the routing truth table.

9. **Quality eval harness**
   - Add deterministic quality baselines for counts and finding codes.
   - Do not introduce score concepts.

10. **Portability manifest and notes**
    - Add manifest and `PORTABILITY.md`.
    - Validate referenced paths and covered/deferred schema surfaces.

## Success Criteria

- All 4 JSON Schema files validate against current tool output.
- `metadata.json` declares tool dependencies that can be checked programmatically.
- Gate/route telemetry is opt-in, zero-overhead when disabled, and schema-compliant when enabled.
- `evals/run_evals.sh` passes on the current skill state and catches intentional regressions.
- `manifest.yaml` is valid and all referenced paths exist.
- No existing test, gate, or script behavior changes.
- No changes to domain content (rubric, failure modes, examples, formatting rules).
- `scripts/test_schemas.sh` passes in a clean temporary environment.
- Existing tests continue to pass:
  - `python3 scripts/test_bead_quality_gate.py`
  - `bash scripts/test_bead_gate_loop.sh`
  - `bash scripts/test_cli_robot_surfaces.sh`
- For each telemetry-instrumented script, a no-telemetry invocation produces
  byte-identical stdout and the same exit code as before instrumentation.
- For each telemetry-instrumented script, telemetry failure writes only stderr
  diagnostics and does not alter the primary command result.
- Eval baselines are deterministic, offline, and do not depend on the caller's
  active `.beads` graph.
