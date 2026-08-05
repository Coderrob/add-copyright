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

@test "excludes dependency and generated directories" {
  create_source "src/app.js" "console.log('app');"
  create_source "node_modules/library.js" "module.exports = {};"
  create_source "dist/app.js" "generated"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  assert_file_contains "src/app.js" "Copyright (c) $(date +%Y) BATS Runner"
  ! grep -Fq "Copyright" "$(source_path node_modules/library.js)"
  ! grep -Fq "Copyright" "$(source_path dist/app.js)"
}

@test "adds the current notice when only an old year exists" {
  local old_year=$(( $(date +%Y) - 1 ))
  create_source "example.ts" "// Copyright (c) $old_year BATS Runner
export const value = 1;"
  run_copyright MIT "BATS Runner"
  [ "$status" -eq 0 ]
  assert_file_contains "example.ts" "Copyright (c) $(date +%Y) BATS Runner"
  assert_file_contains "example.ts" "Copyright (c) $old_year BATS Runner"
}

@test "resolves licenses from the GitHub action checkout" {
  create_source "example.py" "print('remote action')"
  run env GITHUB_ACTION_PATH="$PROJECT_ROOT" "$COPYRIGHT_SCRIPT" \
    "$TEST_WORKSPACE" MIT "Remote Runner"
  [ "$status" -eq 0 ]
  assert_file_contains "example.py" "Copyright (c) $(date +%Y) Remote Runner"
}

@test "rejects an invalid GitHub action checkout path" {
  create_source "example.py" "print('remote action')"
  run env GITHUB_ACTION_PATH="$TEST_WORKSPACE/missing-action" \
    "$COPYRIGHT_SCRIPT" "$TEST_WORKSPACE" MIT "Remote Runner"
  [ "$status" -ne 0 ]
}

@test "publishes structured action outputs" {
  create_source "example.py" "print('outputs')"
  local output_file="$BATS_TEST_TMPDIR/github-output"
  run env GITHUB_OUTPUT="$output_file" "$COPYRIGHT_SCRIPT" \
    "$TEST_WORKSPACE" MIT "Output Runner"
  [ "$status" -eq 0 ]
  grep -qx 'updated-count=1' "$output_file"
  grep -qx 'skipped-count=0' "$output_file"
  grep -qx 'error-count=0' "$output_file"
  grep -qx 'changed=true' "$output_file"
}

@test "comment-style manifest is unique and loadable" {
  local manifest="$PROJECT_ROOT/scripts/config/comment-styles.tsv"
  [ "$(awk -F '\t' '!/^#/ { print $1 }' "$manifest" | sort | uniq -d | wc -l)" -eq 0 ]
  [ "$(awk -F '\t' '!/^#/ && NF == 2 { count++ } END { print count }' "$manifest")" -ge 18 ]
}
