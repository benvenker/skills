#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCHER="$SCRIPT_DIR/better-beads"
QUALITY="$SCRIPT_DIR/bead_quality_gate.py"
LOOP="$SCRIPT_DIR/bead_gate_loop.sh"
CLOSEOUT="$SCRIPT_DIR/bead_closeout_guard.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMP_REPO="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-cli-test.XXXXXX")"

if [[ "${KEEP_BETTER_BEADS_CLI_TEST_TMP:-0}" == "1" ]]; then
  trap 'printf "Leaving Better Beads CLI test temp repo at %s\n" "$TMP_REPO" >&2' EXIT
else
  trap 'rm -rf "$TMP_REPO"' EXIT
fi

assert_json_field() {
  local expected_tool="$1"
  local payload
  payload="$(cat)"
  python3 - "$expected_tool" "$payload" <<'PY'
import json
import sys
expected_tool = sys.argv[1]
payload = json.loads(sys.argv[2])
assert payload["tool"] == expected_tool, payload
assert payload["contract_version"], payload
assert payload["exit_codes"], payload
assert any(surface["argv"] == ["capabilities", "--json"] for surface in payload["robot_surfaces"]), payload
assert any(surface["argv"] == ["robot-docs", "guide"] for surface in payload["robot_surfaces"]), payload
PY
}

assert_route_capabilities_schema_registry() {
  local payload
  payload="$(cat)"
  python3 - "$payload" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
schemas = payload.get("schemas", {})
for name in ("better-beads-route-v1", "capabilities-v1", "markdown-guide-v1"):
    assert name in schemas, payload
assert payload["contract_version"] != "better-beads-route-v1", payload
route = schemas["better-beads-route-v1"]
required = set(route["required_top_level_fields"])
for field in ("plan_readiness", "graph_state", "recommended_mode"):
    assert field in required, payload
assert any(
    "dispatcher delegates route output" in note
    for note in route.get("notes", [])
), payload
PY
}

assert_dispatcher_route_surfaces() {
  local payload
  payload="$(cat)"
  python3 - "$payload" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert any(
    surface["argv"] == ["route", "--json"]
    and surface["stdout_schema"] == "better-beads-route-v1"
    for surface in payload["robot_surfaces"]
), payload
assert any(
    command.get("name") == "route"
    and command.get("delegates_to") == "bead_route.sh"
    for command in payload["commands"]
), payload
PY
}

assert_dispatcher_semantic_pack_surface() {
  local payload
  payload="$(cat)"
  python3 - "$payload" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert any(
    surface["argv"] == ["semantic-pack", "--json"]
    and surface["stdout_schema"] == "better-beads-semantic-pack-v1"
    for surface in payload["robot_surfaces"]
), payload
assert any(
    command.get("name") == "semantic-pack"
    and command.get("stdout_schema") == "better-beads-semantic-pack-v1"
    for command in payload["commands"]
), payload
PY
}

assert_dispatcher_authoring_triage_surface() {
  local payload
  payload="$(cat)"
  python3 - "$payload" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
assert any(
    surface["argv"] == ["authoring-triage", "--json"]
    and surface["stdout_schema"] == "better-beads-authoring-triage-v1"
    for surface in payload["robot_surfaces"]
), payload
assert any(
    command.get("name") == "authoring-triage"
    and command.get("stdout_schema") == "better-beads-authoring-triage-v1"
    for command in payload["commands"]
), payload
PY
}

snapshot_tracked_files() {
  python3 - "$REPO_ROOT" <<'PY'
import hashlib
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
raw_paths = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"])
paths = sorted(path for path in raw_paths.split(b"\0") if path)
for raw_path in paths:
    rel = raw_path.decode("utf-8", "surrogateescape")
    path = root / rel
    if path.exists():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    else:
        digest = "MISSING"
    print(f"{rel}\t{digest}")
PY
}

