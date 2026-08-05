#!/usr/bin/env bash
# filepath: scripts/update_licenses.sh

# SPDX License Database Update Script
# ===================================
#
# Updates the local license database by fetching the latest license data
# from the official SPDX License List Data repository.
#
# Usage: ./update_licenses.sh
#
# Dependencies: git, jq, find, gzip, zcat, mktemp
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Constants ---
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SPDX_REPO="${SPDX_REPO:-https://github.com/spdx/license-list-data.git}"
readonly SPDX_JSON_DIR="json/details"
readonly LOCAL_LICENSES_DIR="licenses"
TMP_DIR="$(mktemp -d)"
readonly TMP_DIR
readonly SPDX_CLONE_DIR="$TMP_DIR/spdx-license-list-data"

# --- Logging ---
# log: Logs a message with timestamp, script name, and log level.
log() {
  local level="$1"; shift
  printf '%s [%s] %s: %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$SCRIPT_NAME" "$level" "$*" >&2
}
# log_info: Logs an informational message.
log_info() { log "INFO" "$@"; }
# log_warn: Logs a warning message.
log_warn() { log "WARN" "$@"; }
# log_error: Logs an error message.
log_error() { log "ERROR" "$@"; }

# --- Error Handling ---
# cleanup: Removes temporary directories created during execution.
cleanup() {
  rm -rf "$TMP_DIR"
}

# on_error: Handles script errors by logging the error and exiting.
on_error() {
  log_error "Error on line $LINENO: $BASH_COMMAND"
  exit 1
}

trap on_error ERR
trap cleanup EXIT

# --- Dependencies ---
# require_cmd: Checks if a command is available in the system PATH.
# Arguments: command_name
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

# report_missing_command: Prints installation guidance for one dependency.
# Arguments: command_name
report_missing_command() {
  if [[ "$1" != "jq" ]]; then
    log_error "Missing required command: $1"
    return 0
  fi
  log_error "Missing required command: jq"
  log_error "Install jq with your system package manager."
}

# require_cmds: Verifies that all required commands are installed.
require_cmds() {
  local cmd
  for cmd in git jq find gzip zcat mktemp; do
    if ! require_cmd "$cmd"; then
      report_missing_command "$cmd"
      exit 2
    fi
  done
}

# --- SPDX Sync ---
# clone_spdx_repo: Clones the SPDX license-list-data repository.
clone_spdx_repo() {
  log_info "Cloning SPDX license-list-data repository..."
  git clone --depth 1 "$SPDX_REPO" "$SPDX_CLONE_DIR"
}

# spdx_json_dir: Returns the path to the SPDX JSON details directory.
spdx_json_dir() {
  printf '%s' "$SPDX_CLONE_DIR/$SPDX_JSON_DIR"
}

# ensure_spdx_json_dir: Ensures the SPDX JSON directory exists and returns its path.
ensure_spdx_json_dir() {
  local dir
  dir="$(spdx_json_dir)"
  [[ -d "$dir" ]] || { log_error "SPDX json details directory not found: $dir"; exit 3; }
  printf '%s' "$dir"
}

# reset_local_license_dir: Removes and recreates the local licenses directory.
reset_local_license_dir() {
  rm -rf "$LOCAL_LICENSES_DIR"
  mkdir -p "$LOCAL_LICENSES_DIR"
}

# sync_license_files: Compresses SPDX JSON details into the runtime database.
# Arguments: source_directory
sync_license_files() {
  local src_dir="$1"
  local source_file
  while IFS= read -r -d '' source_file; do
    gzip -c "$source_file" > "$LOCAL_LICENSES_DIR/$(basename "$source_file").gz"
  done < <(find "$src_dir" -name "*.json" -print0)
  log_info "Compressed $(count_local_licenses) license detail files"
}

# count_local_licenses: Counts compressed license records in the local database.
count_local_licenses() {
  find "$LOCAL_LICENSES_DIR" -name "*.json.gz" | wc -l
}

# --- Root LICENSE ---
# root_license_exists: Checks if a root LICENSE file already exists.
root_license_exists() {
  [[ -f LICENSE || -f LICENSE.md || -f LICENSE.txt ]]
}

# candidate_license: Determines the candidate license based on package.json or defaults to Apache-2.0.
candidate_license() {
  local candidate="Apache-2.0"
  if [[ -f package.json ]]; then
    local lic
    lic="$(jq -r '.license // empty' package.json 2>/dev/null || true)"
    [[ -n "$lic" ]] && candidate="$lic"
  fi
  printf '%s' "$candidate"
}

# create_root_license_if_missing: Creates a root LICENSE file if it doesn't exist.
create_root_license_if_missing() {
  if root_license_exists; then
    log_info "Root LICENSE file already present; skipping creation."
    return 0
  fi

  local candidate
  candidate="$(candidate_license)"
  local jsonfile="$LOCAL_LICENSES_DIR/${candidate}.json.gz"
  if [[ ! -f "$jsonfile" ]]; then
    log_warn "Candidate license json not found ($jsonfile); will not create root LICENSE."
    return 0
  fi

  log_info "Creating root LICENSE using $candidate"
  zcat "$jsonfile" | jq -r '.licenseText' > LICENSE
}

# --- Reporting ---
# list_updated_licenses: Lists all updated license identifiers in sorted order.
list_updated_licenses() {
  find "$LOCAL_LICENSES_DIR" -name "*.json.gz" -exec basename {} \; \
    | while IFS= read -r name; do printf '%s\n' "${name%.json.gz}"; done \
    | sort
}

# --- Main ---
# main: Main function that orchestrates the license update process.
main() {
  log_info "Starting license update process..."
  require_cmds
  clone_spdx_repo

  local spdx_dir
  spdx_dir="$(ensure_spdx_json_dir)"

  reset_local_license_dir
  sync_license_files "$spdx_dir"
  create_root_license_if_missing

  log_info "License update complete. $(count_local_licenses) license json detail files synced."
  log_info "Updated licenses:"
  list_updated_licenses
}

main "$@"
