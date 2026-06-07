# Good Bead Examples
These examples are copied from a high-quality Poolside Studio Beads graph so this skill is portable. Use them as taste references, not as domain templates.
Read at least one parent example and one child example before creating or polishing beads.

For copy-paste `br` commands that create this parent/child shape, see
`GRAPH-CONSTRUCTION-COOKBOOK.md`.

---

## bd-1mu: PR 4A: Extract reusable file-size policy helpers
**Why this is a good example:** Strong parent/PR-slice bead: preserves rationale, names child ordering, defines closure semantics, and keeps PR4A focused on reusable file-size policy helpers rather than the whole diagnostics product.

- Type: `feature`
- Priority: `1`
- Status in source graph: `closed`
- Labels: `feedback-harness, file-size, pr-slice`
- Dependency/child references in source graph:
  - `bd-3gc` ↔ `BD-1MU.3: align file-size doctor with shared policy helper`
  - `bd-3vn` ↔ `BD-1MU.2: lock file-size policy helper parity coverage`
  - `bd-2p3` ↔ `BD-1MU.1: extract shared file-size policy core for structural tests`
  - `bd-1m7` ↔ `PR 3: Doctor command scaffold for contextual remediation`

### Description

## Background and rationale
The current file-size ratchet lives in Vitest structural tests. The plan requires a dependency-free file-size diagnostic lane, but PR 4 must be split by default to keep reviewable. PR 4A extracts reusable policy helpers while preserving existing Vitest behavior.

Docs, plans, and research files are intentionally allowed to be long and should not be governed by normal source/test file-size ratchets.

PR3 also left a temporary duplicate of file-size policy data in `scripts/lib/feedback/doctors.mjs` with a comment saying it should stay PR3-local until this PR4A helper extraction. This parent therefore covers both the structural-test extraction and the doctor alignment needed to remove that duplicate, while still avoiding PR4B's standalone diagnostics CLI.

## Implementation slicing note
This parent is a roll-up/closure contract, not a single implementation PR. Do not close `bd-1mu` until every direct child below is closed or explicitly closed as unnecessary with evidence. The parent depends directly on each child so Beads/BV show the roll-up closure gate.

Direct children:
- `bd-2p3` / BD-1MU.1: extract shared file-size policy core for structural tests.
- `bd-3vn` / BD-1MU.2: lock file-size policy helper parity coverage.
- `bd-3gc` / BD-1MU.3: align file-size doctor with shared policy helper.

Intended technical order: `bd-2p3` -> `bd-3vn` -> `bd-3gc`.

The only prior useful implementation material is parked on `origin/wip/non-bd-1ey-doctor-file-size`. Inspect or cherry-pick selectively from that WIP branch, especially `scripts/lib/harness/file-size-policy.mjs`, `tests/electron/feedback-file-size-policy.test.ts`, and the `tests/structural/architecture.test.ts` extraction. Do not merge or base on that branch wholesale because it mixes older PR3 scaffold work with PR4A material.

## Scope
- Move file-size policy data/logic into reusable helpers while preserving current structural-test behavior.
- Preserve existing semantics for generated artifact exceptions, production-file baseline growth, test-file tolerance, unbaselined large code/test files, generated-pattern growth exemptions, and explicit hard-limit exemptions.
- Preserve `docs/`, `plans/`, and `research/` exclusion from normal source/test file-size ratchets.
- Add parity tests proving reusable policy behavior matches current structural behavior.
- Remove PR3-local doctor policy duplication by wiring the file-size doctor to the shared helper after helper behavior is locked.

## Non-goals
- No standalone file-size diagnostics CLI; that is `bd-4pf` / PR4B.
- No GitHub Actions workflow.
- No baseline policy change unless forced by mechanical extraction.
- No contextual split advice in policy helpers.
- No normal source/test ratchet for docs/plans/research files.
- No baseline move to config unless handled by optional `bd-ihn`.

