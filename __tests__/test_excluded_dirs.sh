#!/usr/bin/env bash
# filepath: __tests__/test_excluded_dirs.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TEST_DIR="__tests__/test_excluded_dirs"
LICENSE_TYPE="MIT"
COPYRIGHT_HOLDER="Excluded Dir User"
EXPECTED_LINE="Copyright (c) $(current_year) $COPYRIGHT_HOLDER"

# Test 1: node_modules directory is excluded
test_node_modules_excluded() {
  local test_dir="$TEST_DIR/test_node_modules"
  local included_file="$test_dir/src/app.js"
  local excluded_file="$test_dir/node_modules/lib.js"

  create_workspace "$test_dir"
  write_file "$included_file" "console.log('app');"
  write_file "$excluded_file" "module.exports = {};"

  run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

  assert_contains "$included_file" "$EXPECTED_LINE"
  assert_not_contains "$excluded_file" "$EXPECTED_LINE"
  assert_contains "$excluded_file" "module.exports = {};"
  pass "node_modules directory is excluded from processing"

  remove_dir "$test_dir"
}

# Test 2: .git directory is excluded
test_git_dir_excluded() {
  local test_dir="$TEST_DIR/test_git_dir"
  local included_file="$test_dir/main.py"
  local excluded_file="$test_dir/.git/hooks/pre-commit"

  create_workspace "$test_dir"
  write_file "$included_file" "print('hello')"
  write_file "$excluded_file" "#!/bin/sh"

  run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

  assert_contains "$included_file" "$EXPECTED_LINE"
  assert_not_contains "$excluded_file" "$EXPECTED_LINE"
  assert_contains "$excluded_file" "#!/bin/sh"
  pass ".git directory is excluded from processing"

  remove_dir "$test_dir"
}

# Test 3: dist directory is excluded
test_dist_dir_excluded() {
  local test_dir="$TEST_DIR/test_dist_dir"
  local included_file="$test_dir/src/index.ts"
  local excluded_file="$test_dir/dist/index.js"

  create_workspace "$test_dir"
  write_file "$included_file" "export const x = 1;"
  write_file "$excluded_file" "exports.x = 1;"

  run_copyright "$test_dir" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"

  assert_contains "$included_file" "$EXPECTED_LINE"
  assert_not_contains "$excluded_file" "$EXPECTED_LINE"
  assert_contains "$excluded_file" "exports.x = 1;"
  pass "dist directory is excluded from processing"

  remove_dir "$test_dir"
}

remove_dir "$TEST_DIR"
mkdir -p "$TEST_DIR"

test_node_modules_excluded
test_git_dir_excluded
test_dist_dir_excluded

remove_dir "$TEST_DIR"
