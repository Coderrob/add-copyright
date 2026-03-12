#!/usr/bin/env bash
# filepath: scripts/run_tests.sh

# Test Runner Script
# ==================
#
# Runs all test scripts in the __tests__ directory.
#
# Usage: ./run_tests.sh
#
# Dependencies: bash
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT_DIR/__tests__"

# main: Main execution that runs all test files.
if [[ ! -d "$TEST_DIR" ]]; then
  echo "Test directory not found: $TEST_DIR" >&2
  exit 2
fi

shopt -s nullglob
test_files=( "$TEST_DIR"/test_*.sh )
shopt -u nullglob

if (( ${#test_files[@]} == 0 )); then
  echo "No test files found in $TEST_DIR" >&2
  exit 3
fi

for test_file in "${test_files[@]}"; do
  echo "Running $test_file"
  bash "$test_file"
  echo ""
done

echo "All tests passed."