## Acceptance criteria for closing this parent
- All direct child beads (`bd-2p3`, `bd-3vn`, `bd-3gc`) are closed or explicitly closed as unnecessary with evidence.
- `pnpm check:harness` still enforces the same file-size behavior through Vitest.
- File-size policy helpers are reusable by a later zero-dependency CLI.
- Parity tests cover docs/plans/research exclusion and existing source/test thresholds/tolerances.
- No generated-artifact exception is broadened without explicit tests.
- Doctor file-size facts no longer duplicate separate thresholds/baselines and remain aligned with the shared helper.
- PR4A remains separate from PR4B diagnostics CLI and PR4C optional config movement.

## Validation commands
- targeted tests for file-size policy helpers/parity
- targeted tests for file-size doctor integration
- `pnpm harness doctor file-size src/features/chat/components/chat-input.svelte`
- `pnpm harness doctor POOL_FILE_SIZE_GROWTH src/features/chat/components/chat-input.svelte`
- `pnpm check:harness`
- `pnpm lint`
- `pnpm verify:quick`

## Expected files likely touched across the full lane
- `tests/structural/architecture.test.ts`
- `scripts/lib/harness/file-size-policy.mjs`
- `tests/electron/feedback-file-size-policy.test.ts`
- `scripts/lib/feedback/doctors.mjs`
- `tests/electron/feedback-doctors.test.ts`

## Blocking prerequisites
- PR 3 doctor scaffold (`bd-1m7`), already linked via dependency and currently closed.

## Parallelization notes
- Treat the children as a stacked sequence by default because each later child depends on the helper contract from the previous child.
- Do not combine this with PR4B, PR4C, or micro-CI wiring.

---

## bd-4pf: PR 4B: Add zero-dependency file-size diagnostics CLI
**Why this is a good example:** Strong follow-on parent/PR-slice bead: depends on bd-1mu, has concrete child ordering, and scopes a diagnostics CLI without drifting into unrelated policy extraction.

- Type: `feature`
- Priority: `1`
- Status in source graph: `closed`
- Labels: `bd-4pf, feedback-harness, file-size, pr-slice, pr4b`
- Dependency/child references in source graph:
  - `bd-1rd` ↔ `BD-4PF.3: emit GitHub annotations and lock PR4B parity`
  - `bd-3bw` ↔ `BD-4PF.2: add file-size diagnostics CLI with terminal and JSON output`
  - `bd-21v` ↔ `BD-4PF.1: model file-size diagnostics from shared policy`
  - `bd-1mu` ↔ `PR 4A: Extract reusable file-size policy helpers`

### Description

## Background and rationale
Fast deterministic feedback needs a Node-only diagnostic check that does not require `pnpm install`, Vitest, Playwright, or network access. This PR turns the extracted file-size policy into a CLI that emits stable diagnostics and doctor commands.

The checker must emit codes/facts/doctor pointers, not bespoke refactor plans.

## Implementation slicing note
This parent is the PR4B roll-up/closure contract, not a single implementation task. Do not close `bd-4pf` until every direct child below is closed or explicitly closed as unnecessary with evidence.

Direct children:
- `bd-21v` / BD-4PF.1: model file-size diagnostics from shared policy.
- `bd-3bw` / BD-4PF.2: add file-size diagnostics CLI with terminal and JSON output.
- `bd-1rd` / BD-4PF.3: emit GitHub annotations and lock PR4B parity.

Intended technical order: `bd-21v` -> `bd-3bw` -> `bd-1rd`.

`bd-4pf` depends directly on all three children so Beads/BV show the roll-up closure gate. `bd-4pf` also remains under broader epic `bd-11t`; do not bypass this parent when closing PR4B work.

## Scope
- Add `scripts/harness/file-size-diagnostics.mjs` or equivalent zero-dependency Node CLI.
- Support terminal, JSON, and GitHub annotation output modes.
- Emit diagnostic codes such as `POOL_FILE_SIZE_LIMIT_EXCEEDED`, `POOL_FILE_SIZE_GROWTH`, and `POOL_FILE_SIZE_UNBASELINED_LARGE_FILE`.
- Include `pnpm harness doctor file-size <file>` pointers in diagnostics.
- Keep current file-size semantics from PR 4A.
- Ensure `docs/` remains outside the normal source/test ratchet.

## Non-goals
- No GitHub Actions workflow yet; PR5 consumes this CLI.
- No baseline move to config unless handled by PR 4C.
- No LLM calls.
- No context-specific split recommendation in checker output.

