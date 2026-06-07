#!/usr/bin/env python3
"""Shared telemetry helpers for Better Beads scripts.

The helper is intentionally dependency-free and fail-soft. Callers can import
the Python API or invoke the CLI from shell scripts; telemetry write failures
return a warning and do not dictate the caller's primary exit code.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

SCHEMA_VERSION = "better-beads-telemetry-v1"


@dataclass(frozen=True)
class TelemetryWriteResult:
    ok: bool
    warning: str | None = None


def utc_timestamp() -> str:
    return datetime.now(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def repo_identity(repo: str | os.PathLike[str]) -> tuple[str, str]:
    resolved = Path(repo).expanduser().resolve()
    digest = hashlib.sha256(str(resolved).encode("utf-8")).hexdigest()[:16]
    return digest, resolved.name


def make_event(
    *,
    tool: str,
    tool_version: str,
    contract_version: str,
    mode: str,
    repo: str | os.PathLike[str],
    duration_ms: int,
    exit_code: int,
    verdict: str,
    finding_counts: dict[str, int] | None = None,
    run_id: str | None = None,
    timestamp: str | None = None,
) -> dict[str, object]:
    repo_id, repo_basename = repo_identity(repo)
    return {
        "run_id": run_id or uuid.uuid4().hex,
        "timestamp": timestamp or utc_timestamp(),
        "tool": tool,
        "tool_version": tool_version,
        "contract_version": contract_version,
        "mode": mode,
        "repo_id": repo_id,
        "repo_basename": repo_basename,
        "duration_ms": int(duration_ms),
        "exit_code": int(exit_code),
        "verdict": verdict,
        "finding_counts": finding_counts or {},
        "schema_version": SCHEMA_VERSION,
    }


def append_event(path: str | os.PathLike[str], event: dict[str, object]) -> TelemetryWriteResult:
    line = json.dumps(event, sort_keys=True, separators=(",", ":")) + "\n"
    flags = os.O_APPEND | os.O_CREAT | os.O_WRONLY
    try:
        fd = os.open(os.fspath(path), flags, 0o600)
        try:
            os.write(fd, line.encode("utf-8"))
        finally:
            os.close(fd)
    except Exception as exc:
        return TelemetryWriteResult(False, f"better-beads telemetry warning: {exc}")
    return TelemetryWriteResult(True)


def emit_event(path: str | os.PathLike[str], **event_kwargs: object) -> TelemetryWriteResult:
    return append_event(path, make_event(**event_kwargs))


def _parse_counts(raw: str) -> dict[str, int]:
    try:
        data = json.JSONDecoder().decode(raw)
    except json.JSONDecodeError as exc:
        raise argparse.ArgumentTypeError(f"finding counts must be JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise argparse.ArgumentTypeError("finding counts must be a JSON object")
    counts: dict[str, int] = {}
    for key, value in data.items():
        if not isinstance(key, str) or not isinstance(value, int):
            raise argparse.ArgumentTypeError("finding counts must map strings to integers")
        counts[key] = value
    return counts


def _event_contains_forbidden_content(event: dict[str, object], repo: Path) -> bool:
    text = json.dumps(event, sort_keys=True)
    return str(repo.resolve()) in text or "description" in text or "stdout" in text or "prompt" in text


def self_test() -> int:
    root = Path(tempfile.mkdtemp(prefix="better-beads-telemetry-self-test."))
    repo = root / "repo"
    repo.mkdir()
    out = root / "events.jsonl"
    event = make_event(
        tool="self-test",
        tool_version="1.0.0",
        contract_version="2026-06-07",
        mode="self-test",
        repo=repo,
        duration_ms=7,
        exit_code=0,
        verdict="pass",
        finding_counts={"errors": 0, "warnings": 0},
        run_id="self-test-run",
    )
    if _event_contains_forbidden_content(event, repo):
        print("self-test failed: event leaked forbidden content", file=sys.stderr)
        return 1
    result = append_event(out, event)
    if not result.ok:
        print(result.warning, file=sys.stderr)
        return 1
    try:
        loaded = json.JSONDecoder().decode(out.read_text(encoding="utf-8").splitlines()[0])
    except json.JSONDecodeError as exc:
        print(f"self-test failed: malformed appended event: {exc}", file=sys.stderr)
        return 1
    if loaded != event:
        print("self-test failed: appended event changed during serialization", file=sys.stderr)
        return 1
    print(f"self-test OK telemetry_path={out}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Append Better Beads telemetry JSONL events.")
    parser.add_argument("--self-test", action="store_true", help="run helper self-test")
    parser.add_argument("--emit", metavar="PATH", help="append one telemetry event to PATH")
    parser.add_argument("--tool")
    parser.add_argument("--tool-version")
    parser.add_argument("--contract-version")
    parser.add_argument("--mode")
    parser.add_argument("--repo", default=".")
    parser.add_argument("--duration-ms", type=int)
    parser.add_argument("--exit-code", type=int)
    parser.add_argument("--verdict")
    parser.add_argument("--finding-counts", default="{}", type=_parse_counts)
    parser.add_argument("--run-id")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.emit:
        parser.error("expected --self-test or --emit PATH")
    required = {
        "--tool": args.tool,
        "--tool-version": args.tool_version,
        "--contract-version": args.contract_version,
        "--mode": args.mode,
        "--duration-ms": args.duration_ms,
        "--exit-code": args.exit_code,
        "--verdict": args.verdict,
    }
    missing = [flag for flag, value in required.items() if value is None]
    if missing:
        parser.error(f"missing required arguments for --emit: {', '.join(missing)}")
    result = emit_event(
        args.emit,
        tool=args.tool,
        tool_version=args.tool_version,
        contract_version=args.contract_version,
        mode=args.mode,
        repo=args.repo,
        duration_ms=args.duration_ms,
        exit_code=args.exit_code,
        verdict=args.verdict,
        finding_counts=args.finding_counts,
        run_id=args.run_id,
    )
    if not result.ok and result.warning:
        print(result.warning, file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
