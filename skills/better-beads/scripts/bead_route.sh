#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
CONTRACT_VERSION="2026-06-06"
KNOWN_FLAGS=(--repo --json --version --robot-help -h --help)

usage() {
  cat >&2 <<'EOF'
Usage: bead_route.sh [--repo PATH] [--json]
       bead_route.sh capabilities --json
       bead_route.sh robot-docs guide

Inspects Beads graph state and recommends an operator mode.

Modes:
  create-from-raw-plan   No relevant beads; create from a ready plan
  improve-plan-first     Plan is raw or weak; strengthen before creating beads
  polish-existing-graph  Beads exist; repair graph before implementation dispatch
  closeout               Implementation ending; make in_progress state truthful

Options:
  --repo PATH       Repository containing .beads (default: current directory)
  --json            Emit JSON instead of human-readable output
  --version         Print version and exit
  --robot-help      Print an agent-oriented guide and exit

Examples:
  bead_route.sh --repo . --json
  bead_route.sh capabilities --json

Exit codes:
  0  routing recommendation produced
  2  usage error or missing tooling
EOF
}

capabilities_json() {
  cat <<EOF
{
  "tool": "bead_route.sh",
  "version": "$VERSION",
  "contract_version": "$CONTRACT_VERSION",
  "summary": "Inspect Beads graph state and recommend an operator mode before mutation.",
  "stdout": "Human status or requested JSON payload only.",
  "stderr": "Usage errors and missing tooling diagnostics only.",
  "exit_codes": {
    "0": "routing recommendation produced",
    "2": "usage error or missing tooling"
  },
  "modes": [
    "create-from-raw-plan",
    "improve-plan-first",
    "polish-existing-graph",
    "closeout"
  ],
  "mode_references": {
    "create-from-raw-plan": "references/MODE-CREATE-FROM-RAW-PLAN.md",
    "improve-plan-first": "references/MODE-IMPROVE-PLAN-FIRST.md",
    "polish-existing-graph": "references/MODE-POLISH-EXISTING-GRAPH.md",
    "closeout": "references/MODE-CLOSEOUT.md"
  },
  "robot_surfaces": [
    {"argv": ["capabilities", "--json"], "stdout_schema": "capabilities-v1"},
    {"argv": ["robot-docs", "guide"], "stdout_schema": "markdown-guide-v1"},
    {"argv": ["--robot-help"], "stdout_schema": "markdown-guide-v1"},
    {"argv": ["--json"], "stdout_schema": "better-beads-route-v1"}
  ],
  "examples": [
    "bead_route.sh --repo . --json",
    "bead_route.sh capabilities --json"
  ]
}
EOF
}

robot_docs() {
  cat <<'EOF'
# Better Beads route robot guide

Use `bead_route.sh` (or `better-beads route --json`) as the first step
before creating, polishing, or closing beads. It inspects graph state and
recommends the correct operator mode.

## First commands to try

```bash
scripts/better-beads route --json
scripts/bead_route.sh --repo . --json
scripts/bead_route.sh capabilities --json
```

## Output contract

- JSON mode emits `{ recommended_mode, reasoning, graph_state, modes }`.
- Human mode prints the recommendation and next steps.
- Exit `0` means a recommendation was produced.
- Exit `2` means usage error or missing tooling.

## After routing

Read the mode procedure for the recommended mode:

- `references/MODE-CREATE-FROM-RAW-PLAN.md`
- `references/MODE-IMPROVE-PLAN-FIRST.md`
- `references/MODE-POLISH-EXISTING-GRAPH.md`
- `references/MODE-CLOSEOUT.md`

Then follow the mode's Actions → Gates → Outputs flow.
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
    echo "Use: $(basename "$0") capabilities --json" >&2
    exit 2
    ;;
  robot-docs)
    if [[ "${2:-}" == "guide" && "$#" -eq 2 ]]; then
      robot_docs
      exit 0
    fi
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
JSON=0

while (($#)); do
  case "$1" in
    --repo)
      [[ -n "${2:-}" ]] || { echo "--repo requires a path" >&2; exit 2; }
      REPO="$2"
      shift 2
      ;;
    --json)
      JSON=1
      shift
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

# No .beads directory — recommend create-from-raw-plan
if [[ ! -d "$REPO/.beads" ]]; then
  python3 - "$JSON" <<'PY'
import json, sys
emit_json = sys.argv[1] == "1"

modes = [
    {"mode": "create-from-raw-plan", "reference": "references/MODE-CREATE-FROM-RAW-PLAN.md", "recommended": True},
    {"mode": "improve-plan-first", "reference": "references/MODE-IMPROVE-PLAN-FIRST.md", "recommended": False},
    {"mode": "polish-existing-graph", "reference": "references/MODE-POLISH-EXISTING-GRAPH.md", "recommended": False},
    {"mode": "closeout", "reference": "references/MODE-CLOSEOUT.md", "recommended": False},
]

