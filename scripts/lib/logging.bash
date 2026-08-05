#!/usr/bin/env bash

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
