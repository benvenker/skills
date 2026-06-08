#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_DIR="$SKILL_DIR/schemas"
ROUTE="$SCRIPT_DIR/bead_route.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-schema-test.XXXXXX")"

printf 'Leaving Better Beads schema test temp root at %s\n' "$TMP_ROOT" >&2

usage() {
  cat >&2 <<'EOF'
Usage: test_schemas.sh [route|dispatch|quality|authoring-triage|smithers|telemetry]

Validates Better Beads JSON schemas using only bash and python3 stdlib.
EOF
}

case "${1:-all}" in
  all|route|dispatch|quality|authoring-triage|smithers|telemetry)
    TARGET="${1:-all}"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

SCHEMA_ROUTE="$SCHEMA_DIR/better-beads-route-v1.schema.json"
SCHEMA_DISPATCH="$SCHEMA_DIR/better-beads-dispatch-verdict-v1.schema.json"
SCHEMA_QUALITY="$SCHEMA_DIR/better-beads-quality-gate-v1.schema.json"
SCHEMA_AUTHORING="$SCHEMA_DIR/better-beads-authoring-triage-v1.schema.json"
SCHEMA_SMITHERS="$SCHEMA_DIR/better-beads-smithers-check-v1.schema.json"
SCHEMA_SMITHERS_POLISH="$SCHEMA_DIR/better-beads-smithers-polish-graph-v1.schema.json"
SCHEMA_TELEMETRY="$SCHEMA_DIR/better-beads-telemetry-v1.schema.json"
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/br" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-} ${3:-}" in
  "list --json ")
    cat .beads/list.json
    ;;
  "ready --json ")
    if [[ -f .beads/ready.json ]]; then
      cat .beads/ready.json
    else
      cat .beads/list.json
    fi
    ;;
  "blocked --json ")
    if [[ -f .beads/blocked.json ]]; then
      cat .beads/blocked.json
    else
      printf '[]\n'
    fi
    ;;
  "dep cycles --json")
    if [[ -f .beads/cycles.exit ]]; then
      cat .beads/cycles.stderr >&2
      exit "$(cat .beads/cycles.exit)"
    fi
    cat .beads/cycles.json
    ;;
  *)
    echo "unsupported fake br invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/br"

cat >"$FAKE_BIN/bv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --robot-plan)
    echo '{"plan":{"summary":{"ready":true}}}'
    ;;
  --robot-insights)
    echo '{"insights":[]}'
    ;;
  *)
    echo "unsupported fake bv invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/bv"

make_repo() {
  local name="$1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo/.beads"
  printf '[]\n' >"$repo/.beads/list.json"
  printf '{"count":0,"cycles":[]}\n' >"$repo/.beads/cycles.json"
  printf '%s\n' "$repo"
}

write_valid_issue_repo() {
  local repo="$1"
  local oversized="${2:-0}"
  mkdir -p "$repo/.beads"
  python3 - "$repo/.beads/issues.jsonl" "$repo/.beads/list.json" "$repo/.beads/ready.json" "$repo/.beads/blocked.json" "$oversized" <<'PY'
import json
import sys
from pathlib import Path

issues_path = Path(sys.argv[1])
list_path = Path(sys.argv[2])
ready_path = Path(sys.argv[3])
blocked_path = Path(sys.argv[4])
oversized = sys.argv[5] == "1"

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
    "id": "bd-schema-smoke",
    "title": "schema smoke bead",
    "status": "open",
    "priority": 2,
    "issue_type": "task",
    "created_at": "2026-06-07T00:00:00Z",
    "created_by": "test",
    "updated_at": "2026-06-07T00:00:00Z",
    "source_repo": "schema-test",
    "source_repo_path": str(issues_path.parent.parent),
    "compaction_level": 0,
    "original_size": 0,
    "labels": [],
    "dependencies": [],
    "dependency_count": 0,
    "description": description,
}

