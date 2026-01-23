#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_FILE=".github/workflows/ci.yml"
JOB_NAME="action-integration"
ACT_OUTPUT_FILE=""

# cleanup: Removes temporary output files created during execution.
cleanup() {
  [[ -n "$ACT_OUTPUT_FILE" && -f "$ACT_OUTPUT_FILE" ]] && rm -f "$ACT_OUTPUT_FILE"
}

trap cleanup EXIT

# require_act: Checks if the 'act' command is available.
require_act() {
  if command -v act >/dev/null 2>&1; then
    ACT=act
    return 0
  fi

  echo "act not found. In the devcontainer this feature is provided by the devcontainer feature 'act'. Start the devcontainer in VS Code or install act locally: https://github.com/nektos/act" >&2
  exit 2
}

# prepare_workspace: Prepares the workspace by creating necessary directories.
prepare_workspace() {
  mkdir -p src
  local pre_count
  pre_count=$(find src -type f | wc -l || true)
  echo "Pre-run files: $pre_count"
}

# run_act: Runs the GitHub Actions workflow using act.
run_act() {
  echo "Running act for workflow: $WORKFLOW_FILE (job: $JOB_NAME)"
  ACT_OUTPUT_FILE=$(mktemp)

  if ! "$ACT" -s GITHUB_TOKEN="" -W .github/workflows -j "$JOB_NAME" 2>&1 | tee "$ACT_OUTPUT_FILE"; then
    echo "act failed" >&2
    echo "---- act output (tail) ----"
    tail -n 200 "$ACT_OUTPUT_FILE"
    exit 3
  fi
}

# assert_updated_file: Asserts that the action reported updating the expected file.
assert_updated_file() {
  if ! grep -E "Updated: .*src/example.js" "$ACT_OUTPUT_FILE" >/dev/null 2>&1; then
    echo "FAIL: action did not report updating src/example.js" >&2
    echo "---- act output (tail) ----"
    tail -n 200 "$ACT_OUTPUT_FILE"
    exit 4
  fi
}

# assert_output_content: Asserts that the output contains expected copyright and license information.
assert_output_content() {
  local year
  year=$(date +%Y)
  local expected_copyright_line="Copyright (c) $year Test Runner"
  local expected_license_token="MIT"

  if grep -F "$expected_copyright_line" "$ACT_OUTPUT_FILE" >/dev/null 2>&1 \
    && grep -F "$expected_license_token" "$ACT_OUTPUT_FILE" >/dev/null 2>&1; then
    echo "PASS: file contains expected copyright line and SPDX token"
    return 0
  fi

  echo "FAIL: file content does not contain expected copyright or SPDX token" >&2
  echo "Expected copyright line: $expected_copyright_line"
  echo "Expected license token: $expected_license_token"
  echo "---- act output (tail) ----"
  tail -n 200 "$ACT_OUTPUT_FILE"
  exit 5
}

# main: Main function that runs the act test.
main() {
  require_act
  prepare_workspace
  run_act

  echo "Act finished, running assertions..."
  assert_updated_file
  assert_output_content
}

main "$@"