if emit_json:
    print(json.dumps({
        "tool": "bead_route.sh",
        "schema": "better-beads-route-v1",
        "graph_state": {
            "has_beads_dir": False,
            "total_beads": 0,
            "by_status": {},
            "has_cycles": False,
            "cycle_count": 0,
            "cycle_inspection": "ok",
            "inspection_warnings": [],
        },
        "recommended_mode": "create-from-raw-plan",
        "reasoning": "No .beads directory found. Use create-from-raw-plan if you have a ready plan, or improve-plan-first if the plan needs strengthening.",
        "modes": modes,
        "next_steps": [
            "Read references/MODE-CREATE-FROM-RAW-PLAN.md for the full mode procedure",
            "If the plan is weak or under-grounded, read references/MODE-IMPROVE-PLAN-FIRST.md instead",
            "Initialize beads with: br init"
        ],
    }, indent=2))
else:
    print("Better Beads route: no .beads directory found")
    print()
    print("Recommended mode: create-from-raw-plan")
    print("  Use create-from-raw-plan if you have a ready plan.")
    print("  Use improve-plan-first if the plan needs strengthening.")
    print()
    print("Next steps:")
    print("  1. Read references/MODE-CREATE-FROM-RAW-PLAN.md")
    print("  2. Or read references/MODE-IMPROVE-PLAN-FIRST.md if plan is weak")
    print("  3. Initialize beads: br init")
PY
  exit 0
fi

# .beads exists — need br to inspect
if ! command -v br >/dev/null 2>&1; then
  echo "br not found on PATH; cannot inspect .beads state" >&2
  exit 2
fi

BEADS_JSON="$(mktemp "${TMPDIR:-/tmp}/bead-route-list.XXXXXX.json")"
BEADS_ERR="$(mktemp "${TMPDIR:-/tmp}/bead-route-list.XXXXXX.err")"
CYCLES_JSON="$(mktemp "${TMPDIR:-/tmp}/bead-route-cycles.XXXXXX.json")"
CYCLES_ERR="$(mktemp "${TMPDIR:-/tmp}/bead-route-cycles.XXXXXX.err")"
trap 'rm -f "$BEADS_JSON" "$BEADS_ERR" "$CYCLES_JSON" "$CYCLES_ERR"' EXIT

cd "$REPO"
if ! br list --json >"$BEADS_JSON" 2>"$BEADS_ERR"; then
  echo "br list --json failed; cannot safely inspect .beads state" >&2
  if [[ -s "$BEADS_ERR" ]]; then
    sed 's/^/  /' "$BEADS_ERR" >&2
  fi
  exit 2
fi

CYCLE_INSPECTION="ok"
if ! br dep cycles --json >"$CYCLES_JSON" 2>"$CYCLES_ERR"; then
  CYCLE_INSPECTION="failed"
fi

python3 - "$BEADS_JSON" "$CYCLES_JSON" "$JSON" "$CYCLE_INSPECTION" "$CYCLES_ERR" <<'PY'
import json
import sys

beads_path = sys.argv[1]
cycles_path = sys.argv[2]
emit_json = sys.argv[3] == "1"
cycle_inspection = sys.argv[4]
cycles_err_path = sys.argv[5]

# Parse beads
try:
    with open(beads_path) as f:
        beads_data = json.load(f)
except Exception as exc:
    print(f"br list --json returned malformed JSON; cannot safely inspect .beads state: {exc}", file=sys.stderr)
    sys.exit(2)

if isinstance(beads_data, dict) and any(key in beads_data for key in ("error", "errors")):
    print("br list --json returned an error envelope; cannot safely inspect .beads state", file=sys.stderr)
    sys.exit(2)

if isinstance(beads_data, dict):
    issues = beads_data.get("issues", [])
elif isinstance(beads_data, list):
    issues = beads_data
else:
    print("br list --json returned unsupported JSON; cannot safely inspect .beads state", file=sys.stderr)
    sys.exit(2)

if not isinstance(issues, list):
    print("br list --json returned a non-list issues payload; cannot safely inspect .beads state", file=sys.stderr)
    sys.exit(2)

# Parse cycles
inspection_warnings = []
if cycle_inspection == "failed":
    cycle_count = None
    cycle_stderr = ""
    try:
        with open(cycles_err_path) as f:
            cycle_stderr = f.read().strip()
    except Exception:
        cycle_stderr = ""
    warning = "br dep cycles --json failed; cycle safety is unknown"
    if cycle_stderr:
        warning += f": {cycle_stderr}"
    inspection_warnings.append(warning)
else:
    try:
        with open(cycles_path) as f:
            cycles_data = json.load(f)
        if not isinstance(cycles_data, dict):
            raise ValueError("expected object")
        cycle_count = cycles_data.get("count")
        if cycle_count is None and isinstance(cycles_data.get("cycles"), list):
            cycle_count = len(cycles_data["cycles"])
        if cycle_count is None:
            cycle_count = 0
    except Exception as exc:
        cycle_count = None
        cycle_inspection = "failed"
        inspection_warnings.append(f"Could not parse br dep cycles --json output; cycle safety is unknown: {exc}")