issues_path.write_text(json.dumps(issue) + "\n", encoding="utf-8")
list_path.write_text(json.dumps([issue]) + "\n", encoding="utf-8")
ready_path.write_text(json.dumps([issue]) + "\n", encoding="utf-8")
blocked_path.write_text("[]\n", encoding="utf-8")
PY
  printf '{"count":0,"cycles":[]}\n' >"$repo/.beads/cycles.json"
}

write_ready_plan() {
  local path="$1"
  cat >"$path" <<'EOF'
## Outcome
The route mode handles a structurally ready plan.

## Anchors
- Surface: scripts/bead_route.sh --plan PATH --json.

## Validation
```bash
bash skills/better-beads/scripts/bead_route.sh --plan plan.md --json
```

## Failure behavior
- Missing plan paths fail closed.

## Non-goals
- Do not mutate beads in route inspection.

## Parent child shape
- Parent closure and child behavior are described.

## Dependency order
- Route inspection happens before graph mutation.
EOF
}

write_weak_plan() {
  local path="$1"
  cat >"$path" <<'EOF'
## Outcome
There is a vague plan.
EOF
}

validate_schema_and_payload() {
  local schema="$1"
  local payload="$2"
  local case_name="$3"
  local producer="$4"
  python3 - "$schema" "$payload" "$case_name" "$producer" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
payload_path = Path(sys.argv[2])
case_name = sys.argv[3]
producer = sys.argv[4]

SUPPORTED = {
    "$schema",
    "$id",
    "title",
    "description",
    "type",
    "additionalProperties",
    "required",
    "properties",
    "items",
    "enum",
    "const",
    "anyOf",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path}: malformed JSON: {exc}")


def check_keywords(node: Any, path: str) -> None:
    if not isinstance(node, dict):
        return
    for key, value in node.items():
        if key not in SUPPORTED:
            fail(f"{schema_path}: unsupported keyword {key} at {path}")
        if key == "properties":
            if not isinstance(value, dict):
                fail(f"{schema_path}: properties must be object at {path}")
            for prop_name, prop_schema in value.items():
                check_keywords(prop_schema, f"{path}.properties.{prop_name}")
        elif key == "items":
            check_keywords(value, f"{path}.items")
        elif key == "anyOf":
            if not isinstance(value, list):
                fail(f"{schema_path}: anyOf must be array at {path}")
            for index, item in enumerate(value):
                check_keywords(item, f"{path}.anyOf[{index}]")
        elif key == "additionalProperties" and isinstance(value, dict):
            check_keywords(value, f"{path}.additionalProperties")


def type_name(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int) and not isinstance(value, bool):
        return "integer"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def validate(schema: dict[str, Any], value: Any, path: str) -> None:
    if "anyOf" in schema:
        failures = []
        for candidate in schema["anyOf"]:
            try:
                validate(candidate, value, path)
                return
            except AssertionError as exc:
                failures.append(str(exc))
        raise AssertionError(f"{path}: did not match anyOf: {failures}")

    if "const" in schema and value != schema["const"]:
        raise AssertionError(f"{path}: expected const {schema['const']!r}, got {value!r}")

    if "enum" in schema and value not in schema["enum"]:
        raise AssertionError(f"{path}: expected one of {schema['enum']!r}, got {value!r}")

    if "type" in schema:
        allowed = schema["type"]
        if isinstance(allowed, str):
            allowed_types = [allowed]
        elif isinstance(allowed, list):
            allowed_types = allowed
        else:
            raise AssertionError(f"{path}: schema type must be string or array")
        actual = type_name(value)
        if actual not in allowed_types:
            raise AssertionError(f"{path}: expected type {allowed_types!r}, got {actual}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise AssertionError(f"{path}: missing required key {key}")
        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        for key, child in value.items():
            if key in properties:
                validate(properties[key], child, f"{path}.{key}")
            elif additional is False:
                raise AssertionError(f"{path}: unexpected key {key}")
            elif isinstance(additional, dict):
                validate(additional, child, f"{path}.{key}")

    if isinstance(value, list) and "items" in schema:
        for index, item in enumerate(value):
            validate(schema["items"], item, f"{path}[{index}]")


schema = load_json(schema_path)
payload = load_json(payload_path)
check_keywords(schema, "$")
validate(schema, payload, "$")
print(f"ok schema={schema_path} case={case_name} producer={producer}")
PY
}

run_route_case() {
  local case_name="$1"
  local repo="$2"
  local producer="$3"
  shift 3
  local payload="$TMP_ROOT/${case_name}.json"
  if ! PATH="$FAKE_BIN:$PATH" bash "$ROUTE" --repo "$repo" "$@" --json >"$payload" 2>"$TMP_ROOT/${case_name}.stderr"; then
    echo "producer failed for case=$case_name producer=$producer" >&2
    cat "$TMP_ROOT/${case_name}.stderr" >&2
    exit 1
  fi
  validate_schema_and_payload "$SCHEMA_ROUTE" "$payload" "$case_name" "$producer"
}

run_route_tests() {
  local repo plan

  repo="$TMP_ROOT/no-beads-no-plan"
  mkdir -p "$repo"
  run_route_case "no-beads-no-plan" "$repo" "bead_route.sh --repo REPO --json"

  repo="$TMP_ROOT/no-beads-weak-plan"
  mkdir -p "$repo"
  plan="$TMP_ROOT/weak-plan.md"
  write_weak_plan "$plan"
  run_route_case "no-beads-weak-plan" "$repo" "bead_route.sh --repo REPO --plan PLAN --json" --plan "$plan"

  repo="$(make_repo graph-present-fake-br-list)"
  cat >"$repo/.beads/list.json" <<'EOF'
[
  {"id":"bd-open","status":"open"},
  {"id":"bd-closed","status":"closed"}
]
EOF
  run_route_case "graph-present-fake-br-list" "$repo" "bead_route.sh --repo REPO --json"

  repo="$(make_repo graph-present-cycle-inspection-failed)"
  cat >"$repo/.beads/list.json" <<'EOF'
[
  {"id":"bd-open","status":"open"}
]
EOF
  printf '5\n' >"$repo/.beads/cycles.exit"
  printf 'cycle inspection unavailable\n' >"$repo/.beads/cycles.stderr"
  run_route_case "graph-present-cycle-inspection-failed" "$repo" "bead_route.sh --repo REPO --json"
}

run_json_producer_case() {
  local schema="$1"
  local case_name="$2"
  local producer="$3"
  shift 3
  local payload="$TMP_ROOT/${case_name}.json"
  if ! "$@" >"$payload" 2>"$TMP_ROOT/${case_name}.stderr"; then
    echo "producer failed for case=$case_name producer=$producer" >&2
    cat "$TMP_ROOT/${case_name}.stderr" >&2
    exit 1
  fi
  validate_schema_and_payload "$schema" "$payload" "$case_name" "$producer"
}

run_dispatch_tests() {
  local repo

  repo="$TMP_ROOT/dispatch-pass"
  write_valid_issue_repo "$repo" 0
  run_json_producer_case "$SCHEMA_DISPATCH" "dispatch-operator-pass" "bead_gate_loop.sh --operator-dispatch --json" \
    env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/bead_gate_loop.sh" --repo "$repo" --operator-dispatch --json

  repo="$TMP_ROOT/dispatch-block"
  write_valid_issue_repo "$repo" 1
  local payload="$TMP_ROOT/dispatch-operator-block.json"
  set +e
  PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/bead_gate_loop.sh" --repo "$repo" --operator-dispatch --json >"$payload" 2>"$TMP_ROOT/dispatch-operator-block.stderr"
  local rc=$?
  set -e
  [[ "$rc" -eq 2 ]]
  validate_schema_and_payload "$SCHEMA_DISPATCH" "$payload" "dispatch-operator-block" "bead_gate_loop.sh --operator-dispatch --json"
}

run_quality_tests() {
  local repo
  repo="$TMP_ROOT/quality-json"
  write_valid_issue_repo "$repo" 0
  run_json_producer_case "$SCHEMA_QUALITY" "quality-gate-json" "bead_quality_gate.py --json" \
    python3 "$SCRIPT_DIR/bead_quality_gate.py" --repo "$repo" --json
}

run_authoring_tests() {
  local repo

  repo="$TMP_ROOT/authoring-no-graph"
  mkdir -p "$repo"
  run_json_producer_case "$SCHEMA_AUTHORING" "authoring-triage-no-graph" "better-beads authoring-triage --json" \
    env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/better-beads" authoring-triage --repo "$repo" --json

  repo="$TMP_ROOT/authoring-graph-present"
  write_valid_issue_repo "$repo" 0
  run_json_producer_case "$SCHEMA_AUTHORING" "authoring-triage-graph-present" "better-beads authoring-triage --json" \
    env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT_DIR/better-beads" authoring-triage --repo "$repo" --json

  # Regression: bv --robot-plan returns plan.tracks:null (fully closed/empty graph)
  # Must not crash; must emit valid authoring-triage JSON.
  local null_tracks_bin="$TMP_ROOT/null-tracks-bin"
  mkdir -p "$null_tracks_bin"
  cp "$FAKE_BIN/br" "$null_tracks_bin/br"
  cat >"$null_tracks_bin/bv" <<'NULLBV'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --robot-plan)
    echo '{"plan":{"tracks":null,"total_actionable":0,"total_blocked":0,"summary":{"ready":true}}}'
    ;;
  --robot-insights)
    echo '{"insights":[]}'
    ;;
  *)
    echo "unsupported fake bv invocation: $*" >&2
    exit 2
    ;;
