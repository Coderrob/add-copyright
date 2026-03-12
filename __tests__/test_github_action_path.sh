#!/usr/bin/env bash
# filepath: __tests__/test_github_action_path.sh

# Tests GITHUB_ACTION_PATH license lookup for remote action invocations.
# When a user calls this action from a remote repository, GitHub Actions sets
# GITHUB_ACTION_PATH to the path where the action is checked out.

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

LICENSE_TYPE="apache-2.0"
COPYRIGHT_HOLDER="Action Path User"
EXPECTED_HEADER="Copyright $(date +"%Y") $COPYRIGHT_HOLDER"

ACTION_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Test 1: GITHUB_ACTION_PATH is used when set
test_github_action_path_lookup() {
  local test_dir
  test_dir="$(mktemp -d)"
  local src_file="$test_dir/app.ts"

  write_file "$src_file" "export const greet = () => 'Hi!';"

  export GITHUB_ACTION_PATH="$ACTION_ROOT"
  if run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"; then
    assert_contains "$src_file" "$EXPECTED_HEADER"
    pass "GITHUB_ACTION_PATH license lookup works correctly"
  else
    fail "GITHUB_ACTION_PATH license lookup failed"
  fi
  unset GITHUB_ACTION_PATH

  remove_dir "$test_dir"
}

# Test 2: Script falls back to SCRIPT_DIR when GITHUB_ACTION_PATH is not set
test_fallback_to_script_dir() {
  local test_dir
  test_dir="$(mktemp -d)"
  local src_file="$test_dir/main.py"

  write_file "$src_file" "print('hello')"

  if run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"; then
    assert_contains "$src_file" "$EXPECTED_HEADER"
    pass "Script correctly falls back to SCRIPT_DIR when GITHUB_ACTION_PATH is unset"
  else
    fail "Script failed when GITHUB_ACTION_PATH is unset"
  fi

  remove_dir "$test_dir"
}

# Test 3: Invalid GITHUB_ACTION_PATH results in error
test_invalid_github_action_path() {
  local test_dir
  test_dir="$(mktemp -d)"
  local src_file="$test_dir/index.js"

  write_file "$src_file" "console.log('test');"

  export GITHUB_ACTION_PATH="/nonexistent/path"
  if run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER" 2>/dev/null; then
    unset GITHUB_ACTION_PATH
    fail "Expected failure with invalid GITHUB_ACTION_PATH"
  else
    unset GITHUB_ACTION_PATH
    pass "Invalid GITHUB_ACTION_PATH correctly results in error"
  fi

  remove_dir "$test_dir"
}

test_github_action_path_lookup
test_fallback_to_script_dir
test_invalid_github_action_path
