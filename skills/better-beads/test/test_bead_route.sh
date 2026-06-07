#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/better-beads/scripts/bead_route.sh"
TEST_BIN="$ROOT/skills/better-beads/test/bin"
FIXTURES="$ROOT/skills/better-beads/test/fixtures"
WORK_ROOT="${TMPDIR:-/tmp}/better-beads-route-test.$$"

mkdir -p "$WORK_ROOT"
chmod +x "$TEST_BIN/br"

make_repo() {
  local name="$1"
  local repo="$WORK_ROOT/$name"
  mkdir -p "$repo/.beads"
  printf '{"count":0,"cycles":[]}\n' > "$repo/.beads/cycles.json"
  printf '%s\n' "$repo"
}

write_list() {
  local repo="$1"
  local payload="$2"
  printf '%s\n' "$payload" > "$repo/.beads/list.json"
}

route_json() {
  PATH="$TEST_BIN:$PATH" bash "$SCRIPT" --repo "$1" --json
}

route_json_plan() {
  PATH="$TEST_BIN:$PATH" bash "$SCRIPT" --repo "$1" --plan "$2" --json
}

assert_route() {
  local repo="$1"
  local expected_mode="$2"
  local expected_total="$3"
  local payload="$WORK_ROOT/payload-${expected_mode}-${expected_total}.json"
  route_json "$repo" > "$payload"
  python3 - "$expected_mode" "$expected_total" "$payload" <<'PY'
import json
import sys

expected_mode = sys.argv[1]
expected_total = int(sys.argv[2])
with open(sys.argv[3]) as f:
    payload = json.load(f)
assert payload["tool"] == "bead_route.sh", payload
assert payload["schema"] == "better-beads-route-v1", payload
assert payload["recommended_mode"] == expected_mode, payload
assert payload["graph_state"]["total_beads"] == expected_total, payload
assert payload["graph_state"]["cycle_inspection"] == "ok", payload
assert payload["graph_state"]["cycle_count"] == 0, payload
PY
}

assert_plan_route() {
  local repo="$1"
  local plan="$2"
  local expected_mode="$3"
  local expected_status="$4"
  local payload="$WORK_ROOT/plan-${expected_mode}-${expected_status}.json"
  route_json_plan "$repo" "$plan" > "$payload"
  python3 - "$expected_mode" "$expected_status" "$payload" <<'PY'
import json
import sys

expected_mode = sys.argv[1]
expected_status = sys.argv[2]
with open(sys.argv[3]) as f:
    payload = json.load(f)
readiness = payload["plan_readiness"]
assert payload["tool"] == "bead_route.sh", payload
assert payload["schema"] == "better-beads-route-v1", payload
assert payload["recommended_mode"] == expected_mode, payload
assert readiness["check_required"] is True, payload
assert readiness["gate_reference"].endswith("#pre-mutation-readiness-gates"), payload
assert readiness["required_gates"] == [
    "outcome",
    "anchors",
    "validation",
    "failure_behavior",
    "non_goals",
    "parent_child_shape",
    "dependency_order",
], payload
assert readiness["alternate_mode_if_weak"] == "improve-plan-first", payload
assert readiness["status"] == expected_status, payload
if expected_status == "weak":
    assert readiness["missing_gates"], payload
else:
    assert readiness["missing_gates"] == [], payload
PY
}

assert_exit2_no_stdout() {
  local repo="$1"
  local stderr_needle="$2"
  local stdout="$WORK_ROOT/stdout.txt"
  local stderr="$WORK_ROOT/stderr.txt"
  set +e
  PATH="$TEST_BIN:$PATH" bash "$SCRIPT" --repo "$repo" --json >"$stdout" 2>"$stderr"
  local rc=$?
  set -e
  [[ "$rc" -eq 2 ]]
  [[ ! -s "$stdout" ]]
  grep -q "$stderr_needle" "$stderr"
}

repo="$(make_repo all-open)"
write_list "$repo" '[{"id":"a","status":"open"},{"id":"b","status":"open"}]'
assert_route "$repo" polish-existing-graph 2