esac
NULLBV
  chmod +x "$null_tracks_bin/bv"
  repo="$TMP_ROOT/authoring-null-tracks"
  write_valid_issue_repo "$repo" 0
  run_json_producer_case "$SCHEMA_AUTHORING" "authoring-triage-null-tracks" "better-beads authoring-triage --json (null tracks regression)" \
    env PATH="$null_tracks_bin:$PATH" bash "$SCRIPT_DIR/better-beads" authoring-triage --repo "$repo" --json
}

run_smithers_tests() {
  local repo payload fake_bun_bin marker scores_marker calls_log eval_stdout eval_stderr

  repo="$TMP_ROOT/smithers-unavailable"
  mkdir -p "$repo"
  payload="$TMP_ROOT/smithers-unavailable.json"
  run_json_producer_case "$SCHEMA_SMITHERS" "smithers-unavailable" "better-beads smithers check --json" \
    env PATH="/usr/bin:/bin" bash "$SCRIPT_DIR/better-beads" smithers check --repo "$repo" --json
  python3 - "$TMP_ROOT/smithers-unavailable.json" "$repo" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
repo = Path(sys.argv[2]).resolve()
assert payload["repo"] == str(repo), payload
assert payload["available"] is False, payload
assert payload["checks"]["bunx"]["available"] is False, payload
assert payload["checks"]["bunx"]["path"] is None, payload
assert payload["checks"]["smithers_dir"]["available"] is False, payload
assert payload["checks"]["workflow"]["available"] is False, payload
assert set(payload["missing"]) == {"bunx", "smithers_dir", "workflow"}, payload
assert payload["side_effects"]["invokes_smithers"] is False, payload
assert payload["side_effects"]["invokes_bunx"] is False, payload
PY

  repo="$TMP_ROOT/smithers-available"
  fake_bun_bin="$TMP_ROOT/fake-bun-bin"
  marker="$TMP_ROOT/bunx-invoked"
  mkdir -p "$repo/.smithers/workflows" "$fake_bun_bin"
  printf '// schema fixture only\n' >"$repo/.smithers/workflows/better-beads-polish-graph.tsx"
  cat >"$fake_bun_bin/bunx" <<EOF
#!/usr/bin/env bash
printf invoked >"$marker"
exit 99
EOF
  chmod +x "$fake_bun_bin/bunx"
  run_json_producer_case "$SCHEMA_SMITHERS" "smithers-available" "better-beads smithers check --json" \
    env PATH="$fake_bun_bin:/usr/bin:/bin" bash "$SCRIPT_DIR/better-beads" smithers check --repo "$repo" --json
  if [[ -e "$marker" ]]; then
    echo "smithers check invoked bunx unexpectedly" >&2
    exit 1
  fi
  python3 - "$TMP_ROOT/smithers-available.json" "$repo" "$fake_bun_bin/bunx" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
repo = Path(sys.argv[2]).resolve()
bunx = Path(sys.argv[3]).resolve()
assert payload["repo"] == str(repo), payload
assert payload["available"] is True, payload
assert payload["checks"]["bunx"]["available"] is True, payload
assert Path(payload["checks"]["bunx"]["path"]).resolve() == bunx, payload
assert payload["checks"]["bunx"]["invoked"] is False, payload
assert payload["checks"]["smithers_dir"]["available"] is True, payload
assert payload["checks"]["workflow"]["available"] is True, payload
assert payload["missing"] == [], payload
assert payload["side_effects"]["invokes_smithers"] is False, payload
assert payload["side_effects"]["invokes_bunx"] is False, payload
PY

  repo="$TMP_ROOT/smithers-polish-unavailable"
  mkdir -p "$repo"
  run_json_producer_case "$SCHEMA_SMITHERS_POLISH" "smithers-polish-unavailable" "better-beads smithers polish-graph --json" \
    env PATH="/usr/bin:/bin" bash "$SCRIPT_DIR/better-beads" smithers polish-graph --repo "$repo" --json
  python3 - "$TMP_ROOT/smithers-polish-unavailable.json" "$repo" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
repo = Path(sys.argv[2]).resolve()
assert payload["repo"] == str(repo), payload
assert payload["schema"] == "better-beads-smithers-polish-graph-v1", payload
assert payload["available"] is False, payload
assert payload["result"] is None, payload
assert payload["run_id"] is None, payload
assert payload["error"] == "Smithers unavailable: bunx missing, .smithers missing, or workflow template not installed.", payload
assert set(payload["missing"]) == {"bunx", "smithers_dir", "workflow"}, payload
PY

  repo="$TMP_ROOT/smithers-polish-ready"
  write_valid_issue_repo "$repo" 0
  mkdir -p "$repo/.smithers/workflows"
  printf '// fake workflow fixture\n' >"$repo/.smithers/workflows/better-beads-polish-graph.tsx"
  fake_bun_bin="$TMP_ROOT/fake-bun-polish-bin"
  scores_marker="$TMP_ROOT/scores-invoked"
  calls_log="$TMP_ROOT/fake-bun-polish-calls.log"
  mkdir -p "$fake_bun_bin"
  cat >"$fake_bun_bin/bunx" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$calls_log"
case "\${1:-} \${2:-}" in
  "smithers-orchestrator up")
    exit 0
    ;;
  "smithers-orchestrator output")
    cat <<'JSON'
{"output":{"verdict":"ready","summary":"Fake Smithers says graph is ready.","recommended_mutations":[],"ready_frontier":["42"],"blocked_dispatch_reasons":[],"judge_scores":{"behavior_contract_quality":0.9,"implementation_fungibility":0.9,"dependency_correctness":0.9,"reviewability":0.9,"dispatch_readiness":0.9}}}
JSON
    ;;
  "smithers-orchestrator inspect")
    cat <<'JSON'
{"status":"completed","nodes":{"synthesize-polish-plan":{"state":"completed"}}}
JSON
    ;;
  "smithers-orchestrator node")
    cat <<'JSON'
{"output":{"validated":null,"raw":null,"source":"none","cacheKey":null}}
JSON
    ;;
  "smithers-orchestrator events")
    printf ''
    ;;
  "smithers-orchestrator workflow")
    cat <<'JSON'
{"workflowRoot":"/tmp/fake","workflows":[{"id":"better-beads-polish-graph"}],"agents":[]}
JSON
    ;;
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
  "smithers-orchestrator scores")
    printf invoked >"$scores_marker"
    exit 99
    ;;
  *)
    echo "unexpected fake bunx invocation: \$*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$fake_bun_bin/bunx"
  run_json_producer_case "$SCHEMA_SMITHERS_POLISH" "smithers-polish-ready" "better-beads smithers polish-graph --json" \
    env PATH="$fake_bun_bin:$FAKE_BIN:/usr/bin:/bin" bash "$SCRIPT_DIR/better-beads" smithers polish-graph --repo "$repo" --request "Fake request" --json
  if [[ -e "$scores_marker" ]]; then
    echo "smithers polish-graph invoked scores unexpectedly" >&2
    exit 1
  fi
  python3 - "$TMP_ROOT/smithers-polish-ready.json" "$repo" "$calls_log" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
