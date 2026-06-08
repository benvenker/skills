#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
CONTRACT_VERSION="2026-06-05"
KNOWN_FLAGS=(--repo --all --changed-staged --changed-since --operator-dispatch --strict --json --telemetry --version --robot-help -h --help)
START_MS="$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"

usage() {
  cat >&2 <<'EOF'
Usage: bead_gate_loop.sh [--repo PATH] [--all | --changed-staged | --changed-since REF | --operator-dispatch] [--strict] [--json] [--telemetry PATH]
       bead_gate_loop.sh capabilities --json
       bead_gate_loop.sh robot-docs guide

Runs deterministic Beads quality gates and writes repair artifacts. Designed for
agent loops, pre-commit-style orchestration, and pre-implementation dispatch.

Modes:
  --changed-staged      lint only staged .beads/issues.jsonl changes (default)
  --changed-since REF   lint only bead changes since REF
  --all                 lint all active beads
  --operator-dispatch   pre-implementation gate over all active beads; elevates
                        structural child size/section warnings into split-review
                        blockers and writes a dispatch verdict artifact
  --strict              fail on warnings as well as errors
  --json                emit the dispatch verdict JSON on stdout; human status
                        and repair prompts move to stderr
  --telemetry PATH      Append one Better Beads telemetry JSONL event for this
                        outer gate-loop run
  --version             print version and exit
  --robot-help          print an agent-oriented guide and exit

Examples:
  bead_gate_loop.sh --repo . --changed-staged
  bead_gate_loop.sh --repo . --operator-dispatch --strict
  bead_gate_loop.sh --repo . --operator-dispatch --telemetry /tmp/better-beads.jsonl
  bead_gate_loop.sh capabilities --json
  bead_gate_loop.sh robot-docs guide

Exit codes:
  0  gates passed for selected mode
  2  usage error, missing tooling, inspection failure, or gate blockage
EOF
}

capabilities_json() {
  cat <<EOF
{
  "tool": "bead_gate_loop.sh",
  "version": "$VERSION",
  "contract_version": "$CONTRACT_VERSION",
  "summary": "Run Beads quality, cycle, plan, and insight gates as one operator command.",
  "stdout": "Human-readable status plus artifact paths, requested capabilities JSON, or requested dispatch verdict JSON.",
  "stderr": "Usage errors, lower-level diagnostics, and human status when --json is requested.",
  "exit_codes": {
    "0": "all selected gates passed",
    "2": "usage error, missing br/bv/tooling, inspection failure, or blocked dispatch"
  },
  "robot_surfaces": [
    {"argv": ["capabilities", "--json"], "stdout_schema": "capabilities-v1"},
    {"argv": ["robot-docs", "guide"], "stdout_schema": "markdown-guide-v1"},
    {"argv": ["--robot-help"], "stdout_schema": "markdown-guide-v1"},
    {"argv": ["--operator-dispatch", "--json"], "stdout_schema": "better-beads-dispatch-verdict-v1"}
  ],
  "schemas": {
    "better-beads-dispatch-verdict-v1": {
      "stability": "stable",
      "description": "Machine-readable operator dispatch verdict emitted by --operator-dispatch --json.",
      "required_fields": [
        "schema",
        "tool",
        "version",
        "contract_version",
        "mode",
        "operator_dispatch",
        "dispatch_allowed",
        "blocked_reasons",
        "command_statuses",
        "finding_counts",
        "parse_failures",
        "schema_failures",
        "inspection_error_envelopes",
        "artifacts"
      ]
    }
  },
  "examples": [
    "bead_gate_loop.sh --repo . --operator-dispatch",
    "bead_gate_loop.sh --repo . --operator-dispatch --json",
    "bead_gate_loop.sh --repo . --operator-dispatch --telemetry /tmp/better-beads.jsonl",
    "bead_gate_loop.sh --repo . --changed-since HEAD --strict",
    "bead_gate_loop.sh capabilities --json"
  ]
}
EOF
}

