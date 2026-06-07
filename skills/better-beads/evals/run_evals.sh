#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: run_evals.sh [routing|quality]

Runs Better Beads executable eval harnesses.
With no suite, runs all default evals.
EOF
}

case "${1:-}" in
  routing)
    shift
    python3 "$SCRIPT_DIR/routing_eval.py" "$@"
    ;;
  quality)
    shift
    python3 "$SCRIPT_DIR/quality_eval.py" "$@"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    "$0" routing
    "$0" quality
    ;;
  *)
    echo "Unknown eval suite: $1" >&2
    usage
    exit 2
    ;;
esac
