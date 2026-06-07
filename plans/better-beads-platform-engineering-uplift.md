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

### WI-1: Publish JSON Schema files for structured outputs

**Outcome**: Every named JSON contract has a machine-validatable schema.

**Scope**:
- Create `schemas/better-beads-route-v1.schema.json` matching current `bead_route.sh --json` output.
- Create `schemas/better-beads-dispatch-verdict-v1.schema.json` matching current `bead_gate_loop.sh --operator-dispatch --json` output.
- Create `schemas/better-beads-quality-gate-v1.schema.json` matching current `bead_quality_gate.py --json` output.
- Create `schemas/better-beads-authoring-triage-v1.schema.json` matching current `better-beads authoring-triage --json` output.

**Validation**:
- Each schema passes `jsonschema` or `ajv` validation against actual tool output.
- Add a test script `scripts/test_schemas.sh` that runs each tool and validates output against its schema.
- Existing `--json` output must not change; schemas describe current behavior.

**Failure behavior**:
- If current output is inconsistent across modes, document the variance and pick the superset shape.
- If a field is optional in practice, mark it as such in the schema rather than forcing it.

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
- Add `required_tools` section: `br` (minimum version TBD from `br --version`), `bv` (minimum version TBD), `python3` (≥3.10), `bash` (≥4.0).
- Add `optional_tools` section: `jq`, `jsonschema`/`ajv` (for schema validation).
- Add `compatibility` section with tested `br`/`bv` versions.
- Add `triggers` and `exclusions` fields matching SKILL.md frontmatter semantics.
- Add `required_capabilities`: `filesystem_read`, `filesystem_write`, `bash_execute`.
- Preserve existing fields (`version`, `organization`, `date`, `abstract`, `references`).

**Validation**:
- `python3 -c "import json; d=json.load(open('metadata.json')); assert 'required_tools' in d"`
- A pre-existing tool version mismatch should be detectable by reading metadata alone.

**Failure behavior**:
- If a tool version cannot be reliably pinned (e.g., `bv` has no `--version`), document the check command instead.

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
- When the flag is set, append one JSONL event per invocation with:
  - `timestamp` (ISO 8601)
  - `tool` (script name)
  - `mode` (route mode, gate mode, etc.)
  - `project` (repo root or `.beads` path)
  - `duration_ms`
  - `verdict` (pass/fail/block/etc.)
  - `finding_counts` (errors, warnings, by category)
  - `schema_version` (`better-beads-telemetry-v1`)
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

**Known anchors**:
- `scripts/bead_quality_gate.py` — Python entry, add `argparse` flag
- `scripts/bead_gate_loop.sh` — shell orchestrator, forward flag to Python
- `scripts/bead_route.sh` — route helper, add duration/verdict logging
- `scripts/test_bead_quality_gate.py` — existing Python tests
- `scripts/test_bead_gate_loop.sh` — existing shell tests

**Dependencies**: WI-1 (schemas should exist before defining telemetry schema).

---

### WI-4: Build minimal eval harness for routing and bead quality

**Outcome**: An automated eval pipeline that can detect routing drift and bead quality regression across model changes.

**Scope**:
- Create `evals/` directory.
- Create `evals/routing_eval.py`:
  - Reads each `test/golden/*.input.md` fixture.
  - Runs `bead_route.sh` with the fixture as `--plan`.
  - Compares recommended mode against `test/golden/*.expected.md`.
  - Reports pass/fail per fixture.
- Create `evals/quality_eval.py`:
  - Reads `test/fixtures/example-graph.json`.
  - Runs `bead_quality_gate.py` against each bead.
  - Compares scores and findings against expected baselines in `evals/baselines/`.
  - Reports score drift.
- Create `evals/run_evals.sh` as the single entry point.
- Add `evals/baselines/` with current golden scores.
- Add `evals/README.md` documenting how to run and update baselines.

**Validation**:
- `bash evals/run_evals.sh` exits 0 when baselines match.
- Intentionally breaking a fixture (e.g., changing expected mode) causes exit 1.
- The eval harness does not require network access or LLM calls.

**Failure behavior**:
- If `bead_route.sh` or `bead_quality_gate.py` is missing or broken, the eval reports the tool error rather than silently passing.
- Score drift within ±1 point is a warning; drift beyond ±2 is a failure.

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
  - `input_schema`, `output_schema` (referencing schemas/)
  - `risk_level`: `low` (read-only inspection) to `medium` (bead mutation)
  - `resources` listing reference files
  - `scripts` listing executable tools
- Ensure `SKILL.md` can be consumed standalone (it already can, but verify no broken relative paths when the skill is installed outside the skills monorepo).
- Add a `PORTABILITY.md` note documenting what works without `br`/`bv` (the rubric, failure modes, formatting guide, and examples are all portable; the scripts and gates require the toolchain).

**Validation**:
- `python3 -c "import yaml; yaml.safe_load(open('manifest.yaml'))"` succeeds.
- All paths referenced in manifest.yaml exist.
- SKILL.md relative references resolve correctly when the skill dir is symlinked elsewhere.

**Failure behavior**:
- If YAML validation fails, the manifest is malformed and must be fixed before merge.

**Known anchors**:
- `metadata.json` — current metadata
- `SKILL.md` — current entrypoint
- `references/README.md` — reading order and package status

**Dependencies**: WI-1 (schemas referenced in manifest), WI-2 (tool deps referenced in manifest).

---

## Dependency Graph

```
WI-1 (schemas) ──┬──→ WI-3 (telemetry)
                  ├──→ WI-4 (eval harness)
                  └──→ WI-5 (portability)
WI-2 (metadata)  ────→ WI-5 (portability)
```

WI-1 and WI-2 can run in parallel. WI-3, WI-4, and WI-5 depend on WI-1. WI-5
also depends on WI-2.

## Recommended Implementation Order

1. **WI-1** + **WI-2** in parallel (foundation, no cross-dependencies)
2. **WI-3** (telemetry, needs schemas from WI-1)
3. **WI-4** (eval harness, needs schemas from WI-1)
4. **WI-5** (portability, needs both WI-1 and WI-2)

## Sizing Estimates

| Item | Estimated effort | Files touched | New files |
|------|-----------------|---------------|-----------|
| WI-1 | Small-medium | 0 existing | 4–5 schema files + 1 test script |
| WI-2 | Small | 1 (metadata.json) | 0 |
| WI-3 | Medium | 3 (gate scripts) | 1 schema + 1 reference doc |
| WI-4 | Medium | 0 existing | 4–6 eval files + baselines |
| WI-5 | Small | 0–1 existing | 2 (manifest.yaml + PORTABILITY.md) |

## Success Criteria

- All 4 JSON Schema files validate against current tool output.
- `metadata.json` declares tool dependencies that can be checked programmatically.
- Gate/route telemetry is opt-in, zero-overhead when disabled, and schema-compliant when enabled.
- `evals/run_evals.sh` passes on the current skill state and catches intentional regressions.
- `manifest.yaml` is valid and all referenced paths exist.
- No existing test, gate, or script behavior changes.
- No changes to domain content (rubric, failure modes, examples, formatting rules).