## Acceptance criteria for closing this parent
- All direct child beads (`bd-21v`, `bd-3bw`, `bd-1rd`) are closed or explicitly closed as unnecessary with evidence.
- CLI can run after checkout with Node built-ins only.
- CLI emits terminal, JSON, and GitHub annotation output deterministically.
- File-size failures include stable diagnostic codes and doctor commands.
- Tests prove CLI output agrees with reusable policy behavior.
- `pnpm check:harness` remains green and semantically unchanged.

## Validation commands
- `node scripts/harness/file-size-diagnostics.mjs --format=json` or final equivalent
- `node scripts/harness/file-size-diagnostics.mjs --format=github` or final equivalent
- targeted CLI/policy tests
- `pnpm check:harness`
- `pnpm lint`
- `pnpm verify:quick`

## Expected files likely touched across the full PR4B lane
- `scripts/lib/harness/file-size-diagnostics.mjs` or equivalent helper module
- `scripts/harness/file-size-diagnostics.mjs`
- `scripts/lib/harness/file-size-policy.mjs` only for tiny reusable exports if required
- focused tests for diagnostics core and CLI formats
- `package.json` if adding a local alias

## Blocking prerequisites
- PR 4A reusable file-size policy helpers (`bd-1mu`), already linked and closed.

## Parallelization notes
- Treat the children as a stacked sequence by default because each later surface depends on the previous contract.
- Do not run in parallel with PR 4C.
- PR 5 can start after `bd-4pf` closes; PR 4C remains optional and should not block PR 5 unless implementation proves baseline config is required.

---

## bd-vm1: BD-1M7.1: add harness doctor CLI dispatcher and registry contract
**Why this is a good example:** Strong child implementation bead: one concrete outcome, parent/source-of-truth context, expected files, non-goals, and exact validation.

- Type: `feature`
- Priority: `2`
- Status in source graph: `closed`
- Labels: `bd-1m7, doctor, feedback-harness, pr3`
- Dependency/child references in source graph:
  - `bd-13e` ↔ `BD-13E: diagnostic schema and shared feedback core lane`

### Description

## Parent and source of truth
Child of `bd-1m7` / PR 3: Doctor command scaffold for contextual remediation.

This is the first PR-sized slice of the doctor lane. It establishes the command/registry surface that later PR3 children fill in, while staying strictly separate from PR2 (`bd-1ey`) and PR4A (`bd-1mu`).

## Background and rationale
Low-level feedback should point humans and agents to deterministic doctor commands. Before any file-size remediation details exist, the repo needs a stable non-mutating command shape and a tiny doctor registry contract so future diagnostics can say:

```text
pnpm harness doctor file-size <file>
```

The preserved branch `origin/wip/non-bd-1ey-doctor-file-size` contains useful prior work for this area, but it also includes PR4A reusable file-size policy extraction. For this child, inspect or cherry-pick only the CLI/registry pieces; do not merge the branch wholesale.

## Scope
- Add the `pnpm harness doctor ...` package-script shape and Node entrypoint.
- Add a doctor registry/dispatcher module under the feedback harness code, e.g. `scripts/lib/feedback/doctors.mjs`.
- Define the exported API future slices can reuse: available domains, `runDoctor(...)`, deterministic usage text, and structured `{ ok, text, facts }` results.
- Add the `file-size` doctor domain as a shell with clear argument/path validation and usage errors, but do not yet implement final status classification or remediation prose in this slice.
- Handle unknown commands/domains deterministically, including inherited-object keys such as `__proto__`, `constructor`, and `toString`.

## Non-goals
- No automatic LLM invocation.
- No file edits or mutation of target files.
- No zero-dependency file-size diagnostics CLI; that belongs to `bd-4pf` after PR4A.
- No reusable file-size policy helper extraction or `tests/structural/architecture.test.ts` rewrite; that belongs to `bd-1mu`.
- No JSON/GitHub annotation feedback output.