robot_docs() {
  cat <<'EOF'
# Better Beads gate loop robot guide

Use `bead_gate_loop.sh` when an agent needs one pre-dispatch command that runs
Beads quality checks, dependency-cycle inspection, BV robot plan, and BV robot insights.

## First commands to try

```bash
scripts/bead_gate_loop.sh capabilities --json
scripts/bead_gate_loop.sh --repo . --operator-dispatch
scripts/bead_gate_loop.sh --repo . --operator-dispatch --json
scripts/bead_gate_loop.sh --repo . --operator-dispatch --telemetry /tmp/better-beads.jsonl
scripts/bead_gate_loop.sh --repo . --changed-staged --strict
```

## Output contract

- Human stdout names artifact paths, including the dispatch verdict JSON.
- With `--json`, stdout is one `better-beads-dispatch-verdict-v1` JSON object.
- With `--json`, human status and repair prompts move to stderr or artifacts.
- With `--telemetry PATH`, the loop appends one outer run event and does not
  pass telemetry flags to `bead_quality_gate.py`.
- Diagnostics and usage errors go to stderr.
- Exit `0` means dispatch/gate criteria passed.
- Exit `2` means usage, tooling, parse/schema, cycle, or deterministic gate failure.

## Agent workflow

1. Prefer `--operator-dispatch` before assigning implementation agents.
2. Read the printed dispatch verdict JSON for machine-readable blocked reasons.
3. Repair the generated markdown artifact, then rerun the same command.
EOF
}

suggest_option() {
  local bad="$1"
  python3 - "$bad" "${KNOWN_FLAGS[@]}" <<'PY'
import difflib, sys
bad = sys.argv[1]
flags = sys.argv[2:]
match = difflib.get_close_matches(bad, flags, n=1, cutoff=0.72)
if match:
    print(match[0])
PY
}

unknown_option() {
  local bad="$1"
  shift || true
  echo "Unknown option: $bad" >&2
  local suggestion
  suggestion="$(suggest_option "$bad")"
  if [[ -n "$suggestion" ]]; then
    local corrected=()
    local replaced=0
    local arg
    for arg in "$@"; do
      if [[ "$arg" == "$bad" && "$replaced" -eq 0 ]]; then
        corrected+=("$suggestion")
        replaced=1
      else
        corrected+=("$arg")
      fi
    done
    echo "Did you mean: $suggestion" >&2
    echo "Corrected command: $(basename "$0") ${corrected[*]}" >&2
  fi
  usage
  exit 2
}

case "${1:-}" in
  capabilities)
    if [[ "${2:-}" == "--json" && "$#" -eq 2 ]]; then
      capabilities_json
      exit 0
    fi
    echo "Unknown capabilities invocation: $*" >&2
    echo "Use: $(basename "$0") capabilities --json" >&2
    exit 2
    ;;
  robot-docs)
    if [[ "${2:-}" == "guide" && "$#" -eq 2 ]]; then
      robot_docs
      exit 0
    fi
    echo "Unknown robot-docs invocation: $*" >&2
    echo "Use: $(basename "$0") robot-docs guide" >&2
    exit 2
    ;;
  --robot-help)
    robot_docs
    exit 0
    ;;
  --version)
    echo "$VERSION"
    exit 0
    ;;
esac

REPO="$(pwd)"
MODE="changed-staged"
CHANGED_SINCE=""
STRICT=0
OPERATOR_DISPATCH=0
JSON_OUTPUT=0
TELEMETRY_PATH=""

while (($#)); do
  case "$1" in
    --repo)
      [[ -n "${2:-}" ]] || { echo "--repo requires a path" >&2; exit 2; }
      REPO="$2"
      shift 2
      ;;
    --all)
      MODE="all"
      OPERATOR_DISPATCH=0
      shift
      ;;
    --changed-staged)
      MODE="changed-staged"
      OPERATOR_DISPATCH=0
      shift
      ;;
    --changed-since)
      [[ -n "${2:-}" ]] || { echo "--changed-since requires a ref" >&2; exit 2; }
      MODE="changed-since"
      CHANGED_SINCE="$2"
      OPERATOR_DISPATCH=0
      shift 2
      ;;
    --operator-dispatch)
      MODE="operator-dispatch"
      OPERATOR_DISPATCH=1
      shift
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    --telemetry)
      [[ -n "${2:-}" ]] || { echo "--telemetry requires a path" >&2; exit 2; }
      TELEMETRY_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      unknown_option "$1" "$@"
      ;;
  esac
