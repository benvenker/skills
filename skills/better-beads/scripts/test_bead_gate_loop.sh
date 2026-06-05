#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP="$SCRIPT_DIR/bead_gate_loop.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bead-gate-loop-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/br" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "dep" && "${2:-}" == "cycles" && "${3:-}" == "--json" ]]; then
  if [[ "${BR_ERROR_JSON:-0}" == "1" ]]; then
    echo '{"error":"br dependency inspection failed internally"}'
  elif [[ "${BR_CYCLES:-0}" == "1" ]]; then
    echo '{"count":1,"cycles":[["bd-a","bd-b","bd-a"]]}'
  else
    echo '{"count":0,"cycles":[]}'
  fi
  exit 0
fi
echo "unsupported fake br invocation: $*" >&2
exit 2
EOF
chmod +x "$FAKE_BIN/br"

cat >"$FAKE_BIN/bv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --robot-plan)
    if [[ "${BV_BAD_JSON:-0}" == "1" ]]; then
      echo 'not-json'
    elif [[ "${BV_PLAN_WRONG_SHAPE:-0}" == "1" ]]; then
      echo '[]'
    elif [[ "${BV_PLAN_ERROR_JSON:-0}" == "1" ]]; then
      echo '{"error":"bv plan inspection failed internally"}'
    else
      echo '{"plan":{"summary":{"ready":true}}}'
    fi
    ;;
  --robot-insights)
    if [[ "${BV_INSIGHTS_ERROR_JSON:-0}" == "1" ]]; then
      echo '{"error":"bv insights inspection failed internally"}'
    else
      echo '{"insights":[]}'
    fi
    ;;
  *)
    echo "unsupported fake bv invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/bv"

write_repo() {
  local repo="$1"
  local oversized="$2"
  mkdir -p "$repo/.beads"
  python3 - "$repo/.beads/issues.jsonl" "$oversized" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
oversized = sys.argv[2] == "1"
extra = ""
if oversized:
    extra = "\n".join(f"- Extra same-behavior detail {i}: keep filtered graph behavior explicit." for i in range(90))

description = f"""## Outcome
Filtered library load graphs render the correct series for the selected scope.

## Success criteria
- Selected filters change the rendered series.
- Empty result sets show the documented empty state.

## Scope / non-goals
- Do: update the graph behavior for filtered library loads.
- Do not: redesign the dashboard or add unrelated chart types.

## Failure behavior
- Missing data renders the empty state without throwing.
- Invalid filters fail closed to no series.

## Known anchors / surfaces
- User-visible surface: library load graph.
- Data contract: filtered series rows with label, timestamp, and value.
- Current likely files/patterns: search for existing graph rendering tests.

## Validation
```bash
python3 -m pytest tests/test_library_load_graphs.py
```
Expected: targeted graph behavior tests pass.

## Closure evidence
Close with commands run, result summary, and any follow-up bead IDs.
{extra}
"""
issue = {
    "id": "bd-loop",
    "title": "loop smoke bead",
    "status": "open",
    "labels": [],
    "description": description,
    "dependencies": [],
    "dependency_count": 0,
}
path.write_text(json.dumps(issue) + "\n", encoding="utf-8")
PY
}

extract_verdict() {
  awk '/Dispatch verdict:/ {print $3}'
}

assert_json_bool() {
  local file="$1"
  local key="$2"
  local expected="$3"
  python3 - "$file" "$key" "$expected" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
actual = payload[sys.argv[2]]
expected = sys.argv[3] == "true"
raise SystemExit(0 if actual is expected else 1)
PY
}

PASS_REPO="$TMP_ROOT/pass-repo"
write_repo "$PASS_REPO" 0
PASS_OUTPUT="$(PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$PASS_REPO" --operator-dispatch 2>&1)"
PASS_VERDICT="$(printf '%s\n' "$PASS_OUTPUT" | extract_verdict)"
[[ -f "$PASS_VERDICT" ]]
assert_json_bool "$PASS_VERDICT" dispatch_allowed true

