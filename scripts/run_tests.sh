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

# filepath: scripts/run_tests.sh

# Test Runner Script
# ==================
#
# Runs the BATS suite and shell quality checks.
#
# Usage: ./run_tests.sh
#
# Dependencies: bash, bats, shellcheck
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly TEST_DIR="$ROOT_DIR/scripts/tests"

# require_test_tools: Verifies that the BATS runner and ShellCheck are available.
require_test_tools() {
  command -v bats >/dev/null 2>&1
  command -v shellcheck >/dev/null 2>&1
}

# main: Runs static shell validation followed by the complete BATS suite.
main() {
  require_test_tools
  "$ROOT_DIR/scripts/check_shell_quality.sh"
  shellcheck "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/scripts/lib/*.bash \
    "$ROOT_DIR"/scripts/tests/*.bash "$ROOT_DIR"/scripts/tests/*.sh
  bats "$TEST_DIR"
}

main "$@"
