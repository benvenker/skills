#!/usr/bin/env python3
"""Executable routing truth-table evals for bead_route.sh."""

from __future__ import annotations

import argparse
import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
SKILL_ROOT = ROOT / "skills" / "better-beads"
ROUTE_TOOL = SKILL_ROOT / "scripts" / "bead_route.sh"
CASES_PATH = SKILL_ROOT / "evals" / "cases" / "routing_cases.json"

READY_PLAN = """# Ready Plan Fixture

## Outcome
The authoring router reports a clear system truth before any bead mutation.

## Anchors
- Surface: `skills/better-beads/scripts/bead_route.sh`.
- Contract: JSON route output for robot callers.
- State transition: weak plan input routes to `improve-plan-first`.

## Validation
- Run the routing eval harness.
- Verify JSON output with contract checks.

## Failure behavior
- Missing plan paths exit 2 with a clear stderr error.
- Weak plans list missing readiness gates instead of mutating bead state.

## Non-goals
- Do not perform semantic LLM review.
- Do not create or update beads from `--plan`.

## Parent/child shape
The parent closes when child implementation beads provide evidence.

## Dependency order
Route inspection lands before downstream tests rely on it.
"""

WEAK_PLAN = """# Weak Plan Fixture

## Goal
Make the authoring flow better.

## Notes
There are probably docs and scripts involved, but this draft does not yet say
what behavior should become true or how a fresh agent would prove it.
"""

FAKE_BR = """#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list" && "${2:-}" == "--json" ]]; then
  if [[ -f ".beads/list.exit" ]]; then
    rc="$(cat ".beads/list.exit")"
    if [[ -f ".beads/list.stderr" ]]; then
      cat ".beads/list.stderr" >&2
    fi
    if [[ -f ".beads/list.json" ]]; then
      cat ".beads/list.json"
    fi
    exit "$rc"
  fi
  cat ".beads/list.json"
  exit 0
fi

if [[ "${1:-}" == "dep" && "${2:-}" == "cycles" && "${3:-}" == "--json" ]]; then
  if [[ -f ".beads/cycles.exit" ]]; then
    rc="$(cat ".beads/cycles.exit")"
    if [[ -f ".beads/cycles.stderr" ]]; then
      cat ".beads/cycles.stderr" >&2
    fi
    if [[ -f ".beads/cycles.json" ]]; then
      cat ".beads/cycles.json"
    fi
    exit "$rc"
  fi
  if [[ -f ".beads/cycles.json" ]]; then
    cat ".beads/cycles.json"
  else
    printf '{"count":0,"cycles":[]}\n'
  fi
  exit 0
fi

echo "unexpected fake br invocation: $*" >&2
exit 99
"""


class EvalFailure(AssertionError):
    """Raised when a routing case does not match the truth table."""


def load_cases(path: Path) -> list[dict[str, Any]]:
    try:
        with path.open(encoding="utf-8") as handle:
            cases = json.load(handle)
    except json.JSONDecodeError as exc:
        raise EvalFailure(f"routing cases file is malformed JSON: {exc}") from exc
    if not isinstance(cases, list):
        raise EvalFailure("routing cases file must contain a JSON array")
    case_ids = [case.get("case_id") for case in cases]
    expected_ids = [f"A{i}" for i in range(1, 15)]
    if case_ids != expected_ids:
        raise EvalFailure(f"expected case ids {expected_ids}, got {case_ids}")
    return cases


def write_fake_br(bin_dir: Path) -> None:
    bin_dir.mkdir(parents=True, exist_ok=True)
    fake_br = bin_dir / "br"
    fake_br.write_text(FAKE_BR, encoding="utf-8")
    fake_br.chmod(fake_br.stat().st_mode | stat.S_IXUSR)


def write_plan(tmp_root: Path, plan_kind: str | None) -> Path | None:
    if plan_kind is None:
        return None
    plan_dir = tmp_root / "plans"
    plan_dir.mkdir(exist_ok=True)
    path = plan_dir / f"{plan_kind}-plan.md"
    if plan_kind == "ready":
        path.write_text(READY_PLAN, encoding="utf-8")
    elif plan_kind == "weak":
        path.write_text(WEAK_PLAN, encoding="utf-8")
    else:
        raise EvalFailure(f"unknown plan fixture kind: {plan_kind}")
    return path


def prepare_repo(tmp_root: Path, case: dict[str, Any]) -> Path:
    repo = tmp_root / "repos" / case["name"]
    repo.mkdir(parents=True)
    if case["repo_state"] == "no_beads":
        return repo
    if case["repo_state"] != "beads":
        raise EvalFailure(f"{case['case_id']} unknown repo_state: {case['repo_state']}")

    beads_dir = repo / ".beads"
    beads_dir.mkdir()
    issues = case.get("issues", [])
    (beads_dir / "list.json").write_text(json.dumps(issues) + "\n", encoding="utf-8")
    cycles = case.get("cycles", {"count": 0, "cycles": []})
    (beads_dir / "cycles.json").write_text(json.dumps(cycles) + "\n", encoding="utf-8")

    if "list_exit" in case:
        (beads_dir / "list.exit").write_text(str(case["list_exit"]) + "\n", encoding="utf-8")
    if "list_stderr" in case:
        (beads_dir / "list.stderr").write_text(case["list_stderr"] + "\n", encoding="utf-8")
    if "cycles_exit" in case:
        (beads_dir / "cycles.exit").write_text(str(case["cycles_exit"]) + "\n", encoding="utf-8")
    if "cycles_stderr" in case:
        (beads_dir / "cycles.stderr").write_text(case["cycles_stderr"] + "\n", encoding="utf-8")

    return repo


