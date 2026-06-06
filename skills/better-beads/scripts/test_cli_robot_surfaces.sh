#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCHER="$SCRIPT_DIR/better-beads"
QUALITY="$SCRIPT_DIR/bead_quality_gate.py"
LOOP="$SCRIPT_DIR/bead_gate_loop.sh"
CLOSEOUT="$SCRIPT_DIR/bead_closeout_guard.sh"

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

bash "$DISPATCHER" capabilities --json | assert_json_field better-beads
python3 "$QUALITY" capabilities --json | assert_json_field bead_quality_gate.py
bash "$LOOP" capabilities --json | assert_json_field bead_gate_loop.sh
bash "$CLOSEOUT" capabilities --json | assert_json_field bead_closeout_guard.sh

bash "$DISPATCHER" robot-docs guide | grep -q "Better Beads CLI robot guide"
bash "$DISPATCHER" triage --json | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["schema"] == "better-beads-triage-v1", payload; [(_ for _ in ()).throw(AssertionError(command)) for command in payload["recommended_commands"] if sys.argv[1] not in command]' "$DISPATCHER"
python3 "$QUALITY" robot-docs guide | grep -q "Better Beads quality gate robot guide"
bash "$LOOP" robot-docs guide | grep -q "Better Beads gate loop robot guide"
bash "$CLOSEOUT" robot-docs guide | grep -q "Better Beads closeout guard robot guide"

set +e
DISPATCHER_ERR="$(bash "$DISPATCHER" quality-gat --repo . 2>&1 >/dev/null)"
DISPATCHER_RC=$?
QUALITY_ERR="$(python3 "$QUALITY" --repo . --jsno 2>&1 >/dev/null)"
QUALITY_RC=$?
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

TMP_REPO="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-cli-test.XXXXXX")"
trap 'rm -rf "$TMP_REPO"' EXIT
mkdir -p "$TMP_REPO/.beads"
python3 - "$TMP_REPO/.beads/issues.jsonl" <<'PY'
import json
import sys
from pathlib import Path
issue = {
    "id": "bb-cli-smoke",
    "title": "dispatcher arbitrary cwd smoke",
    "status": "open",
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
(
  cd "${TMPDIR:-/tmp}"
  bash "$DISPATCHER" quality-gate --repo "$TMP_REPO" --json
) | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["issue_count"] == 1, payload'

echo "CLI robot surfaces smoke passed."
