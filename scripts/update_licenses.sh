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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SPDX_REPO="${SPDX_REPO:-https://github.com/spdx/license-list-data.git}"
readonly SPDX_JSON_DIR="json/details"
readonly LOCAL_LICENSES_DIR="licenses"
readonly MIN_LICENSE_COUNT="${MIN_LICENSE_COUNT:-700}"
TMP_DIR="$(mktemp -d "$(pwd)/.license-update.XXXXXX")"
readonly TMP_DIR
readonly SPDX_CLONE_DIR="$TMP_DIR/spdx-license-list-data"
readonly STAGED_LICENSES_DIR="$TMP_DIR/licenses"
readonly BACKUP_LICENSES_DIR="$TMP_DIR/licenses.backup"

# shellcheck source=scripts/lib/logging.bash
source "$SCRIPT_DIR/lib/logging.bash"

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

# sync_license_files: Compresses SPDX JSON details into the runtime database.
# Arguments: source_directory, destination_directory
sync_license_files() {
  local src_dir="$1" destination="$2"
  local source_file
  mkdir -p "$destination"
  while IFS= read -r -d '' source_file; do
    gzip -c "$source_file" > "$destination/$(basename "$source_file").gz"
  done < <(find "$src_dir" -name "*.json" -print0)
  log_info "Compressed $(count_licenses "$destination") license detail files"
}

# count_licenses: Counts compressed license records in a database directory.
# Arguments: license_directory
count_licenses() {
  find "$1" -name "*.json.gz" | wc -l
}

# validate_staged_database: Rejects incomplete or unreadable staged databases.
validate_staged_database() {
  local count
  count="$(count_licenses "$STAGED_LICENSES_DIR")"
  [[ "$count" -ge "$MIN_LICENSE_COUNT" ]] || { log_error "Expected at least $MIN_LICENSE_COUNT licenses; found $count"; return 1; }
  find "$STAGED_LICENSES_DIR" -name '*.json.gz' -print0 \
    | while IFS= read -r -d '' record; do gzip -t "$record"; done
}

# install_staged_database: Replaces the live database and rolls back on failure.
install_staged_database() {
  [[ -d "$LOCAL_LICENSES_DIR" ]] && mv "$LOCAL_LICENSES_DIR" "$BACKUP_LICENSES_DIR"
  if mv "$STAGED_LICENSES_DIR" "$LOCAL_LICENSES_DIR"; then
    return 0
  fi
  [[ -d "$BACKUP_LICENSES_DIR" ]] && mv "$BACKUP_LICENSES_DIR" "$LOCAL_LICENSES_DIR"
  return 1
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

  sync_license_files "$spdx_dir" "$STAGED_LICENSES_DIR"
  validate_staged_database
  install_staged_database
  create_root_license_if_missing

  log_info "License update complete. $(count_licenses "$LOCAL_LICENSES_DIR") license json detail files synced."
  log_info "Updated licenses:"
  list_updated_licenses
}

main "$@"