BLOCK_REPO="$TMP_ROOT/block-repo"
write_repo "$BLOCK_REPO" 1
set +e
BLOCK_OUTPUT="$(PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$BLOCK_REPO" --operator-dispatch 2>&1)"
BLOCK_RC=$?
set -e
[[ "$BLOCK_RC" -eq 2 ]]
BLOCK_VERDICT="$(printf '%s\n' "$BLOCK_OUTPUT" | extract_verdict)"
[[ -f "$BLOCK_VERDICT" ]]
assert_json_bool "$BLOCK_VERDICT" dispatch_allowed false
python3 - "$BLOCK_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "split-review-required" in payload["blocked_reasons"], payload
split_path = payload["artifacts"]["split_review_markdown"]
text = open(split_path, encoding="utf-8").read()
assert "Operator Split Review Required" in text
assert "bd-loop" in text
PY

BAD_JSON_REPO="$TMP_ROOT/bad-json-repo"
write_repo "$BAD_JSON_REPO" 0
set +e
BAD_JSON_OUTPUT="$(BV_BAD_JSON=1 PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$BAD_JSON_REPO" --operator-dispatch 2>&1)"
BAD_JSON_RC=$?
set -e
[[ "$BAD_JSON_RC" -eq 2 ]]
BAD_JSON_VERDICT="$(printf '%s\n' "$BAD_JSON_OUTPUT" | extract_verdict)"
[[ -f "$BAD_JSON_VERDICT" ]]
assert_json_bool "$BAD_JSON_VERDICT" dispatch_allowed false
python3 - "$BAD_JSON_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "inspection-json-parse-failure" in payload["blocked_reasons"], payload
assert "bv_robot_plan" in payload["parse_failures"], payload
PY

WRONG_SHAPE_REPO="$TMP_ROOT/wrong-shape-repo"
write_repo "$WRONG_SHAPE_REPO" 0
set +e
WRONG_SHAPE_OUTPUT="$(BV_PLAN_WRONG_SHAPE=1 PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$WRONG_SHAPE_REPO" --operator-dispatch 2>&1)"
WRONG_SHAPE_RC=$?
set -e
[[ "$WRONG_SHAPE_RC" -eq 2 ]]
WRONG_SHAPE_VERDICT="$(printf '%s\n' "$WRONG_SHAPE_OUTPUT" | extract_verdict)"
[[ -f "$WRONG_SHAPE_VERDICT" ]]
assert_json_bool "$WRONG_SHAPE_VERDICT" dispatch_allowed false
python3 - "$WRONG_SHAPE_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "inspection-json-schema-failure" in payload["blocked_reasons"], payload
assert "bv_robot_plan" in payload["schema_failures"], payload
PY

OP_BLOCK_LOOP_DIR="$TMP_ROOT/operator-blocking-loop"
mkdir -p "$OP_BLOCK_LOOP_DIR"
cp "$LOOP" "$OP_BLOCK_LOOP_DIR/bead_gate_loop.sh"
chmod +x "$OP_BLOCK_LOOP_DIR/bead_gate_loop.sh"
cat >"$OP_BLOCK_LOOP_DIR/bead_quality_gate.py" <<'PY'
#!/usr/bin/env python3
import json
print(json.dumps({
    "repo": ".",
    "issue_count": 1,
    "error_count": 0,
    "warning_count": 1,
    "fail_on": "error",
    "operator_dispatch": True,
    "operator_blocking_count": 1,
    "split_review_required_count": 0,
    "findings": [{
        "severity": "warning",
        "issue_id": "bd-op",
        "title": "synthetic operator block",
        "code": "synthetic-operator-block",
        "message": "operator-blocking findings must block dispatch even without deterministic errors",
        "operator_blocking": True,
        "requires_split_review": False,
    }],
}))
PY
chmod +x "$OP_BLOCK_LOOP_DIR/bead_quality_gate.py"
OP_BLOCK_REPO="$TMP_ROOT/operator-blocking-repo"
write_repo "$OP_BLOCK_REPO" 0
set +e
OP_BLOCK_OUTPUT="$(PATH="$FAKE_BIN:$PATH" "$OP_BLOCK_LOOP_DIR/bead_gate_loop.sh" --repo "$OP_BLOCK_REPO" --operator-dispatch 2>&1)"
OP_BLOCK_RC=$?
set -e
[[ "$OP_BLOCK_RC" -eq 2 ]]
OP_BLOCK_VERDICT="$(printf '%s\n' "$OP_BLOCK_OUTPUT" | extract_verdict)"
[[ -f "$OP_BLOCK_VERDICT" ]]
assert_json_bool "$OP_BLOCK_VERDICT" dispatch_allowed false
python3 - "$OP_BLOCK_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "operator-blocking-findings" in payload["blocked_reasons"], payload
assert payload["deterministic_error_count"] == 0, payload
assert payload["operator_blocking_count"] == 1, payload
PY