repo = Path(sys.argv[2]).resolve()
calls = Path(sys.argv[3]).read_text(encoding="utf-8")
assert payload["repo"] == str(repo), payload
assert payload["available"] is True, payload
assert payload["request"] == "Fake request", payload
assert payload["result"]["verdict"] == "ready", payload
assert payload["result"]["summary"] == "Fake Smithers says graph is ready.", payload
assert payload["result_source"] == "output_row", payload
assert payload["node_command"], payload
assert payload["events_command"], payload
assert payload["chat_command"], payload
assert payload["logs_command"], payload
assert payload["smithers"]["up"]["exit_code"] == 0, payload
assert payload["smithers"]["output"]["exit_code"] == 0, payload
assert payload["smithers"]["inspect"]["exit_code"] == 0, payload
assert payload["smithers"]["node"]["exit_code"] == 0, payload
assert payload["smithers"]["events"]["exit_code"] == 0, payload
assert payload["smithers"]["workflow_doctor"]["exit_code"] == 0, payload
assert payload["smithers"]["output"]["parse_error"] is None, payload
assert payload["local_inspection"]["context_pack"]["beads"], payload
assert payload["scores_command"], payload
assert "scores" not in calls, calls
assert "smithers-orchestrator up" in calls, calls
assert "smithers-orchestrator output" in calls, calls
assert "smithers-orchestrator inspect" in calls, calls
assert "smithers-orchestrator node" in calls, calls
assert "smithers-orchestrator events" in calls, calls
assert "smithers-orchestrator workflow doctor" in calls, calls
PY

  repo="$TMP_ROOT/smithers-polish-events"
  write_valid_issue_repo "$repo" 0
  mkdir -p "$repo/.smithers/workflows"
  printf '// fake workflow fixture\n' >"$repo/.smithers/workflows/better-beads-polish-graph.tsx"
  fake_events_bin="$TMP_ROOT/fake-bun-polish-events-bin"
  events_calls_log="$TMP_ROOT/fake-bun-polish-events-calls.log"
  mkdir -p "$fake_events_bin"
  cat >"$fake_events_bin/bunx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$events_calls_log"