done

REPO="$(cd "$REPO" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUALITY_GATE="$SCRIPT_DIR/bead_quality_gate.py"
TELEMETRY_HELPER="$SCRIPT_DIR/better_beads_telemetry.py"

if [[ ! -x "$QUALITY_GATE" ]]; then
  echo "Missing executable quality gate: $QUALITY_GATE" >&2
  exit 2
fi

if [[ ! -d "$REPO/.beads" ]]; then
  echo "No .beads directory found in $REPO" >&2
  exit 2
fi

ARTIFACT_DIR="${BEAD_GATE_LOOP_ARTIFACT_DIR:-${TMPDIR:-/tmp}/bead-quality-gate-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
mkdir -p "$ARTIFACT_DIR"

FAIL_ON="error"
if (( STRICT == 1 )); then
  FAIL_ON="warning"
fi

QUALITY_ARGS=(--repo "$REPO" --json --fail-on "$FAIL_ON")
case "$MODE" in
  all|operator-dispatch)
    ;;
  changed-staged)
    QUALITY_ARGS+=(--changed-only --staged)
    ;;
  changed-since)
    QUALITY_ARGS+=(--changed-only --changed-since "$CHANGED_SINCE")
    ;;
esac
if (( OPERATOR_DISPATCH == 1 )); then
  QUALITY_ARGS+=(--operator-dispatch)
fi

emit_loop_telemetry() {
  local exit_code="$1"
  local verdict="$2"
  if [[ -z "$TELEMETRY_PATH" ]]; then
    return 0
  fi
  if [[ ! -r "$TELEMETRY_HELPER" ]]; then
    echo "better-beads telemetry warning: helper missing or unreadable: $TELEMETRY_HELPER" >&2
    return 0
  fi
  local duration_ms
  duration_ms="$(python3 - "$START_MS" <<'PY'
import sys, time
start = int(sys.argv[1])
print(max(0, int(time.time() * 1000) - start))
PY
)"
  local counts_json
  counts_json="$(python3 - "$VERDICT_JSON" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    counts = data.get("finding_counts") or {}
except Exception:
    counts = {}
print(json.dumps(counts, sort_keys=True, separators=(",", ":")))
PY
)"
  local telemetry_stderr
  if ! telemetry_stderr="$(python3 "$TELEMETRY_HELPER" \
    --emit "$TELEMETRY_PATH" \
    --tool "bead_gate_loop.sh" \
    --tool-version "$VERSION" \
    --contract-version "$CONTRACT_VERSION" \
    --mode "$MODE" \
    --repo "$REPO" \
    --duration-ms "$duration_ms" \
    --exit-code "$exit_code" \
    --verdict "$verdict" \
    --finding-counts "$counts_json" 2>&1 >/dev/null)"; then
    echo "better-beads telemetry warning: helper failed: $telemetry_stderr" >&2
  elif [[ -n "$telemetry_stderr" ]]; then
    echo "$telemetry_stderr" >&2
  fi
}

GATE_JSON="$ARTIFACT_DIR/bead-quality-gate.json"
CYCLES_JSON="$ARTIFACT_DIR/br-dep-cycles.json"
PLAN_JSON="$ARTIFACT_DIR/bv-robot-plan.json"
INSIGHTS_JSON="$ARTIFACT_DIR/bv-robot-insights.json"
PROMPT_MD="$ARTIFACT_DIR/fix-beads-and-rerun.md"
SPLIT_REVIEW_MD="$ARTIFACT_DIR/split-review-required.md"
VERDICT_JSON="$ARTIFACT_DIR/dispatch-verdict.json"

cd "$REPO"

