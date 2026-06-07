# Better Beads Portability

Better Beads is portable as a writing and review framework, but its robot
surfaces are intentionally Beads-first. Use `metadata.json` as the canonical
source for required tools and compatibility notes; `manifest.json` only
references those tool names.

## Portable Without br or bv

These parts remain useful in any tracker or planning environment:

- The behavioral bead model: outcome, success criteria, validation, non-goals,
  failure behavior, and current anchors.
- The quality rubric and failure modes in `references/QUALITY-RUBRIC.md` and
  `references/FAILURE-MODES.md`.
- The formatting guidance in `references/BEAD-FORMATTING.md`.
- The examples in `references/GOOD-BEAD-EXAMPLES.md`.
- The mode procedures as conceptual checklists for graph creation, plan
  improvement, graph polish, and closeout.
- The JSON schemas in `schemas/` as documentation of current Better Beads
  output contracts.

When using those materials outside Beads, translate "bead" to the local work
item type and keep the same execution-contract standard. Do not import the
scripts unless the target environment also provides the required tools from
`metadata.json`.

## Requires the Local Beads Toolchain

These surfaces require `br`, `bv`, or both, plus the shell or Python runtime
listed in `metadata.json`:

- `scripts/better-beads route --json`
- `scripts/better-beads authoring-triage --json`
- `scripts/better-beads triage --json`
- `scripts/better-beads frontier --json`
- `scripts/better-beads create-graph --dry-run PATH`
- `scripts/better-beads create-graph --apply PATH`
- `scripts/better-beads quality-gate --repo REPO --json`
- `scripts/better-beads gate-loop --repo REPO --operator-dispatch --json`
- `scripts/better-beads closeout-guard --repo REPO --json`
- Direct script equivalents under `scripts/`.

The scripts assume Beads graph semantics, Beads JSON output, and robot-mode BV
inspection. There is no adapter layer for GitHub Issues, Linear, Jira, or other
trackers.

## Schema Coverage Boundary

`manifest.json` marks stdout contracts with one of three statuses:

- `covered`: the contract has a schema in `schemas/` and is validated by
  `scripts/test_schemas.sh`.
- `deferred`: the surface is advertised, but no schema has shipped yet.
- `markdown`: the surface returns Markdown and is not modeled as JSON Schema.

Covered contracts are route, dispatch verdict, quality gate, and authoring
triage. Frontier, triage, create-graph, semantic-pack, closeout guard, and
capabilities contracts are deferred.

## Installation Notes

For a repo that already uses Beads, copy the whole `better-beads` skill
directory and keep the relative paths intact. Run:

```bash
python3 -m json.tool skills/better-beads/manifest.json >/dev/null
bash skills/better-beads/scripts/test_schemas.sh
```

For a repo that does not use Beads, copy only the references you need and treat
the scripts as non-portable examples. The authoring rules are portable; the
graph inspection, mutation, dispatch, and closeout commands are not.
