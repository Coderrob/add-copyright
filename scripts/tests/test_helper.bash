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


PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
readonly PROJECT_ROOT
readonly COPYRIGHT_SCRIPT="$PROJECT_ROOT/scripts/copyright.sh"

# create_source: Writes source content below the isolated BATS workspace.
# Arguments: relative_path, content
create_source() {
  local path="$TEST_WORKSPACE/$1"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$2" > "$path"
}

# source_path: Returns an absolute path within the isolated BATS workspace.
# Arguments: relative_path
source_path() {
  printf '%s/%s' "$TEST_WORKSPACE" "$1"
}

# run_copyright: Invokes the public copyright CLI against the BATS workspace.
# Arguments: license_identifier, copyright_holder
run_copyright() {
  run "$COPYRIGHT_SCRIPT" "$TEST_WORKSPACE" "$1" "$2"
}

# assert_file_contains: Fails unless a file contains the expected literal text.
# Arguments: relative_path, expected_text
assert_file_contains() {
  grep -Fq "$2" "$(source_path "$1")"
}
