#!/usr/bin/env bash
# filepath: __tests__/test_copyright.sh

set -euo pipefail

# --- Test Setup ---
TEST_DIR="__tests__/test_workspace"
SRC_FILE="$TEST_DIR/hello.ts"
LICENSE_TYPE="apache-2.0"
COPYRIGHT_HOLDER="Test User"
EXPECTED_HEADER="Copyright (c) $(date +"%Y") $COPYRIGHT_HOLDER"

cleanup() {
  rm -rf "$TEST_DIR"
}

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
"$(dirname "$0")/../scripts/copyright.sh" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
if [ "$(grep -c "$EXPECTED_HEADER" "$SRC_FILE")" -eq 1 ]; then
  echo "[PASS] Header not duplicated on second run"
else
  echo "[FAIL] Header duplicated on second run" >&2
  cat "$SRC_FILE" || true
  exit 1
fi

# Clean up at the end, not via trap
cleanup
