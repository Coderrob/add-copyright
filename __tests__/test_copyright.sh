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
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/../scripts/copyright.sh"
TEST_DIR="$(mktemp -d)"
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
echo -e "export const hello = () => 'Hello, world!';\n" > "$SRC_FILE"

# --- Run Script ---
"$SCRIPT_PATH" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"


# --- Test Assertion ---
if grep -q "$EXPECTED_HEADER" "$SRC_FILE"; then
  echo "[PASS] Copyright header present in $SRC_FILE"
else
  echo "[FAIL] Copyright header missing in $SRC_FILE" >&2
  cat "$SRC_FILE" || true
  cleanup
  exit 1
fi

# Check idempotency (should not duplicate header line)
"$SCRIPT_PATH" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
if [ "$(grep -c "$EXPECTED_HEADER" "$SRC_FILE")" -eq 1 ]; then
  echo "[PASS] Header not duplicated on second run"
else
  echo "[FAIL] Header duplicated on second run" >&2
  cat "$SRC_FILE" || true
  cleanup
  exit 1
fi

# --- Test: GITHUB_ACTION_PATH license lookup ---
# Simulate a remote action by setting GITHUB_ACTION_PATH to the action root,
# which is where GitHub Actions will place the checked-out action when invoked
# from a remote repository.
ACTION_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_ACTION_PATH_TEST_DIR="$(mktemp -d)"
GA_SRC_FILE="$GITHUB_ACTION_PATH_TEST_DIR/app.ts"
echo -e "export const greet = () => 'Hi!';\n" > "$GA_SRC_FILE"

if GITHUB_ACTION_PATH="$ACTION_ROOT" "$SCRIPT_PATH" "$GITHUB_ACTION_PATH_TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"; then
  if grep -q "$EXPECTED_HEADER" "$GA_SRC_FILE"; then
    echo "[PASS] GITHUB_ACTION_PATH license lookup works correctly"
  else
    echo "[FAIL] GITHUB_ACTION_PATH license lookup failed to insert header" >&2
    cat "$GA_SRC_FILE" || true
    rm -rf "$GITHUB_ACTION_PATH_TEST_DIR"
    cleanup
    exit 1
  fi
else
  echo "[FAIL] Script exited with error when GITHUB_ACTION_PATH is set" >&2
  rm -rf "$GITHUB_ACTION_PATH_TEST_DIR"
  cleanup
  exit 1
fi
rm -rf "$GITHUB_ACTION_PATH_TEST_DIR"

# Clean up at the end, not via trap
cleanup