BR_RC=0
if command -v br >/dev/null 2>&1; then
  br dep cycles --json >"$CYCLES_JSON" || BR_RC=$?
else
  echo '{"error":"br not found"}' >"$CYCLES_JSON"
  BR_RC=127
fi

BV_PLAN_RC=0
BV_INSIGHTS_RC=0
if command -v bv >/dev/null 2>&1; then
  bv --robot-plan >"$PLAN_JSON" || BV_PLAN_RC=$?
  bv --robot-insights >"$INSIGHTS_JSON" || BV_INSIGHTS_RC=$?
else
  echo '{"error":"bv not found"}' >"$PLAN_JSON"
  echo '{"error":"bv not found"}' >"$INSIGHTS_JSON"
  BV_PLAN_RC=127
  BV_INSIGHTS_RC=127
fi

QUALITY_RC=0
python3 "$QUALITY_GATE" "${QUALITY_ARGS[@]}" >"$GATE_JSON" || QUALITY_RC=$?

python3 - "$GATE_JSON" "$CYCLES_JSON" "$PLAN_JSON" "$INSIGHTS_JSON" "$PROMPT_MD" "$SPLIT_REVIEW_MD" "$VERDICT_JSON" "$MODE" "$FAIL_ON" "$CHANGED_SINCE" "$OPERATOR_DISPATCH" "$BR_RC" "$BV_PLAN_RC" "$BV_INSIGHTS_RC" "$QUALITY_RC" "$ARTIFACT_DIR" "$VERSION" "$CONTRACT_VERSION" <<'PY'
import json
import sys
from pathlib import Path

(
    gate_path,
    cycles_path,
    plan_path,
    insights_path,
    prompt_path,
    split_path,
    verdict_path,
    mode,
    fail_on,
    changed_since,
    operator_dispatch,
    br_rc,
    bv_plan_rc,
    bv_insights_rc,
    quality_rc,
    artifact_dir,
    version,
    contract_version,
) = sys.argv[1:]

gate_path = Path(gate_path)
cycles_path = Path(cycles_path)
plan_path = Path(plan_path)
insights_path = Path(insights_path)
prompt_path = Path(prompt_path)
split_path = Path(split_path)
verdict_path = Path(verdict_path)
operator_dispatch_bool = operator_dispatch == "1"
rcs = {
    "br_dep_cycles": int(br_rc),
    "bv_robot_plan": int(bv_plan_rc),
    "bv_robot_insights": int(bv_insights_rc),
    "bead_quality_gate": int(quality_rc),
}

parse_failures = []
schema_failures = []

def load(path, name):
    try:
        payload = json.loads(path.read_text())
    except Exception as exc:
        parse_failures.append(name)
        return {"error": str(exc)}
    if not isinstance(payload, dict):
        schema_failures.append(name)
        return {"error": f"expected top-level JSON object, got {type(payload).__name__}"}
    return payload

gate = load(gate_path, "bead_quality_gate")
cycles = load(cycles_path, "br_dep_cycles")
plan = load(plan_path, "bv_robot_plan")
insights = load(insights_path, "bv_robot_insights")
inspection_payloads = {
    "br_dep_cycles": cycles,
    "bv_robot_plan": plan,
    "bv_robot_insights": insights,
}
inspection_error_envelopes = {}
for name, payload in inspection_payloads.items():
    if rcs[name] != 0 or name in parse_failures or name in schema_failures:
        continue
    error = payload.get("error")
    if error:
        inspection_error_envelopes[name] = error

STRUCTURAL_SPLIT_CODES = {"long-child-contract", "too-many-child-sections", "large-child"}
findings = gate.get("findings", [])
errors = [f for f in findings if f.get("severity") == "error"]
warnings = [f for f in findings if f.get("severity") == "warning"]
split_findings = [
    f for f in findings
    if f.get("requires_split_review")
    or (operator_dispatch_bool and f.get("code") in STRUCTURAL_SPLIT_CODES)
]
operator_blocks = [f for f in findings if f.get("operator_blocking")]
cycle_count = cycles.get("count")
if cycle_count is None and isinstance(cycles.get("cycles"), list):
    cycle_count = len(cycles.get("cycles"))