case "${1:-} ${2:-}" in
  "smithers-orchestrator up")
    exit 0
    ;;
  "smithers-orchestrator output")
    printf 'null\n'
    ;;
  "smithers-orchestrator inspect")
    printf '{"status":"completed","nodes":{"synthesize-polish-plan":{"state":"completed"}}}\n'
    ;;
  "smithers-orchestrator node")
    printf '{"output":{"validated":null,"raw":null,"source":"none","cacheKey":null}}\n'
    ;;
  "smithers-orchestrator events")
    cat <<'JSONL'
{"runId":"fake","seq":1,"type":"NodeOutput","payload":{"nodeId":"synthesize-polish-plan","stream":"stdout","text":"{\"verdict\":\"needs_"}}
{"runId":"fake","seq":2,"type":"NodeOutput","payload":{"nodeId":"synthesize-polish-plan","stream":"stdout","text":"mutation\",\"summary\":\"Recovered from events.\",\"recommended_mutations\":[],\"ready_frontier\":[],\"blocked_dispatch_reasons\":[\"output row was null\"],\"judge_scores\":{\"behavior_contract_quality\":0.5,\"implementation_fungibility\":0.5,\"dependency_correctness\":0.5,\"reviewability\":0.5,\"dispatch_readiness\":0.1}}"}}
JSONL
    ;;
  "smithers-orchestrator workflow")
    printf '{"workflowRoot":"/tmp/fake","workflows":[{"id":"better-beads-polish-graph"}],"agents":[]}\n'
    ;;
  *)
    echo "unexpected fake bunx invocation: $*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$fake_events_bin/bunx"
  run_json_producer_case "$SCHEMA_SMITHERS_POLISH" "smithers-polish-events" "better-beads smithers polish-graph --json events fallback" \
    env PATH="$fake_events_bin:$FAKE_BIN:/usr/bin:/bin" events_calls_log="$events_calls_log" bash "$SCRIPT_DIR/better-beads" smithers polish-graph --repo "$repo" --request "Fake request" --json
  python3 - "$TMP_ROOT/smithers-polish-events.json" "$repo" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
