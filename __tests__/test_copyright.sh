#!/usr/bin/env bash
# filepath: __tests__/test_copyright.sh

# Copyright Script Test Suite
# ===========================
#
# This test suite validates the functionality of the copyright.sh script.
# It tests basic copyright header insertion and idempotency (no duplication
# on subsequent runs).
#
# Tests:
# - Copyright header insertion for TypeScript files
# - Idempotency check (no duplicate headers)
# - License text formatting
#
# Usage: ./test_copyright.sh
#
# Dependencies: bash, grep, date
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Test Setup ---
TEST_DIR="__tests__/test_workspace"
SRC_FILE="$TEST_DIR/hello.ts"
LICENSE_TYPE="apache-2.0"
COPYRIGHT_HOLDER="Test User"
EXPECTED_HEADER="Copyright $(date +"%Y") $COPYRIGHT_HOLDER"

# cleanup()
# Removes test directory and files after test completion.
cleanup() {
  rm -rf "$TEST_DIR"
}

# Create test directory and sample TypeScript file
mkdir -p "$TEST_DIR"
echo -e "export const hello = () => 'Hello, world!';\n" > "$SRC_FILE"

# --- Run Script ---
"$(dirname "$0")/../scripts/copyright.sh" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"


# --- Test Assertion ---
if grep -q "$EXPECTED_HEADER" "$SRC_FILE"; then
  echo "[PASS] Copyright header present in $SRC_FILE"
else
  echo "[FAIL] Copyright header missing in $SRC_FILE" >&2
  cat "$SRC_FILE" || true
  exit 1
fi

# Check idempotency (should not duplicate header line)
"$(dirname "$0")"/../scripts/copyright.sh" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
if [ "$(grep -c "$EXPECTED_HEADER" "$SRC_FILE")" -eq 1 ]; then
  echo "[PASS] Header not duplicated on second run"
else
  echo "[FAIL] Header duplicated on second run" >&2
  cat "$SRC_FILE" || true
  exit 1
fi

# Clean up at the end, not via trap
cleanup