def run_case(tmp_root: Path, fake_bin: Path, case: dict[str, Any]) -> subprocess.CompletedProcess[str]:
    repo = prepare_repo(tmp_root, case)
    plan = write_plan(tmp_root, case.get("plan"))
    argv = ["bash", str(ROUTE_TOOL), "--repo", str(repo), "--json"]
    if plan is not None:
        argv.extend(["--plan", str(plan)])
    env = {"PATH": f"{fake_bin}{os.pathsep}/usr/local/bin:/usr/bin:/bin"}
    return subprocess.run(
        argv,
        env=env,
        text=True,
        capture_output=True,
        check=False,
        timeout=10,
    )


def assert_contains_all(haystack: str, needles: list[str], label: str, case_id: str) -> None:
    for needle in needles:
        if needle not in haystack:
            raise EvalFailure(f"{case_id}: missing {label} substring {needle!r} in {haystack!r}")


def assert_expected_subset(actual: dict[str, Any], expected: dict[str, Any], path: str, case_id: str) -> None:
    for key, expected_value in expected.items():
        if key not in actual:
            raise EvalFailure(f"{case_id}: missing {path}.{key}")
        actual_value = actual[key]
        if isinstance(expected_value, dict):
            if not isinstance(actual_value, dict):
                raise EvalFailure(f"{case_id}: expected {path}.{key} to be an object")
            assert_expected_subset(actual_value, expected_value, f"{path}.{key}", case_id)
        elif actual_value != expected_value:
            raise EvalFailure(
                f"{case_id}: {path}.{key} expected {expected_value!r}, got {actual_value!r}"
            )


def validate_success(case: dict[str, Any], proc: subprocess.CompletedProcess[str]) -> dict[str, Any]:
    case_id = case["case_id"]
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise EvalFailure(f"{case_id}: stdout was not JSON: {exc}\n{proc.stdout}") from exc

    expected = case["expected"]
    if payload.get("tool") != "bead_route.sh":
        raise EvalFailure(f"{case_id}: unexpected tool field {payload.get('tool')!r}")
    if payload.get("schema") != "better-beads-route-v1":
        raise EvalFailure(f"{case_id}: unexpected schema field {payload.get('schema')!r}")
    if payload.get("recommended_mode") != expected["recommended_mode"]:
        raise EvalFailure(
            f"{case_id}: recommended_mode expected {expected['recommended_mode']!r}, "
            f"got {payload.get('recommended_mode')!r}"
        )

    assert_expected_subset(payload["graph_state"], expected["graph_state"], "graph_state", case_id)
    assert_expected_subset(
        payload["plan_readiness"], expected["plan_readiness"], "plan_readiness", case_id
    )

    next_steps_text = "\n".join(payload.get("next_steps", []))
    assert_contains_all(
        next_steps_text, expected.get("next_steps_substrings", []), "next_steps", case_id
    )
    assert_contains_all(
        payload.get("reasoning", ""), expected.get("reasoning_substrings", []), "reasoning", case_id
    )

    return payload


def validate_case(case: dict[str, Any], proc: subprocess.CompletedProcess[str]) -> None:
    case_id = case["case_id"]
    expected = case["expected"]
    expected_exit = expected["exit_code"]
    if proc.returncode != expected_exit:
        raise EvalFailure(
            f"{case_id}: exit code expected {expected_exit}, got {proc.returncode}\n"
            f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        )

    if expected_exit == 0:
        validate_success(case, proc)
        return

    if proc.stdout != expected.get("stdout", proc.stdout):
        raise EvalFailure(f"{case_id}: unexpected stdout for failing case: {proc.stdout!r}")
    assert_contains_all(proc.stderr, expected.get("stderr_substrings", []), "stderr", case_id)


def run_all(cases_path: Path) -> int:
    cases = load_cases(cases_path)
    with tempfile.TemporaryDirectory(prefix="better-beads-routing-eval.") as tmp:
        tmp_root = Path(tmp)
        fake_bin = tmp_root / "bin"
        write_fake_br(fake_bin)

        passed = 0
        for case in cases:
            proc = run_case(tmp_root, fake_bin, case)
            validate_case(case, proc)
            passed += 1
            print(f"PASS {case['case_id']} {case['name']}")

    print(f"{passed} routing cases passed")
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cases",
        default=str(CASES_PATH),
        help="Path to routing case JSON. Defaults to evals/cases/routing_cases.json.",
    )
    args = parser.parse_args()

    if not ROUTE_TOOL.exists():
        print(f"routing tool not found: {ROUTE_TOOL}", file=sys.stderr)
        return 2

    cases_path = Path(args.cases)
    try:
        run_all(cases_path)
    except EvalFailure as exc:
        print(f"routing eval failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