repo = Path(sys.argv[2]).resolve()
assert payload["repo"] == str(repo), payload
assert payload["result"]["verdict"] == "needs_mutation", payload
assert payload["result"]["summary"] == "Recovered from events.", payload
assert payload["result_source"] == "output_events", payload
assert payload["result_error"] is None, payload
assert payload["error"] is None, payload
assert payload["smithers"]["output"]["stdout_json"] is None, payload
assert len(payload["smithers"]["events"]["stdout_json"]) == 2, payload
assert payload["local_inspection"]["context_pack"]["beads"][0]["id"] == "bd-schema-smoke", payload
assert payload["local_inspection"]["context_pack"]["gate"]["artifacts"] is not None, payload
PY

  repo="$TMP_ROOT/smithers-polish-events-invalid"
  write_valid_issue_repo "$repo" 0
  mkdir -p "$repo/.smithers/workflows"
  printf '// fake workflow fixture\n' >"$repo/.smithers/workflows/better-beads-polish-graph.tsx"
  fake_invalid_bin="$TMP_ROOT/fake-bun-polish-invalid-bin"
  mkdir -p "$fake_invalid_bin"
  cat >"$fake_invalid_bin/bunx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "smithers-orchestrator up")
    exit 0
    ;;
  "smithers-orchestrator output")
    printf 'null\n'
    ;;
  "smithers-orchestrator inspect")
    printf '{"status":"completed","nodes":{"synthesize-polish-plan":{"state":"completed"}}}\n'
    ;;
  "smithers-orchestrator node")
    printf '{"output":{"validated":null,"raw":null,"source":"none","cacheKey":null}}\n'
    ;;
  "smithers-orchestrator events")
    cat <<'JSONL'
{"runId":"fake","seq":1,"type":"NodeOutput","payload":{"nodeId":"synthesize-polish-plan","stream":"stdout","text":"{\"verdict\":\"ready\",\"summary\":\"missing scores\"}"}}
JSONL
    ;;
  "smithers-orchestrator workflow")
    printf '{"workflowRoot":"/tmp/fake","workflows":[{"id":"better-beads-polish-graph"}],"agents":[]}\n'
    ;;
  *)
    echo "unexpected fake bunx invocation: $*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$fake_invalid_bin/bunx"
  run_json_producer_case "$SCHEMA_SMITHERS_POLISH" "smithers-polish-events-invalid" "better-beads smithers polish-graph --json invalid events" \
    env PATH="$fake_invalid_bin:$FAKE_BIN:/usr/bin:/bin" bash "$SCRIPT_DIR/better-beads" smithers polish-graph --repo "$repo" --request "Fake request" --json
  python3 - "$TMP_ROOT/smithers-polish-events-invalid.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert payload["result"] is None, payload