tool_failures = {name: rc for name, rc in rcs.items() if rc != 0 and name != "bead_quality_gate"}
blocked_reasons = []
if tool_failures:
    if any(rc == 127 for rc in tool_failures.values()):
        blocked_reasons.append("missing-tooling")
    else:
        blocked_reasons.append("inspection-tool-failure")
if parse_failures:
    blocked_reasons.append("inspection-json-parse-failure")
if schema_failures:
    blocked_reasons.append("inspection-json-schema-failure")
if inspection_error_envelopes:
    blocked_reasons.append("inspection-error-envelope")
if cycle_count:
    blocked_reasons.append("dependency-cycles")
if errors:
    blocked_reasons.append("deterministic-errors")
if operator_blocks:
    blocked_reasons.append("operator-blocking-findings")
if split_findings:
    blocked_reasons.append("split-review-required")
if int(quality_rc) != 0 and not errors and not operator_blocks:
    blocked_reasons.append("strict-warning-block")

dispatch_allowed = not blocked_reasons

lines = []
lines.append("# Fix Beads Quality Gate Failures\n")
if operator_dispatch_bool:
    lines.append("The operator-dispatch gate blocked implementation dispatch. Fix the graph/descriptions, then rerun the gate.\n")
else:
    lines.append("The Beads quality gate failed or produced warnings. Fix the graph/descriptions, then rerun the gate.\n")
lines.append(f"- Mode: `{mode}`")
lines.append(f"- Fail-on: `{fail_on}`")
lines.append(f"- Operator dispatch: `{operator_dispatch_bool}`")
lines.append(f"- Errors: `{len(errors)}`")
lines.append(f"- Warnings: `{len(warnings)}`")
lines.append(f"- Split-review findings: `{len(split_findings)}`")
lines.append(f"- Operator-blocking findings: `{len(operator_blocks)}`")
lines.append(f"- JSON parse failures: `{len(parse_failures)}`")
lines.append(f"- JSON schema failures: `{len(schema_failures)}`")
lines.append(f"- Inspection error envelopes: `{len(inspection_error_envelopes)}`")
lines.append(f"- Cycle count: `{cycle_count}`")
lines.append(f"- Blocked reasons: `{', '.join(blocked_reasons) if blocked_reasons else 'none'}`")
lines.append("")
lines.append("## Required actions\n")
if tool_failures:
    lines.append("Inspection tooling failed; fix tooling or PATH before trusting dispatch:\n")
    for name, rc in tool_failures.items():
        lines.append(f"- `{name}` exited `{rc}`")
    lines.append("")
if schema_failures:
    lines.append("Inspection tooling returned valid JSON with the wrong top-level schema; fix tooling before trusting dispatch:\n")
    for name in schema_failures:
        lines.append(f"- `{name}` must emit a top-level JSON object")
    lines.append("")
if inspection_error_envelopes:
    lines.append("Inspection tooling returned rc-0 JSON error envelopes; fix tooling or graph inspection before trusting dispatch:\n")
    for name, error in inspection_error_envelopes.items():
        lines.append(f"- `{name}` returned error envelope: {error}")
    lines.append("")
if cycle_count:
    lines.append("Dependency cycles block dispatch; inspect `br-dep-cycles.json` and remove or reorder edges.\n")
if errors:
    lines.append("Fix all deterministic errors before continuing:\n")
    for f in errors[:40]:
        lines.append(f"- `{f.get('issue_id')}` `{f.get('code')}` — {f.get('message')}")
        lines.append(f"  - {f.get('title')}")
else:
    lines.append("No deterministic errors. Review warnings and semantic quality before swarm work.\n")

if warnings:
    lines.append("\nWarnings to address where practical:\n")
    for f in warnings[:60]:
        lines.append(f"- `{f.get('issue_id')}` `{f.get('code')}` — {f.get('message')}")
        lines.append(f"  - {f.get('title')}")

