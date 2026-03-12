#!/usr/bin/env bash
# filepath: __tests__/test_copyright.sh

set -euo pipefail

# --- Test Setup ---
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/../scripts/copyright.sh"
TEST_DIR="$(mktemp -d)"
GITHUB_ACTION_PATH_TEST_DIR=""
SRC_FILE="$TEST_DIR/hello.ts"
LICENSE_TYPE="apache-2.0"
COPYRIGHT_HOLDER="Test User"
EXPECTED_HEADER="Copyright $(date +"%Y") $COPYRIGHT_HOLDER"

# cleanup()
# Removes test directory and files after test completion.
cleanup() {
  [[ -n "$GITHUB_ACTION_PATH_TEST_DIR" ]] && rm -rf "$GITHUB_ACTION_PATH_TEST_DIR"
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Create test directory and sample TypeScript file
echo -e "export const hello = () => 'Hello, world!';\n" > "$SRC_FILE"

# --- Run Script ---
"$SCRIPT_PATH" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

create_workspace "$TEST_DIR"
write_file "$SRC_FILE" "export const hello = () => 'Hello, world!';"

run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
assert_contains "$SRC_FILE" "$EXPECTED_HEADER"
pass "Copyright header present in $SRC_FILE"

# Check idempotency (should not duplicate header line)
"$SCRIPT_PATH" "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
if [ "$(grep -c "$EXPECTED_HEADER" "$SRC_FILE")" -eq 1 ]; then
  echo "[PASS] Header not duplicated on second run"
else
  fail "Header duplicated on second run"
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
    exit 1
  fi
else
  echo "[FAIL] Script exited with error when GITHUB_ACTION_PATH is set" >&2
  exit 1
fi

# Clean up is handled by the EXIT trap
