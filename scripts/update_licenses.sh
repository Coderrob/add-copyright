#!/usr/bin/env bash
# filepath: scripts/update_licenses.sh

set -euo pipefail

# --- Constants ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly SPDX_REPO="https://github.com/spdx/license-list-data.git"
readonly SPDX_TEXT_DIR="text"
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
  command -v "$1" >/dev/null 2>&1 || { log_error "Missing required command: $1"; exit 2; }
}
for cmd in git sed awk find mktemp; do require_cmd "$cmd"; done

# --- Functions ---
clone_spdx_repo() {
  log_info "Cloning SPDX license-list-data repository..."
  git clone --depth 1 "$SPDX_REPO" "$SPDX_CLONE_DIR"
}

copy_license_files() {
  log_info "Copying license files from SPDX repository..."
  local spdx_text_path="$SPDX_CLONE_DIR/$SPDX_TEXT_DIR"
  if [[ ! -d "$spdx_text_path" ]]; then
    log_error "SPDX text directory not found: $spdx_text_path"
    exit 3
  fi

  # Create backup of current licenses
  if [[ -d "$LOCAL_LICENSES_DIR" ]]; then
    cp -r "$LOCAL_LICENSES_DIR" "$TMP_DIR/licenses_backup"
  fi

  # Remove old licenses
  rm -rf "$LOCAL_LICENSES_DIR"
  mkdir -p "$LOCAL_LICENSES_DIR"

  # Copy new licenses, excluding deprecated ones
  find "$spdx_text_path" -name "*.txt" ! -name "deprecated_*.txt" -exec cp {} "$LOCAL_LICENSES_DIR/" \;
  log_info "Copied $(find "$LOCAL_LICENSES_DIR" -name "*.txt" | wc -l) license files"
}

normalize_license_text() {
  local file="$1"
  log_debug "Normalizing $file"

  # Replace various copyright notice formats with placeholder
  if grep -q "Copyright (c) <year> <copyright holders>" "$file"; then
    sed -i 's/Copyright (c) <year> <copyright holders>/{{COPYRIGHT_NOTICE}}/' "$file"
  elif grep -q "Copyright (c) <year> <owner>" "$file"; then
    sed -i 's/Copyright (c) <year> <owner>\./{{COPYRIGHT_NOTICE}}/' "$file"
  elif grep -q "Copyright [yyyy] [name of copyright owner]" "$file"; then
    sed -i 's/Copyright [yyyy] [name of copyright owner]/{{COPYRIGHT_NOTICE}}/' "$file"
  elif grep -q "Copyright ©" "$file"; then
    sed -i 's/Copyright © [0-9]\{4\} .*/{{COPYRIGHT_NOTICE}}/' "$file"
  else
    # If no copyright line found, add one at the top
    sed -i '1i{{COPYRIGHT_NOTICE}}' "$file"
  fi
}

normalize_all_licenses() {
  log_info "Normalizing license texts..."
  for file in "$LOCAL_LICENSES_DIR"/*.txt; do
    [[ -f "$file" ]] || continue
    normalize_license_text "$file"
  done
}

# --- Main ---
log_info "Starting license update process..."

clone_spdx_repo
copy_license_files
normalize_all_licenses

log_info "License update complete. $(find "$LOCAL_LICENSES_DIR" -name "*.txt" | wc -l) licenses updated."

# Optional: Show summary
log_info "Updated licenses:"
find "$LOCAL_LICENSES_DIR" -name "*.txt" -exec basename {} \; | sed 's/\.txt$//' | sort
