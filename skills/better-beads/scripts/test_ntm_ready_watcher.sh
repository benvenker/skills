#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHER="$SCRIPT_DIR/ntm_ready_watcher.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ntm-ready-watcher-test.XXXXXX")"

FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/ntm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "work" && "${2:-}" == "queue-dry" && "${4:-}" == "--json" ]]; then
  cat "$NTM_QUEUE_DRY_JSON"
  exit 0
fi
case "${1:-}" in
  --robot-is-working=*)
    cat "$NTM_WORKING_JSON"
    exit 0
    ;;
esac
echo "unexpected fake ntm invocation: $*" >&2
exit 99
EOF
chmod +x "$FAKE_BIN/ntm"

cat >"$FAKE_BIN/br" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "ready" && "${2:-}" == "--json" ]]; then
  cat "$BR_READY_JSON"
  exit 0
fi
echo "unexpected fake br invocation: $*" >&2
exit 99
EOF
chmod +x "$FAKE_BIN/br"

write_json() {
  local path="$1"
  shift
  printf '%s\n' "$*" >"$path"
}

READY_QUEUE="$TMP_ROOT/ready-queue.json"
READY_BEADS="$TMP_ROOT/ready-beads.json"
IDLE_WORKING="$TMP_ROOT/idle-working.json"

write_json "$READY_QUEUE" '{
  "success": true,
  "queue_dry": false,
  "evidence": {
    "ready_count": 1,
    "in_progress_count": 0,
    "sync": {"status": "in_sync"}
  },
  "recommendations": [
    {"code": "claim_top_ready", "command": "br update bd-ready --status=in_progress"}
  ]
}'
write_json "$READY_BEADS" '[{"id":"bd-ready","title":"ready bead","status":"open"}]'
write_json "$IDLE_WORKING" '{
  "success": true,
  "panes": {
    "3": {"is_idle": true, "is_working": false, "is_rate_limited": false, "recommendation": "READY_FOR_ASSIGNMENT"},
    "4": {"is_idle": false, "is_working": true, "is_rate_limited": false, "recommendation": "DO_NOT_INTERRUPT"}
  }
}'

READY_OUTPUT="$(NTM_QUEUE_DRY_JSON="$READY_QUEUE" BR_READY_JSON="$READY_BEADS" NTM_WORKING_JSON="$IDLE_WORKING" PATH="$FAKE_BIN:$PATH" "$WATCHER" skills --json)"
python3 - "$READY_OUTPUT" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["action"] == "targeted_assignment_recommended", payload
assert payload["ready_ids"] == ["bd-ready"], payload
assert payload["suggested_next_id"] == "bd-ready", payload
assert payload["idle_panes"] == ["3"], payload
assert payload["must_assign"] is True, payload
assert "ntm --robot-send=skills --panes=3" in payload["suggested_command"], payload
assert "bd-ready" in payload["assignment_message"], payload
PY

DRY_QUEUE="$TMP_ROOT/dry-queue.json"
DRY_READY="$TMP_ROOT/dry-ready.json"
DRY_WORKING="$TMP_ROOT/dry-working.json"

write_json "$DRY_QUEUE" '{
  "success": true,
  "queue_dry": true,
  "evidence": {
    "ready_count": 0,
    "in_progress_count": 0,
    "sync": {"status": "in_sync"}
  },
  "recommendations": []
}'
write_json "$DRY_READY" '[]'
write_json "$DRY_WORKING" '{"success": true, "panes": {"3": {"is_idle": true, "is_working": false, "is_rate_limited": false}}}'

DRY_OUTPUT="$(NTM_QUEUE_DRY_JSON="$DRY_QUEUE" BR_READY_JSON="$DRY_READY" NTM_WORKING_JSON="$DRY_WORKING" PATH="$FAKE_BIN:$PATH" "$WATCHER" skills --json)"
python3 - "$DRY_OUTPUT" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["action"] == "true_queue_dry", payload
assert payload["queue_dry"] is True, payload
assert payload["ready_count"] == 0, payload
assert payload["must_assign"] is False, payload
assert payload["suggested_command"] is None, payload
PY

DRIFT_QUEUE="$TMP_ROOT/drift-queue.json"
write_json "$DRIFT_QUEUE" '{
  "success": true,
  "queue_dry": false,
  "evidence": {
    "ready_count": 0,
    "in_progress_count": 0,
    "sync": {"status": "needs_flush"}
  }
}'
DRIFT_OUTPUT="$(NTM_QUEUE_DRY_JSON="$DRIFT_QUEUE" BR_READY_JSON="$DRY_READY" NTM_WORKING_JSON="$DRY_WORKING" PATH="$FAKE_BIN:$PATH" "$WATCHER" skills --json)"
python3 - "$DRIFT_OUTPUT" <<'PY'
import json
import sys
payload = json.loads(sys.argv[1])
assert payload["action"] == "tracker_drift", payload
assert payload["queue_dry_reason"] == "beads_jsonl_or_db_sync_not_clean", payload
PY

echo "ntm_ready_watcher fixture tests passed."