repo="$(make_repo mixed-active)"
write_list "$repo" '[{"id":"a","status":"open"},{"id":"b","status":"in_progress"},{"id":"c","status":"closed"}]'
assert_route "$repo" polish-existing-graph 3

repo="$(make_repo closeout-ready)"
write_list "$repo" '[{"id":"a","status":"in_progress"},{"id":"b","status":"closed"}]'
assert_route "$repo" closeout 2

repo="$(make_repo all-closed)"
write_list "$repo" '[{"id":"a","status":"closed"},{"id":"b","status":"closed"}]'
assert_route "$repo" create-from-raw-plan 2

repo="$(make_repo empty)"
write_list "$repo" '[]'
assert_route "$repo" create-from-raw-plan 0

repo="$WORK_ROOT/no-beads"
mkdir -p "$repo"
route_json "$repo" > "$WORK_ROOT/no-beads.json"
python3 - "$WORK_ROOT/no-beads.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    payload = json.load(f)
assert payload["tool"] == "bead_route.sh", payload
assert payload["recommended_mode"] == "create-from-raw-plan", payload
assert payload["graph_state"]["has_beads_dir"] is False, payload
PY
assert_plan_route "$repo" "$FIXTURES/weak-plan.md" improve-plan-first weak
assert_plan_route "$repo" "$FIXTURES/ready-plan.md" create-from-raw-plan structurally_ready

stdout="$WORK_ROOT/missing-plan-stdout.txt"
stderr="$WORK_ROOT/missing-plan-stderr.txt"
set +e
PATH="$TEST_BIN:$PATH" bash "$SCRIPT" --repo "$repo" --plan "$WORK_ROOT/missing-plan.md" --json >"$stdout" 2>"$stderr"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
[[ ! -s "$stdout" ]]
grep -q -- "--plan path is missing or unreadable" "$stderr"

repo="$(make_repo blocked-only)"
write_list "$repo" '[{"id":"a","status":"blocked"},{"id":"b","status":"blocked"}]'
assert_route "$repo" polish-existing-graph 2

repo="$(make_repo ready-plan-preserves-graph-state)"
write_list "$repo" '[{"id":"a","status":"open"}]'
assert_plan_route "$repo" "$FIXTURES/ready-plan.md" polish-existing-graph structurally_ready

repo="$(make_repo pending-only)"
write_list "$repo" '[{"id":"a","status":"pending"}]'
assert_route "$repo" polish-existing-graph 1

repo="$(make_repo unknown-active)"
write_list "$repo" '[{"id":"a","status":"waiting-on-human"}]'
assert_route "$repo" polish-existing-graph 1

repo="$(make_repo list-nonzero)"
write_list "$repo" '[{"id":"a","status":"open"}]'
printf '7\n' > "$repo/.beads/list.exit"
printf 'database unavailable\n' > "$repo/.beads/list.stderr"
assert_exit2_no_stdout "$repo" "br list --json failed"

repo="$(make_repo malformed-list)"
write_list "$repo" '{'
assert_exit2_no_stdout "$repo" "malformed JSON"

repo="$(make_repo error-envelope)"
write_list "$repo" '{"error":"database unavailable"}'
assert_exit2_no_stdout "$repo" "error envelope"

repo="$(make_repo cycles-fail)"
write_list "$repo" '[{"id":"a","status":"open"}]'
printf '5\n' > "$repo/.beads/cycles.exit"
printf 'cycles command unavailable\n' > "$repo/.beads/cycles.stderr"
route_json "$repo" > "$WORK_ROOT/cycles-fail.json"
python3 - "$WORK_ROOT/cycles-fail.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    payload = json.load(f)
state = payload["graph_state"]
assert payload["recommended_mode"] == "polish-existing-graph", payload
assert state["cycle_inspection"] == "failed", payload
assert state["cycle_count"] is None, payload
assert state["inspection_warnings"], payload
assert "cycle inspection failed" in payload["reasoning"], payload
PY

echo "bead_route fixture tests passed."
