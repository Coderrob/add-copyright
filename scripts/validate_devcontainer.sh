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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly DEVCONTAINER_CLI_VERSION="${DEVCONTAINER_CLI_VERSION:-0.88.0}"

# run_devcontainer: Runs the pinned official Dev Container CLI.
# Arguments: devcontainer_cli_arguments...
run_devcontainer() {
  npx --yes "@devcontainers/cli@$DEVCONTAINER_CLI_VERSION" "$@"
}

cd "$ROOT_DIR"

echo "Building the complete devcontainer with Dev Container CLI $DEVCONTAINER_CLI_VERSION..."
run_devcontainer build --workspace-folder .

echo "Recreating the devcontainer from the validated image..."
run_devcontainer up --workspace-folder . --remove-existing-container

echo "Running unit and action-integration tests inside the devcontainer..."
run_devcontainer exec --workspace-folder . \
  bash -lc './scripts/run_tests.sh && ./scripts/run_act_test.sh'