assert payload["result_source"] == "none", payload
assert payload["result_error"], payload
assert "could not locate polish result" in payload["error"], payload
assert payload["output_command"], payload
assert payload["inspect_command"], payload
assert payload["node_command"], payload
assert payload["events_command"], payload
assert payload["chat_command"], payload
assert payload["logs_command"], payload
assert payload["scores_command"], payload
PY
  mkdir -p "$repo/.smithers/evals"
  cp "$SCRIPT_DIR/../smithers-templates/better-beads-polish-graph.eval.jsonl" "$repo/.smithers/evals/better-beads-polish-graph.eval.jsonl"
  eval_stdout="$TMP_ROOT/smithers-polish-eval-dry-run.stdout"
  eval_stderr="$TMP_ROOT/smithers-polish-eval-dry-run.stderr"
  (
    cd "$repo"
    PATH="$fake_bun_bin:/usr/bin:/bin" bunx smithers-orchestrator eval .smithers/workflows/better-beads-polish-graph.tsx \
      --cases .smithers/evals/better-beads-polish-graph.eval.jsonl \
      --suite better-beads-polish-smoke \
      --dry-run
  ) >"$eval_stdout" 2>"$eval_stderr"
  python3 - "$eval_stdout" "$calls_log" "$repo/.smithers/evals/better-beads-polish-graph.eval.jsonl" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
