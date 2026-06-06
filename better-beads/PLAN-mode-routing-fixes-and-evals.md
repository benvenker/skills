# Plan: Better-Beads Mode Routing — Fixes, Plan Readiness Gate, and Eval Infrastructure

> **Context for the implementing agent:** This plan was produced by a code review of uncommitted changes in `skills/better-beads/` that decompose four operator modes into dedicated reference files and add a CLI routing command (`bead_route.sh`). The changes are solid but have correctness bugs, missing test coverage, and no route/eval infrastructure. This plan addresses those issues and adds a plan-readiness gate so `improve-plan-first` becomes a directly routable mode.
>
> **Read before starting:**
> - `skills/better-beads/SKILL.md` — top-level skill instructions
> - `skills/better-beads/scripts/bead_route.sh` — the routing CLI (primary edit target)
> - `skills/better-beads/scripts/better-beads` — dispatcher behavior and first-try CLI surface
> - `skills/better-beads/scripts/test_cli_robot_surfaces.sh` — existing robot-surface regression tests
> - `skills/better-beads/references/MODE-*.md` — the four mode procedure files
> - `skills/better-beads/references/AUTHORING-PROMPTS.md`, `QUALITY-GATES.md`, and `SEMANTIC-GATE.md` — routing/dispatch policy and readiness gates
> - The agent-ergonomics skill, if available in the local skill installation, for CLI patterns, schema/versioning patterns, eval patterns, and adversarial fixture examples.
>
> **Packaging note:** This plan currently lives outside the installable skill package. Before release, either move it under `skills/better-beads/references/` if it should be durable, or remove/archive it as scratch planning so `npx skills add benvenker/skills --skill better-beads` does not ship stale implementation notes.

---

## Part 1: Must-Fix (3 items)

### 1.1 Fix inspection failure handling in `bead_route.sh`

**File:** `skills/better-beads/scripts/bead_route.sh`

**Problem:** When `.beads` exists but `br list --json` fails (malformed JSON, `br` error envelope, permission error), the current `|| true` suppression + Python `except: issues = []` chain treats it as “0 beads” and recommends `create-from-raw-plan`. This risks duplicate bead creation over an existing graph the router could not read.

**Fix:** Capture inspection exit codes without letting `set -e` exit early, pass those codes into Python, and fail closed when bead inspection is unsafe.

In the bash section around the `br list` and `br dep cycles` calls, replace the suppressed calls with an explicit capture block:

```bash
cd "$REPO"

set +e
br list --json >"$BEADS_JSON" 2>"$BEADS_ERR"
LIST_RC=$?
br dep cycles --json >"$CYCLES_JSON" 2>"$CYCLES_ERR"
CYCLES_RC=$?
set -e

python3 - "$BEADS_JSON" "$CYCLES_JSON" "$JSON" "$LIST_RC" "$CYCLES_RC" "$BEADS_ERR" "$CYCLES_ERR" <<'PY'
```

Add `BEADS_ERR` / `CYCLES_ERR` temp files to the existing `mktemp`/`trap` cleanup.

In the Python section, replace the bare `except: issues = []` with explicit failure handling:

```python
list_rc = int(sys.argv[4])
cycles_rc = int(sys.argv[5])
beads_err_path = sys.argv[6]
cycles_err_path = sys.argv[7]
inspection_warnings = []

try:
    with open(beads_path, encoding="utf-8") as f:
        raw = f.read().strip()
    if list_rc != 0:
        stderr = open(beads_err_path, encoding="utf-8").read().strip()
        raise ValueError(f"br list --json exited {list_rc}: {stderr or 'no stderr'}")
    if not raw:
        raise ValueError("empty output from br list --json")
    beads_data = json.loads(raw)
    if isinstance(beads_data, dict) and "error" in beads_data:
        raise ValueError(f"br list returned error: {beads_data['error']}")
    if isinstance(beads_data, dict):
        issues = beads_data.get("issues", [])
    elif isinstance(beads_data, list):
        issues = beads_data
    else:
        raise ValueError(f"unexpected br list JSON shape: {type(beads_data).__name__}")
except Exception as e:
    print(f".beads exists but inspection failed: {e}", file=sys.stderr)
    print("Cannot route safely. Fix br or inspect .beads manually.", file=sys.stderr)
    sys.exit(2)
```

Handle cycle inspection separately. Do **not** silently default cycles to safe/zero when parsing fails. Prefer an explicit unknown state:

