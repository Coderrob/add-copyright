#!/usr/bin/env bash
set -euo pipefail

readonly WORKFLOW_FILE=".github/workflows/ci.yml"
readonly JOB_NAME="action-integration"
readonly ACT="act"

# require_act: Checks if the 'act' command is available.
require_act() {
  command -v "$ACT" >/dev/null 2>&1 && return 0

  echo "act not found. In the devcontainer this feature is provided by the devcontainer feature 'act'. Start the devcontainer in VS Code or install act locally: https://github.com/nektos/act" >&2
  exit 2
}

# run_act: Runs the GitHub Actions workflow using act.
run_act() {
  local output_file="$1"
  echo "Running act for workflow: $WORKFLOW_FILE (job: $JOB_NAME)"

  if ! "$ACT" \
    -P ubuntu-latest=catthehacker/ubuntu:act-latest \
    -s GITHUB_TOKEN="" \
    -W .github/workflows \
    -j "$JOB_NAME" 2>&1 | tee "$output_file"; then
    echo "act failed" >&2
    echo "---- act output (tail) ----"
    tail -n 200 "$output_file"
    exit 3
  fi
}

# assert_updated_file: Asserts that the action reported updating the expected file.
assert_updated_file() {
  local output_file="$1"
  if ! grep -E "Updated: .*src/example.js" "$output_file" >/dev/null 2>&1; then
    echo "FAIL: action did not report updating src/example.js" >&2
    echo "---- act output (tail) ----"
    tail -n 200 "$output_file"
    exit 4
  fi
}

# assert_output_content: Asserts that the output contains expected copyright and license information.
assert_output_content() {
  local output_file="$1"
  local year
  year=$(date +%Y)
  local expected_copyright_line="Copyright (c) $year Test Runner"
  local expected_license_token="MIT"

  if grep -F "$expected_copyright_line" "$output_file" >/dev/null 2>&1 \
    && grep -F "$expected_license_token" "$output_file" >/dev/null 2>&1; then
    echo "PASS: file contains expected copyright line and SPDX token"
    return 0
  fi

  echo "FAIL: file content does not contain expected copyright or SPDX token" >&2
  echo "Expected copyright line: $expected_copyright_line"
  echo "Expected license token: $expected_license_token"
  echo "---- act output (tail) ----"
  tail -n 200 "$output_file"
  exit 5
}

# main: Main function that runs the act test.
main() {
  local output_file
  output_file="$(mktemp)"
  # The trusted mktemp path is intentionally captured while the local exists.
  # shellcheck disable=SC2064
  trap "rm -f '$output_file'" EXIT
  require_act
  run_act "$output_file"

  echo "Act finished, running assertions..."
  assert_updated_file "$output_file"
  assert_output_content "$output_file"
}

main "$@"