CYCLES_REPO="$TMP_ROOT/cycles-repo"
write_repo "$CYCLES_REPO" 0
set +e
CYCLES_OUTPUT="$(BR_CYCLES=1 PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$CYCLES_REPO" --operator-dispatch 2>&1)"
CYCLES_RC=$?
set -e
[[ "$CYCLES_RC" -eq 2 ]]
CYCLES_VERDICT="$(printf '%s\n' "$CYCLES_OUTPUT" | extract_verdict)"
[[ -f "$CYCLES_VERDICT" ]]
assert_json_bool "$CYCLES_VERDICT" dispatch_allowed false
python3 - "$CYCLES_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "dependency-cycles" in payload["blocked_reasons"], payload
assert payload["dependency_cycle_count"] == 1, payload
PY

BR_ERROR_REPO="$TMP_ROOT/br-error-repo"
write_repo "$BR_ERROR_REPO" 0
set +e
BR_ERROR_OUTPUT="$(BR_ERROR_JSON=1 PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$BR_ERROR_REPO" --operator-dispatch 2>&1)"
BR_ERROR_RC=$?
set -e
[[ "$BR_ERROR_RC" -eq 2 ]]
BR_ERROR_VERDICT="$(printf '%s\n' "$BR_ERROR_OUTPUT" | extract_verdict)"
[[ -f "$BR_ERROR_VERDICT" ]]
assert_json_bool "$BR_ERROR_VERDICT" dispatch_allowed false
python3 - "$BR_ERROR_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "inspection-error-envelope" in payload["blocked_reasons"], payload
assert payload["inspection_error_envelopes"].get("br_dep_cycles"), payload
PY

PLAN_ERROR_REPO="$TMP_ROOT/plan-error-repo"
write_repo "$PLAN_ERROR_REPO" 0
set +e
PLAN_ERROR_OUTPUT="$(BV_PLAN_ERROR_JSON=1 PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$PLAN_ERROR_REPO" --operator-dispatch 2>&1)"
PLAN_ERROR_RC=$?
set -e
[[ "$PLAN_ERROR_RC" -eq 2 ]]
PLAN_ERROR_VERDICT="$(printf '%s\n' "$PLAN_ERROR_OUTPUT" | extract_verdict)"
[[ -f "$PLAN_ERROR_VERDICT" ]]
assert_json_bool "$PLAN_ERROR_VERDICT" dispatch_allowed false
python3 - "$PLAN_ERROR_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "inspection-error-envelope" in payload["blocked_reasons"], payload
assert payload["inspection_error_envelopes"].get("bv_robot_plan"), payload
PY

INSIGHTS_ERROR_REPO="$TMP_ROOT/insights-error-repo"
write_repo "$INSIGHTS_ERROR_REPO" 0
set +e
INSIGHTS_ERROR_OUTPUT="$(BV_INSIGHTS_ERROR_JSON=1 PATH="$FAKE_BIN:$PATH" "$LOOP" --repo "$INSIGHTS_ERROR_REPO" --operator-dispatch 2>&1)"
INSIGHTS_ERROR_RC=$?
set -e
[[ "$INSIGHTS_ERROR_RC" -eq 2 ]]
INSIGHTS_ERROR_VERDICT="$(printf '%s\n' "$INSIGHTS_ERROR_OUTPUT" | extract_verdict)"
[[ -f "$INSIGHTS_ERROR_VERDICT" ]]
assert_json_bool "$INSIGHTS_ERROR_VERDICT" dispatch_allowed false
python3 - "$INSIGHTS_ERROR_VERDICT" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert "inspection-error-envelope" in payload["blocked_reasons"], payload
assert payload["inspection_error_envelopes"].get("bv_robot_insights"), payload
PY

echo "bead_gate_loop smoke tests passed"
