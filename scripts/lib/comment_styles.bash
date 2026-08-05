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


# load_comment_styles: Loads the extension manifest into an associative array.
# Arguments: manifest_path, destination_array_name
load_comment_styles() {
  local manifest_path="$1"
  local -n destination="$2"
  local extension style
  while IFS=$'\t' read -r extension style; do
    [[ -z "$extension" || "$extension" == \#* ]] && continue
    # shellcheck disable=SC2034 # The caller consumes the nameref destination.
    destination["$extension"]="$style"
  done < "$manifest_path"
}

# comment_style_for: Prints the configured comment style for an extension.
# Arguments: extension, associative_array_name
comment_style_for() {
  local extension="$1"
  local -n styles="$2"
  printf '%s' "${styles[$extension]:-}"
}
