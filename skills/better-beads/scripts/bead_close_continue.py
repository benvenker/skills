#!/usr/bin/env python3
"""Close a bead and report whether a swarm must continue.

This helper intentionally does not commit, push, or mutate Beads internals. It
uses `br close`, `br sync --flush-only`, and read-only `br` inspections so
implementation panes can avoid false queue-dry conclusions after closing work.
"""
from __future__ import annotations

import argparse
import json
import subprocess  # nosec B404 - this helper shells out to fixed local br commands.
import sys
import tempfile
from pathlib import Path
from typing import Sequence

TOOL = "bead_close_continue.py"
SCHEMA = "better-beads-close-continue-v1"
CONTRACT_VERSION = "2026-06-08"
COMMAND_TIMEOUT_SECONDS = 30
JSON_DECODER = json.JSONDecoder()


def run_command(argv: Sequence[str], repo: Path) -> dict[str, object]:
    command = list(argv)
    try:
        result = subprocess.run(  # nosec B603 - commands are fixed argv lists; shell=False.
            command,
            cwd=repo,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        return {
            "command": command,
            "returncode": 124,
            "stdout": (exc.stdout or "").strip() if isinstance(exc.stdout, str) else "",
            "stderr": f"timed out after {COMMAND_TIMEOUT_SECONDS}s",
        }
    return {
        "command": command,
        "returncode": result.returncode,
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
    }


def parse_json_list(record: dict[str, object]) -> list[dict[str, object]] | None:
    stdout = str(record.get("stdout") or "")
    if not stdout:
        return None
    try:
        data = JSON_DECODER.decode(stdout)
    except json.JSONDecodeError:
        return None
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        for key in ("issues", "ready", "items"):
            value = data.get(key)
            if isinstance(value, list):
                return [item for item in value if isinstance(item, dict)]
    return None


def item_id(item: dict[str, object]) -> str | None:
    value = item.get("id")
    return value if isinstance(value, str) else None


def inspect_after_close(repo: Path, closed_id: str, close_record: dict[str, object], sync_record: dict[str, object]) -> dict[str, object]:
    ready_record = run_command(["br", "ready", "--json"], repo)
    list_record = run_command(["br", "list", "--status", "in_progress", "--json"], repo)
    ready_items = parse_json_list(ready_record)
    in_progress_items = parse_json_list(list_record)

    inspection_errors: list[str] = []
    if sync_record["returncode"] != 0:
        inspection_errors.append("sync-failed")
    if ready_record["returncode"] != 0 or ready_items is None:
        inspection_errors.append("ready-inspection-failed")
        ready_items = []
    if list_record["returncode"] != 0 or in_progress_items is None:
        inspection_errors.append("in-progress-inspection-failed")
        in_progress_items = []

    suggested_next_id = item_id(ready_items[0]) if ready_items else None
    ready_count = len(ready_items)
    in_progress_count = len(in_progress_items)
    queue_dry = ready_count == 0 and in_progress_count == 0 and not inspection_errors
    must_continue = ready_count > 0 or in_progress_count > 0 or bool(inspection_errors)

    if suggested_next_id:
        suggested_command = f"br update {suggested_next_id} --status in_progress --json"
    elif in_progress_count:
        suggested_command = "skills/better-beads/scripts/bead_closeout_guard.sh --repo . --json"
    elif inspection_errors:
        suggested_command = "br ready --json"
    else:
        suggested_command = ""

    return {
        "tool": TOOL,
        "schema": SCHEMA,
        "contract_version": CONTRACT_VERSION,
        "closed_id": closed_id,
        "closed": close_record["returncode"] == 0,
        "suggested_next_id": suggested_next_id,
        "ready_count": ready_count,
        "queue_dry": queue_dry,
        "must_continue": must_continue,
        "suggested_command": suggested_command,
        "in_progress_count": in_progress_count,
        "inspection_errors": inspection_errors,
        "ready_ids": [item_id(item) for item in ready_items if item_id(item)],
        "in_progress_ids": [item_id(item) for item in in_progress_items if item_id(item)],
        "command_statuses": {
            "close": close_record,
            "sync": sync_record,
            "ready": ready_record,
            "in_progress": list_record,
        },
    }


def close_and_continue(repo: Path, bead_id: str, reason: str) -> tuple[int, dict[str, object]]:
    close_record = run_command(["br", "close", bead_id, "--reason", reason], repo)
    if close_record["returncode"] != 0:
        return 2, {
            "tool": TOOL,
            "schema": SCHEMA,
            "contract_version": CONTRACT_VERSION,
            "closed_id": bead_id,
            "closed": False,
            "suggested_next_id": None,
            "ready_count": 0,
            "queue_dry": False,
            "must_continue": True,
            "suggested_command": "br close <id> --reason <reason>",
            "in_progress_count": 0,
            "inspection_errors": ["close-failed"],
            "ready_ids": [],
            "in_progress_ids": [],
            "command_statuses": {"close": close_record},
        }
    sync_record = run_command(["br", "sync", "--flush-only"], repo)
    payload = inspect_after_close(repo, bead_id, close_record, sync_record)
    return (0 if sync_record["returncode"] == 0 else 2), payload


def create_fixture_repo(name: str) -> Path:
    root = Path(tempfile.mkdtemp(prefix=f"better-beads-close-continue-{name}."))
    run_command(["br", "init"], root)
    return root


def create_bead(repo: Path, title: str) -> str:
    record = run_command(["br", "create", "--title", title, "--type", "task", "--priority", "1", "--json"], repo)
    if record["returncode"] != 0:
        raise RuntimeError(str(record))
    try:
        data = JSON_DECODER.decode(str(record["stdout"]))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"br create returned malformed JSON: {record}") from exc
    return str(data["id"])