```python
cycle_inspection = "ok"
cycle_count = 0

try:
    with open(cycles_path, encoding="utf-8") as f:
        raw_cycles = f.read().strip()
    if cycles_rc != 0:
        stderr = open(cycles_err_path, encoding="utf-8").read().strip()
        raise ValueError(f"br dep cycles --json exited {cycles_rc}: {stderr or 'no stderr'}")
    if not raw_cycles:
        raise ValueError("empty output from br dep cycles --json")
    cycles_data = json.loads(raw_cycles)
    if isinstance(cycles_data, dict) and "error" in cycles_data:
        raise ValueError(f"br dep cycles returned error: {cycles_data['error']}")
    cycle_count = cycles_data.get("count") if isinstance(cycles_data, dict) else None
    if cycle_count is None and isinstance(cycles_data, dict) and isinstance(cycles_data.get("cycles"), list):
        cycle_count = len(cycles_data["cycles"])
    if cycle_count is None:
        raise ValueError("unexpected br dep cycles JSON shape")
except Exception as e:
    cycle_inspection = "failed"
    cycle_count = None
    inspection_warnings.append(f"cycle inspection failed: {e}")
```

In `graph_state`, represent unknown cycles explicitly:

```python
has_cycles = cycle_count is not None and cycle_count > 0

graph_state = {
    "has_beads_dir": True,
    "total_beads": total,
    "by_status": by_status,
    "cycle_inspection": cycle_inspection,
    "has_cycles": has_cycles,
    "cycle_count": cycle_count,
    "inspection_warnings": inspection_warnings,
}
```

If cycle inspection failed, append the warning to `reasoning` and `next_steps`, but keep routing based on bead state because bead inspection succeeded.

**Verify:**

- `.beads` exists and `br list --json` emits malformed JSON → exit 2, stderr diagnostic, no stdout JSON.
- `.beads` exists and `br list --json` emits `{ "error": "..." }` → exit 2.
- `.beads` exists and `br dep cycles --json` fails/malformed → route still emits JSON, with `cycle_inspection: "failed"`, `cycle_count: null`, and `inspection_warnings` populated.

---

### 1.2 Fix “all closed” branch to handle blocked/pending/unknown statuses

**File:** `skills/better-beads/scripts/bead_route.sh` (Python decision tree)

**Problem:** The decision tree only branches on `in_progress` and `open`. Any graph with `blocked`, `pending`, or novel statuses but no open/in_progress beads falls through to `create-from-raw-plan` with reasoning “N beads, all closed” — factually wrong.

**Fix:** Replace the final `else` branch:

```python
else:
    # Check if truly all terminal, or if active work uses non-standard statuses.
    terminal_statuses = {"closed", "archived"}
    non_terminal = {k: v for k, v in by_status.items() if k not in terminal_statuses}
    if non_terminal:
        status_desc = ", ".join(f"{v} {k}" for k, v in sorted(non_terminal.items()))
        mode = "polish-existing-graph"
        reasoning = (
            f"{total} beads with non-terminal statuses ({status_desc}). "
            "Graph has active work in non-standard states; inspect and repair before dispatch."
        )
    else:
        mode = "create-from-raw-plan"
        reasoning = (
            f"{total} beads, all closed/archived. Use create-from-raw-plan for new work, "
            "or improve-plan-first if the plan needs strengthening."
        )
```

**Verify:** Create a fixture with 3 beads all in `blocked`/`pending` statuses, run `bead_route.sh --repo . --json`, and confirm `recommended_mode` is `polish-existing-graph`.

---

### 1.3 Fix `tool` field inconsistency and dispatcher identity semantics

**Files:** `skills/better-beads/scripts/bead_route.sh`, possibly `skills/better-beads/scripts/better-beads`

**Problem:** `bead_route.sh capabilities --json` emits `"tool": "bead_route.sh"`, but route recommendations emit `"tool": "better-beads"`. Robot consumers that key on `tool` get confused.

**Current dispatcher reality:** `better-beads route` currently `exec`s `bead_route.sh`; it does **not** wrap or re-stamp the output. Do not assume the dispatcher can add fields unless you intentionally replace `exec` with a wrapper.

**Fix option A (simplest):** Make raw/delegated route output self-identify consistently as the helper:

```python
print(json.dumps({
    "tool": "bead_route.sh",
    "schema": "better-beads-route-v1",
    ...
```

