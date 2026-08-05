#!/usr/bin/env bash

# Validates the calling-repository fixture used by action integration tests.
# Usage: ./validate_action_fixture.sh <capture|verify> <source-dir> <snapshot-dir>

set -euo pipefail

# assert_contains: Verifies that a file contains literal expected text.
# Arguments: file_path, expected_text
assert_contains() {
  grep -Fq "$2" "$1" || { printf 'Missing expected text in %s: %s\n' "$1" "$2" >&2; return 1; }
}

# capture_fixture: Validates first-run content and stores immutable snapshots.
# Arguments: source_directory, snapshot_directory
capture_fixture() {
  local source_dir="$1" snapshot_dir="$2" year
  year="$(date +%Y)"
  assert_contains "$source_dir/example.js" "Copyright (c) $year Test Runner"
  assert_contains "$source_dir/example.py" "Copyright (c) $year Test Runner"
  assert_contains "$source_dir/example.js" "Permission is hereby granted, free of charge"
  assert_contains "$source_dir/example.py" "Permission is hereby granted, free of charge"
  assert_contains "$source_dir/example.js" "// sample"
  assert_contains "$source_dir/example.py" 'print("sample")'
  [[ -n "$(git status --porcelain -- "$source_dir")" ]]
  mkdir -p "$snapshot_dir"
  cp "$source_dir/example.js" "$snapshot_dir/example.js"
  cp "$source_dir/example.py" "$snapshot_dir/example.py"
}

# verify_fixture: Confirms a second action run is byte-for-byte idempotent.
# Arguments: source_directory, snapshot_directory
verify_fixture() {
  cmp "$2/example.js" "$1/example.js"
  cmp "$2/example.py" "$1/example.py"
}

# main: Validates arguments and dispatches the requested fixture operation.
# Arguments: operation, source_directory, snapshot_directory
main() {
  [[ $# -eq 3 ]] || { printf 'Usage: %s <capture|verify> <source-dir> <snapshot-dir>\n' "$0" >&2; return 2; }
  case "$1" in
    capture) capture_fixture "$2" "$3" ;;
    verify) verify_fixture "$2" "$3" ;;
    *) printf 'Unknown operation: %s\n' "$1" >&2; return 2 ;;
  esac
}

main "$@"
