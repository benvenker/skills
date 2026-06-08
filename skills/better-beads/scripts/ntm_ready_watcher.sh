#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ntm_ready_watcher.sh SESSION --json

Checks NTM queue-dry state, Beads ready work, and NTM pane state. Emits a
targeted assignment recommendation when ready Beads work and idle panes are both
visible. This helper is read-only: it does not send prompts, mutate Beads, or
touch Git state.
EOF
}

SESSION=""
JSON=0

while (($#)); do
  case "$1" in
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
    *)
      if [[ -n "$SESSION" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage
        exit 2
      fi
      SESSION="$1"
      shift
      ;;
  esac
done

if [[ -z "$SESSION" || "$JSON" -ne 1 ]]; then
  usage
  exit 2
fi

if ! QUEUE_JSON="$(ntm work queue-dry "$SESSION" --json)"; then
  echo "ntm work queue-dry failed" >&2
  exit 2
fi

if ! READY_JSON="$(br ready --json)"; then
  echo "br ready --json failed" >&2
  exit 2
fi

if ! WORKING_JSON="$(ntm --robot-is-working="$SESSION")"; then
  echo "ntm --robot-is-working failed" >&2
  exit 2
fi

QUEUE_JSON="$QUEUE_JSON" READY_JSON="$READY_JSON" WORKING_JSON="$WORKING_JSON" python3 - "$SESSION" <<'PY'
import json
import shlex
import sys
import os

session = sys.argv[1]
queue = json.loads(os.environ["QUEUE_JSON"])
ready_payload = json.loads(os.environ["READY_JSON"])
working = json.loads(os.environ["WORKING_JSON"])

ready_items = ready_payload.get("issues", ready_payload) if isinstance(ready_payload, dict) else ready_payload
if not isinstance(ready_items, list):
    ready_items = []

ready_ids = [item.get("id") for item in ready_items if isinstance(item, dict) and item.get("id")]
ready_count = len(ready_ids)
suggested_next_id = ready_ids[0] if ready_ids else None

panes = working.get("panes", {}) if isinstance(working, dict) else {}
idle_panes = []
working_panes = []
rate_limited_panes = []
unknown_panes = []

for pane_id, state in panes.items():
    if not isinstance(state, dict):
        continue
    recommendation = str(state.get("recommendation") or "").upper()
    pane = str(pane_id)
    if state.get("is_working"):
        working_panes.append(pane)
    if state.get("is_rate_limited"):
        rate_limited_panes.append(pane)
    is_idle = bool(state.get("is_idle")) or recommendation in {
        "IDLE",
        "READY",
        "READY_FOR_ASSIGNMENT",
        "ASSIGN",
    }
    if is_idle and not state.get("is_working") and not state.get("is_rate_limited"):
        idle_panes.append(pane)
    elif not state.get("is_working") and not state.get("is_idle") and recommendation in {"", "UNKNOWN"}:
        unknown_panes.append(pane)

queue_dry = bool(queue.get("queue_dry")) if isinstance(queue, dict) else False
evidence = queue.get("evidence", {}) if isinstance(queue, dict) else {}
sync = evidence.get("sync", {}) if isinstance(evidence, dict) else {}
sync_status = sync.get("status", "unknown") if isinstance(sync, dict) else "unknown"
in_progress_count = evidence.get("in_progress_count") if isinstance(evidence, dict) else None

action = "no_op"
queue_dry_reason = "unknown"
must_assign = False
suggested_command = None
assignment_message = None

if ready_count and idle_panes:
    target_pane = idle_panes[0]
    action = "targeted_assignment_recommended"
    queue_dry_reason = "ready_work_with_idle_pane"
    must_assign = True
    assignment_message = (
        f"Claim ready bead {suggested_next_id}. Use Agent Mail, reserve only files you edit, "
        "mark in_progress, implement, validate, close, sync, release reservations, and summarize."
    )
    suggested_command = (
        f"ntm --robot-send={shlex.quote(session)} --panes={shlex.quote(target_pane)} "
        f"--msg={shlex.quote(assignment_message)}"
    )
elif ready_count:
    action = "ready_work_no_idle_pane"
    queue_dry_reason = "ready_work_but_no_idle_pane"
elif queue_dry and ready_count == 0 and sync_status == "in_sync" and (in_progress_count in (0, None)):
    action = "true_queue_dry"
    queue_dry_reason = "queue_dry_verified"
elif ready_count == 0 and sync_status != "in_sync":
    action = "tracker_drift"
    queue_dry_reason = "beads_jsonl_or_db_sync_not_clean"
elif ready_count == 0 and isinstance(in_progress_count, int) and in_progress_count > 0:
    action = "in_flight_work"
    queue_dry_reason = "in_progress_beads_remain"
else:
    action = "no_ready_work_unverified"
    queue_dry_reason = "queue_dry_not_verified"

result = {
    "tool": "ntm_ready_watcher.sh",
    "schema": "better-beads-ntm-ready-watcher-v1",
    "session": session,
    "queue_dry": queue_dry,
    "queue_dry_reason": queue_dry_reason,
    "ready_count": ready_count,
    "ready_ids": ready_ids,
    "suggested_next_id": suggested_next_id,
    "idle_panes": idle_panes,
    "working_panes": working_panes,
    "rate_limited_panes": rate_limited_panes,
    "unknown_panes": unknown_panes,
    "action": action,
    "must_assign": must_assign,
    "suggested_command": suggested_command,
    "assignment_message": assignment_message,
    "evidence": {
        "queue_dry_success": queue.get("success") if isinstance(queue, dict) else None,
        "queue_dry_recommendations": queue.get("recommendations", []) if isinstance(queue, dict) else [],
        "sync_status": sync_status,
        "in_progress_count": in_progress_count,
        "working_success": working.get("success") if isinstance(working, dict) else None,
    },
}
print(json.dumps(result, indent=2, sort_keys=True))
PY