READ_ONLY_CHECK_INDEX=0
assert_read_only_command() {
  local label="$1"
  shift
  READ_ONLY_CHECK_INDEX=$((READ_ONLY_CHECK_INDEX + 1))
  local before="$TMP_REPO/read-only-${READ_ONLY_CHECK_INDEX}.before"
  local after="$TMP_REPO/read-only-${READ_ONLY_CHECK_INDEX}.after"
  local stdout="$TMP_REPO/read-only-${READ_ONLY_CHECK_INDEX}.stdout"
  local stderr="$TMP_REPO/read-only-${READ_ONLY_CHECK_INDEX}.stderr"

  snapshot_tracked_files >"$before"
  if ! "$@" >"$stdout" 2>"$stderr"; then
    cat "$stderr" >&2
    return 1
  fi
  snapshot_tracked_files >"$after"

  if ! cmp -s "$before" "$after"; then
    echo "Read-only robot command mutated tracked files: $label" >&2
    python3 - "$before" "$after" <<'PY' >&2
import sys
from pathlib import Path

def load(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        rel, digest = line.split("\t", 1)
        result[rel] = digest
    return result

before = load(sys.argv[1])
after = load(sys.argv[2])
changed = [
    path for path in sorted(set(before) | set(after))
    if before.get(path) != after.get(path)
]
for path in changed:
    print(f"  {path}")
PY
    exit 1
  fi
}

bash "$DISPATCHER" capabilities --json | assert_json_field better-beads
bash "$DISPATCHER" capabilities --json | assert_dispatcher_route_surfaces
bash "$DISPATCHER" capabilities --json | assert_dispatcher_semantic_pack_surface
bash "$DISPATCHER" capabilities --json | assert_dispatcher_authoring_triage_surface
bash "$DISPATCHER" route capabilities --json | assert_route_capabilities_schema_registry
python3 "$QUALITY" capabilities --json | assert_json_field bead_quality_gate.py
bash "$LOOP" capabilities --json | assert_json_field bead_gate_loop.sh
bash "$CLOSEOUT" capabilities --json | assert_json_field bead_closeout_guard.sh

bash "$DISPATCHER" robot-docs guide | grep -q "Better Beads CLI robot guide"
bash "$DISPATCHER" robot-docs guide | grep -q "authoring-triage"
bash "$DISPATCHER" robot-docs guide | grep -q "semantic-pack"
bash "$DISPATCHER" route robot-docs guide | grep -q "cycle_inspection"
bash "$DISPATCHER" route robot-docs guide | grep -q "delegates to \`bead_route.sh\`"
bash "$DISPATCHER" route --robot-help | grep -q "Better Beads route robot guide"
bash "$DISPATCHER" triage --json | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["schema"] == "better-beads-triage-v1", payload; [(_ for _ in ()).throw(AssertionError(command)) for command in payload["recommended_commands"] if sys.argv[1] not in command]' "$DISPATCHER"
bash "$DISPATCHER" triage --json | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert any("route --json" in command for command in payload["recommended_commands"]), payload'
bash "$DISPATCHER" authoring-triage --json | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["schema"] == "better-beads-authoring-triage-v1", payload; assert payload["mutation_eligibility"]["authoring_triage_is_read_only"] is True, payload'
python3 "$QUALITY" robot-docs guide | grep -q "Better Beads quality gate robot guide"
bash "$LOOP" robot-docs guide | grep -q "Better Beads gate loop robot guide"
bash "$CLOSEOUT" robot-docs guide | grep -q "Better Beads closeout guard robot guide"

set +e
DISPATCHER_ERR="$(bash "$DISPATCHER" quality-gat --repo . 2>&1 >/dev/null)"
DISPATCHER_RC=$?
QUALITY_ERR="$(python3 "$QUALITY" --repo . --jsno 2>&1 >/dev/null)"
QUALITY_RC=$?
ROUTE_ERR="$(bash "$DISPATCHER" route --jsno 2>&1 >/dev/null)"
ROUTE_RC=$?
AUTHORING_ERR="$(bash "$DISPATCHER" authoring-triage --jsno 2>&1 >/dev/null)"
AUTHORING_RC=$?
LOOP_ERR="$(bash "$LOOP" --repo . --operator-dispatc 2>&1 >/dev/null)"
LOOP_RC=$?
CLOSEOUT_ERR="$(bash "$CLOSEOUT" --repo . --jsno 2>&1 >/dev/null)"
CLOSEOUT_RC=$?
set -e

[[ "$DISPATCHER_RC" -eq 2 ]]
[[ "$DISPATCHER_ERR" == *"Did you mean: quality-gate"* ]]
[[ "$DISPATCHER_ERR" == *"Corrected command:"*"quality-gate --repo ."* ]]

[[ "$QUALITY_RC" -eq 2 ]]
[[ "$QUALITY_ERR" == *"Did you mean: \`--json\`"* ]]
[[ "$QUALITY_ERR" == *"Corrected command:"*"--repo . --json"* ]]

[[ "$ROUTE_RC" -eq 2 ]]
[[ "$ROUTE_ERR" == *"Did you mean: --json"* ]]
[[ "$ROUTE_ERR" == *"Corrected command:"*"--json"* ]]

[[ "$AUTHORING_RC" -eq 2 ]]
[[ "$AUTHORING_ERR" == *"Did you mean: --json"* ]]
[[ "$AUTHORING_ERR" == *"Use: better-beads authoring-triage"*"--json"* ]]

[[ "$LOOP_RC" -eq 2 ]]
[[ "$LOOP_ERR" == *"Did you mean: --operator-dispatch"* ]]
[[ "$LOOP_ERR" == *"Corrected command:"*"--repo . --operator-dispatch"* ]]

[[ "$CLOSEOUT_RC" -eq 2 ]]
[[ "$CLOSEOUT_ERR" == *"Did you mean: --json"* ]]
[[ "$CLOSEOUT_ERR" == *"Corrected command:"*"--repo . --json"* ]]

bash "$DISPATCHER" --help 2>&1 | grep -q "Exit codes:"
python3 "$QUALITY" --help | grep -q "Exit codes:"
bash "$LOOP" --help 2>&1 | grep -q "Exit codes:"
bash "$CLOSEOUT" --help 2>&1 | grep -q "Exit codes:"

assert_read_only_command "bv --robot-plan" bv --robot-plan
assert_read_only_command "bv --robot-insights" bv --robot-insights
assert_read_only_command "better-beads route --json" bash "$DISPATCHER" route --json
assert_read_only_command "better-beads authoring-triage --json" bash "$DISPATCHER" authoring-triage --json
assert_read_only_command "better-beads triage --json" bash "$DISPATCHER" triage --json
assert_read_only_command "better-beads semantic-pack --json" bash "$DISPATCHER" semantic-pack --json

NO_BEADS_REPO="$TMP_REPO/no-beads-route"
mkdir -p "$NO_BEADS_REPO"
(
  cd "${TMPDIR:-/tmp}"
  bash "$DISPATCHER" route --repo "$NO_BEADS_REPO" --json
) | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["tool"] == "bead_route.sh", payload; assert payload["recommended_mode"] == "create-from-raw-plan", payload; assert payload["graph_state"]["has_beads_dir"] is False, payload'

mkdir -p "$TMP_REPO/.beads"
python3 - "$TMP_REPO/.beads/issues.jsonl" <<'PY'
import json
import sys
from pathlib import Path
issue = {
    "id": "bb-cli-smoke",
    "title": "dispatcher arbitrary cwd smoke",
    "status": "open",
    "priority": 2,
    "issue_type": "task",
    "created_at": "2026-06-06T00:00:00Z",
    "created_by": "test",
    "updated_at": "2026-06-06T00:00:00Z",
    "source_repo": "better-beads-cli-test",
    "source_repo_path": str(Path(sys.argv[1]).parent.parent),
    "compaction_level": 0,
    "original_size": 0,
    "labels": [],
    "dependency_count": 0,
    "dependencies": [],
    "description": """## Outcome
Dispatcher delegation works from an arbitrary current directory.

## Success criteria
- The quality gate can load this temporary repo.
- JSON output remains parseable.

## Scope / non-goals
- Do not require the caller to cd into the skill directory.

## Failure behavior
- Missing repo data fails with a non-zero exit and stderr diagnostic.

## Known anchors / surfaces
- User-visible surface: scripts/better-beads quality-gate --repo <path> --json.
- Data contract: JSON payload with issue_count.

## Validation
```bash
bash scripts/better-beads quality-gate --repo /tmp/repo --json
```
Expected: issue_count is 1.

## Closure evidence
Close with command output and result summary.
""",
}
Path(sys.argv[1]).write_text(json.dumps(issue) + "\n", encoding="utf-8")
PY
cat >"$TMP_REPO/plan.md" <<'EOF'
## Outcome
Temporary dispatcher smoke plan has enough shape for route readiness.

## Anchors
- User-visible surface: scripts/better-beads authoring-triage --json.

## Validation
```bash
bash scripts/better-beads authoring-triage --json
```

## Failure behavior
- Missing plan paths fail closed.

## Non-goals
- Do not mutate Beads.

## Parent child shape
- One child behavior is enough for this fixture.

## Dependency order
- Inspect route output before any graph mutation.
EOF
(
  cd "${TMPDIR:-/tmp}"
  bash "$DISPATCHER" quality-gate --repo "$TMP_REPO" --json
) | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["issue_count"] == 1, payload'

(
  cd "${TMPDIR:-/tmp}"
  bash "$DISPATCHER" authoring-triage --repo "$TMP_REPO" --plan "$TMP_REPO/plan.md" --json
) | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["schema"] == "better-beads-authoring-triage-v1", payload; assert payload["graph_inspection"]["issue_count"] == 1, payload; assert payload["plan_readiness"]["plan_path"], payload'

(
  cd "${TMPDIR:-/tmp}"
  bash "$DISPATCHER" semantic-pack --repo "$TMP_REPO" --json
) | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["schema"] == "better-beads-semantic-pack-v1", payload; assert "You are reviewing a Beads graph" in payload["semantic_review"]["judge_prompt"], payload'

(
  cd "${TMPDIR:-/tmp}"
  bash "$DISPATCHER" semantic-pack --repo "$TMP_REPO" --markdown
) | grep -q "Judge prompt"

echo "CLI robot surfaces smoke passed."
