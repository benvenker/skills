#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCHER="$SCRIPT_DIR/better-beads"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-frontier-test.XXXXXX")"
BIN="$WORK_ROOT/bin"

mkdir -p "$BIN"

cat >"$BIN/br" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1 $2" in
  "list --json")
    cat .beads/list.json
    ;;
  "ready --json")
    cat .beads/ready.json
    ;;
  "blocked --json")
    cat .beads/blocked.json
    ;;
  *)
    echo "unexpected br invocation: $*" >&2
    exit 99
    ;;
esac
EOF
chmod +x "$BIN/br"

cat >"$BIN/bv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "--robot-plan" ]]; then
  cat .beads/plan.json
  exit 0
fi

echo "unexpected bv invocation: $*" >&2
exit 99
EOF
chmod +x "$BIN/bv"

make_repo() {
  local name="$1"
  local repo="$WORK_ROOT/$name"
  mkdir -p "$repo/.beads"
  printf '{"issues":[]}\n' >"$repo/.beads/list.json"
  printf '[]\n' >"$repo/.beads/ready.json"
  printf '[]\n' >"$repo/.beads/blocked.json"
  printf '{"plan":{"tracks":[],"total_actionable":0,"total_blocked":0,"summary":{}}}\n' >"$repo/.beads/plan.json"
  printf '%s\n' "$repo"
}

frontier_json() {
  PATH="$BIN:$PATH" bash "$DISPATCHER" frontier --repo "$1" --json
}

repo="$WORK_ROOT/no-beads"
mkdir -p "$repo"
frontier_json "$repo" >"$WORK_ROOT/no-beads.json"
python3 - "$WORK_ROOT/no-beads.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
assert payload["schema"] == "better-beads-frontier-v1", payload
assert payload["graph_state"]["has_beads_dir"] is False, payload
assert payload["actionable_ready"] == [], payload
assert payload["ready_label_audit"]["stale_or_invalid_ready_labels"] == [], payload
PY

repo="$(make_repo empty)"
frontier_json "$repo" >"$WORK_ROOT/empty.json"
python3 - "$WORK_ROOT/empty.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
assert payload["graph_state"]["has_beads_dir"] is True, payload
assert payload["graph_state"]["issue_count"] == 0, payload
assert payload["graph_state"]["ready_count"] == 0, payload
assert payload["bv_plan_summary"]["track_count"] == 0, payload
PY

repo="$(make_repo blocked-ready-label)"
cat >"$repo/.beads/list.json" <<'EOF'
{"issues":[
  {"id":"parent-1","title":"Parent closure","status":"open","issue_type":"epic","labels":["ready-for-agent"],"dependency_count":1,"description":"## Closure contract\nWait for child evidence.\n\n## Dependency order\nSingle-owner risk: dispatcher command table."},
  {"id":"child-1","title":"Child blocker","status":"open","issue_type":"task","labels":[],"dependency_count":0,"description":"## Outcome\nBlocks parent."}
]}
EOF
cat >"$repo/.beads/blocked.json" <<'EOF'
[{"id":"parent-1","title":"Parent closure","status":"open","blocked_by":["child-1"],"blocked_by_count":1}]
EOF
frontier_json "$repo" >"$WORK_ROOT/blocked-ready-label.json"
python3 - "$WORK_ROOT/blocked-ready-label.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
stale = payload["ready_label_audit"]["stale_or_invalid_ready_labels"]
parents = payload["deterministic_warnings"]["parent_closure_blockers"]
single_owner = payload["deterministic_warnings"]["single_owner_surface_warnings"]
assert stale and stale[0]["id"] == "parent-1", payload
assert stale[0]["blocked_by"] == ["child-1"], payload
assert parents and parents[0]["id"] == "parent-1", payload
assert single_owner and single_owner[0]["id"] == "parent-1", payload
PY

repo="$(make_repo valid-ready)"
cat >"$repo/.beads/list.json" <<'EOF'
{"issues":[
  {"id":"ready-1","title":"Ready work","status":"open","issue_type":"task","priority":2,"labels":[],"description":"## Outcome\nReady work."}
]}
EOF
cat >"$repo/.beads/ready.json" <<'EOF'
[{"id":"ready-1","title":"Ready work","status":"open","priority":2,"labels":[]}]
EOF
cat >"$repo/.beads/plan.json" <<'EOF'
{"plan":{"tracks":[{"track_id":"track-A","items":[{"id":"ready-1"}]}],"total_actionable":1,"total_blocked":0,"summary":{"highest_impact":"ready-1"}}}
EOF
frontier_json "$repo" >"$WORK_ROOT/valid-ready.json"
python3 - "$WORK_ROOT/valid-ready.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
ready = payload["actionable_ready"]
unlabeled = payload["ready_label_audit"]["unlabeled_ready_candidates"]
assert ready and ready[0]["id"] == "ready-1", payload
assert ready[0]["graph_theoretic_ready"] is True, payload
assert ready[0]["semantic_readiness"] == "unverified", payload
assert unlabeled and unlabeled[0]["id"] == "ready-1", payload
assert payload["bv_plan_summary"]["highest_impact"] == "ready-1", payload
PY

repo="$(make_repo malformed-list)"
printf '{\n' >"$repo/.beads/list.json"
stdout="$WORK_ROOT/malformed.stdout"
stderr="$WORK_ROOT/malformed.stderr"
set +e
frontier_json "$repo" >"$stdout" 2>"$stderr"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
[[ ! -s "$stdout" ]]
grep -q "br list --json returned malformed JSON" "$stderr"

repo="$(make_repo malformed-plan)"
printf '{\n' >"$repo/.beads/plan.json"
stdout="$WORK_ROOT/malformed-plan.stdout"
stderr="$WORK_ROOT/malformed-plan.stderr"
set +e
frontier_json "$repo" >"$stdout" 2>"$stderr"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
[[ ! -s "$stdout" ]]
grep -q "bv --robot-plan returned malformed JSON" "$stderr"

echo "frontier JSON tests passed."
