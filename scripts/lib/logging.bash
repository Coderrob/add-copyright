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


# log_message: Writes one timestamped operational message to standard error.
# Arguments: level, message...
log_message() {
  local level="$1"
  shift
  printf '%s [%s] %s: %s\n' \
    "$(date +'%Y-%m-%dT%H:%M:%S%z')" "${SCRIPT_NAME:-shell}" "$level" "$*" >&2
}

# log_info: Writes an informational operational message.
# Arguments: message...
log_info() { log_message "INFO" "$@"; }

# log_warn: Writes a recoverable-warning operational message.
# Arguments: message...
log_warn() { log_message "WARN" "$@"; }

# log_error: Writes a failure-oriented operational message.
# Arguments: message...
log_error() { log_message "ERROR" "$@"; }

# log_debug: Writes a diagnostic message when DEBUG equals one.
# Arguments: message...
log_debug() { [[ "${DEBUG:-}" == "1" ]] && log_message "DEBUG" "$@"; }
