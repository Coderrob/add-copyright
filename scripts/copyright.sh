#!/usr/bin/env bash
# filepath: scripts/copyright.sh

# Copyright and License Script
# ============================
#
# This script automatically adds copyright headers and license texts to source files
# in a specified directory. It supports multiple programming languages and uses SPDX
# license identifiers to fetch the appropriate license text from JSON files.
#
# Features:
# - Supports 700+ SPDX licenses
# - Handles multiple file types with appropriate comment styles
# - Skips files already containing current year copyright
# - Ignores files in .gitignore and common config files
# - Creates root LICENSE file if missing
#
# Usage: ./copyright.sh <directory> <license-type> <copyright-title>
#
# Arguments:
#   directory:     Directory to scan for source files
#   license-type:  SPDX license identifier (e.g., MIT, Apache-2.0)
#   copyright-title: Name of the copyright holder
#
# Dependencies: git, sed, awk, find, mktemp, jq
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Constants ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly LICENSES_DIR="licenses"
readonly TMP_FILE="$(mktemp)"
readonly CURRENT_YEAR="$(date +"%Y")"

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
# trap 'log_error "Error on line $LINENO: $BASH_COMMAND"; rm -f "$TMP_FILE"; exit 1' ERR
trap 'rm -f "$TMP_FILE"' EXIT

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

# Helper: extract a field from a json file using jq if present, otherwise python.
json_get() {
  local file="$1" expr="$2"
  jq -r "$expr" "$file" 2>/dev/null || true
}

# --- Comment Styles ---
declare -A COMMENT_STYLES=(
  [sh]="#"
  [py]="#"
  [js]="/*"
  [ts]="/*"
  [java]="/*"
  [cpp]="/*"
  [hpp]="/*"
  [c]="/*"
  [h]="/*"
  [cs]="/*"
  [go]="//"
  [swift]="//"
  [php]="/*"
  [rb]="#"
  [yml]="#"
  [yaml]="#"
)

# --- Functions ---

# should_ignore_file()
# Determines if a file should be ignored during processing.
# Files are ignored if they are in .gitignore or are common config files.
#
# Arguments:
#   file: Path to the file to check
#
# Returns:
#   0 if file should be ignored, 1 otherwise
should_ignore_file() {
  local file="$1"
  git check-ignore -q "$file" && return 0
  [[ "$file" == *".eslintrc"* || "$file" == "eslint.config."* ]] && return 0
  return 1
}

# get_comment_style()
# Returns the appropriate comment style for a given file extension.
#
# Arguments:
#   file: Path to the file (extension is extracted)
#
# Returns:
#   Comment prefix string (e.g., "#", "//", "/*")
get_comment_style() {
  local ext="${1##*.}"
  printf '%s' "${COMMENT_STYLES[$ext]:-}"
}

# get_license_text()
# Retrieves the license text for a given SPDX license identifier.
# Tries multiple filename variations and falls back to different text sources.
#
# Arguments:
#   license: SPDX license identifier (e.g., "MIT", "Apache-2.0")
#   title: Copyright holder name
#
# Returns:
#   Formatted license text with placeholders replaced
get_license_text() {
  # Returns license text suitable for insertion as the header body.
  # Prefer `standardLicenseHeader` from the license json detail; otherwise fall back to licenseText from json or old .txt files.
  local license="$1" title="$2"
  local json_file="$LICENSES_DIR/$license.json"
  # Try several filename casings to be tolerant of input (e.g. apache-2.0 -> Apache-2.0.json)
  if [[ ! -f "$json_file" ]]; then
    json_file="$LICENSES_DIR/${license,,}.json"
  fi
  if [[ ! -f "$json_file" ]]; then
    json_file="$LICENSES_DIR/${license^^}.json"
  fi
  if [[ ! -f "$json_file" ]]; then
    json_file="$LICENSES_DIR/${license^}.json"
  fi
  if [[ -f "$json_file" ]]; then
    # Try standardLicenseHeader first
  local header
  header="$(json_get "$json_file" '.standardLicenseHeader')"
  if [[ -n "$header" ]]; then
      # Replace placeholder year/name patterns with the provided title and current year
      printf '%s' "$header" | sed "s/\[yyyy\]/$CURRENT_YEAR/g; s/\[name of copyright owner\]/$title/g; s/\[year\]/$CURRENT_YEAR/g"
      return
    fi
    # Fall back to licenseText
    local license_text
    license_text="$(json_get "$json_file" '.licenseText')"
    if [[ -n "$license_text" ]]; then
      printf '%s' "$license_text" | sed "s/{{COPYRIGHT_NOTICE}}/Copyright (c) $CURRENT_YEAR $title/g; s/\[yyyy\]/$CURRENT_YEAR/g; s/\[name of copyright owner\]/$title/g"
      return
    fi
  fi

  # Backwards compatible: try old .txt files
  local license_file="$LICENSES_DIR/$license.txt"
  if [[ ! -f "$license_file" ]]; then
    license_file="$LICENSES_DIR/${license,,}.txt"
  fi
  if [[ ! -f "$license_file" ]]; then
    license_file="$LICENSES_DIR/${license^^}.txt"
  fi
  [[ -f "$license_file" ]] || { log_error "License file for '$license' not found in json or txt form."; exit 3; }
  sed "s/{{COPYRIGHT_NOTICE}}/Copyright (c) $CURRENT_YEAR $title/g" "$license_file"
}

