#!/usr/bin/env bash
# filepath: __tests__/helpers.sh

# Test Helper Functions
# =====================
#
# Common utility functions used by test scripts.
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# fail: Prints a failure message and exits with code 1.
# Arguments: message
fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

# pass: Prints a success message.
# Arguments: message
pass() {
  echo "[PASS] $*"
}

# create_workspace: Creates a clean test workspace directory.
# Arguments: directory_path
create_workspace() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
}

# remove_dir: Removes a directory and all its contents.
# Arguments: directory_path
remove_dir() {
  rm -rf "$1"
}

# write_file: Writes content to a file, creating parent directories if needed.
# Arguments: file_path, content
write_file() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
}

# init_git_repo: Initializes a git repository in the specified directory.
# Arguments: directory_path
init_git_repo() {
  local dir="$1"
  (
    cd "$dir"
    git init -q
    git config user.name "Test Runner"
    git config user.email "testrunner@example.com"
  )
}

# run_copyright: Runs the copyright script with the given parameters.
# Arguments: directory, license_type, copyright_holder
run_copyright() {
  local dir="$1" license="$2" holder="$3"
  "$(dirname "$0")/../scripts/copyright.sh" "$dir" "$license" "$holder"
}

# assert_contains: Asserts that a file contains the specified text.
# Arguments: file_path, expected_text
assert_contains() {
  local file="$1" text="$2"
  grep -Fq "$text" "$file" || fail "Expected '$text' in $file"
}

# assert_not_contains: Asserts that a file does not contain the specified text.
# Arguments: file_path, unexpected_text
assert_not_contains() {
  local file="$1" text="$2"
  if grep -Fq "$text" "$file"; then
    fail "Did not expect '$text' in $file"
  fi
}

# current_year: Returns the current year as a 4-digit number.
current_year() {
  date +%Y
}
