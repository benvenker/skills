#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


VERSION = "1.0.0"
CONTRACT_VERSION = "2026-06-06"
READY_LABEL = "ready-for-agent"
COMMAND_TIMEOUT_SECONDS = 60


class DraftError(Exception):
    def __init__(self, path: str, message: str) -> None:
        super().__init__(f"{path}: {message}")
        self.path = path
        self.message = message


def eprint(message: str) -> None:
    print(message, file=sys.stderr)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise DraftError(str(path), f"invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}") from exc
    except OSError as exc:
        raise DraftError(str(path), f"could not read draft: {exc}") from exc


def require_mapping(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise DraftError(path, "must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise DraftError(path, "must be an array")
    return value


def require_str(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise DraftError(path, "must be a non-empty string")
    return value.strip()


def optional_str(value: Any, path: str) -> str | None:
    if value is None:
        return None
    return require_str(value, path)


def normalize_labels(value: Any, path: str) -> list[str]:
    if value is None:
        return []
    labels = require_list(value, path)
    result: list[str] = []
    seen: set[str] = set()
    for index, label in enumerate(labels):
        normalized = require_str(label, f"{path}[{index}]")
        if normalized not in seen:
            seen.add(normalized)
            result.append(normalized)
    return result


def normalize_priority(value: Any, path: str) -> int:
    if isinstance(value, int) and 0 <= value <= 4:
        return value
    if isinstance(value, str):
        raw = value.strip().upper()
        if raw.startswith("P"):
            raw = raw[1:]
        if raw.isdigit():
            parsed = int(raw)
            if 0 <= parsed <= 4:
                return parsed
    raise DraftError(path, "must be a priority from 0 to 4 or P0 to P4")


def issue_key(issue: dict[str, Any], index: int) -> str:
    if "key" in issue:
        return require_str(issue["key"], f"issues[{index}].key")
    if "slug" in issue:
        return require_str(issue["slug"], f"issues[{index}].slug")
    title = require_str(issue.get("title"), f"issues[{index}].title")
    return title.lower().replace(" ", "-")


def parse_draft(payload: Any) -> dict[str, Any]:
    draft = require_mapping(payload, "draft")
    schema = draft.get("schema", "better-beads-graph-draft-v1")
    if schema != "better-beads-graph-draft-v1":
        raise DraftError("schema", "must be better-beads-graph-draft-v1")

    raw_issues = require_list(draft.get("issues"), "issues")
    if not raw_issues:
        raise DraftError("issues", "must contain at least one issue")

    issues: list[dict[str, Any]] = []
    keys: set[str] = set()
    titles: set[str] = set()
    slugs: set[str] = set()
    errors: list[dict[str, str]] = []

    for index, raw_issue in enumerate(raw_issues):
        try:
            issue = require_mapping(raw_issue, f"issues[{index}]")
            key = issue_key(issue, index)
            title = require_str(issue.get("title"), f"issues[{index}].title")
            issue_type = require_str(issue.get("type", "task"), f"issues[{index}].type")
            priority = normalize_priority(issue.get("priority", 2), f"issues[{index}].priority")
            description = require_str(issue.get("description"), f"issues[{index}].description")
            slug = optional_str(issue.get("slug"), f"issues[{index}].slug")
            status = optional_str(issue.get("status"), f"issues[{index}].status")
            parent = optional_str(issue.get("parent"), f"issues[{index}].parent")
            ready_frontier = bool(issue.get("ready_frontier", False))
            labels = normalize_labels(issue.get("labels", []), f"issues[{index}].labels")
            if ready_frontier and READY_LABEL not in labels:
                labels.append(READY_LABEL)

            if key in keys:
                raise DraftError(f"issues[{index}].key", f"duplicate issue key: {key}")
            if title in titles:
                raise DraftError(f"issues[{index}].title", f"duplicate issue title: {title}")
            if slug and slug in slugs:
                raise DraftError(f"issues[{index}].slug", f"duplicate issue slug: {slug}")

            keys.add(key)
            titles.add(title)
            if slug:
                slugs.add(slug)
            issues.append({
                "key": key,
                "title": title,
                "type": issue_type,
                "priority": priority,
                "description": description,
                "labels": labels,
                "slug": slug,
                "status": status,
                "parent": parent,
                "ready_frontier": ready_frontier,
                "input_index": index,
            })
        except DraftError as exc:
            errors.append({"path": exc.path, "message": exc.message})

    if errors:
        raise DraftError("issues", json.dumps(errors))

    parent_by_child: dict[str, str] = {}
    for issue in issues:
        if issue["parent"]:
            parent_by_child[issue["key"]] = issue["parent"]

    raw_parent_closure = require_list(draft.get("parent_closure", []), "parent_closure")
    for index, raw_edge in enumerate(raw_parent_closure):
        edge = require_mapping(raw_edge, f"parent_closure[{index}]")
        parent = require_str(edge.get("parent"), f"parent_closure[{index}].parent")
        child = require_str(edge.get("child"), f"parent_closure[{index}].child")
        if child in parent_by_child and parent_by_child[child] != parent:
            raise DraftError(
                f"parent_closure[{index}]",
                f"child {child} already has parent {parent_by_child[child]}",
            )
        parent_by_child[child] = parent

    dependencies: list[dict[str, str]] = []
    raw_dependencies = require_list(draft.get("dependencies", []), "dependencies")
    for index, raw_dep in enumerate(raw_dependencies):
        dep = require_mapping(raw_dep, f"dependencies[{index}]")
        issue = require_str(dep.get("issue"), f"dependencies[{index}].issue")
        depends_on = require_str(dep.get("depends_on"), f"dependencies[{index}].depends_on")
        dep_type = require_str(dep.get("type", "blocks"), f"dependencies[{index}].type")
        if dep_type == "parent-child":
            raise DraftError(
                f"dependencies[{index}].type",
                "use parent_closure or issue.parent for parent-child relationships",
            )
        dependencies.append({"issue": issue, "depends_on": depends_on, "type": dep_type})

    return {
        "schema": schema,
        "issues": issues,
        "parent_by_child": parent_by_child,
        "dependencies": dependencies,
    }


def run_json(repo: Path, argv: list[str]) -> tuple[Any, dict[str, Any]]:
    try:
        result = subprocess.run(
            argv,
            cwd=repo,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return None, {
            "command": argv,
            "returncode": 2,
            "stderr": f"command timed out after {COMMAND_TIMEOUT_SECONDS}s",
        }
    status = {
        "command": argv,
        "returncode": result.returncode,
        "stderr": result.stderr.strip(),
    }
    if result.returncode != 0:
        return None, status
    try:
        return json.loads(result.stdout or "null"), status
    except json.JSONDecodeError as exc:
        status["parse_error"] = str(exc)
        return None, status


def existing_issues(repo: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if not (repo / ".beads").exists():
        return [], {"command": ["br", "list", "--json"], "returncode": 0, "stderr": "", "state": "skipped_no_beads"}
    payload, status = run_json(repo, ["br", "list", "--json"])
    if status["returncode"] != 0 or status.get("parse_error"):
        raise DraftError("repo", f"br list --json failed before graph mutation: {status}")
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)], status
    if isinstance(payload, dict) and isinstance(payload.get("issues"), list):
        return [item for item in payload["issues"] if isinstance(item, dict)], status
    raise DraftError("repo", "br list --json returned unsupported JSON shape")


def detect_cycles(edges: list[tuple[str, str]]) -> list[list[str]]:
    by_issue: dict[str, list[str]] = defaultdict(list)
    for issue, depends_on in edges:
        by_issue[issue].append(depends_on)

    cycles: list[list[str]] = []
    path: list[str] = []
    state: dict[str, str] = {}

    def visit(node: str) -> None:
        state[node] = "visiting"
        path.append(node)
        for next_node in by_issue.get(node, []):
            if state.get(next_node) == "visiting":
                start = path.index(next_node)
                cycles.append(path[start:] + [next_node])
            elif state.get(next_node) != "done":
                visit(next_node)
        path.pop()
        state[node] = "done"

    for issue, depends_on in edges:
        if state.get(issue) is None:
            visit(issue)
        if state.get(depends_on) is None:
            visit(depends_on)
    return cycles


def creation_order(issues: list[dict[str, Any]], parent_by_child: dict[str, str]) -> list[str]:
    by_key = {issue["key"]: issue for issue in issues}
    ordered: list[str] = []
    visiting: set[str] = set()
    done: set[str] = set()

    def add(key: str) -> None:
        if key in done:
            return
        if key in visiting:
            raise DraftError("parent_closure", f"cycle includes parent relationship for {key}")
        visiting.add(key)
        parent = parent_by_child.get(key)
        if parent and parent in by_key:
            add(parent)
        visiting.remove(key)
        done.add(key)
        ordered.append(key)

    for issue in sorted(issues, key=lambda item: item["input_index"]):
        add(issue["key"])
    return ordered


def build_plan(draft: dict[str, Any], repo: Path, draft_path: Path) -> dict[str, Any]:
    issues = draft["issues"]
    by_key = {issue["key"]: issue for issue in issues}
    keys = set(by_key)
    errors: list[dict[str, str]] = []

    for child, parent in draft["parent_by_child"].items():
        if child not in keys:
            errors.append({"path": "parent_closure", "message": f"unknown child reference: {child}"})
        if parent not in keys:
            errors.append({"path": "parent_closure", "message": f"unknown parent reference: {parent}"})

    for index, dep in enumerate(draft["dependencies"]):
        if dep["issue"] not in keys:
            errors.append({"path": f"dependencies[{index}].issue", "message": f"unknown issue reference: {dep['issue']}"})
        if dep["depends_on"] not in keys:
            errors.append({"path": f"dependencies[{index}].depends_on", "message": f"unknown dependency reference: {dep['depends_on']}"})

    existing, list_status = existing_issues(repo)
    existing_titles = {
        issue.get("title")
        for issue in existing
        if issue.get("status") not in {"closed", "archived"} and issue.get("title")
    }
    for issue in issues:
        if issue["title"] in existing_titles:
            errors.append({"path": f"issues[{issue['input_index']}].title", "message": f"title already exists in active graph: {issue['title']}"})

    parent_keys = set(draft["parent_by_child"].values())
    blocking_edges = [(dep["issue"], dep["depends_on"]) for dep in draft["dependencies"]]
    blocking_cycles = detect_cycles(blocking_edges)
    if blocking_cycles:
        errors.append({"path": "dependencies", "message": f"blocking dependency cycle detected: {blocking_cycles[0]}"})

    parent_edges = [(child, parent) for child, parent in draft["parent_by_child"].items()]
    parent_cycles = detect_cycles(parent_edges)
    if parent_cycles:
        errors.append({"path": "parent_closure", "message": f"parent closure cycle detected: {parent_cycles[0]}"})

    blocked_ready_labels: list[dict[str, Any]] = []
    blockers_by_issue: dict[str, list[str]] = defaultdict(list)
    for issue, depends_on in blocking_edges:
        blockers_by_issue[issue].append(depends_on)

    for issue in issues:
        reasons: list[str] = []
        if issue["key"] in blockers_by_issue:
            reasons.append("has blocking dependencies")
        if issue["key"] in parent_keys or issue["type"] == "epic":
            reasons.append("is a parent/closure issue")
        if issue["ready_frontier"] and reasons:
            blocked_ready_labels.append({
                "key": issue["key"],
                "title": issue["title"],
                "reasons": reasons,
                "blocking_dependencies": blockers_by_issue.get(issue["key"], []),
            })

    if blocked_ready_labels:
        errors.append({"path": "issues.ready_frontier", "message": "ready_frontier is set on blocked or parent issues"})

    try:
        ordered_keys = creation_order(issues, draft["parent_by_child"])
    except DraftError as exc:
        errors.append({"path": exc.path, "message": exc.message})
        ordered_keys = [issue["key"] for issue in sorted(issues, key=lambda item: item["input_index"])]

    preview_ids = {
        key: {
            "source": "br",
            "slug": by_key[key]["slug"],
            "preview": f"created-by-br:{by_key[key]['slug'] or key}",
        }
        for key in ordered_keys
    }

    commands: list[list[str]] = []
    for key in ordered_keys:
        issue = by_key[key]
        command = [
            "br", "create",
            "--title", issue["title"],
            "--type", issue["type"],
            "--priority", str(issue["priority"]),
            "--description", issue["description"],
            "--json",
        ]
        if issue["labels"]:
            command.extend(["--labels", ",".join(issue["labels"])])
        if issue["slug"]:
            command.extend(["--slug", issue["slug"]])
        if issue["status"]:
            command.extend(["--status", issue["status"]])
        parent = draft["parent_by_child"].get(key)
        if parent:
            command.extend(["--parent", f"${{{parent}}}"])
        commands.append(command)

    for dep in draft["dependencies"]:
        command = ["br", "dep", "add", f"${{{dep['issue']}}}", f"${{{dep['depends_on']}}}", "--json"]
        if dep["type"] != "blocks":
            command.extend(["--type", dep["type"]])
        commands.append(command)

    return {
        "tool": "bead_create_graph.py",
        "schema": "better-beads-create-graph-preview-v1",
        "contract_version": CONTRACT_VERSION,
        "repo": str(repo),
        "draft": str(draft_path),
        "preflight": {
            "valid": not errors,
            "errors": errors,
            "blocked_ready_labels": blocked_ready_labels,
            "blocking_cycles": blocking_cycles,
            "parent_cycles": parent_cycles,
            "br_list": list_status,
        },
        "issue_preview": [
            {
                "key": issue["key"],
                "preview_id": preview_ids[issue["key"]]["preview"],
                "title": issue["title"],
                "type": issue["type"],
                "priority": issue["priority"],
                "labels": issue["labels"],
                "parent": draft["parent_by_child"].get(issue["key"]),
                "ready_frontier": issue["ready_frontier"],
            }
            for issue in sorted(issues, key=lambda item: item["input_index"])
        ],
        "parent_closure": [
            {"parent": parent, "child": child}
            for child, parent in sorted(draft["parent_by_child"].items())
        ],
        "dependencies": sorted(draft["dependencies"], key=lambda item: (item["issue"], item["depends_on"], item["type"])),
        "creation_order": ordered_keys,
        "would_run": {
            "files": {
                "draft": str(draft_path),
                "repo": str(repo),
                "beads_dir": str(repo / ".beads"),
            },
            "commands": commands,
        },
        "apply_allowed": not errors,
    }


def command_with_ids(command: list[str], ids: dict[str, str]) -> list[str]:
    resolved: list[str] = []
    for item in command:
        if item.startswith("${") and item.endswith("}"):
            key = item[2:-1]
            resolved.append(ids[key])
        else:
            resolved.append(item)
    return resolved


def created_id(payload: Any) -> str | None:
    if isinstance(payload, dict):
        value = payload.get("id") or payload.get("issue_id")
        if isinstance(value, str) and value:
            return value
    if isinstance(payload, list) and payload and isinstance(payload[0], dict):
        value = payload[0].get("id") or payload[0].get("issue_id")
        if isinstance(value, str) and value:
            return value
    return None


def apply_plan(repo: Path, plan: dict[str, Any]) -> dict[str, Any]:
    if not plan["apply_allowed"]:
        raise DraftError("preflight", "draft is not safe to apply; inspect preflight.errors")

    ids: dict[str, str] = {}
    mutations: list[dict[str, Any]] = []
    commands = plan["would_run"]["commands"]
    creation_count = len(plan["creation_order"])

    for index, command in enumerate(commands):
        resolved = command_with_ids(command, ids)
        payload, status = run_json(repo, resolved)
        mutation = {
            "phase": "create" if index < creation_count else "dependency",
            "command": resolved,
            "returncode": status["returncode"],
            "stderr": status["stderr"],
        }
        if status["returncode"] != 0 or status.get("parse_error"):
            mutation["parse_error"] = status.get("parse_error")
            mutations.append(mutation)
            return {
                "tool": "bead_create_graph.py",
                "schema": "better-beads-create-graph-apply-v1",
                "contract_version": CONTRACT_VERSION,
                "repo": plan["repo"],
                "applied": False,
                "created_ids": ids,
                "mutations": mutations,
                "last_successful_mutation": mutations[-2] if len(mutations) > 1 else None,
                "failed_mutation": mutation,
                "recovery": {
                    "message": "A br mutation failed after preflight. Inspect created_ids and command output before retrying.",
                    "evidence_commands": ["br list --json", "br dep cycles --json", "br sync --flush-only"],
                },
            }
        if index < creation_count:
            key = plan["creation_order"][index]
            issue_id = created_id(payload)
            if not issue_id:
                mutation["parse_error"] = "br create JSON did not include id"
                mutations.append(mutation)
                return {
                    "tool": "bead_create_graph.py",
                    "schema": "better-beads-create-graph-apply-v1",
                    "contract_version": CONTRACT_VERSION,
                    "repo": plan["repo"],
                    "applied": False,
                    "created_ids": ids,
                    "mutations": mutations,
                    "last_successful_mutation": mutations[-2] if len(mutations) > 1 else None,
                    "failed_mutation": mutation,
                    "recovery": {
                        "message": "A br create command succeeded but did not return an issue id.",
                        "evidence_commands": ["br list --json", "br dep cycles --json"],
                    },
                }
            ids[key] = issue_id
            mutation["key"] = key
            mutation["created_id"] = issue_id
        mutations.append(mutation)

    cycles_payload, cycles_status = run_json(repo, ["br", "dep", "cycles", "--json"])
    return {
        "tool": "bead_create_graph.py",
        "schema": "better-beads-create-graph-apply-v1",
        "contract_version": CONTRACT_VERSION,
        "repo": plan["repo"],
        "applied": True,
        "created_ids": ids,
        "mutations": mutations,
        "post_apply": {
            "br_dep_cycles": cycles_status,
            "cycles": cycles_payload,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="bead_create_graph.py",
        description="Dry-run or apply a reviewed Better-Beads graph draft safely.",
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", dest="dry_run", metavar="DRAFT")
    mode.add_argument("--apply", dest="apply", metavar="DRAFT")
    parser.add_argument("--repo", default=".", help="Repository containing .beads (default: current directory)")
    parser.add_argument("--version", action="store_true", help=argparse.SUPPRESS)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    draft_path = Path(args.dry_run or args.apply)
    if not draft_path.is_absolute():
        draft_path = Path.cwd() / draft_path
    draft_path = draft_path.resolve()

    try:
        payload = load_json(draft_path)
        draft = parse_draft(payload)
        plan = build_plan(draft, repo, draft_path)
        if args.dry_run:
            print(json.dumps(plan, indent=2))
            return 0 if plan["preflight"]["valid"] else 2
        result = apply_plan(repo, plan)
        print(json.dumps(result, indent=2))
        return 0 if result.get("applied") else 2
    except DraftError as exc:
        eprint(f"{exc.path}: {exc.message}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