Then document that `better-beads route --json` preserves delegated helper output, so the `tool` field remains `bead_route.sh` even when invoked via the dispatcher.

**Fix option B (if dispatcher identity matters):** Replace `exec bash "$SCRIPT_DIR/bead_route.sh" "$@"` with a wrapper that captures JSON, validates it, and adds a dispatcher provenance field such as:

```json
"via": "better-beads"
```

Only choose option B if the additional wrapper complexity is worth it. Option A is enough for this plan.

**Verify:**

- `bead_route.sh capabilities --json` and `bead_route.sh --json` return the same `tool` value.
- `better-beads route --json` either intentionally returns `tool: bead_route.sh` (option A) or returns a documented wrapper/provenance shape (option B).

---

## Part 2: Improvements (5 items)

### 2.1 Add route surfaces to `test_cli_robot_surfaces.sh`

**File:** `skills/better-beads/scripts/test_cli_robot_surfaces.sh`

**What to add** after the existing closeout assertions, before the temp-repo section:

```bash
ROUTE="$SCRIPT_DIR/bead_route.sh"

# Route capabilities
bash "$ROUTE" capabilities --json | assert_json_field bead_route.sh

# Route robot-docs
bash "$ROUTE" robot-docs guide | grep -q "Better Beads route robot guide"

# Route --robot-help alias
bash "$ROUTE" --robot-help | grep -q "Better Beads route robot guide"

# Route typo suggestion
set +e
ROUTE_ERR="$(bash "$ROUTE" --jsno 2>&1 >/dev/null)"
ROUTE_RC=$?
set -e
[[ "$ROUTE_RC" -eq 2 ]]
[[ "$ROUTE_ERR" == *"Did you mean: --json"* ]]
[[ "$ROUTE_ERR" == *"Corrected command:"*"--json"* ]]

# Dispatcher route delegation (no .beads — should recommend create-from-raw-plan)
(
  cd "${TMPDIR:-/tmp}"
  NO_BEADS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-route-test.XXXXXX")"
  bash "$DISPATCHER" route --repo "$NO_BEADS_DIR" --json \
    | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["recommended_mode"] == "create-from-raw-plan", p'
  rm -rf "$NO_BEADS_DIR"
)
```

Also strengthen dispatcher discovery assertions:

- `better-beads capabilities --json` includes a `robot_surfaces` entry for `["route", "--json"]`.
- `better-beads capabilities --json` includes a `commands` entry named `route` delegating to `bead_route.sh`.
- `better-beads triage --json` includes a `recommended_commands` entry containing `route --json`.

Use `python3` for JSON assertions rather than adding a `jq` dependency.

**Verify:** Run `bash scripts/test_cli_robot_surfaces.sh` — all assertions pass.

---

### 2.2 Make `improve-plan-first` directly routable via a plan-readiness gate

**Files:** `skills/better-beads/scripts/bead_route.sh`, `skills/better-beads/references/MODE-CREATE-FROM-RAW-PLAN.md`

**Problem:** The router never directly recommends `improve-plan-first`. The user confirmed this is not intentional — the mode should be reachable either by explicit user request (“improve the plan”) or by the router detecting that the plan is not ready for beads.

**Design:** Add two mechanisms.

#### (a) JSON output fields for plan-readiness awareness

In the `create-from-raw-plan` recommendation branches (no `.beads`, empty graph, and all-terminal graph), add:

```python
"plan_readiness": {
    "check_required": True,
    "gate_reference": "references/MODE-CREATE-FROM-RAW-PLAN.md § Pre-mutation readiness gates",
    "required_gates": [
        "Outcome",
        "Anchors",
        "Validation",
        "Failure behavior",
        "Non-goals",
        "Parent/child shape",
        "Dependency order"
    ],
    "alternate_mode_if_weak": "improve-plan-first",
    "alternate_reference": "references/MODE-IMPROVE-PLAN-FIRST.md"
}
```

Update `next_steps` to include:

```text
Check plan readiness gates before creating beads — if the plan is weak or under-grounded, use improve-plan-first instead.
```

For non-create routes, either omit `plan_readiness` or include:

```json
"plan_readiness": { "check_required": false }
```

Keep the schema stable and document whichever choice is implemented.

#### (b) `--plan PATH` for explicit plan-quality routing

Add `--plan PATH` to `bead_route.sh` if time permits. This flag performs a shallow structural check of a plan file and can route directly to `improve-plan-first` without requiring LLM judgment.

