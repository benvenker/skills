#!/usr/bin/env python3
"""Deterministic quality gate for Beads descriptions.

This is intentionally conservative and dependency-free. It catches formatting,
missing-section, generic-validation, and obvious execution-contract problems.
It does not replace human/LLM semantic review.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

try:
    import signal
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except Exception:
    pass

REQUIRED_ANY = {
    "outcome": ["outcome", "goal"],
    "scope_boundary": ["non-goals", "non goals", "out of scope", "non-goal"],
    "success": ["success criteria", "acceptance", "acceptance criteria", "parent acceptance criteria"],
    "validation": ["validation", "verification", "validation commands"],
}

ADVISORY_ANY = {
    "closure": ["closure evidence", "close reason", "closing evidence"],
}

IMPLEMENTATION_REQUIRED_ANY = {
    "failure_behavior": ["failure modes", "failure behavior", "error cases"],
    "grounding": [
        "known anchors",
        "anchors",
        "surfaces",
        "key surfaces",
        "expected files",
        "files likely touched",
        "files / symbols",
        "symbols",
        "existing patterns",
        "current seams",
        "data contract",
        "data shapes",
        "contracts",
        "key fields",
    ],
}

PARENT_REQUIRED_ANY = {
    "children": ["child beads", "children", "intended order"],
    "closure_contract": ["closure contract", "implementation slicing note"],
}

GENERIC_VALIDATION_ONLY = {
    "pnpm build",
    "pnpm check",
    "pnpm lint",
    "npm run build",
    "npm build",
    "cargo test",
    "go test ./...",
    "pytest",
    "npm test",
    "pnpm test",
}

BAD_PHRASES = [
    "or document the exact alternate",
    "manual smoke is acceptable",
    "as needed",
    "etc.",
    "and stuff",
    "clean up",
    "polish ux",
    "add tests",
]

OVER_PRESCRIPTIVE_TEST_PATTERNS = [
    r"mock\s+[^\n]{0,80}\s+with\s+this\s+exact",
    r"write\s+a\s+test\s+that\s+[^\n]{0,120}\s+expects\s+this\s+exact",
]

@dataclass
class Finding:
    severity: str  # error | warning
    issue_id: str
    title: str
    code: str
    message: str


def norm_heading(line: str) -> str | None:
    m = re.match(r"^\s{0,3}#{1,6}\s+(.+?)\s*$", line)
    if not m:
        return None
    return re.sub(r"[^a-z0-9]+", " ", m.group(1).strip().lower()).strip()


def headings(desc: str) -> list[str]:
    return [h for line in desc.splitlines() if (h := norm_heading(line))]


def has_any_heading(hs: list[str], needles: list[str]) -> bool:
    return any(any(n in h for n in needles) for h in hs)


def is_parent(issue: dict[str, Any]) -> bool:
    labels = set(issue.get("labels") or [])
    return (
        "parent" in labels
        or issue.get("issue_type") in {"epic"}
        or "closure contract" in (issue.get("description") or "").lower()
        or "implementation slicing note" in (issue.get("description") or "").lower()
    )


def active(issue: dict[str, Any]) -> bool:
    return issue.get("status") not in {"closed", "archived"}


def load_issues(repo: Path) -> list[dict[str, Any]]:
    jsonl = repo / ".beads" / "issues.jsonl"
    if jsonl.exists():
        issues = []
        for line in jsonl.read_text().splitlines():
            line = line.strip()
            if line:
                issues.append(json.loads(line))
        return issues

    result = subprocess.run(
        ["br", "list", "--json"],
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"failed to load beads via br: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    return data.get("issues", data if isinstance(data, list) else [])


def changed_issue_ids(repo: Path, staged: bool = False, ref: str | None = None) -> set[str]:
    cmd = ["git", "diff", "--unified=0"]
    if staged:
        cmd.append("--cached")
    elif ref:
        cmd.append(ref)
    cmd.extend(["--", ".beads/issues.jsonl"])
    result = subprocess.run(
        cmd,
        cwd=repo,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"failed to inspect git diff: {result.stderr.strip()}")
    ids: set[str] = set()
    for line in result.stdout.splitlines():
        if not line.startswith("+") or line.startswith("+++"):
            continue
        payload = line[1:].strip()
        if not payload.startswith("{"):
            continue
        try:
            obj = json.loads(payload)
        except json.JSONDecodeError:
            continue
        if obj.get("id"):
            ids.add(obj["id"])
    return ids


def paragraph_lines(desc: str) -> list[str]:
    out = []
    in_fence = False
    for line in desc.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or not stripped:
            continue
        if stripped.startswith("#") or stripped.startswith("-") or re.match(r"^\d+\.\s", stripped):
            continue
        out.append(stripped)
    return out


def fenced_commands(desc: str) -> list[str]:
    commands: list[str] = []
    in_bash = False
    for line in desc.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            lang = stripped[3:].strip().lower()
            if in_bash:
                in_bash = False
            elif lang in {"bash", "sh", "shell", "zsh"}:
                in_bash = True
            continue
        if in_bash and stripped and not stripped.startswith("#"):
            commands.append(stripped)
    return commands


def inline_command_mentions(desc: str) -> list[str]:
    mentions = []
    for cmd in ["pnpm build", "pnpm check", "pnpm lint", "npm run build", "cargo test", "go test", "curl ", "node scripts/", "python scripts/"]:
        if cmd in desc:
            mentions.append(cmd)
    return mentions


def referenced_scripts(desc: str) -> list[str]:
    scripts = []
    for m in re.finditer(r"(?:node|python|python3|bun|pnpm\s+tsx)\s+((?:scripts|tools)/[^\s,`]+)", desc):
        scripts.append(m.group(1).rstrip("."))
    return scripts


def section_body(desc: str, heading_needles: list[str]) -> str:
    current: str | None = None
    chunks: list[str] = []
    capture = False
    for line in desc.splitlines():
        h = norm_heading(line)
        if h is not None:
            current = h
            capture = any(needle in h for needle in heading_needles)
            continue
        if capture:
            chunks.append(line)
    return "\n".join(chunks).strip()


def substantive_section(desc: str, heading_needles: list[str], min_words: int = 5) -> bool:
    body = section_body(desc, heading_needles)
    if not body:
        return False
    lowered = body.strip().lower()
    if lowered in {"todo", "tbd", "n/a", "none", "as needed"}:
        return False
    words = re.findall(r"[A-Za-z0-9_./:-]+", body)
    bullets = len(re.findall(r"(?m)^\s*(?:-|\d+\.)\s+", body))
    fenced = "```" in body
    # A compact section can be substantive if it has a few meaningful words,
    # multiple bullets, or a fenced contract/command block.
    return len(words) >= min_words or bullets >= 2 or fenced


def has_verification_detail(desc: str) -> bool:
    validation = section_body(desc, ["validation", "verification"])
    if not validation:
        return False
    if fenced_commands(validation):
        return True
    if inline_command_mentions(validation):
        return True
    if re.search(r"(?im)^\s*\d+\.\s+", validation) and re.search(r"(?i)(manual|browser|smoke|verify|confirm)", validation):
        return True
    if re.search(r"(?i)(add|update|write)\s+(targeted\s+)?(behavior|regression|contract|integration|unit|e2e)\s+tests?", validation):
        return True
    return False


def parent_section_names_child_ids(desc: str) -> bool:
    body = section_body(desc, ["child", "children", "intended order"])
    return bool(re.search(r"(?m)(`[^`]+`|\b[a-z0-9][a-z0-9_.-]{6,}\b)", body))


def lint_issue(issue: dict[str, Any], repo: Path, status_by_id: dict[str, str]) -> list[Finding]:
    desc = issue.get("description") or ""
    issue_id = issue.get("id", "<unknown>")
    title = issue.get("title", "<untitled>")
    hs = headings(desc)
    findings: list[Finding] = []

    def add(sev: str, code: str, msg: str) -> None:
        findings.append(Finding(sev, issue_id, title, code, msg))

    if not desc.strip():
        add("error", "empty-description", "description is empty")
        return findings

    parent_issue = is_parent(issue)
    if not parent_issue:
        if len(desc) > 3500:
            add("warning", "long-child-contract", "child bead is over 3500 chars; split-test first, then tighten if every section supports the same outcome")
        if len(hs) > 11:
            add("warning", "too-many-child-sections", f"child bead has {len(hs)} sections; merge overlapping sections for agent readability")
        if len(desc.split()) > 850:
            add("warning", "large-child", "child bead description is very large; consider split or tighten")
    elif len(desc) > 6500:
        add("warning", "large-parent", "parent bead is very large; move reusable context to child beads or external plan references")

    if len(hs) < 5:
        add("error", "too-few-sections", "description has too few markdown sections")

    for key, needles in REQUIRED_ANY.items():
        if not has_any_heading(hs, needles):
            add("error", f"missing-{key}", f"missing section like: {', '.join(needles[:2])}")
        elif key != "validation" and not substantive_section(desc, needles):
            add("error", f"thin-{key}", f"section exists but does not answer the contract question: {', '.join(needles[:2])}")

    for key, needles in ADVISORY_ANY.items():
        if not has_any_heading(hs, needles):
            add("warning", f"missing-{key}", f"missing recommended section like: {', '.join(needles[:2])}")
        elif not substantive_section(desc, needles):
            add("warning", f"thin-{key}", f"section exists but is too thin to guide closeout: {', '.join(needles[:2])}")

    if parent_issue:
        for key, needles in PARENT_REQUIRED_ANY.items():
            if not has_any_heading(hs, needles):
                add("error", f"missing-parent-{key}", f"parent bead missing required section like: {', '.join(needles[:2])}")
            elif not substantive_section(desc, needles):
                add("error", f"thin-parent-{key}", f"parent section exists but is too thin to guide closure/order: {', '.join(needles[:2])}")
        if has_any_heading(hs, ["child beads", "children", "intended order"]) and not parent_section_names_child_ids(desc):
            add("error", "parent-children-not-addressable", "parent children/order section should name concrete child bead ids or titles")
    else:
        for key, needles in IMPLEMENTATION_REQUIRED_ANY.items():
            if not has_any_heading(hs, needles):
                add("error", f"missing-impl-{key}", f"implementation bead missing section like: {', '.join(needles[:2])}")
            elif not substantive_section(desc, needles):
                add("error", f"thin-impl-{key}", f"implementation section exists but is too thin to guide execution: {', '.join(needles[:2])}")

    paras = paragraph_lines(desc)
    long_paras = [p for p in paras if len(p) > 180]
    if long_paras:
        add("warning", "prose-wall", f"{len(long_paras)} long prose line(s); use bullets for BV readability")

    very_long = [line for line in desc.splitlines() if len(line) > 240]
    if very_long:
        add("warning", "long-lines", f"{len(very_long)} line(s) over 240 chars; likely ugly in BV")

    if "## Data contract" in desc or "## Contracts" in desc:
        data_contract_section = re.search(r"## (?:Data contract|Contracts[^\n]*)\n(.+?)(?:\n## |\Z)", desc, flags=re.I | re.S)
        if data_contract_section:
            body = data_contract_section.group(1)
            if "```" not in body and body.count("\n-") < 2 and len(body.strip()) > 160:
                add("warning", "inline-data-contract", "data contract is prose/inline; prefer field bullets or fenced type block")

    commands = fenced_commands(desc)
    inline_mentions = inline_command_mentions(desc)
    if has_any_heading(hs, ["validation", "verification"]) and not has_verification_detail(desc):
        add("error", "no-verification-detail", "validation must name commands, behavior tests, or manual smoke observations")
    if inline_mentions and not commands:
        add("warning", "unfenced-commands", "commands appear inline; use fenced bash block")

    normalized_commands = {c.strip().rstrip(";") for c in commands}
    if normalized_commands and normalized_commands.issubset(GENERIC_VALIDATION_ONLY):
        add("warning", "generic-validation-only", "validation only uses generic build/test command; add specific smoke/test")

    if not commands and has_any_heading(hs, ["validation", "verification"]):
        add("warning", "no-fenced-validation", "validation section has no fenced bash commands")

    for phrase in BAD_PHRASES:
        if phrase in desc.lower():
            add("warning", "weak-phrase", f"weak/vague phrase present: {phrase!r}")

    for pattern in OVER_PRESCRIPTIVE_TEST_PATTERNS:
        if re.search(pattern, desc, flags=re.I):
            add("warning", "over-prescriptive-test", "bead should describe behavior to verify, not dictate exact test implementation")

    for script in referenced_scripts(desc):
        if not (repo / script).exists():
            add("warning", "referenced-script-missing", f"referenced script does not exist yet: {script}; bead should require creating it explicitly")

    labels = set(issue.get("labels") or [])
    dep_count = issue.get("dependency_count")
    deps = issue.get("dependencies") or []
    unresolved_deps = []
    for dep in deps:
        if not isinstance(dep, dict):
            continue
        dep_id = dep.get("id") or dep.get("depends_on_id")
        dep_status = dep.get("status") or status_by_id.get(dep_id or "")
        if dep_id and dep_status not in {"closed", "archived"}:
            unresolved_deps.append(dep_id)
    if "ready-for-agent" in labels and (
        (isinstance(dep_count, int) and dep_count > 0) or unresolved_deps
    ):
        add("warning", "ready-label-blocked", "label ready-for-agent is present but bead has unresolved dependencies")

    return findings


def render_markdown_report(repo: Path, issues: list[dict[str, Any]], findings: list[Finding], fail_on: str) -> str:
    errors = [f for f in findings if f.severity == "error"]
    warnings = [f for f in findings if f.severity == "warning"]
    by_id: dict[str, list[Finding]] = defaultdict(list)
    issue_by_id = {i.get("id", "<unknown>"): i for i in issues}
    for finding in findings:
        by_id[finding.issue_id].append(finding)

    def counts(issue_id: str) -> tuple[int, int]:
        fs = by_id.get(issue_id, [])
        return (
            sum(1 for f in fs if f.severity == "error"),
            sum(1 for f in fs if f.severity == "warning"),
        )

    def sort_key(issue_id: str) -> tuple[int, int, str]:
        err, warn = counts(issue_id)
        return (-err, -warn, issue_id)

    issue_ids_with_findings = sorted(by_id, key=sort_key)
    worst_ids = issue_ids_with_findings[:15]
    active_error_ids = [
        issue_id for issue_id in issue_ids_with_findings
        if counts(issue_id)[0] and active(issue_by_id.get(issue_id, {}))
    ]
    all_error_ids = [issue_id for issue_id in issue_ids_with_findings if counts(issue_id)[0]]
    rewrite_ids = active_error_ids or all_error_ids

    code_counts = Counter(f.code for f in findings)
    severity_code_counts = Counter((f.severity, f.code) for f in findings)

    if errors:
        verdict = "Not swarm-ready: hard execution-contract errors remain."
    elif warnings:
        verdict = "Hook-safe but not strict-clean: only advisory warnings remain."
    else:
        verdict = "Strict-clean for this scope."

    lines: list[str] = []
    lines.append("# Beads Quality Audit Report")
    lines.append("")
    lines.append(f"- Repo: `{repo}`")
    lines.append(f"- Beads checked: `{len(issues)}`")
    lines.append(f"- Errors: `{len(errors)}`")
    lines.append(f"- Warnings: `{len(warnings)}`")
    lines.append(f"- Fail-on mode: `{fail_on}`")
    lines.append(f"- Verdict: **{verdict}**")
    lines.append("")

    lines.append("## Top recurring failure modes")
    lines.append("")
    if code_counts:
        for code, count in code_counts.most_common(12):
            err_count = severity_code_counts.get(("error", code), 0)
            warn_count = severity_code_counts.get(("warning", code), 0)
            parts = []
            if err_count:
                parts.append(f"{err_count} error")
            if warn_count:
                parts.append(f"{warn_count} warning")
            lines.append(f"- `{code}`: {count} ({', '.join(parts)})")
    else:
        lines.append("- None.")
    lines.append("")

    lines.append("## Worst beads")
    lines.append("")
    if worst_ids:
        for issue_id in worst_ids:
            issue = issue_by_id.get(issue_id, {})
            err, warn = counts(issue_id)
            title = issue.get("title") or by_id[issue_id][0].title
            status = issue.get("status", "unknown")
            labels = ", ".join(issue.get("labels") or []) or "none"
            lines.append(f"### `{issue_id}` — {title}")
            lines.append(f"- Status: `{status}`")
            lines.append(f"- Labels: `{labels}`")
            lines.append(f"- Findings: `{err}` errors, `{warn}` warnings")
            lines.append("- What sucked:")
            for finding in by_id[issue_id]:
                lines.append(f"  - **{finding.severity} / `{finding.code}`**: {finding.message}")
            lines.append("")
    else:
        lines.append("No findings.")
        lines.append("")

    lines.append("## Suggested rewrite order")
    lines.append("")
    if rewrite_ids:
        for index, issue_id in enumerate(rewrite_ids[:25], start=1):
            issue = issue_by_id.get(issue_id, {})
            err, warn = counts(issue_id)
            status = issue.get("status", "unknown")
            title = issue.get("title") or by_id[issue_id][0].title
            lines.append(f"{index}. `{issue_id}` — {title} (`{status}`, {err} errors / {warn} warnings)")
    else:
        lines.append("No hard-error rewrite order needed.")
    lines.append("")

    lines.append("## Rewrite guidance")
    lines.append("")
    lines.append("For each hard-error bead, make the smallest rewrite that answers the Strong Agent Question Test:")
    lines.append("")
    lines.append("1. What should become true?")
    lines.append("2. How will we know it worked?")
    lines.append("3. What should the agent not do or invent?")
    lines.append("")
    lines.append("Prefer adding or tightening outcome, success criteria, verification, non-goals, failure behavior, grounding anchors/surfaces, and closure evidence. Do not pad with template prose just to satisfy headings.")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint Beads for execution-contract quality")
    parser.add_argument("--repo", default=os.getcwd(), help="repo root containing .beads")
    parser.add_argument("--json", action="store_true", help="emit JSON")
    parser.add_argument("--report", choices=["markdown"], help="emit human-readable audit report")
    parser.add_argument("--fail-on", choices=["error", "warning", "never"], default="error")
    parser.add_argument("--strict", action="store_true", help="alias for --fail-on warning")
    parser.add_argument("--include-closed", action="store_true")
    parser.add_argument("--id", action="append", default=[], help="lint only this bead id; repeatable")
    parser.add_argument("--label", action="append", default=[], help="lint only beads with this label; repeatable")
    parser.add_argument("--changed-only", action="store_true", help="lint only beads changed in git diff")
    parser.add_argument("--staged", action="store_true", help="with --changed-only, inspect staged diff")
    parser.add_argument("--changed-since", help="with --changed-only, inspect diff since ref")
    args = parser.parse_args()

    if args.strict:
        args.fail_on = "warning"

    repo = Path(args.repo).resolve()
    all_issues = load_issues(repo)
    status_by_id = {i.get("id"): i.get("status") for i in all_issues if i.get("id")}
    issues = list(all_issues)
    # Full-graph checks default to active work. Changed-only checks include closed
    # beads because closing a bead changes .beads/issues.jsonl and the close packet
    # should still be readable, bounded, and evidence-rich before commit.
    if not args.include_closed and not args.changed_only and not args.id:
        issues = [i for i in issues if active(i)]

    if args.id:
        wanted = set(args.id)
        issues = [i for i in issues if i.get("id") in wanted]

    if args.label:
        wanted_labels = set(args.label)
        issues = [i for i in issues if wanted_labels.issubset(set(i.get("labels") or []))]

    if args.changed_only:
        ids = changed_issue_ids(repo, staged=args.staged, ref=args.changed_since)
        issues = [i for i in issues if i.get("id") in ids]

    findings: list[Finding] = []
    for issue in issues:
        findings.extend(lint_issue(issue, repo, status_by_id))

    errors = [f for f in findings if f.severity == "error"]
    warnings = [f for f in findings if f.severity == "warning"]

    if args.report == "markdown":
        print(render_markdown_report(repo, issues, findings, args.fail_on))
    elif args.json:
        print(json.dumps({
            "repo": str(repo),
            "issue_count": len(issues),
            "error_count": len(errors),
            "warning_count": len(warnings),
            "fail_on": args.fail_on,
            "findings": [asdict(f) for f in findings],
        }, indent=2))
    else:
        print(f"Bead quality gate: {len(issues)} active issue(s), {len(errors)} error(s), {len(warnings)} warning(s)")
        for f in findings:
            print(f"[{f.severity.upper()}] {f.issue_id} {f.code}: {f.message}")
            print(f"        {f.title}")

    if args.fail_on == "never":
        return 0
    if args.fail_on == "warning" and findings:
        return 1
    if args.fail_on == "error" and errors:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