## Acceptance criteria
- `pnpm harness doctor` reaches the new entrypoint and reports unknown/missing commands clearly.
- `runDoctor("file-size", ...)` exists and returns structured results without throwing on missing arguments or missing files.
- Unknown domains list the available domains and fail closed.
- The registry uses own-property checks, not inherited property lookup.
- Tests cover CLI dispatch, unknown command/domain behavior, missing file argument handling, and the inherited-key guard.

## Expected files likely touched
- `package.json`
- `scripts/harness-doctor.mjs`
- `scripts/lib/feedback/doctors.mjs`
- `tests/electron/feedback-doctors.test.ts` or a similarly focused test file

## Validation commands
- targeted doctor registry/CLI tests
- `pnpm check:harness`
- `pnpm lint`
- `pnpm verify:quick` before parent closure

---

## bd-21v: BD-4PF.1: model file-size diagnostics from shared policy
**Why this is a good example:** Strong foundation child bead: models data from shared policy before CLI/UI work and clearly explains dependency/order/PR sizing.

- Type: `feature`
- Priority: `1`
- Status in source graph: `closed`
- Labels: `bd-4pf, feedback-harness, file-size, pr-slice, pr4b`
- Dependency/child references in source graph:
  - `bd-1mu` ↔ `PR 4A: Extract reusable file-size policy helpers`

### Description

## Background and rationale
`bd-4pf` needs a zero-dependency file-size diagnostics CLI, but implementation should not start by mixing policy semantics, argv parsing, and format rendering. This child establishes the reusable diagnostic model that later CLI/output slices can consume.

## Scope
- Add a zero-dependency file-size diagnostics helper module, likely `scripts/lib/harness/file-size-diagnostics.mjs`.
- Convert PR4A policy outputs into stable diagnostics with `code`, `severity`, `message`, `file`, `facts`, `source`, and `doctor` data.
- Emit these diagnostic codes from shared policy facts, without duplicating thresholds or baselines:
  - `POOL_FILE_SIZE_LIMIT_EXCEEDED`
  - `POOL_FILE_SIZE_GROWTH`
  - `POOL_FILE_SIZE_UNBASELINED_LARGE_FILE`
- Include deterministic doctor pointers such as `pnpm harness doctor file-size <file>` in each actionable diagnostic.
- Preserve current PR4A semantics for docs/plans/research exclusion, source hard limits, generated artifacts, production baseline growth, test-file growth tolerance, and unbaselined large files.

## Non-goals
- No executable CLI or argv parser.
- No terminal, JSON, or GitHub annotation renderer.
- No GitHub Actions workflow.
- No baseline move to config.
- No LLM calls or context-specific split recommendations.

## Likely files
- `scripts/lib/harness/file-size-diagnostics.mjs`
- `scripts/lib/harness/file-size-policy.mjs` only if a tiny export is needed
- `tests/electron/feedback-file-size-diagnostics.test.ts`

## Acceptance criteria
- Diagnostic helper returns deterministic diagnostics for over-limit source files, baseline growth, and unbaselined large source/test files.
- Diagnostics include stable codes, severity, facts, source metadata, and doctor commands.
- Tests prove docs/plans/research paths, generated growth exemptions, and hard-limit exceptions behave exactly like the PR4A policy helper.
- The helper uses only Node built-ins and local policy helpers; no Vitest/PNPM/runtime dependency is required by the production helper.
- No current `pnpm check:harness` semantics change.

## Validation commands
- `pnpm test -- tests/electron/feedback-file-size-diagnostics.test.ts`
- `pnpm check:harness`
- `pnpm lint`

## Dependency notes / ordering
- Depends on closed PR4A parent `bd-1mu` because it consumes the shared policy helper.
- Must land before the executable CLI/output slices.
- `bd-4pf` depends on this child as a direct roll-up gate.

## PR sizing
Can be its own PR in the PR4B stack. It should be a small policy/diagnostic contract PR, roughly 1-3 files.

---

## bd-11t: Epic: Agent-agnostic feedback harness lane
**Why this is a good example:** Strong epic/closure bead: captures strategic decisions and coordinates a lane without pretending the epic itself is implementation work.