Update known flags:

```bash
KNOWN_FLAGS=(--repo --json --plan --version --robot-help -h --help)
```

The shallow check should look for all readiness gates, not only the first four:

- Outcome
- Anchors / surfaces / contracts / key files
- Validation / verification
- Failure behavior
- Non-goals / scope boundary
- Parent/child shape / graph shape
- Dependency order / sequencing / ready frontier

If any required gate is missing, route to `improve-plan-first` and include structured details:

```json
"plan_readiness": {
  "check_required": true,
  "checked": true,
  "plan_path": "...",
  "status": "weak",
  "missing_gates": ["Anchors", "Failure behavior"],
  "alternate_mode_if_weak": "improve-plan-first"
}
```

If all shallow checks pass, keep the graph-state recommendation but include:

```json
"plan_readiness": {
  "check_required": true,
  "checked": true,
  "status": "structurally_ready",
  "missing_gates": []
}
```

The structural check is deliberately shallow. It validates section/term presence, not plan quality. The mode procedure still performs semantic review before bead creation.

**Verify:**

- `bead_route.sh --repo /tmp/no-beads --json` includes `plan_readiness.check_required: true`.
- `bead_route.sh --repo /tmp/no-beads --plan weak-plan.md --json` recommends `improve-plan-first` and reports `missing_gates`.
- `bead_route.sh --repo /tmp/no-beads --plan ready-plan.md --json` keeps `create-from-raw-plan` and reports `status: structurally_ready`.

---

### 2.3 Add Inspection section to `MODE-IMPROVE-PLAN-FIRST.md`

**File:** `skills/better-beads/references/MODE-IMPROVE-PLAN-FIRST.md`

**Problem:** The other three mode files have explicit Inspection blocks with `br`/`bv` commands. This mode has none, making it the only non-self-contained procedure.

**Fix:** Add after the “When to use” section:

````markdown
## Inspection

Before strengthening the plan, assess its current state:

1. **Review the plan** against the pre-mutation readiness gates in `MODE-CREATE-FROM-RAW-PLAN.md`:
   - Outcome defined?
   - Anchors (surfaces, contracts, key files/symbols, state transitions) identified?
   - Validation criteria specified?
   - Failure behavior described?
   - Non-goals scoped?
   - Parent/child shape clear?
   - Dependency order and ready frontier clear?

2. **Check for existing beads if a graph exists.** If `.beads` exists, inspect for relevant work that already covers parts of the plan:
   ```bash
   br list --json
   bv --robot-plan
   ```
   If `.beads` does not exist yet, record that no bead graph exists and keep this mode plan-space only.

3. **Identify the gaps** — which readiness gates fail? Those are the plan sections to strengthen before any bead mutation.
````

**Verify:** All four `MODE-*.md` files now have an Inspection section.

---

### 2.4 Adopt schema versioning from agent-ergonomics

**File:** `skills/better-beads/scripts/bead_route.sh`

**What:** The agent-ergonomics guidance recommends separating `contract_version` (overall tool contract) from per-schema versions. `bead_route.sh` already has `CONTRACT_VERSION="2026-06-06"` and route JSON uses `"schema": "better-beads-route-v1"`; make that explicit and discoverable in `capabilities --json`.

**Fix:** Add a schema registry to `capabilities --json`:

```json
{
  "tool": "bead_route.sh",
  "version": "1.0.0",
  "contract_version": "2026-06-06",
  "schemas": {
    "better-beads-route-v1": {
      "description": "Routing recommendation with graph state, optional plan readiness, and inspection warnings.",
      "stability": "experimental",
      "introduced": "2026-06-06",
      "fields": [
        "tool",
        "schema",
        "graph_state",
        "recommended_mode",
        "reasoning",
        "modes",
        "next_steps",
        "plan_readiness"
      ]
    },
    "capabilities-v1": {
      "description": "Tool capabilities, robot surfaces, mode references, and schema registry.",
      "stability": "stable",
      "introduced": "2026-06-06"
    },
    "markdown-guide-v1": {
      "description": "Agent-oriented route guide emitted by robot-docs guide / --robot-help.",
      "stability": "stable",
      "introduced": "2026-06-06"
    }
  },
  ...
}
```

Also update `robot_docs()` to explain any new fields, especially:

