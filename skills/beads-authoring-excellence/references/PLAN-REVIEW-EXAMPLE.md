# Plan Review Example: Plausible But Underpowered Beads Plan

This example captures the kind of plan that looks reasonable but should not be treated as excellent yet.

## Situation

A proposed graph for “Create workflow from chat” had:

1. Parent: Create workflow from chat
2. Child 1: Port workflow authoring service
3. Child 2: Expose create-from-chat API
4. Child 3: Add Chat Node workflow creation action
5. Child 4: Materialize generated workflow as right-side canvas node

A polish pass collapsed Child 3 and Child 4 into one vertical UI/canvas bead.
That graph shape was probably better:

1. Parent closure bead
2. Port workflow authoring service
3. Expose create-from-chat API
4. Add end-to-end chat action that creates the canvas Workflow Node

## What was good

- Small graph.
- Parent-as-closure-contract was correct.
- Preserved key architecture decision: generate ordinary Smithers TSX source, not a canvas-owned IR.
- Non-goals were present.
- UI action and materialized canvas result were eventually collapsed into one more meaningful vertical outcome.

## Why it still was not excellent

### 1. Not enough codebase reconnaissance

The plan named likely files, but did not name enough existing symbols, state shapes, route registration mechanisms, node creation APIs, or CustomHarness functions to port/discard.

A strong bead should say things like:

- existing route/plugin entrypoint
- existing node type/state shape
- existing canvas node creation helper
- exact CustomHarness authoring functions or extraction logic being reused

### 2. Validation was too weak

Most children used only:

```bash
pnpm build
```

Manual smoke was mentioned but not specified. That is validation theater.

Better beads should require exact smoke scripts or exact manual steps with expected output, for example:

```bash
pnpm tsx scripts/smoke-create-workflow-from-chat.ts
curl -s http://localhost:5173/api/smithers/workflows/create-from-chat ... | jq ...
```

If no test runner exists, a bead can require adding a tiny smoke script.

### 3. Child 1 was likely too large unless grounded by code

“OpenRouter authoring, TSX extraction, source validation, repair attempts, file write, and Smithers render verification” contains many failure modes.

It can remain one bead only if the port is straightforward and the bead defines:

- service API
- structured attempt/error shape
- path/id sanitization
- overwrite semantics
- injectable/mock provider or no-network fixture
- render verification without execution
- no writes outside `.smithers/workflows/`

### 4. Missing data contracts

The API bead said “structured shape” and “metadata” but did not define request/response fields.

A better bead includes draft contracts, e.g.:

```ts
type CreateFromChatRequest = {
  chatId: string;
  title?: string;
  messages: Array<{ role: "user" | "assistant"; content: string; createdAt?: string }>;
  context?: string;
  model?: string;
  workflowId?: string;
  displayName?: string;
  overwrite?: boolean;
};

type CreateFromChatResponse = {
  workflowId: string;
  displayName: string;
  path: string;
  verified: boolean;
  sourceSaved: boolean;
  attempts: AuthoringAttempt[];
  error?: string;
};
```

### 5. Missing failure-mode acceptance

Important cases were underspecified:

- generation fails
- extraction fails
- verification fails but source is saved
- overwrite disabled and ID exists
- missing OpenRouter key
- empty transcript
- oversized transcript
- path traversal in workflow ID
- dev server route throws

## Review verdict

The plan was not bad. It avoided the worst checklist-sludge failure. But it was a **well-formatted plan**, not yet an excellent execution graph.

Apply this hard cap:

> If a Beads plan has not inspected enough codebase context to name concrete files, symbols, data contracts, failure modes, and verification commands, it cannot score above 24/30.

## Better feedback to give

```text
Keep the 3-child graph shape, but deepen the beads. Do not claim 28–30/30 yet.
Each bead needs implementation evidence: concrete files/symbols, request/response
or state contracts, failure modes, exact verification, and closure evidence.
The current graph prevents checklist sludge, but it does not yet prevent agent
improvisation.
```