# Count by status
by_status = {}
for issue in issues:
    status = issue.get("status", "unknown")
    by_status[status] = by_status.get(status, 0) + 1

total = len(issues)
in_progress = by_status.get("in_progress", 0)
open_count = by_status.get("open", 0)
closed_count = by_status.get("closed", 0)
active_count = total - closed_count

# Decision tree
if total == 0:
    mode = "create-from-raw-plan"
    reasoning = (
        "No beads in graph. Use create-from-raw-plan if you have a ready plan, "
        "or improve-plan-first if the plan needs strengthening."
    )
elif in_progress > 0 and open_count == 0:
    mode = "closeout"
    reasoning = (
        f"{in_progress} bead(s) in_progress with no open beads remaining. "
        "Implementation appears to be ending; make in_progress state truthful."
    )
elif in_progress > 0:
    mode = "polish-existing-graph"
    reasoning = (
        f"{total} beads ({in_progress} in_progress, {open_count} open). "
        "Graph has active and pending work; inspect and repair before dispatch. "
        "Consider closeout for in_progress beads that are actually complete."
    )
elif open_count > 0:
    mode = "polish-existing-graph"
    reasoning = (
        f"{total} beads ({open_count} open, {closed_count} closed). "
        "Open beads need inspection for split/merge/dependency/label repair before dispatch."
    )
elif active_count == 0:
    mode = "create-from-raw-plan"
    reasoning = (
        f"{total} beads, all closed. Use create-from-raw-plan for new work, "
        "or improve-plan-first if the plan needs strengthening."
    )
else:
    mode = "polish-existing-graph"
    reasoning = (
        f"{total} beads with non-terminal active status values ({active_count} not closed). "
        "Existing graph state needs inspection before creating new work."
    )

if cycle_count is not None and cycle_count > 0:
    reasoning += f" WARNING: {cycle_count} dependency cycle(s) detected; resolve before dispatch."
elif cycle_inspection == "failed":
    reasoning += " WARNING: dependency cycle inspection failed; cycle safety is unknown."

has_cycles = cycle_count is not None and cycle_count > 0

graph_state = {
    "has_beads_dir": True,
    "total_beads": total,
    "by_status": by_status,
    "has_cycles": has_cycles,
    "cycle_count": cycle_count,
    "cycle_inspection": cycle_inspection,
    "inspection_warnings": inspection_warnings,
}

modes = [
    {"mode": "create-from-raw-plan", "reference": "references/MODE-CREATE-FROM-RAW-PLAN.md", "recommended": mode == "create-from-raw-plan"},
    {"mode": "improve-plan-first", "reference": "references/MODE-IMPROVE-PLAN-FIRST.md", "recommended": mode == "improve-plan-first"},
    {"mode": "polish-existing-graph", "reference": "references/MODE-POLISH-EXISTING-GRAPH.md", "recommended": mode == "polish-existing-graph"},
    {"mode": "closeout", "reference": "references/MODE-CLOSEOUT.md", "recommended": mode == "closeout"},
]

ref_file = next(m["reference"] for m in modes if m["mode"] == mode)
next_steps = [f"Read {ref_file} for the full mode procedure"]

if mode == "create-from-raw-plan":
    next_steps.append("If the plan is weak, read references/MODE-IMPROVE-PLAN-FIRST.md instead")
elif mode == "polish-existing-graph":
    next_steps.append("Inspect beads: br list --json")
    next_steps.append("Check graph insights: bv --robot-insights")
elif mode == "closeout":
    next_steps.append("Inspect in_progress beads: br list --json")
    next_steps.append("Run closeout guard: scripts/bead_closeout_guard.sh --repo . --json")

if has_cycles:
    next_steps.append("Resolve dependency cycles: br dep cycles --json")
elif cycle_inspection == "failed":
    next_steps.append("Resolve cycle inspection failure before implementation dispatch")

if emit_json:
    print(json.dumps({
        "tool": "bead_route.sh",
        "schema": "better-beads-route-v1",
        "graph_state": graph_state,
        "recommended_mode": mode,
        "reasoning": reasoning,
        "modes": modes,
        "next_steps": next_steps,
    }, indent=2))
else:
    print(f"Better Beads route: {total} bead(s) found")
    if by_status:
        parts = [f"{v} {k}" for k, v in sorted(by_status.items())]
        print(f"  Status: {', '.join(parts)}")
    if has_cycles:
        print(f"  WARNING: {cycle_count} dependency cycle(s)")
    print()
    print(f"Recommended mode: {mode}")
    print(f"  {reasoning}")
    print()
    print("Next steps:")
    for i, step in enumerate(next_steps, 1):
        print(f"  {i}. {step}")
PY