- `plan_readiness`
- `graph_state.cycle_inspection`
- `graph_state.inspection_warnings`
- optional `--plan PATH`, if implemented
- delegated dispatcher identity (`tool: bead_route.sh` even when invoked through `better-beads route`, unless a wrapper is added)

**Verify:** Use `python3` instead of requiring `jq`:

```bash
bash skills/better-beads/scripts/bead_route.sh capabilities --json \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); assert "schemas" in p, p; assert "better-beads-route-v1" in p["schemas"], p'
```

---

### 2.5 Refresh public docs and packaging references

**Files:** likely `skills/better-beads/SKILL.md`, `skills/better-beads/references/AUTHORING-PROMPTS.md`, `skills/better-beads/references/README.md`, root `README.md`, and maybe `skills/better-beads/metadata.json`

**Problem:** Route behavior, plan-readiness semantics, and schema contracts are user-facing. Installed skill users discover behavior through the packaged skill docs and in-tool robot docs, not this implementation plan.

**Fix:** After code changes, update public docs to reflect:

- `scripts/better-beads route --json` remains the first routing command.
- `bead_route.sh --plan PATH --json` exists if implemented.
- `improve-plan-first` can be selected by user intent or failed plan-readiness gates.
- `better-beads route --json` delegates to `bead_route.sh` and preserves helper identity unless explicitly wrapped.
- Route JSON includes `plan_readiness` and cycle inspection warning fields.
- Any implementation plan file should not rely on private machine paths and should not be shipped as stale scratch documentation.

**Verify:** Search for stale private/non-portable paths and stale route claims:

```bash
python3 - <<'PY'
from pathlib import Path
roots = [Path('skills/better-beads'), Path('README.md')]
needles = ['~/.claude', '/Users/', 'dispatcher wraps this output']
for root in roots:
    files = [root] if root.is_file() else list(root.rglob('*'))
    for path in files:
        if path.is_file() and path.suffix in {'.md', '.json', ''}:
            text = path.read_text(errors='ignore')
            for needle in needles:
                if needle in text:
                    print(f'{path}: contains {needle}')
PY
```

---

## Part 3: Eval Infrastructure (3 layers)

### 3.1 Layer 1: Route Decision Fixtures (highest priority — do this first)

**Pattern source:** agent-ergonomics-style self-test fixtures and adversarial CLI fixtures.

**Create these files:**

```text
skills/better-beads/test/
├── bin/
│   └── br                         # executable stub br used by fixture tests
├── fixtures/
│   ├── no-beads/                  # No .beads directory at all
│   │   └── .gitkeep
│   ├── empty-graph/               # .beads exists; br list returns [] or {issues: []}
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-cycles-output.json
│   ├── all-open/                  # 3 open beads
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-cycles-output.json
│   ├── mixed-active/              # 2 in_progress + 2 open
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-cycles-output.json
│   ├── closeout-ready/            # 3 in_progress, 0 open
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-cycles-output.json
│   ├── all-closed/                # 4 closed beads
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-cycles-output.json
│   ├── blocked-statuses/          # 2 blocked + 1 pending (no open/in_progress)
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-cycles-output.json
│   ├── cycles-failed/             # valid beads, malformed/nonzero cycle inspection
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       ├── br-cycles-output.json
│   │       └── br-cycles-rc
│   ├── br-list-malformed/         # malformed br list JSON; expect exit 2
│   │   └── .beads/
│   │       └── br-list-output.json
│   ├── br-list-error-envelope/    # {"error": "..."}; expect exit 2
│   │   └── .beads/
│   │       └── br-list-output.json
│   ├── br-list-nonzero/           # br list rc != 0; expect exit 2
│   │   └── .beads/
│   │       ├── br-list-output.json
│   │       └── br-list-rc
│   ├── weak-plan.md               # missing one or more readiness gates
│   ├── ready-plan.md              # has all shallow readiness gates
│   └── expected.jsonl             # Ground truth: one line per fixture
└── test_bead_route.sh             # Test runner
```

**`expected.jsonl` format** (one JSON object per line):

