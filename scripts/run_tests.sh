#!/usr/bin/env bash
# filepath: scripts/run_tests.sh

# Test Runner Script
# ==================
#
# Runs the BATS suite and shell quality checks.
#
# Usage: ./run_tests.sh
#
# Dependencies: bash, bats, shellcheck
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly TEST_DIR="$ROOT_DIR/scripts/tests"

# require_test_tools: Verifies that the BATS runner and ShellCheck are available.
require_test_tools() {
  command -v bats >/dev/null 2>&1
  command -v shellcheck >/dev/null 2>&1
}

# main: Runs static shell validation followed by the complete BATS suite.
main() {
  require_test_tools
  "$ROOT_DIR/scripts/check_shell_quality.sh"
  shellcheck "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/scripts/tests/*.bash
  bats "$TEST_DIR"
}

main "$@"