if operator_blocks:
    lines.append("\n## Operator-blocking findings\n")
    lines.append("Do not dispatch implementation agents until each operator-blocking finding is resolved.\n")
    for f in operator_blocks[:60]:
        lines.append(f"- `{f.get('issue_id')}` `{f.get('code')}` — {f.get('message')}")
        lines.append(f"  - {f.get('title')}")

if split_findings:
    lines.append("\n## Split-review blockers\n")
    lines.append("Do not dispatch implementation agents until each blocked child is classified and repaired. Use `split-review-required.md`.\n")
    for f in split_findings[:60]:
        lines.append(f"- `{f.get('issue_id')}` `{f.get('code')}` — {f.get('message')}")
        lines.append(f"  - {f.get('title')}")

lines.append("\n## Graph plan snapshot\n")
summary = plan.get("plan", {}).get("summary") or plan.get("summary") or {}
if summary:
    lines.append("```json")
    lines.append(json.dumps(summary, indent=2))
    lines.append("```")
else:
    lines.append("No bv plan summary available.")

lines.append("\n## Rerun command\n")
rerun = [".agents/skills/better-beads/scripts/bead_gate_loop.sh"]
if mode == "operator-dispatch":
    rerun.append("--operator-dispatch")
elif mode == "all":
    rerun.append("--all")
elif mode == "changed-since":
    rerun.extend(["--changed-since", changed_since])
else:
    rerun.append("--changed-staged")
if fail_on == "warning":
    rerun.append("--strict")
lines.append("```bash")
lines.append(" ".join(rerun))
lines.append("```")

lines.append("\n## Agent instruction\n")
lines.append("Fix the Beads, not just this report. Use BEAD-FORMATTING.md, FAILURE-MODES.md, QUALITY-RUBRIC.md, and SEMANTIC-GATE.md. A child bead must be one independently testable functional behavior, not a broad surface bucket, checklist bucket, or detail bucket. If a referenced smoke script does not exist, either create it in scope or rewrite the bead so creation of the script is explicit.")
prompt_path.write_text("\n".join(lines))

split_lines = []
split_lines.append("# Operator Split Review Required\n")
if split_findings:
    split_lines.append("These child beads triggered structural over-detail findings. The deterministic gate does not decide whether they are semantically too broad; it requires this split-review before implementation dispatch.\n")
    split_lines.append("## Functional-behavior rule\n")
    split_lines.append("Each child bead must describe one independently testable functional behavior with compact verification. Parents and epics are closure/dependency contracts, not implementation buckets.\n")
    split_lines.append("## Allowed outcomes\n")
    split_lines.append("For each bead choose exactly one:")
    split_lines.append("- keep one child with evidence that every section supports the same functional behavior;")
    split_lines.append("- split into child beads, each with dependency edges and verification;")
    split_lines.append("- convert a broad bucket into a parent/epic closure contract;")
    split_lines.append("- merge checklist crumbs into a functional behavior bead;")
    split_lines.append("- defer, delete, or close unnecessary work with evidence.\n")
    split_lines.append("## Blocked beads\n")
    by_id = {}
    for f in split_findings:
        by_id.setdefault(f.get("issue_id"), []).append(f)
    for issue_id, fs in by_id.items():
        title = fs[0].get("title")
        codes = ", ".join(sorted({f.get("code") for f in fs if f.get("code")}))
        split_lines.append(f"### `{issue_id}` — {title}")
        split_lines.append(f"- Finding codes: `{codes}`")
        split_lines.append("- Required classification: `keep` | `split` | `convert-to-parent` | `merge` | `defer` | `delete/close unnecessary`")
        split_lines.append("- Required graph updates if changed: dependency edges, parent order, labels, and `ready-for-agent` frontier.")
        split_lines.append("- Evidence to write: why the outcome is one behavior, or how the new child/parent graph proves closure.\n")
else:
    split_lines.append("No split-review findings for this run.\n")
split_path.write_text("\n".join(split_lines))

