#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bead_closeout_guard.sh [--repo PATH] [--allow ID[,ID...]] [--json]

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
EOF
}

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
      echo "Unknown option: $1" >&2
      usage
      exit 2
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
