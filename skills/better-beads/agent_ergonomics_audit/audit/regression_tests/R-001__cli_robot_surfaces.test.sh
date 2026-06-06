#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
cd "$TARGET"

bash scripts/test_cli_robot_surfaces.sh
