#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_DIR="$SKILL_DIR/schemas"
ROUTE="$SCRIPT_DIR/bead_route.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/better-beads-schema-test.XXXXXX")"

printf 'Leaving Better Beads schema test temp root at %s\n' "$TMP_ROOT" >&2

usage() {
  cat >&2 <<'EOF'
Usage: test_schemas.sh [route]

Validates Better Beads JSON schemas using only bash and python3 stdlib.
EOF
}

case "${1:-all}" in
  all|route)
    TARGET="${1:-all}"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
esac

SCHEMA_ROUTE="$SCHEMA_DIR/better-beads-route-v1.schema.json"
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/br" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-} ${3:-}" in
  "list --json ")
    cat .beads/list.json
    ;;
  "dep cycles --json")
    if [[ -f .beads/cycles.exit ]]; then
      cat .beads/cycles.stderr >&2
      exit "$(cat .beads/cycles.exit)"
    fi
    cat .beads/cycles.json
    ;;
  *)
    echo "unsupported fake br invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/br"

cat >"$FAKE_BIN/bv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --robot-plan)
    echo '{"plan":{"summary":{"ready":true}}}'
    ;;
  --robot-insights)
    echo '{"insights":[]}'
    ;;
  *)
    echo "unsupported fake bv invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$FAKE_BIN/bv"

make_repo() {
  local name="$1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo/.beads"
  printf '[]\n' >"$repo/.beads/list.json"
  printf '{"count":0,"cycles":[]}\n' >"$repo/.beads/cycles.json"
  printf '%s\n' "$repo"
}

write_ready_plan() {
  local path="$1"
  cat >"$path" <<'EOF'
## Outcome
The route mode handles a structurally ready plan.

## Anchors
- Surface: scripts/bead_route.sh --plan PATH --json.

## Validation
```bash
bash skills/better-beads/scripts/bead_route.sh --plan plan.md --json
```

## Failure behavior
- Missing plan paths fail closed.

## Non-goals
- Do not mutate beads in route inspection.

## Parent child shape
- Parent closure and child behavior are described.

## Dependency order
- Route inspection happens before graph mutation.
EOF
}

write_weak_plan() {
  local path="$1"
  cat >"$path" <<'EOF'
## Outcome
There is a vague plan.
EOF
}

validate_schema_and_payload() {
  local schema="$1"
  local payload="$2"
  local case_name="$3"
  local producer="$4"
  python3 - "$schema" "$payload" "$case_name" "$producer" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
payload_path = Path(sys.argv[2])
case_name = sys.argv[3]
producer = sys.argv[4]

SUPPORTED = {
    "$schema",
    "$id",
    "title",
    "description",
    "type",
    "additionalProperties",
    "required",
    "properties",
    "items",
    "enum",
    "const",
    "anyOf",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path}: malformed JSON: {exc}")


def check_keywords(node: Any, path: str) -> None:
    if not isinstance(node, dict):
        return
    for key, value in node.items():
        if key not in SUPPORTED:
            fail(f"{schema_path}: unsupported keyword {key} at {path}")
        if key == "properties":
            if not isinstance(value, dict):
                fail(f"{schema_path}: properties must be object at {path}")
            for prop_name, prop_schema in value.items():
                check_keywords(prop_schema, f"{path}.properties.{prop_name}")
        elif key == "items":
            check_keywords(value, f"{path}.items")
        elif key == "anyOf":
            if not isinstance(value, list):
                fail(f"{schema_path}: anyOf must be array at {path}")
            for index, item in enumerate(value):
                check_keywords(item, f"{path}.anyOf[{index}]")
        elif key == "additionalProperties" and isinstance(value, dict):
            check_keywords(value, f"{path}.additionalProperties")


def type_name(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int) and not isinstance(value, bool):
        return "integer"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def validate(schema: dict[str, Any], value: Any, path: str) -> None:
    if "anyOf" in schema:
        failures = []
        for candidate in schema["anyOf"]:
            try:
                validate(candidate, value, path)
                return
            except AssertionError as exc:
                failures.append(str(exc))
        raise AssertionError(f"{path}: did not match anyOf: {failures}")

    if "const" in schema and value != schema["const"]:
        raise AssertionError(f"{path}: expected const {schema['const']!r}, got {value!r}")

    if "enum" in schema and value not in schema["enum"]:
        raise AssertionError(f"{path}: expected one of {schema['enum']!r}, got {value!r}")

    if "type" in schema:
        allowed = schema["type"]
        if isinstance(allowed, str):
            allowed_types = [allowed]
        elif isinstance(allowed, list):
            allowed_types = allowed
        else:
            raise AssertionError(f"{path}: schema type must be string or array")
        actual = type_name(value)
        if actual not in allowed_types:
            raise AssertionError(f"{path}: expected type {allowed_types!r}, got {actual}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise AssertionError(f"{path}: missing required key {key}")
        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        for key, child in value.items():
            if key in properties:
                validate(properties[key], child, f"{path}.{key}")
            elif additional is False:
                raise AssertionError(f"{path}: unexpected key {key}")
            elif isinstance(additional, dict):
                validate(additional, child, f"{path}.{key}")

    if isinstance(value, list) and "items" in schema:
        for index, item in enumerate(value):
            validate(schema["items"], item, f"{path}[{index}]")


schema = load_json(schema_path)
payload = load_json(payload_path)
check_keywords(schema, "$")
validate(schema, payload, "$")
print(f"ok schema={schema_path} case={case_name} producer={producer}")
PY
}

run_route_case() {
  local case_name="$1"
  local repo="$2"
  local producer="$3"
  shift 3
  local payload="$TMP_ROOT/${case_name}.json"
  if ! PATH="$FAKE_BIN:$PATH" bash "$ROUTE" --repo "$repo" "$@" --json >"$payload" 2>"$TMP_ROOT/${case_name}.stderr"; then
    echo "producer failed for case=$case_name producer=$producer" >&2
    cat "$TMP_ROOT/${case_name}.stderr" >&2
    exit 1
  fi
  validate_schema_and_payload "$SCHEMA_ROUTE" "$payload" "$case_name" "$producer"
}

run_route_tests() {
  local repo plan

  repo="$TMP_ROOT/no-beads-no-plan"
  mkdir -p "$repo"
  run_route_case "no-beads-no-plan" "$repo" "bead_route.sh --repo REPO --json"

  repo="$TMP_ROOT/no-beads-weak-plan"
  mkdir -p "$repo"
  plan="$TMP_ROOT/weak-plan.md"
  write_weak_plan "$plan"
  run_route_case "no-beads-weak-plan" "$repo" "bead_route.sh --repo REPO --plan PLAN --json" --plan "$plan"

  repo="$(make_repo graph-present-fake-br-list)"
  cat >"$repo/.beads/list.json" <<'EOF'
[
  {"id":"bd-open","status":"open"},
  {"id":"bd-closed","status":"closed"}
]
EOF
  run_route_case "graph-present-fake-br-list" "$repo" "bead_route.sh --repo REPO --json"

  repo="$(make_repo graph-present-cycle-inspection-failed)"
  cat >"$repo/.beads/list.json" <<'EOF'
[
  {"id":"bd-open","status":"open"}
]
EOF
  printf '5\n' >"$repo/.beads/cycles.exit"
  printf 'cycle inspection unavailable\n' >"$repo/.beads/cycles.stderr"
  run_route_case "graph-present-cycle-inspection-failed" "$repo" "bead_route.sh --repo REPO --json"
}

if [[ "$TARGET" == "route" || "$TARGET" == "all" ]]; then
  run_route_tests
fi

