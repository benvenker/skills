#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: run_evals.sh [routing|quality|smithers]

Runs Better Beads executable eval harnesses.
With no suite, runs all default evals.
EOF
}

snapshot_tracked_files() {
  git -C "$REPO_ROOT" ls-files -z | while IFS= read -r -d '' rel; do
    if [[ -e "$REPO_ROOT/$rel" ]]; then
      sha256sum "$REPO_ROOT/$rel"
    else
      printf 'MISSING  %s\n' "$REPO_ROOT/$rel"
    fi
  done | sort
}

run_smithers_eval_smoke() {
  local template="$SKILL_DIR/smithers-templates/better-beads-polish-graph.tsx"
  local eval_cases="$SKILL_DIR/smithers-templates/better-beads-polish-graph.eval.jsonl"
  local tmp_root fake_bin target_repo calls_log before after stdout stderr

  if [[ ! -f "$template" ]]; then
    echo "missing Smithers workflow template: $template" >&2
    return 1
  fi
  if [[ ! -f "$eval_cases" ]]; then
    echo "missing Smithers eval cases: $eval_cases" >&2
    return 1
  fi

  tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-smithers-eval.XXXXXX")"
  printf 'Leaving Better Beads Smithers eval temp root at %s\n' "$tmp_root" >&2
  fake_bin="$tmp_root/bin"
  target_repo="$tmp_root/repo"
  calls_log="$tmp_root/fake-bunx-calls.log"
  before="$tmp_root/tracked.before"
  after="$tmp_root/tracked.after"
  stdout="$tmp_root/eval.stdout"
  stderr="$tmp_root/eval.stderr"
  mkdir -p "$fake_bin" "$target_repo/.smithers/workflows" "$target_repo/.smithers/evals"
  cp "$template" "$target_repo/.smithers/workflows/better-beads-polish-graph.tsx"
  cp "$eval_cases" "$target_repo/.smithers/evals/better-beads-polish-graph.eval.jsonl"

  cat >"$fake_bin/bunx" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$calls_log"
case "\${1:-} \${2:-}" in
  "smithers-orchestrator eval")
    case " \$* " in
      *" --dry-run "*) ;;
      *)
        echo "expected eval --dry-run" >&2
        exit 2
        ;;
    esac
    test -f ".smithers/workflows/better-beads-polish-graph.tsx"
    test -f ".smithers/evals/better-beads-polish-graph.eval.jsonl"
    printf '{"suite":"better-beads-polish-smoke","dry_run":true,"case_count":3}\n'
    ;;
  *)
    echo "unexpected fake bunx invocation: \$*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$fake_bin/bunx"

  snapshot_tracked_files >"$before"
  (
    cd "$target_repo"
    PATH="$fake_bin:/usr/bin:/bin" bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
      --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
      --suite better-beads-polish-smoke \
      --dry-run
  ) >"$stdout" 2>"$stderr"
  snapshot_tracked_files >"$after"

  if ! cmp -s "$before" "$after"; then
    echo "Smithers eval dry-run mutated tracked files" >&2
    diff -u "$before" "$after" >&2 || true
    return 1
  fi

  python3 - "$stdout" "$calls_log" "$eval_cases" <<'PY'
import json
import sys
from pathlib import Path

stdout_path = Path(sys.argv[1])
calls_path = Path(sys.argv[2])
eval_cases = Path(sys.argv[3])
payload = json.loads(stdout_path.read_text(encoding="utf-8"))
calls = calls_path.read_text(encoding="utf-8")
cases = [json.loads(line) for line in eval_cases.read_text(encoding="utf-8").splitlines() if line.strip()]
assert payload["dry_run"] is True, payload
assert payload["case_count"] == 3, payload
assert "smithers-orchestrator eval" in calls, calls
assert "--dry-run" in calls, calls
assert len(cases) == 3, cases
for case in cases:
    assert {"id", "input", "expected", "annotations"} <= set(case), case
assert cases[0]["expected"]["outputContains"]["polishPlan"]["verdict"] == "ready", cases[0]
assert cases[1]["expected"]["outputContains"]["polishPlan"]["verdict"] == "needs_mutation", cases[1]
PY

  echo "Smithers eval dry-run smoke passed."
}

case "${1:-}" in
  routing)
    shift
    python3 "$SCRIPT_DIR/routing_eval.py" "$@"
    ;;
  quality)
    shift
    python3 "$SCRIPT_DIR/quality_eval.py" "$@"
    ;;
  smithers)
    shift
    run_smithers_eval_smoke "$@"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    "$0" routing
    "$0" quality
    "$0" smithers
    ;;
  *)
    echo "Unknown eval suite: $1" >&2
    usage
    exit 2
    ;;
esac
