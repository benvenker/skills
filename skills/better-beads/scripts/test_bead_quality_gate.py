#!/usr/bin/env python3
"""Smoke tests for bead_quality_gate.py operator-dispatch behavior.

These tests build isolated temporary repos with .beads/issues.jsonl fixtures and
never mutate the caller's Beads database.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("bead_quality_gate.py")


def valid_description(extra: str = "") -> str:
    return f"""## Outcome
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


def write_issues(repo: Path, issues: list[dict]) -> None:
    beads = repo / ".beads"
    beads.mkdir(exist_ok=True)
    (beads / "issues.jsonl").write_text(
        "\n".join(json.dumps(issue) for issue in issues) + "\n",
        encoding="utf-8",
    )


def issue(
    issue_id: str,
    *,
    status: str = "open",
    description: str | None = None,
    labels: list[str] | None = None,
    dependencies: list[dict] | None = None,
    dependency_count: int = 0,
) -> dict:
    return {
        "id": issue_id,
        "title": f"{issue_id} test bead",
        "status": status,
        "labels": labels or [],
        "description": description or valid_description(),
        "dependencies": dependencies or [],
        "dependency_count": dependency_count,
    }


def run_gate(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--repo", str(repo), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


class BeadQualityGateTests(unittest.TestCase):
    def test_operator_dispatch_blocks_oversized_child_that_default_only_warns(self) -> None:
        long_extra = "\n".join(f"- Extra same-behavior detail {i}: keep filtered graph behavior explicit." for i in range(90))
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_issues(repo, [issue("bd-oversized", description=valid_description(long_extra))])

            default = run_gate(repo, "--json")
            self.assertEqual(default.returncode, 0, default.stderr + default.stdout)
            default_payload = json.loads(default.stdout)
            self.assertGreater(default_payload["warning_count"], 0)
            self.assertEqual(default_payload["error_count"], 0)
            default_long = [f for f in default_payload["findings"] if f["code"] == "long-child-contract"]
            self.assertTrue(default_long)
            self.assertFalse(default_long[0]["operator_blocking"])

            operator = run_gate(repo, "--operator-dispatch", "--json")
            self.assertEqual(operator.returncode, 1)
            operator_payload = json.loads(operator.stdout)
            self.assertTrue(operator_payload["operator_dispatch"])
            self.assertGreater(operator_payload["operator_blocking_count"], 0)
            self.assertGreater(operator_payload["split_review_required_count"], 0)
            operator_long = [f for f in operator_payload["findings"] if f["code"] == "long-child-contract"]
            self.assertTrue(operator_long)
            self.assertEqual(operator_long[0]["severity"], "error")
            self.assertTrue(operator_long[0]["operator_blocking"])
            self.assertTrue(operator_long[0]["requires_split_review"])

    def test_operator_dispatch_blocks_ready_label_with_unresolved_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_issues(repo, [
                issue("bd-dep"),
                issue(
                    "bd-ready",
                    labels=["ready-for-agent"],
                    dependencies=[{"id": "bd-dep", "status": "open"}],
                    dependency_count=1,
                ),
            ])

            default = run_gate(repo, "--json")
            self.assertEqual(default.returncode, 0, default.stderr + default.stdout)
            default_payload = json.loads(default.stdout)
            default_ready = [f for f in default_payload["findings"] if f["code"] == "ready-label-blocked"]
            self.assertEqual(len(default_ready), 1, default_payload)
            self.assertEqual(default_ready[0]["severity"], "warning")
            self.assertFalse(default_ready[0]["operator_blocking"])
            self.assertFalse(default_ready[0]["requires_split_review"])

            operator = run_gate(repo, "--operator-dispatch", "--json")
            self.assertEqual(operator.returncode, 1)
            operator_payload = json.loads(operator.stdout)
            operator_ready = [f for f in operator_payload["findings"] if f["code"] == "ready-label-blocked"]
            self.assertEqual(len(operator_ready), 1, operator_payload)
            self.assertEqual(operator_ready[0]["severity"], "error")
            self.assertTrue(operator_ready[0]["operator_blocking"])
            self.assertFalse(operator_ready[0]["requires_split_review"])
            self.assertEqual(operator_payload["operator_blocking_count"], 1)
            self.assertEqual(operator_payload["split_review_required_count"], 0)

    def test_ready_label_prefers_detailed_dependency_status_over_dependency_count(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_issues(repo, [
                issue("bd-dep", status="closed"),
                issue(
                    "bd-ready",
                    labels=["ready-for-agent"],
                    dependencies=[{"id": "bd-dep"}],
                    dependency_count=1,
                ),
            ])

            result = run_gate(repo, "--json")
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            payload = json.loads(result.stdout)
            ready_findings = [f for f in payload["findings"] if f["code"] == "ready-label-blocked"]
            self.assertEqual(ready_findings, [], payload)

    def test_ready_label_falls_back_to_dependency_count_without_detail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_issues(repo, [
                issue("bd-ready", labels=["ready-for-agent"], dependency_count=1),
            ])

            result = run_gate(repo, "--json")
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            payload = json.loads(result.stdout)
            ready_findings = [f for f in payload["findings"] if f["code"] == "ready-label-blocked"]
            self.assertEqual(len(ready_findings), 1, payload)
            self.assertEqual(ready_findings[0]["severity"], "warning")

    def test_missing_referenced_script_is_advisory_warning(self) -> None:
        desc = valid_description("\nCreate or use the targeted smoke command:\n```bash\npython3 scripts/missing_smoke.py\n```\n")
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_issues(repo, [issue("bd-script", description=desc)])

            result = run_gate(repo, "--json")
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            payload = json.loads(result.stdout)
            script_findings = [f for f in payload["findings"] if f["code"] == "referenced-script-missing"]
            self.assertEqual(len(script_findings), 1, payload)
            self.assertEqual(script_findings[0]["severity"], "warning")

    def test_active_filter_excludes_closed_unless_changed_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            write_issues(repo, [issue("bd-open"), issue("bd-closed", status="closed")])

            default = run_gate(repo, "--json")
            self.assertEqual(default.returncode, 0, default.stderr + default.stdout)
            self.assertEqual(json.loads(default.stdout)["issue_count"], 1)

            subprocess.run(["git", "init"], cwd=repo, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            subprocess.run(["git", "add", ".beads/issues.jsonl"], cwd=repo, check=True)
            staged = run_gate(repo, "--changed-only", "--staged", "--json")
            self.assertEqual(staged.returncode, 0, staged.stderr + staged.stdout)
            self.assertEqual(json.loads(staged.stdout)["issue_count"], 2)

    def test_changed_since_filters_to_added_or_modified_issue_ids(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            subprocess.run(["git", "init"], cwd=repo, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Test User"], cwd=repo, check=True)
            write_issues(repo, [issue("bd-initial")])
            subprocess.run(["git", "add", ".beads/issues.jsonl"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-m", "initial beads"], cwd=repo, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            write_issues(repo, [issue("bd-initial"), issue("bd-added")])
            changed = run_gate(repo, "--changed-only", "--changed-since", "HEAD", "--json")
            self.assertEqual(changed.returncode, 0, changed.stderr + changed.stdout)
            payload = json.loads(changed.stdout)
            self.assertEqual(payload["issue_count"], 1)
            self.assertEqual(payload["findings"], [])


if __name__ == "__main__":
    unittest.main()
