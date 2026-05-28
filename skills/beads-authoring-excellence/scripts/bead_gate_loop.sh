#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bead_gate_loop.sh [--repo PATH] [--all | --changed-staged | --changed-since REF] [--strict]

Runs a deterministic Beads quality gate and writes a rerun/fix prompt when the
gate fails. Designed for agent loops and pre-commit-style orchestration.

Modes:
  --changed-staged      lint only staged .beads/issues.jsonl changes (default)
  --changed-since REF   lint only bead changes since REF
  --all                 lint all active beads
  --strict              fail on warnings as well as errors
EOF
}

REPO="$(pwd)"
MODE="changed-staged"
CHANGED_SINCE=""
STRICT=0

while (($#)); do
  case "$1" in
    --repo)
      [[ -n "${2:-}" ]] || { echo "--repo requires a path" >&2; exit 2; }
      REPO="$2"
      shift 2
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --changed-staged)
      MODE="changed-staged"
      shift
      ;;
    --changed-since)
      [[ -n "${2:-}" ]] || { echo "--changed-since requires a ref" >&2; exit 2; }
      MODE="changed-since"
      CHANGED_SINCE="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

REPO="$(cd "$REPO" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUALITY_GATE="$SCRIPT_DIR/bead_quality_gate.py"

if [[ ! -x "$QUALITY_GATE" ]]; then
  echo "Missing executable quality gate: $QUALITY_GATE" >&2
  exit 2
fi

if [[ ! -d "$REPO/.beads" ]]; then
  echo "No .beads directory found in $REPO" >&2
  exit 2
fi

ARTIFACT_DIR="${TMPDIR:-/tmp}/bead-quality-gate-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$ARTIFACT_DIR"

FAIL_ON="error"
if (( STRICT == 1 )); then
  FAIL_ON="warning"
fi

QUALITY_ARGS=(--repo "$REPO" --json --fail-on "$FAIL_ON")
case "$MODE" in
  all)
    ;;
  changed-staged)
    QUALITY_ARGS+=(--changed-only --staged)
    ;;
  changed-since)
    QUALITY_ARGS+=(--changed-only --changed-since "$CHANGED_SINCE")
    ;;
esac

GATE_JSON="$ARTIFACT_DIR/bead-quality-gate.json"
CYCLES_JSON="$ARTIFACT_DIR/br-dep-cycles.json"
PLAN_JSON="$ARTIFACT_DIR/bv-robot-plan.json"
INSIGHTS_JSON="$ARTIFACT_DIR/bv-robot-insights.json"
PROMPT_MD="$ARTIFACT_DIR/fix-beads-and-rerun.md"

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

python3 - "$GATE_JSON" "$CYCLES_JSON" "$PLAN_JSON" "$PROMPT_MD" "$MODE" "$FAIL_ON" "$CHANGED_SINCE" <<'PY'
import json
import sys
from pathlib import Path

gate_path = Path(sys.argv[1])
cycles_path = Path(sys.argv[2])
plan_path = Path(sys.argv[3])
prompt_path = Path(sys.argv[4])
mode = sys.argv[5]
fail_on = sys.argv[6]
changed_since = sys.argv[7]

def load(path):
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        return {"error": str(exc)}

gate = load(gate_path)
cycles = load(cycles_path)
plan = load(plan_path)
findings = gate.get("findings", [])
errors = [f for f in findings if f.get("severity") == "error"]
warnings = [f for f in findings if f.get("severity") == "warning"]
cycle_count = cycles.get("count")
if cycle_count is None and isinstance(cycles.get("cycles"), list):
    cycle_count = len(cycles.get("cycles"))

lines = []
lines.append("# Fix Beads Quality Gate Failures\n")
lines.append("The Beads quality gate failed or produced warnings. Fix the graph/descriptions, then rerun the gate.\n")
lines.append(f"- Mode: `{mode}`")
lines.append(f"- Fail-on: `{fail_on}`")
lines.append(f"- Errors: `{len(errors)}`")
lines.append(f"- Warnings: `{len(warnings)}`")
lines.append(f"- Cycle count: `{cycle_count}`")
lines.append("")
lines.append("## Required actions\n")
if errors:
    lines.append("Fix all errors before continuing:\n")
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

lines.append("\n## Graph plan snapshot\n")
summary = plan.get("plan", {}).get("summary") or {}
if summary:
    lines.append("```json")
    lines.append(json.dumps(summary, indent=2))
    lines.append("```")
else:
    lines.append("No bv plan summary available.")

lines.append("\n## Rerun command\n")
rerun = [".agents/skills/beads-authoring-excellence/scripts/bead_gate_loop.sh"]
if mode == "all":
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
lines.append("Fix the Beads, not just this report. Use BEAD-FORMATTING.md, FAILURE-MODES.md, and QUALITY-RUBRIC.md. If a referenced smoke script does not exist, either create it in scope or rewrite the bead so creation of the script is explicit. Do not claim 28–30/30 until the deterministic gate is clean and the graph passes semantic review.")

prompt_path.write_text("\n".join(lines))
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

echo "Bead gate artifacts: $ARTIFACT_DIR"
if (( BLOCKED == 1 )); then
  echo "Bead quality gate BLOCKED. Fix prompt: $PROMPT_MD" >&2
  sed -n '1,120p' "$PROMPT_MD" >&2
  exit 2
fi

echo "Bead quality gate passed. Artifacts: $ARTIFACT_DIR"
exit 0
