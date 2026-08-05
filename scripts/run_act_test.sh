#!/usr/bin/env bash
# add-copyright: begin
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Robert Lindley
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# add-copyright: end

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

# assert_structured_outputs: Asserts first-run and idempotent action result counts.
assert_structured_outputs() {
  local output_file="$1"
  if grep -F '::set-output:: updated-count=2' "$output_file" >/dev/null 2>&1 \
    && grep -F '::set-output:: skipped-count=2' "$output_file" >/dev/null 2>&1; then
    echo "PASS: action published first-run and idempotent result counts"
    return 0
  fi

  echo "FAIL: action did not publish expected structured outputs" >&2
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
  assert_structured_outputs "$output_file"
}

main "$@"
