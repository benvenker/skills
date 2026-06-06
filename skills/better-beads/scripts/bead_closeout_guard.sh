#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
CONTRACT_VERSION="2026-06-05"
KNOWN_FLAGS=(--repo --allow --json --version --robot-help -h --help)

usage() {
  cat >&2 <<'EOF'
Usage: bead_closeout_guard.sh [--repo PATH] [--allow ID[,ID...]] [--json]
       bead_closeout_guard.sh capabilities --json
       bead_closeout_guard.sh robot-docs guide

Fails if Beads are left in_progress at implementation/swarm closeout.

Use this after a swarm/operator pass, in a closeout hook, or before ending an
agent turn. The guard does not blindly close work; it forces the operator or
agent to make the state truthful:

  - close completed beads with evidence,
  - reopen incomplete work with a reason, or
  - mark genuinely blocked work as blocked with the exact blocker.

Options:
  --repo PATH       Repository containing .beads (default: current directory)
  --allow IDS       Comma-separated in_progress bead IDs that are intentionally
                    still active and should not fail this run
  --json            Emit JSON instead of human-readable output
  --version         Print version and exit
  --robot-help      Print an agent-oriented guide and exit

Examples:
  bead_closeout_guard.sh --repo . --json
  bead_closeout_guard.sh --repo . --allow bd-123,bd-456
  bead_closeout_guard.sh capabilities --json

Exit codes:
  0  no unexpected in_progress beads remain
  2  usage error, missing br, missing .beads, or unexpected in_progress beads remain
EOF
}

capabilities_json() {
  cat <<EOF
{
  "tool": "bead_closeout_guard.sh",
  "version": "$VERSION",
  "contract_version": "$CONTRACT_VERSION",
  "summary": "Fail closeout when implementation beads remain unexpectedly in_progress.",
  "stdout": "Human status or requested JSON payload only.",
  "stderr": "Usage errors and missing tooling diagnostics only.",
  "exit_codes": {
    "0": "no unexpected in_progress beads remain",
    "2": "usage error, missing br/.beads, or unexpected in_progress beads remain"
  },
  "robot_surfaces": [
    {"argv": ["capabilities", "--json"], "stdout_schema": "capabilities-v1"},
    {"argv": ["robot-docs", "guide"], "stdout_schema": "markdown-guide-v1"},
    {"argv": ["--robot-help"], "stdout_schema": "markdown-guide-v1"}
  ],
  "examples": [
    "bead_closeout_guard.sh --repo . --json",
    "bead_closeout_guard.sh --repo . --allow bd-123,bd-456",
    "bead_closeout_guard.sh capabilities --json"
  ]
}
EOF
}

robot_docs() {
  cat <<'EOF'
# Better Beads closeout guard robot guide

Use `bead_closeout_guard.sh` at the end of implementation swarms or operator
passes so completed work cannot silently remain `in_progress`.

## First commands to try

```bash
scripts/bead_closeout_guard.sh capabilities --json
scripts/bead_closeout_guard.sh --repo . --json
scripts/bead_closeout_guard.sh --repo . --allow bd-123,bd-456
```

## Output contract

- JSON mode emits `{ ok, in_progress_count, allowed, unexpected_in_progress }`.
- Human mode prints exact `br` commands for truthful state repair.
- Exit `0` means closeout is clean.
- Exit `2` means closeout is blocked or the invocation/tooling is invalid.
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
ALLOW_CSV=""
JSON=0

while (($#)); do
  case "$1" in
    --repo)
      [[ -n "${2:-}" ]] || { echo "--repo requires a path" >&2; exit 2; }
      REPO="$2"
      shift 2
      ;;
    --allow)
      [[ -n "${2:-}" ]] || { echo "--allow requires a comma-separated ID list" >&2; exit 2; }
      ALLOW_CSV="$2"
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

if [[ ! -d "$REPO/.beads" ]]; then
  echo "No .beads directory found in $REPO" >&2
  exit 2
fi

if ! command -v br >/dev/null 2>&1; then
  echo "br not found on PATH" >&2
  exit 2
fi

ISSUES_JSON="$(mktemp "${TMPDIR:-/tmp}/bead-closeout-issues.XXXXXX.json")"
trap 'rm -f "$ISSUES_JSON"' EXIT

cd "$REPO"
br list --json >"$ISSUES_JSON"

python3 - "$ISSUES_JSON" "$ALLOW_CSV" "$JSON" <<'PY'
import json
import sys

issues_path = sys.argv[1]
allow = {item.strip() for item in sys.argv[2].split(",") if item.strip()}
emit_json = sys.argv[3] == "1"

with open(issues_path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

issues = data.get("issues", data if isinstance(data, list) else [])
in_progress = [
    {
        "id": issue.get("id"),
        "title": issue.get("title"),
        "priority": issue.get("priority"),
        "updated_at": issue.get("updated_at"),
    }
    for issue in issues
    if issue.get("status") == "in_progress" and issue.get("id") not in allow
]

payload = {
    "ok": not in_progress,
    "in_progress_count": len(in_progress),
    "allowed": sorted(allow),
    "unexpected_in_progress": in_progress,
}

if emit_json:
    print(json.dumps(payload, indent=2))
else:
    if not in_progress:
        print("Bead closeout guard passed: no unexpected in_progress beads.")
    else:
        print("Bead closeout guard blocked: unexpected in_progress beads remain.")
        print("")
        for issue in in_progress:
            print(f"- {issue['id']}: {issue['title']} (P{issue['priority']})")
        print("")
        print("Make each bead truthful before ending the run:")
        print("- completed: br close <id> --reason \"<evidence>\" --json")
        print("- incomplete but runnable later: br update <id> --status open --json")
        print("- genuinely blocked: br update <id> --status blocked --json")
        print("")
        print("Then run:")
        print("  br sync --flush-only")
        print("  bead_closeout_guard.sh")

raise SystemExit(0 if not in_progress else 2)
PY
