#!/usr/bin/env bash
# filepath: scripts/update_licenses.sh

# SPDX License Database Update Script
# ===================================
#
# This script updates the local license database by fetching the latest
# license information from the official SPDX License List Data repository.
# It clones the SPDX repository, copies the JSON license detail files,
# and optionally creates a root LICENSE file if missing.
#
# Features:
# - Fetches latest SPDX license data
# - Maintains backup of current licenses
# - Creates root LICENSE file from package.json license field
# - Provides summary of updated licenses
#
# Usage: ./update_licenses.sh
#
# Dependencies: git, jq, find, mktemp
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Constants ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly SPDX_REPO="https://github.com/spdx/license-list-data.git"
readonly SPDX_JSON_DIR="json/details"
readonly LOCAL_LICENSES_DIR="licenses"
readonly TMP_DIR="$(mktemp -d)"
readonly SPDX_CLONE_DIR="$TMP_DIR/spdx-license-list-data"

# --- Logging ---
log() {
  local level="$1"; shift
  printf '%s [%s] %s: %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$SCRIPT_NAME" "$level" "$*" >&2
}
log_info()    { log "INFO" "$@"; }
log_warn()    { log "WARN" "$@"; }
log_error()   { log "ERROR" "$@"; }
log_debug()   { [[ "${DEBUG:-}" == "1" ]] && log "DEBUG" "$@"; }

# --- Error Handling ---
trap 'log_error "Error on line $LINENO: $BASH_COMMAND"; rm -rf "$TMP_DIR"; exit 1' ERR
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Check Dependencies ---
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    if [[ "$1" == "jq" ]]; then
      log_error "Missing required command: jq"
      log_error "Install jq:"
      log_error "  macOS: brew install jq"
      log_error "  Ubuntu/Debian: sudo apt-get install -y jq"
      log_error "  Fedora/CentOS: sudo dnf install -y jq  (or yum install jq)"
      log_error "  Windows (scoop): scoop install jq  or (chocolatey): choco install jq"
      exit 2
    else
      log_error "Missing required command: $1"
      exit 2
    fi
  fi
}
for cmd in git sed awk find mktemp jq; do require_cmd "$cmd"; done

# Extract a JSON field value from a file. Uses jq if available, otherwise falls back to Python.
extract_json_field() {
  local file="$1" field="$2"
  jq -r "$field" "$file" 2>/dev/null || true
}

# --- Functions ---

# clone_spdx_repo()
# Clones the SPDX license-list-data repository to fetch the latest license data.
# Uses shallow clone for faster downloads.
clone_spdx_repo() {
  log_info "Cloning SPDX license-list-data repository..."
  git clone --depth 1 "$SPDX_REPO" "$SPDX_CLONE_DIR"
}

# copy_license_files()
# Copies JSON license detail files from the cloned SPDX repository to the local licenses directory.
# Creates backup of existing licenses and removes old text files.
copy_license_files() {
  log_info "Copying JSON license detail files from SPDX repository..."
  local spdx_json_path="$SPDX_CLONE_DIR/$SPDX_JSON_DIR"
  if [[ ! -d "$spdx_json_path" ]]; then
    log_error "SPDX json details directory not found: $spdx_json_path"
    exit 3
  fi

  # Create backup of current licenses
  if [[ -d "$LOCAL_LICENSES_DIR" ]]; then
    cp -r "$LOCAL_LICENSES_DIR" "$TMP_DIR/licenses_backup"
  fi

  # Remove old licenses (text files) and create directory
  rm -rf "$LOCAL_LICENSES_DIR"
  mkdir -p "$LOCAL_LICENSES_DIR"

  # Copy json detail files (one file per license id)
  find "$spdx_json_path" -name "*.json" -exec cp {} "$LOCAL_LICENSES_DIR/" \;
  log_info "Copied $(find "$LOCAL_LICENSES_DIR" -name "*.json" | wc -l) license json detail files"
}

# create_root_license_if_missing()
# Creates a root LICENSE file if one doesn't exist.
# Determines the license type from package.json if available, otherwise defaults to Apache-2.0.
create_root_license_if_missing() {
  # Determine candidate license to use for root LICENSE file.
  # Preference: package.json 'license' field if present, else default to Apache-2.0.
  local candidate="Apache-2.0"
  if [[ -f package.json ]]; then
    local lic
    lic=$(sed -n 's/.*"license"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json || true)
    if [[ -n "$lic" ]]; then
      candidate="$lic"
    fi
  fi

  if [[ -f LICENSE || -f LICENSE.md || -f LICENSE.txt ]]; then
    log_info "Root LICENSE file already present; skipping creation."
    return
  fi

  local jsonfile="$LOCAL_LICENSES_DIR/${candidate}.json"
  if [[ ! -f "$jsonfile" ]]; then
    log_warn "Candidate license json not found ($jsonfile); will not create root LICENSE."
    return
  fi

  log_info "Creating root LICENSE using $candidate"
  jq -r '.licenseText' "$jsonfile" > LICENSE
}

# --- Main ---
log_info "Starting license update process..."

clone_spdx_repo
copy_license_files
create_root_license_if_missing

log_info "License update complete. $(find "$LOCAL_LICENSES_DIR" -name "*.json" | wc -l) license json detail files synced."

# Optional: Show summary
log_info "Updated licenses:"
find "$LOCAL_LICENSES_DIR" -name "*.json" -exec basename {} \; | sed 's/\.json$//' | sort