calls = Path(sys.argv[2]).read_text(encoding="utf-8")
cases = [json.loads(line) for line in Path(sys.argv[3]).read_text(encoding="utf-8").splitlines() if line.strip()]
assert payload["dry_run"] is True, payload
assert payload["case_count"] == 3, payload
assert "smithers-orchestrator eval" in calls, calls
assert "--dry-run" in calls, calls
assert len(cases) == 3, cases
assert {"id", "input", "expected", "annotations"} <= set(cases[0]), cases[0]
assert cases[0]["expected"]["outputContains"]["polishPlan"]["verdict"] == "ready", cases[0]
assert cases[1]["expected"]["outputContains"]["polishPlan"]["verdict"] == "needs_mutation", cases[1]
PY
}

run_telemetry_tests() {
  local repo event_log payload

  repo="$TMP_ROOT/telemetry-repo"
  mkdir -p "$repo"
  event_log="$TMP_ROOT/telemetry-events.jsonl"
  payload="$TMP_ROOT/telemetry-event.json"
  python3 "$SCRIPT_DIR/better_beads_telemetry.py" \
    --emit "$event_log" \
    --tool test-tool \
    --tool-version 1.0.0 \
    --contract-version 2026-06-07 \
    --mode schema-test \
    --repo "$repo" \
    --duration-ms 12 \
    --exit-code 0 \
    --verdict pass \
    --finding-counts '{"errors":0,"warnings":0}' \
    --run-id schema-test-run
  python3 - "$event_log" "$payload" "$repo" <<'PY'
import json
import sys
from pathlib import Path

event_path = Path(sys.argv[1])
payload_path = Path(sys.argv[2])
repo = Path(sys.argv[3]).resolve()
lines = event_path.read_text(encoding="utf-8").splitlines()
if len(lines) != 1:
    raise SystemExit(f"expected one telemetry event, got {len(lines)}")
event = json.loads(lines[0])
text = json.dumps(event, sort_keys=True)
for forbidden in (str(repo), "description", "stdout", "prompt"):
    if forbidden in text:
        raise SystemExit(f"telemetry event leaked forbidden content: {forbidden}")
payload_path.write_text(json.dumps(event) + "\n", encoding="utf-8")
PY
  validate_schema_and_payload "$SCHEMA_TELEMETRY" "$payload" "telemetry-helper-event" "better_beads_telemetry.py --emit"
}

if [[ "$TARGET" == "route" || "$TARGET" == "all" ]]; then
  run_route_tests
fi

if [[ "$TARGET" == "dispatch" || "$TARGET" == "all" ]]; then
  run_dispatch_tests
fi

if [[ "$TARGET" == "quality" || "$TARGET" == "all" ]]; then
  run_quality_tests
fi

if [[ "$TARGET" == "authoring-triage" || "$TARGET" == "all" ]]; then
  run_authoring_tests
fi

if [[ "$TARGET" == "smithers" || "$TARGET" == "all" ]]; then
  run_smithers_tests
fi

if [[ "$TARGET" == "telemetry" || "$TARGET" == "all" ]]; then
  run_telemetry_tests
fi
