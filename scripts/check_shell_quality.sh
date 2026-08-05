#!/usr/bin/env bash
# Enforces documented Bash functions, a 25-line limit, and complexity below 4.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly CHECKER="$ROOT_DIR/scripts/quality/shell_quality.awk"

mapfile -d '' shell_files < <(find "$ROOT_DIR/scripts" -type f \
  \( -name '*.sh' -o -name '*.bash' \) -print0)

awk -f "$CHECKER" "${shell_files[@]}"