verdict = {
    "schema": "better-beads-dispatch-verdict-v1",
    "tool": "bead_gate_loop.sh",
    "version": version,
    "contract_version": contract_version,
    "mode": mode,
    "operator_dispatch": operator_dispatch_bool,
    "fail_on": fail_on,
    "changed_since": changed_since or None,
    "dispatch_allowed": dispatch_allowed,
    "blocked_reasons": blocked_reasons,
    "command_statuses": rcs,
    "tool_failures": tool_failures,
    "parse_failures": parse_failures,
    "schema_failures": schema_failures,
    "inspection_error_envelopes": inspection_error_envelopes,
    "finding_counts": {
        "deterministic_errors": len(errors),
        "warnings": len(warnings),
        "operator_blocking": len(operator_blocks),
        "split_review_required": len(split_findings),
    },
    "deterministic_error_count": len(errors),
    "warning_count": len(warnings),
    "operator_blocking_count": len(operator_blocks),
    "split_review_required_count": len(split_findings),
    "dependency_cycle_count": cycle_count,
    "quality_gate_exit_code": int(quality_rc),
    "artifacts": {
        "quality_gate_json": str(gate_path),
        "dependency_cycles_json": str(cycles_path),
        "bv_robot_plan_json": str(plan_path),
        "bv_robot_insights_json": str(insights_path),
        "fix_prompt_markdown": str(prompt_path),
        "split_review_markdown": str(split_path),
        "dispatch_verdict_json": str(verdict_path),
        "artifact_dir": artifact_dir,
    },
    "insights_error": insights.get("error"),
}
verdict_path.write_text(json.dumps(verdict, indent=2))
PY

BLOCKED=0
if (( BR_RC != 0 || BV_PLAN_RC != 0 || BV_INSIGHTS_RC != 0 || QUALITY_RC != 0 )); then
  BLOCKED=1
fi

# Also block on actual dependency cycles if the JSON is available.
if python3 - "$CYCLES_JSON" <<'PY'
import json, sys
try:
    data=json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
count=data.get('count')
if count is None and isinstance(data.get('cycles'), list):
    count=len(data['cycles'])
raise SystemExit(0 if not count else 1)
PY
then
  :
else
  BLOCKED=1
fi

# Keep process exit aligned with the generated dispatch verdict.
if python3 - "$VERDICT_JSON" <<'PY'
import json, sys
try:
    data=json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if data.get('dispatch_allowed') else 1)
PY
then
  :
else
  BLOCKED=1
fi

if (( JSON_OUTPUT == 1 )); then
  cat "$VERDICT_JSON"
  echo "Bead gate artifacts: $ARTIFACT_DIR" >&2
  echo "Dispatch verdict: $VERDICT_JSON" >&2
else
  echo "Bead gate artifacts: $ARTIFACT_DIR"
  echo "Dispatch verdict: $VERDICT_JSON"
fi
if (( BLOCKED == 1 )); then
  if (( OPERATOR_DISPATCH == 1 )); then
    echo "Operator dispatch BLOCKED. Fix prompt: $PROMPT_MD" >&2
    echo "Split review artifact: $SPLIT_REVIEW_MD" >&2
  else
    echo "Bead quality gate BLOCKED. Fix prompt: $PROMPT_MD" >&2
  fi
  sed -n '1,140p' "$PROMPT_MD" >&2
  emit_loop_telemetry 2 fail
  exit 2
fi

if (( OPERATOR_DISPATCH == 1 )); then
  if (( JSON_OUTPUT == 1 )); then
    echo "Operator dispatch gate passed. Artifacts: $ARTIFACT_DIR" >&2
  else
    echo "Operator dispatch gate passed. Artifacts: $ARTIFACT_DIR"
  fi
else
  if (( JSON_OUTPUT == 1 )); then
    echo "Bead quality gate passed. Artifacts: $ARTIFACT_DIR" >&2
  else
    echo "Bead quality gate passed. Artifacts: $ARTIFACT_DIR"
  fi
fi
emit_loop_telemetry 0 pass
exit 0
