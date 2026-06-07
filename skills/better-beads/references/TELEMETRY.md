# Better Beads Telemetry

Better Beads telemetry is an optional JSONL event stream for local script runs.
It records operational facts only. It must never include bead descriptions, plan
text, prompts, stdout, absolute paths, or user-authored content.

## Event Contract

Each line is one JSON object with schema version `better-beads-telemetry-v1`:

- `run_id`: caller-provided ID or generated UUID-like hex string.
- `timestamp`: UTC ISO 8601 timestamp.
- `tool`: script or dispatcher name.
- `tool_version`: producer version string.
- `contract_version`: producer contract version string.
- `mode`: command mode, such as `route`, `quality-gate`, or `gate-loop`.
- `repo_id`: first 16 hex characters of SHA-256 over the resolved repo root.
- `repo_basename`: basename of the resolved repo root.
- `duration_ms`: elapsed duration in milliseconds.
- `exit_code`: producer exit code.
- `verdict`: caller-defined outcome label.
- `finding_counts`: integer counters, with no finding text.
- `schema_version`: `better-beads-telemetry-v1`.

The schema lives at `schemas/better-beads-telemetry-v1.schema.json`.

## Helper API

Python callers import `scripts/better_beads_telemetry.py` and use:

```python
from better_beads_telemetry import emit_event

result = emit_event(
    "/tmp/better-beads-events.jsonl",
    tool="bead_route.sh",
    tool_version="1.0.0",
    contract_version="2026-06-06",
    mode="route",
    repo=".",
    duration_ms=42,
    exit_code=0,
    verdict="pass",
    finding_counts={},
)
if not result.ok:
    print(result.warning, file=sys.stderr)
```

Shell callers can invoke the helper directly:

```bash
python3 skills/better-beads/scripts/better_beads_telemetry.py \
  --emit /tmp/better-beads-events.jsonl \
  --tool bead_route.sh \
  --tool-version 1.0.0 \
  --contract-version 2026-06-06 \
  --mode route \
  --repo . \
  --duration-ms 42 \
  --exit-code 0 \
  --verdict pass \
  --finding-counts '{}'
```

## Failure Behavior

Telemetry is fail-soft. If appending an event fails, the helper prints one
warning to stderr for CLI use or returns `TelemetryWriteResult(ok=False)` for
Python use. The helper exits 0 from CLI emit mode so the caller can preserve its
primary command exit code.

Writes use `O_APPEND` and serialize a complete JSON object plus newline in one
write. The helper does not create parent directories for missing paths.

## Validation

Run:

```bash
python3 skills/better-beads/scripts/better_beads_telemetry.py --self-test
bash skills/better-beads/scripts/test_schemas.sh telemetry
```

The self-test leaves its temporary event file in place and verifies that the
event contains no absolute repo path or user-authored fields. The schema test
validates helper output against `better-beads-telemetry-v1`.