# create_root_license_if_missing()
# Creates a root LICENSE file if one doesn't exist.
# Uses the license text from the JSON file to create the LICENSE file.
#
# Arguments:
#   license: SPDX license identifier
#   title: Copyright holder name
create_root_license_if_missing() {
  local license="$1" title="$2"
  if [[ -f LICENSE || -f LICENSE.md || -f LICENSE.txt ]]; then
    log_info "Root LICENSE file already present; skipping creation."
    return
  fi
  local json_file="$LICENSES_DIR/$license.json"
  if [[ ! -f "$json_file" ]]; then
    json_file="$LICENSES_DIR/${license,,}.json"
  fi
  if [[ ! -f "$json_file" ]]; then
    json_file="$LICENSES_DIR/${license^^}.json"
  fi
  if [[ ! -f "$json_file" ]]; then
    json_file="$LICENSES_DIR/${license^}.json"
  fi
  if [[ ! -f "$json_file" ]]; then
    log_warn "License json not found for $license; will not create root LICENSE."
    return
  fi
  local license_text
  license_text="$(json_get "$json_file" '.licenseText')"
  if [[ -z "$license_text" ]]; then
    log_warn "No licenseText in $json_file; will not create root LICENSE."
    return
  fi
  log_info "Creating root LICENSE using $license"
  printf '%s' "$license_text" | sed "s/\[yyyy\]/$CURRENT_YEAR/g; s/\[name of copyright owner\]/$title/g; s/\[year\]/$CURRENT_YEAR/g" > LICENSE
}

# format_license_notice()
# Formats the license text with appropriate comment style for the file type.
#
# Arguments:
#   license_text: Raw license text
#   style: Comment style (e.g., "#", "//", "/*")
#
# Returns:
#   Formatted license notice ready for file insertion
format_license_notice() {
  local license_text="$1" style="$2"
  case "$style" in
    "/*")
      printf '/*\n'
      printf '%s\n' "$license_text" | sed 's/^/ * /'
      printf ' */\n\n'
      ;;
    "//")
      printf '%s\n' "$license_text" | sed 's/^/\/\//'
      printf '\n'
      ;;
    *)
      printf '%s\n' "$license_text" | sed "s/^/$style /"
      printf '\n'
      ;;
  esac
}

# prepend_license()
# Prepends the license notice to a file if it doesn't already have one.
# Checks for existing copyright and skips if present.
#
# Arguments:
#   file: Path to the file to update
#   license: SPDX license identifier
#   title: Copyright holder name
prepend_license() {
  local file="$1" license="$2" title="$3"
  local comment_style license_text formatted_notice

  comment_style="$(get_comment_style "$file")"
  [[ -z "$comment_style" ]] && { log_debug "No comment style for $file"; return; }

  license_text="$(get_license_text "$license" "$title")"
  grep -q "Copyright $CURRENT_YEAR $title" "$file" && {
    log_info "Skipping (already has license): $file"
    return
  }

  formatted_notice="$(format_license_notice "$license_text" "$comment_style")"
  echo "Formatted notice: $formatted_notice" >&2
  { printf '%s\n' "$formatted_notice"; cat "$file"; } > "$TMP_FILE"
  echo "TMP_FILE: $TMP_FILE" >&2
  mv "$TMP_FILE" "$file"
  echo "Moved to $file" >&2
  log_info "Updated: $file"
}

# scan_directory()
# Scans a directory recursively and adds license headers to all eligible files.
# Provides summary statistics of processed, skipped, and error files.
#
# Arguments:
#   dir: Directory to scan
#   license: SPDX license identifier
#   title: Copyright holder name
scan_directory() {
  local dir="$1" license="$2" title="$3"
  local processed=0 skipped=0 errors=0
  while IFS= read -r -d '' file; do
    echo "Processing file: $file" >&2
    if should_ignore_file "$file"; then
      log_debug "Ignored: $file"
      ((skipped++))
    else
      if prepend_license "$file" "$license" "$title"; then
        ((processed++))
      else
        ((errors++))
      fi
    fi
  done < <(find "$dir" -type f -print0) || true
  log_info "Summary: $processed files updated, $skipped files skipped, $errors errors."
}

print_help() {
  printf 'Usage: %s <directory> <license-type> <copyright-title>\n' "$SCRIPT_NAME"
  exit 1
}

# --- Main ---
[[ $# -eq 3 ]] || print_help

LICENSE_TYPE="$2"
COPYRIGHT_TITLE="$3"

log_info "Starting license processing..."
log_info "Directory: $1"
log_info "License Type: $LICENSE_TYPE"
log_info "Copyright Title: $COPYRIGHT_TITLE"

scan_directory "$1" "$LICENSE_TYPE" "$COPYRIGHT_TITLE"

# create_root_license_if_missing "$LICENSE_TYPE" "$COPYRIGHT_TITLE"

log_info "Processing complete."
exit 0