```jsonl
{"fixture": "no-beads", "expected_mode": "create-from-raw-plan", "expected_has_beads_dir": false, "expected_rc": 0}
{"fixture": "empty-graph", "expected_mode": "create-from-raw-plan", "expected_total": 0, "expected_rc": 0}
{"fixture": "all-open", "expected_mode": "polish-existing-graph", "expected_total": 3, "expected_rc": 0}
{"fixture": "mixed-active", "expected_mode": "polish-existing-graph", "expected_total": 4, "expected_rc": 0}
{"fixture": "closeout-ready", "expected_mode": "closeout", "expected_total": 3, "expected_rc": 0}
{"fixture": "all-closed", "expected_mode": "create-from-raw-plan", "expected_total": 4, "expected_rc": 0}
{"fixture": "blocked-statuses", "expected_mode": "polish-existing-graph", "expected_total": 3, "expected_rc": 0}
{"fixture": "cycles-failed", "expected_mode": "polish-existing-graph", "expected_cycle_inspection": "failed", "expected_rc": 0}
{"fixture": "br-list-malformed", "expected_rc": 2, "expected_stderr_contains": "inspection failed"}
{"fixture": "br-list-error-envelope", "expected_rc": 2, "expected_stderr_contains": "br list returned error"}
{"fixture": "br-list-nonzero", "expected_rc": 2, "expected_stderr_contains": "br list --json exited"}
```

If `--plan` is implemented, add plan-specific expected rows or a separate `expected-plan.jsonl`:

```jsonl
{"fixture": "no-beads", "plan": "weak-plan.md", "expected_mode": "improve-plan-first", "expected_missing_gates_min": 1, "expected_rc": 0}
{"fixture": "no-beads", "plan": "ready-plan.md", "expected_mode": "create-from-raw-plan", "expected_plan_status": "structurally_ready", "expected_rc": 0}
```

**`test/bin/br` stub** — name it exactly `br`, because `bead_route.sh` uses `command -v br`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="$(pwd)"

read_rc() {
  local path="$1"
  if [[ -f "$path" ]]; then
    cat "$path"
  else
    echo 0
  fi
}

case "${1:-}" in
  list)
    if [[ "${2:-}" == "--json" ]]; then
      rc="$(read_rc "$REPO/.beads/br-list-rc")"
      if [[ -f "$REPO/.beads/br-list-stderr" ]]; then
        cat "$REPO/.beads/br-list-stderr" >&2
      fi
      cat "$REPO/.beads/br-list-output.json"
      exit "$rc"
    fi
    ;;
  dep)
    if [[ "${2:-}" == "cycles" && "${3:-}" == "--json" ]]; then
      rc="$(read_rc "$REPO/.beads/br-cycles-rc")"
      if [[ -f "$REPO/.beads/br-cycles-stderr" ]]; then
        cat "$REPO/.beads/br-cycles-stderr" >&2
      fi
      cat "$REPO/.beads/br-cycles-output.json"
      exit "$rc"
    fi
    ;;
esac

echo "stub br: unsupported args: $*" >&2
exit 1
```

**`test_bead_route.sh` requirements:**

- Prepend the stub directory to PATH:
  ```bash
  export PATH="$SCRIPT_DIR/bin:$PATH"
  ```
- Use `python3` for JSON parsing instead of `jq`.
- Assert both success cases and negative exit-2 cases.
- For exit-2 cases, assert stderr contains the expected diagnostic and stdout is empty or non-JSON by contract.

**Important missing-tool test:** Because the stubbed PATH masks real `br`, add one dedicated test where `.beads` exists but PATH intentionally excludes the stub and real `br` is unavailable, or simulate that in a subprocess. Expected: exit 2 with `br not found on PATH; cannot inspect .beads state`. If a real `br` exists locally, mark this case skipped with a clear note rather than making it flaky.

**Verify:** `bash skills/better-beads/test/test_bead_route.sh` — all fixtures pass. Run after every edit to `bead_route.sh`.

---

### 3.2 Layer 2: Mode Output Golden Tests (do before first real use)

**Pattern source:** calibration/golden fixtures from CLI-eval workflows.

**Purpose:** Answer “here is a plan/graph — what should this operator mode produce?” for each mode. These are captured from first real use and then pinned as regression anchors.

**Create this structure:**

```text
skills/better-beads/test/golden/
├── README.md
├── create-from-plan/
│   ├── input-plan.md              # Small but complete plan (3-4 beads worth)
│   ├── input-beads/               # Empty .beads state (pre-condition)
│   ├── expected-graph.jsonl       # Expected bead graph after mode runs
│   └── expected-commands.txt      # Expected br create / br dep commands
├── improve-plan-first/
│   ├── input-plan.md              # Vague/weak plan missing readiness gates
│   ├── input-beads/               # Optional existing graph; empty/no .beads is allowed
│   ├── expected-strengthened-plan.md
│   └── expected-readiness-report.json
├── polish-existing/
│   ├── input-plan.md              # Context plan
│   ├── input-beads/               # Messy graph (missing deps, bad labels)
│   │   └── .beads/issues.jsonl
│   ├── expected-graph.jsonl       # Expected graph after polishing
│   └── expected-mutations.txt     # Expected br update / br dep commands
└── closeout/
    ├── input-beads/               # 3 in_progress, 0 open
    │   └── .beads/issues.jsonl
    ├── expected-graph.jsonl       # Expected statuses after closeout
    └── expected-evidence.md       # Expected closure evidence shape