def self_test() -> int:
    unblock_repo = create_fixture_repo("unblock")
    first = create_bead(unblock_repo, "first closes")
    second = create_bead(unblock_repo, "second becomes ready")
    dep_record = run_command(["br", "dep", "add", second, first], unblock_repo)
    if dep_record["returncode"] != 0:
        print(dep_record, file=sys.stderr)
        return 1
    rc, payload = close_and_continue(unblock_repo, first, "self-test unblock")
    if (
        rc != 0
        or payload["suggested_next_id"] != second
        or payload["ready_count"] != 1
        or not isinstance(payload["queue_dry"], bool)
        or payload["queue_dry"]
        or not isinstance(payload["must_continue"], bool)
        or not payload["must_continue"]
    ):
        print(json.dumps(payload, indent=2), file=sys.stderr)
        return 1

    dry_repo = create_fixture_repo("dry")
    only = create_bead(dry_repo, "final closes")
    rc, dry_payload = close_and_continue(dry_repo, only, "self-test dry")
    if (
        rc != 0
        or dry_payload["suggested_next_id"] is not None
        or dry_payload["ready_count"] != 0
        or not isinstance(dry_payload["queue_dry"], bool)
        or not dry_payload["queue_dry"]
        or not isinstance(dry_payload["must_continue"], bool)
        or dry_payload["must_continue"]
    ):
        print(json.dumps(dry_payload, indent=2), file=sys.stderr)
        return 1

    print("self-test OK")
    print(json.dumps({"unblock": payload, "queue_dry": dry_payload}, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Close one bead and report follow-up ready work.")
    parser.add_argument("--repo", default=".", help="repository containing .beads")
    parser.add_argument("--id", dest="bead_id", help="bead id to close")
    parser.add_argument("--reason", help="close reason/evidence")
    parser.add_argument("--json", action="store_true", help="emit JSON")
    parser.add_argument("--self-test", action="store_true", help="run fixture self-test")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.json:
        parser.error("--json is required")
    if not args.bead_id:
        parser.error("--id is required")
    if not args.reason:
        parser.error("--reason is required")
    repo = Path(args.repo).resolve()
    if not repo.exists():
        parser.error(f"repo does not exist: {repo}")
    rc, payload = close_and_continue(repo, args.bead_id, args.reason)
    print(json.dumps(payload, indent=2))
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
