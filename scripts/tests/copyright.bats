#!/usr/bin/env bats

load test_helper

# setup: Creates an isolated workspace before each copyright test.
setup() {
  TEST_WORKSPACE="$(mktemp -d)"
}

# teardown: Removes the isolated copyright-test workspace.
teardown() {
  rm -rf "$TEST_WORKSPACE"
}

@test "adds an MIT header and preserves JavaScript source" {
  create_source "example.js" "console.log('hello');"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  assert_file_contains "example.js" "Copyright (c) $(date +%Y) BATS Runner"
  assert_file_contains "example.js" "Permission is hereby granted"
  assert_file_contains "example.js" "console.log('hello');"
}

@test "is idempotent" {
  create_source "example.py" "print('hello')"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  cp "$(source_path example.py)" "$BATS_TEST_TMPDIR/example.py.first-run"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary: 0 files updated, 1 files skipped, 0 errors."* ]]
  cmp "$BATS_TEST_TMPDIR/example.py.first-run" "$(source_path example.py)"
}

@test "supports Apache placeholder substitution" {
  create_source "example.ts" "export const value = 1;"
  run_copyright apache-2.0 "ACME/Corp & Co"
  [ "$status" -eq 0 ]
  assert_file_contains "example.ts" "Copyright $(date +%Y) ACME/Corp & Co"
}

@test "respects gitignore" {
  create_source ".gitignore" "ignored.py"
  create_source "ignored.py" "print('ignored')"
  git -C "$TEST_WORKSPACE" init -q
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  ! grep -Fq "Copyright" "$(source_path ignored.py)"
}

@test "skips unsupported extensions" {
  create_source "notes.unsupported" "untouched"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  [ "$(<"$(source_path notes.unsupported)")" = "untouched" ]
}

@test "rejects a missing directory" {
  run "$COPYRIGHT_SCRIPT" "$TEST_WORKSPACE/missing" MIT "BATS Runner"
  [ "$status" -ne 0 ]
}

@test "rejects an unknown license" {
  create_source "example.py" "print('hello')"
  run_copyright NOT-A-LICENSE "BATS Runner"
  [ "$status" -ne 0 ]
}

@test "rejects missing arguments" {
  run "$COPYRIGHT_SCRIPT"
  [ "$status" -ne 0 ]
}

@test "runs outside a git repository" {
  create_source "example.go" "package main"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  assert_file_contains "example.go" "Copyright (c) $(date +%Y) BATS Runner"
}
