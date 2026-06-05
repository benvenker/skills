# Bead Formatting for BV and Terminal Readability

Good bead content is not enough. Beads must also be pleasant to scan in `bv`, `br show`, tmux panes, and narrow agent terminals.

The goal is **dense but skimmable execution packets**, not prose walls.

## Core rule

Prefer short sections with bullet lists over paragraphs.

If a line contains more than two concepts, split it.
If a paragraph wraps more than twice in a terminal, rewrite it as bullets.

## Recommended section order

For child implementation beads, use this order as a starting point. Omit sections that do not add behaviorally useful information.

```md
## Outcome
One sentence: what behavior or system truth becomes true.

## Parent / source of truth
- Parent: <parent title or id>
- Preserves: <key decision>

## Success criteria
- Observable behavior or contract.
- Observable behavior or contract.

## Scope / non-goals
- Do: <included work>.
- Do not: <adjacent work or unsafe side effect>.

## Failure behavior
- Error case: required behavior.
- Partial success case: required behavior.

## Known anchors / surfaces
- User-visible surface: <where behavior appears>.
- Data/API contract or key fields: <if relevant>.
- Current likely files/patterns: <starting points, not an edit script>.

## Validation
```bash
command-one
command-two
```
Expected: short description of passing output.

Behavior-test intent: add/update targeted tests for <behavior>; do not encode the exact test implementation in the bead.

## Dependency / parallel notes
- Depends on: <id/title>
- Unblocks: <id/title>
- Single-owner risk: <file/surface>

## Closure evidence
Close with: commands run, result, commit/artifact path, and follow-up beads.
```

For parent / PR-slice beads, use:

```md
## Outcome
The full user/product/architecture outcome of the lane.

## Background
- Key rationale.
- Final decisions to preserve.

## Closure contract
Do not close until child beads are closed or explicitly closed as unnecessary with evidence.

## Children / intended order
1. `<child>` — why it comes first.
2. `<child>` — why it follows.

## Scope
- Included lane work.

## Non-goals
- Excluded work.

## Parent acceptance criteria
- Full-lane observable success condition.

## Validation
```bash
br dep cycles --json
bv --robot-insights
bv --robot-plan
<project-specific verification>
```

## Parallelization notes
- Which tracks can run concurrently.
- Which files/surfaces are single-owner.
```

## BV-friendly style rules

### Titles

- Keep titles under ~80 characters when possible.
- Use a concrete verb and object.
- Prefer PR/lane prefixes only when they help ordering.

Good:

```text
Add create-from-chat API with transcript compiler
Model file-size diagnostics from shared policy
```

Bad:

```text
Implement all remaining backend integration work for workflow generation system
```

### Paragraphs

Avoid:

```md
The service accepts prompt/model/workflow id/display name/overwrite inputs, writes source only under .smithers/workflows/, render-verifies without executing workflow tasks, and returns structured attempts/errors.
```

Prefer:

```md
## Acceptance criteria
- Accepts prompt, model, workflow id, display name, and overwrite inputs.
- Writes source only under `.smithers/workflows/`.
- Render-verifies without executing workflow tasks.
- Returns structured attempts and errors.
```

### Symbol lists

Avoid long inline lists:

```md
Port createWorkflowFromPrompt, authorWorkflowSource, extractWorkflowSource, generatedWorkflowSourceValidationIssues, workflowSourceValidationFeedback, resolveWorkflowId, normalizeWorkflowId, normalizeOpenRouterModelId, and atomicWriteFile.
```

Prefer grouped bullets:

```md
## Expected files / symbols
- `reference-repos/custom-harness/src/server.ts`
  - `createWorkflowFromPrompt`
  - `authorWorkflowSource`
  - `extractWorkflowSource`
  - `generatedWorkflowSourceValidationIssues`
  - `workflowSourceValidationFeedback`
  - `resolveWorkflowId`
  - `normalizeWorkflowId`
  - `normalizeOpenRouterModelId`
  - `atomicWriteFile`
```

### Data contracts

Avoid one-line pseudo-types. They wrap badly.

Prefer a compact fenced block or field bullets:

```ts
type CreateFromChatResult = {
  ok: boolean;
  workflowId?: string;
  workflowPath?: string;
  verified?: boolean;
  sourceSaved?: boolean;
  attempts: AuthoringAttempt[];
  error?: string;
};
```

or:

