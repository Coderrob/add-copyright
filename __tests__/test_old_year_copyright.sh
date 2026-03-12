#!/usr/bin/env bash
# filepath: __tests__/test_old_year_copyright.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TEST_DIR="__tests__/test_old_year_copyright"
LICENSE_TYPE="MIT"
COPYRIGHT_HOLDER="Year Test User"
CURRENT="$(current_year)"
OLD_YEAR="$(( CURRENT - 1 ))"
CURRENT_LINE="Copyright (c) $CURRENT $COPYRIGHT_HOLDER"
OLD_LINE="Copyright (c) $OLD_YEAR $COPYRIGHT_HOLDER"

# Test 1: File with current-year copyright is skipped (idempotent)
test_current_year_is_skipped() {
  local test_dir="$TEST_DIR/test_current_year"
  local src_file="$test_dir/app.js"

  create_workspace "$test_dir"
  write_file "$src_file" "// $CURRENT_LINE
console.log('hello');"

  run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

  # Should not have the header added again (header count should stay at 1)
  local count
  count="$(grep -c "$CURRENT_LINE" "$src_file")"
  [[ "$count" -eq 1 ]] || fail "Expected exactly 1 copyright line, found $count"
  pass "File with current-year copyright is not duplicated"

  remove_dir "$test_dir"
}

# Test 2: File with a previous-year copyright gets the new year header prepended
test_old_year_gets_new_header() {
  local test_dir="$TEST_DIR/test_old_year"
  local src_file="$test_dir/lib.ts"

  create_workspace "$test_dir"
  write_file "$src_file" "// $OLD_LINE
export const x = 1;"

  run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

  # The current year header should now be in the file
  assert_contains "$src_file" "$CURRENT_LINE"
  pass "File with old-year copyright receives new-year header"

  remove_dir "$test_dir"
}

# Test 3: File without any copyright gets one added
test_no_copyright_gets_header() {
  local test_dir="$TEST_DIR/test_no_copyright"
  local src_file="$test_dir/utils.py"

  create_workspace "$test_dir"
  write_file "$src_file" "def greet(): return 'hi'"

  run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

  assert_contains "$src_file" "$CURRENT_LINE"
  pass "File without copyright receives new header"

  remove_dir "$test_dir"
}

remove_dir "$TEST_DIR"
mkdir -p "$TEST_DIR"

test_current_year_is_skipped
test_old_year_gets_new_header
test_no_copyright_gets_header

remove_dir "$TEST_DIR"
