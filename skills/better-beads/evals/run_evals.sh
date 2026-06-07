#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: run_evals.sh routing

Runs Better Beads executable eval harnesses.
EOF
}

case "${1:-}" in
  routing)
    shift
    python3 "$SCRIPT_DIR/routing_eval.py" "$@"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    usage
    exit 2
    ;;
  *)
    echo "Unknown eval suite: $1" >&2
    usage
    exit 2
    ;;
esac