```

**`README.md` content:**

```markdown
# Golden Tests for Better-Beads Mode Outputs

These fixtures capture expected outputs for each Better-Beads operator mode.
They are regression anchors — not strict pass/fail automation, because mode
procedures are agent-driven and exact wording can vary.

Use them as:

1. **Reference examples** — what a good mode run looks like.
2. **Regression smoke** — after editing a MODE-*.md file, compare output to the golden.
3. **Eval seeds** — when LLM-driven eval is set up, these become ground truth.

## How to capture a new golden

1. Run the mode procedure against the input fixture.
2. Copy the resulting `.beads/issues.jsonl`, strengthened plan, readiness report, or closeout evidence into the expected files.
3. Record the `br` commands used in `expected-commands.txt` / `expected-mutations.txt` when the mode mutates bead state.
4. Commit the golden alongside the mode procedure change.

## How to use for quick manual eval

1. Read the input fixture.
2. Ask: “What should this Better-Beads mode output?”
3. Compare the agent’s answer to the expected files.
4. Diff structurally: same beads, dependencies, readiness gaps, and closure evidence; wording can differ.
```

**Implementation note:** Capture final golden outputs from the first real run of each mode, then commit them. Until then, create input fixtures now and leave expected files as stubs with a `# TODO: capture from first real run` header. This still provides input fixtures for manual testing today.

**Verify:** Input fixtures exist and are valid. Golden outputs are populated after first real use.

---

### 3.3 Layer 3: Trigger Probe Table

**File:** Create `skills/better-beads/test/ROUTING-TRUTH-TABLE.md`

**Purpose:** A documented truth table that a human or agent can spot-check. Cheapest eval — a reference document that covers every branch and non-route prompt.

```markdown
# Better-Beads Routing Truth Table

## Route command decision expectations

| Graph state | User intent | Expected `recommended_mode` | Notes |
|---|---|---|---|
| No `.beads` dir | “Create beads from this plan” | `create-from-raw-plan` | + `plan_readiness.check_required: true` |
| No `.beads` dir | “Improve the plan first” | `improve-plan-first` | Agent/user-intent override |
| No `.beads`, plan missing readiness gates | Auto with `--plan` | `improve-plan-first` | `plan_readiness.missing_gates` populated |
| No `.beads`, structurally ready plan | Auto with `--plan` | `create-from-raw-plan` | Still requires semantic gate before mutation |
| Empty graph (0 beads) | Any | `create-from-raw-plan` | Same as no-beads |
| 5 open, 0 in_progress | “Work on beads” | `polish-existing-graph` | Inspect before dispatch |
| 2 in_progress + 3 open | “Continue work” | `polish-existing-graph` | Mixed active state |
| 3 in_progress, 0 open | “Wrap up” | `closeout` | Make in_progress truthful |
| 4 closed/archived, 0 other | “New feature” | `create-from-raw-plan` | All terminal |
| 2 blocked, 1 pending | Any | `polish-existing-graph` | Non-terminal ≠ closed |
| Any + dependency cycles | Any | Normal mode + cycle warning | Cycles appended to reasoning |
| Any + cycle inspection failure | Any | Normal mode + inspection warning | `cycle_inspection: failed`, `cycle_count: null` |
| `.beads` exists, `br` missing | Any | Exit 2 | Cannot inspect graph |
| `.beads` exists, `br list` fails/malformed/error envelope | Any | Exit 2 | Cannot route safely |

## Mode procedure expectations (per-mode spot checks)

| Mode | Input | Key output check |
|---|---|---|
| `create-from-raw-plan` | Plan with 4 features | 1 parent + 4 child beads, dependency edges, `ready-for-agent` on frontier |
| `create-from-raw-plan` | Plan missing validation criteria | Route to `improve-plan-first` before mutation |
| `improve-plan-first` | Vague plan | Strengthened plan with anchors, validation, failure behavior — no bead mutations |
| `polish-existing-graph` | Graph with orphan beads | Dependencies added, labels fixed, split/merge applied |
| `closeout` | 3 in_progress beads (2 done, 1 not) | 2 closed with evidence, 1 reopened or blocked with explanation |

## Scope-creep probes (should NOT trigger mode routing)

| Prompt | Expected behavior |
|---|---|
| “Implement bead bb-042” | Not a routing question — this is dispatch, not mode selection |
| “Show me the bead graph” | Use `br list --json` / `bv --robot-plan` directly, not `bead_route.sh` |
| “What’s the project status?” | Use `bv --robot-triage`, not routing |
```