- Type: `epic`
- Priority: `1`
- Status in source graph: `open`
- Labels: `agent-agnostic, epic, feedback-harness`
- Dependency/child references in source graph:
  - `bd-36d` ↔ `PR 6: Manual changed/staged feedback CLI`
  - `bd-4pf` ↔ `PR 4B: Add zero-dependency file-size diagnostics CLI`
  - `bd-1mu` ↔ `PR 4A: Extract reusable file-size policy helpers`
  - `bd-1ey` ↔ `PR 2: Command registry and non-executable feedback config`
  - `bd-13e` ↔ `BD-13E: diagnostic schema and shared feedback core lane`
  - `bd-38z` ↔ `PR 10: Authority and anti-gaming hardening`
  - `bd-14l` ↔ `PR 9: Claude adapter cleanup and backward compatibility`
  - `bd-2p8` ↔ `PR 8: Codex end-of-turn feedback adapter`
  - `bd-3p1` ↔ `PR 7: Local Git hook wiring for advisory staged feedback`
  - `bd-34l` ↔ `PR 5: Fast harness micro-CI workflow`
  - `bd-1m7` ↔ `PR 3: Doctor command scaffold for contextual remediation`
  - `bd-ihn` ↔ `PR 4C: Optional file-size baseline config move`
  - `bd-wiq` ↔ `Optional: CODEOWNERS and branch-protection hardening for feedback harness`

### Description

## Background and rationale
Build the agent-agnostic feedback harness lane described in `docs/plans/agent-agnostic-feedback-harness.md` as a lean, PR-sliced implementation graph.

The product is a workspace-scoped feedback substrate that emits stable diagnostics, writes agent-readable artifacts, and can be triggered by local hooks, manual CLI commands, micro-CI, full CI, and runtime-specific adapters. It is not a Claude-only hook system.

Key lane decisions to preserve:
- Runtime-specific hooks are adapters over a shared feedback core.
- CI/local hooks emit diagnostic codes, facts, and doctor commands, not bespoke refactor plans.
- Contextual remediation belongs in doctor commands, skills, or prompts.
- Local hooks are convenience; CI/protected PR workflow is authority.
- Feedback config selects approved command IDs only and never arbitrary shell commands.
- Registry safety requires materialized argv-token policy tests, not just self-reported metadata.
- Policy enforcement becomes authoritative as soon as registry/config exists.
- Docs/plans/research files can be long and are excluded from normal source/test file-size ratchets.
- PR 4 file-size work is split by default into PR 4A / 4B / 4C.
- Pre-commit feedback remains advisory unless staged-snapshot semantics make blocking safe.
- Codex starts with end-of-turn/Stop-style feedback, not fake post-edit parity.
- Claude post-edit remains useful but optional/advisory.

## Scope
Coordinate these implementation PR slices:
- PR 1 diagnostic schema/shared core
- PR 2 registry/policy/config
- PR 3 doctor scaffold
- PR 4A file-size policy extraction
- PR 4B file-size diagnostics CLI
- PR 4C optional baseline config move
- PR 5 fast harness micro-CI
- PR 6 manual changed/staged feedback CLI
- PR 7 local Git hook wiring
- PR 8 Codex end-of-turn adapter
- PR 9 Claude adapter cleanup
- PR 10 authority/docs hardening
- optional CODEOWNERS/branch-protection hardening

## Non-goals
- No implementation work in this epic bead itself.
- No source or docs edits as part of bead creation.
- Do not explode the plan into one bead per checklist item.
- Do not treat local hooks as the security boundary.

## Acceptance criteria
- All required implementation PR-slice beads are completed or explicitly closed as unnecessary with evidence.
- Dependency graph remains acyclic.
- Core lane can ship without optional/deferred CODEOWNERS hardening if repo policy defers it.

## Validation commands
- `br dep cycles --json`
- `br ready --json`
- `br sync --flush-only`

## Expected files likely touched
- None directly by this epic.
- Child beads list expected implementation files.

## Blocking prerequisites
- Depends on all implementation PR-slice beads in this lane as completion gates.

## Parallelization notes
- The first ready implementation bead should be PR 1.
- After PR 1, PR 2 and PR 3 may proceed in parallel if their file touches do not conflict.
- Adapter PRs can run in parallel after PR 6 if file ownership is coordinated.