```md
## Contracts / data shapes
- `ok`: whether the operation completed without fatal error.
- `workflowId`: normalized workflow id.
- `workflowPath`: path under `.smithers/workflows/`.
- `verified`: render verification result.
- `attempts`: generation/validation/repair/verify events.
```

### Commands

Use fenced bash blocks. One command per line.

Good:

```bash
pnpm build
node scripts/smoke-workflow-authoring.mjs
```

Avoid inline command paragraphs.

### Known anchors / surfaces

Use file/symbol lists as search anchors, not as brittle instructions. Agents should verify current code owners before editing.

Good:

```md
## Known anchors / surfaces
- User-visible surface: Chat Node composer action.
- API/data contract: create-from-chat request/response and verification status.
- Current likely files/patterns:
  - `src/server/workflowAuthoring.ts`
    - `createWorkflowFromPrompt`
    - `renderVerifyWorkflowSource`
  - `scripts/smoke-workflow-authoring.mjs`
```

### Failure modes

Use bullets with required behavior.

Good:

```md
## Failure modes
- Missing `OPENROUTER_API_KEY`: return a typed configuration error.
- Invalid workflow id: reject before writing files.
- Verification fails after source save: return `sourceSaved: true`, `verified: false`.
```

## Length guidance

These are guidelines, not strict limits:

- Parent bead: 60–140 lines.
- Child bead: 45–90 lines for normal work; 90–110 lines only for high-risk integration work.
- Child bead: usually under ~3500 characters and 6–10 sections.
- Section body: 1–7 bullets.
- Bullet: usually under 120 characters.
- Code/type block: usually under 30 lines.

Length is justified when it prevents a concrete failure: scope creep, wrong file/symbol, unsafe side effect, missing state transition, unclear validation, or bad parallelization. Length is not justified when sections repeat each other. If a child bead needs much more than this, it may be a mega-bead, should be split, or should move reusable rationale to the parent/design doc.

## Reviewable atomicity

Formatting and sizing are connected. If a child bead is likely to produce a large PR because it combines contract design, service implementation, access control, routing, and parity/docs, split it by behavior before polishing prose.

A child bead should describe one independently testable functional behavior, not a broad surface bucket, checklist bucket, or detail bucket. A broad noun like “dashboard” usually belongs to a parent/epic closure contract; a behavior like “filtered load graphs render correct series and empty/error states” is closer to child-sized.

When operator-dispatch writes `split-review-required.md`, write the repair evidence in the bead or close reason so another agent can act without the original conversation:

- classification: keep, split, convert-to-parent, merge, defer, or delete/close unnecessary;
- reason: why the current child is one behavior or how it was split;
- graph updates: dependency edges, parent order, labels, and ready frontier;
- verification: compact tests/smokes that prove each resulting child behavior.

Do not solve oversized PRs by weakening test requirements. Instead, keep the tests close to the behavior atom they prove:

- characterization tests with characterization beads;
- DTO/fixture tests with contract/model beads;
- denial/security tests with access-seam beads;
- response-shape regression tests with route/surface beads;
- docs/wrapper/inventory checks with parity beads.

## Before/after mini-example

### Before

```md
## Scope
Add a reusable server-side authoring module, likely src/server/workflowAuthoring.ts. Port/adapt CustomHarness symbols createWorkflowFromPrompt, authorWorkflowSource, extractWorkflowSource, generatedWorkflowSourceValidationIssues, workflowSourceValidationFeedback, resolveWorkflowId, normalizeWorkflowId, normalizeOpenRouterModelId, and atomicWriteFile. Integrate with existing Smithers CLI/runCommand patterns from src/server/smithersRuntimePlugin.ts.
```

### After

```md
## Scope
- Add a reusable server-side workflow authoring module.
- Port the CustomHarness authoring/repair/render-verify loop.
- Keep generated output as ordinary Smithers TSX source.
- Integrate with existing Smithers CLI/run-command helpers.

## Expected files / symbols
- `src/server/workflowAuthoring.ts`
  - `createWorkflowFromPrompt`
  - `authorWorkflowSource`
  - `extractWorkflowSource`
  - `renderVerifyWorkflowSource`
- `src/server/smithersRuntimePlugin.ts`
  - existing CLI / run-command helper to reuse
- `scripts/smoke-workflow-authoring.mjs`
```

The “after” version is longer in source but much easier to scan in BV.