**Verify:** Read the table and confirm each row matches the decision tree in `bead_route.sh`.

---

## Implementation Order

Execute in this order. Each step is independently committable.

| Step | Items | Files touched | Commit message pattern |
|---|---|---|---|
| 1 | 1.1 + 1.2 + 1.3 | `bead_route.sh` | `Fix bead_route.sh: inspection failures, blocked statuses, tool field` |
| 2 | 2.1 | `test_cli_robot_surfaces.sh` | `Add route command to CLI robot surface tests` |
| 3 | 2.3 | `MODE-IMPROVE-PLAN-FIRST.md` | `Add Inspection section to improve-plan-first mode` |
| 4 | 2.2 | `bead_route.sh`, `MODE-CREATE-FROM-RAW-PLAN.md` | `Add plan_readiness gate and improve-plan-first routing` |
| 5 | 2.4 | `bead_route.sh` | `Add schema registry to route capabilities output` |
| 6 | 3.1 | `test/bin/br`, `test/fixtures/*`, `test/test_bead_route.sh` | `Add route decision and failure fixture tests` |
| 7 | 3.3 | `test/ROUTING-TRUTH-TABLE.md` | `Add routing truth table for eval reference` |
| 8 | 3.2 | `test/golden/*` | `Add golden test input fixtures for mode outputs` |
| 9 | 2.5 | docs/readmes/metadata as needed | `Refresh Better-Beads routing docs for public package` |

**After all steps:** Run:

```bash
bash skills/better-beads/scripts/test_cli_robot_surfaces.sh
bash skills/better-beads/test/test_bead_route.sh
python3 skills/better-beads/scripts/test_bead_quality_gate.py
bash skills/better-beads/scripts/test_bead_gate_loop.sh
```

Then commit the full batch with a summary message.

---

## Verification Checklist

- [ ] `bead_route.sh --repo /path/with/.beads-but-corrupt --json` exits 2 with stderr diagnostic.
- [ ] `bead_route.sh` with a `br list` JSON error envelope exits 2 with stderr diagnostic.
- [ ] `bead_route.sh` with blocked/pending-only beads recommends `polish-existing-graph`.
- [ ] `bead_route.sh` with cycle inspection failure emits JSON with `cycle_inspection: "failed"`, `cycle_count: null`, and `inspection_warnings`.
- [ ] `bead_route.sh capabilities --json` and `bead_route.sh --json` return the intended documented `tool` value.
- [ ] `better-beads route --json` identity semantics are documented and tested.
- [ ] `bash skills/better-beads/scripts/test_cli_robot_surfaces.sh` passes, including route assertions.
- [ ] `bash skills/better-beads/test/test_bead_route.sh` passes all success and negative fixtures.
- [ ] `MODE-IMPROVE-PLAN-FIRST.md` has a conditional Inspection section.
- [ ] `create-from-raw-plan` route JSON includes `plan_readiness` object.
- [ ] If `--plan` is implemented, weak plans route to `improve-plan-first` with `missing_gates`, and ready plans report `structurally_ready`.
- [ ] `capabilities --json` includes a `schemas` registry documenting route/capabilities/markdown-guide schemas.
- [ ] `robot-docs guide` explains new route fields and `--plan` if present.
- [ ] `test/ROUTING-TRUTH-TABLE.md` exists and covers every decision-tree branch.
- [ ] `test/golden/create-from-plan/input-plan.md`, `test/golden/improve-plan-first/input-plan.md`, and `test/golden/polish-existing/input-plan.md` exist.
- [ ] Public docs do not contain private machine paths such as `~/.claude` or `/Users/...`.
- [ ] This plan is either moved into the installable skill references if durable, or removed/archived before release if scratch.
