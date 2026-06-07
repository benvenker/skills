#!/usr/bin/env python3
"""Baseline drift eval for bead_quality_gate.py."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
SKILL_ROOT = ROOT / "skills" / "better-beads"
QUALITY_TOOL = SKILL_ROOT / "scripts" / "bead_quality_gate.py"
FIXTURE_GRAPH = SKILL_ROOT / "test" / "fixtures" / "example-graph.json"
BASELINE_PATH = SKILL_ROOT / "evals" / "baselines" / "quality_gate_baseline.json"


class QualityEvalError(AssertionError):
    """Raised when quality gate output drifts from the baseline."""


def load_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as exc:
        raise QualityEvalError(f"{path} is malformed JSON: {exc}") from exc


def issue_from_graph_entry(entry: dict[str, Any]) -> dict[str, Any]:
    issue_id = entry.get("id") or entry.get("slug") or entry.get("key")
    if not issue_id:
        raise QualityEvalError(f"fixture issue lacks id/slug/key: {entry}")
    return {
        "id": issue_id,
        "title": entry.get("title", issue_id),
        "description": entry.get("description", ""),
        "status": entry.get("status", "open"),
        "priority": entry.get("priority", 2),
        "issue_type": entry.get("type", entry.get("issue_type", "task")),
        "labels": entry.get("labels", []),
        "dependencies": entry.get("dependencies", []),
        "dependency_count": len(entry.get("dependencies", [])),
    }


def write_fixture_repo(tmp_root: Path) -> Path:
    graph = load_json(FIXTURE_GRAPH)
    issues = graph.get("issues")
    if not isinstance(issues, list):
        raise QualityEvalError(f"{FIXTURE_GRAPH} must contain an issues array")

    repo = tmp_root / "repo"
    beads_dir = repo / ".beads"
    beads_dir.mkdir(parents=True)
    lines = [json.dumps(issue_from_graph_entry(issue), sort_keys=True) for issue in issues]
    (beads_dir / "issues.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return repo


def run_quality_gate(repo: Path) -> tuple[int, dict[str, Any]]:
    if not QUALITY_TOOL.exists():
        raise QualityEvalError(f"quality gate tool not found: {QUALITY_TOOL}")

    argv = ["python3", str(QUALITY_TOOL), "--repo", str(repo), "--json", "--fail-on", "error"]
    env = {"PATH": "/usr/local/bin:/usr/bin:/bin"}
    proc = subprocess.run(
        argv,
        env=env,
        text=True,
        capture_output=True,
        check=False,
        timeout=10,
    )
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise QualityEvalError(
            f"quality gate stdout was not JSON; exit={proc.returncode}\n"
            f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        ) from exc
    return proc.returncode, payload


def sorted_finding_summaries(findings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    selected = []
    for finding in findings:
        selected.append(
            {
                "severity": finding["severity"],
                "issue_id": finding["issue_id"],
                "code": finding["code"],
                "operator_blocking": finding["operator_blocking"],
                "requires_split_review": finding["requires_split_review"],
            }
        )
    return sorted(
        selected,
        key=lambda item: (
            item["severity"],
            item["issue_id"],
            item["code"],
            item["operator_blocking"],
            item["requires_split_review"],
        ),
    )


def summarize(exit_code: int, payload: dict[str, Any]) -> dict[str, Any]:
    findings = payload.get("findings", [])
    if not isinstance(findings, list):
        raise QualityEvalError("quality gate payload findings must be a list")
    code_multiset = Counter(finding["code"] for finding in findings)
    return {
        "exit_code": exit_code,
        "issue_count": payload["issue_count"],
        "error_count": payload["error_count"],
        "warning_count": payload["warning_count"],
        "operator_blocking_count": payload["operator_blocking_count"],
        "split_review_required_count": payload["split_review_required_count"],
        "finding_code_multiset": dict(sorted(code_multiset.items())),
        "findings": sorted_finding_summaries(findings),
    }


def write_baseline(path: Path, summary: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def strict_keys() -> tuple[str, ...]:
    return (
        "exit_code",
        "issue_count",
        "error_count",
        "operator_blocking_count",
        "split_review_required_count",
        "finding_code_multiset",
        "findings",
    )


def compare_to_baseline(actual: dict[str, Any], expected: dict[str, Any]) -> tuple[bool, list[str]]:
    mismatches = []
    for key in strict_keys():
        if actual.get(key) != expected.get(key):
            mismatches.append(
                f"{key}: expected {expected.get(key)!r}, got {actual.get(key)!r}"
            )
    if mismatches:
        return False, mismatches

    warning_changed = actual.get("warning_count") != expected.get("warning_count")
    if warning_changed:
        return True, [
            "warning_count drifted but exit code, hard counts, finding codes, and selected findings match"
        ]
    return True, []


def evaluate(update_baseline: bool) -> int:
    with tempfile.TemporaryDirectory(prefix="better-beads-quality-eval.") as tmp:
        repo = write_fixture_repo(Path(tmp))
        exit_code, payload = run_quality_gate(repo)
    actual = summarize(exit_code, payload)

    if update_baseline:
        write_baseline(BASELINE_PATH, actual)
        print(f"updated baseline: {BASELINE_PATH}")
        print(
            "quality baseline summary: "
            f"exit_code={actual['exit_code']} "
            f"issues={actual['issue_count']} "
            f"errors={actual['error_count']} "
            f"warnings={actual['warning_count']} "
            f"findings={len(actual['findings'])}"
        )
        return 0

    expected = load_json(BASELINE_PATH)
    passed, notes = compare_to_baseline(actual, expected)
    if not passed:
        print("quality eval failed: baseline drift detected", file=sys.stderr)
        for note in notes:
            print(f"- {note}", file=sys.stderr)
        return 1

    for note in notes:
        print(f"WARNING: {note}", file=sys.stderr)
    print(
        "quality eval passed: "
        f"exit_code={actual['exit_code']} "
        f"issues={actual['issue_count']} "
        f"errors={actual['error_count']} "
        f"warnings={actual['warning_count']} "
        f"findings={len(actual['findings'])}"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        help="Rewrite evals/baselines/quality_gate_baseline.json from current output.",
    )
    args = parser.parse_args()
    try:
        return evaluate(args.update_baseline)
    except QualityEvalError as exc:
        print(f"quality eval failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
