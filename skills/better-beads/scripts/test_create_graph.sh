#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCHER="$SCRIPT_DIR/better-beads"
FIXTURE="$SCRIPT_DIR/../test/fixtures/example-graph.json"
TMP_REPO="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-create-graph-test.XXXXXX")"
BIN_DIR="$TMP_REPO/bin"
REPO="$TMP_REPO/repo"

mkdir -p "$BIN_DIR" "$REPO/.beads"
printf '[]\n' >"$REPO/.beads/list.json"

cat >"$BIN_DIR/br" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$BR_CALLS"

if [[ "${1:-}" == "list" && "${2:-}" == "--json" ]]; then
  cat ".beads/list.json"
  exit 0
fi

if [[ "${1:-}" == "create" ]]; then
  slug=""
  title=""
  parent=""
  while (($#)); do
    case "$1" in
      --slug)
        slug="$2"
        shift 2
        ;;
      --title)
        title="$2"
        shift 2
        ;;
      --parent)
        parent="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done
  id="made-${slug:-${title// /-}}"
  printf '{"id":"%s","parent":"%s"}\n' "$id" "$parent"
  exit 0
fi

if [[ "${1:-}" == "dep" && "${2:-}" == "add" ]]; then
  printf '{"ok":true,"issue":"%s","depends_on":"%s"}\n' "$3" "$4"
  exit 0
fi

if [[ "${1:-}" == "dep" && "${2:-}" == "cycles" && "${3:-}" == "--json" ]]; then
  printf '{"count":0,"cycles":[]}\n'
  exit 0
fi

echo "unexpected br invocation: $*" >&2
exit 99
SH
chmod +x "$BIN_DIR/br"

export PATH="$BIN_DIR:$PATH"
export BR_CALLS="$TMP_REPO/br.calls"
: >"$BR_CALLS"

bash "$DISPATCHER" create-graph --repo "$REPO" --dry-run "$FIXTURE" | python3 -m json.tool >/dev/null
python3 - "$BR_CALLS" <<'PY'
import sys
from pathlib import Path
calls = Path(sys.argv[1]).read_text().splitlines()
assert calls == ["list --json"], calls
PY

DRY_OUTPUT="$(bash "$DISPATCHER" create-graph --repo "$REPO" --dry-run "$FIXTURE")"
python3 - "$DRY_OUTPUT" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["schema"] == "better-beads-create-graph-preview-v1", payload
assert payload["preflight"]["valid"] is True, payload
assert payload["apply_allowed"] is True, payload
assert payload["creation_order"] == ["authoring-parent", "cookbook", "helper"], payload
assert {"parent": "authoring-parent", "child": "cookbook"} in payload["parent_closure"], payload
assert {"issue": "helper", "depends_on": "cookbook", "type": "blocks"} in payload["dependencies"], payload
assert any("br" in command[0] and "create" in command for command in payload["would_run"]["commands"]), payload
PY

cat >"$TMP_REPO/unknown-dependency.json" <<'JSON'
{
  "schema": "better-beads-graph-draft-v1",
  "issues": [
    {
      "key": "one",
      "title": "One",
      "type": "task",
      "priority": 2,
      "description": "## Outcome\nOne."
    }
  ],
  "dependencies": [
    {"issue": "one", "depends_on": "missing"}
  ]
}
JSON

set +e
UNKNOWN_OUTPUT="$(bash "$DISPATCHER" create-graph --repo "$REPO" --dry-run "$TMP_REPO/unknown-dependency.json" 2>"$TMP_REPO/unknown.stderr")"
UNKNOWN_RC=$?
set -e
[[ "$UNKNOWN_RC" -eq 2 ]]
python3 - "$UNKNOWN_OUTPUT" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["apply_allowed"] is False, payload
assert any(error["path"] == "dependencies[0].depends_on" for error in payload["preflight"]["errors"]), payload
PY

cat >"$TMP_REPO/blocked-ready.json" <<'JSON'
{
  "schema": "better-beads-graph-draft-v1",
  "issues": [
    {
      "key": "earlier",
      "title": "Earlier",
      "type": "task",
      "priority": 2,
      "description": "## Outcome\nEarlier."
    },
    {
      "key": "later",
      "title": "Later",
      "type": "task",
      "priority": 2,
      "ready_frontier": true,
      "description": "## Outcome\nLater."
    }
  ],
  "dependencies": [
    {"issue": "later", "depends_on": "earlier"}
  ]
}
JSON

set +e
BLOCKED_OUTPUT="$(bash "$DISPATCHER" create-graph --repo "$REPO" --dry-run "$TMP_REPO/blocked-ready.json" 2>"$TMP_REPO/blocked.stderr")"
BLOCKED_RC=$?
set -e
[[ "$BLOCKED_RC" -eq 2 ]]
python3 - "$BLOCKED_OUTPUT" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["preflight"]["blocked_ready_labels"], payload
assert payload["preflight"]["blocked_ready_labels"][0]["key"] == "later", payload
PY

cat >"$TMP_REPO/parent-closure.json" <<'JSON'
{
  "schema": "better-beads-graph-draft-v1",
  "issues": [
    {
      "key": "parent",
      "slug": "parent",
      "title": "Parent",
      "type": "epic",
      "priority": 1,
      "description": "## Outcome\nParent."
    },
    {
      "key": "child",
      "slug": "child",
      "title": "Child",
      "type": "task",
      "priority": 2,
      "description": "## Outcome\nChild."
    }
  ],
  "parent_closure": [
    {"parent": "parent", "child": "child"}
  ]
}
JSON

: >"$BR_CALLS"
bash "$DISPATCHER" create-graph --repo "$REPO" --apply "$TMP_REPO/parent-closure.json" | python3 -m json.tool >/dev/null
python3 - "$BR_CALLS" <<'PY'
import sys
from pathlib import Path
calls = Path(sys.argv[1]).read_text().splitlines()
joined = "\n".join(calls)
assert calls[0] == "list --json", calls
assert "create --title Parent" in joined, calls
assert "create --title Child" in joined, calls
assert "--parent made-parent" in joined, calls
assert calls[-1] == "dep cycles --json", calls
PY

echo "create-graph helper smoke passed."
