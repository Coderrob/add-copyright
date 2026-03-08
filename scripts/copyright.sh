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

set -uo pipefail  # Remove -e to be more tolerant of errors

# --- Configuration ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LICENSES_DIR="${GITHUB_ACTION_PATH:-${SCRIPT_DIR}/..}/licenses"
readonly TMP_FILE="$(mktemp)"
readonly CURRENT_YEAR="$(date +"%Y")"

# File processing constants
readonly EXCLUDED_DIRS=".git node_modules .next dist build .cache .vscode .idea __pycache__ .github .continue licenses"
readonly EXCLUDED_FILES=".eslintrc* eslint.config.* .DS_Store Thumbs.db"

# Required commands
readonly REQUIRED_COMMANDS="git sed awk find mktemp jq"

# --- Logging ---
log() {
  local level="$1"; shift
  printf '%s [%s] %s: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$SCRIPT_NAME" "$level" "$*" >&2
}

log_info()    { log "INFO" "$@"; }
log_warn()    { log "WARN" "$@"; }
log_error()   { log "ERROR" "$@"; }
log_debug()   { [[ "${DEBUG:-}" == "1" ]] && log "DEBUG" "$@"; }

# --- Error Handling ---
cleanup() {
  [[ -f "$TMP_FILE" ]] && rm -f "$TMP_FILE"
}

# Custom error handler for ERR trap - keep it simple to avoid variable issues
handle_error() {
  local exit_code=$?
  # Only handle actual errors (non-zero exit codes)
  if [[ $exit_code -ne 0 && $exit_code -ne 130 ]]; then  # 130 is Ctrl+C
    # Use simple error message to avoid variable scoping issues
    echo "Error: Script failed with exit code $exit_code" >&2
    cleanup
    exit $exit_code
  fi
}

# Set up error handling
trap cleanup EXIT
trap handle_error ERR

# --- Dependency Management ---
check_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Missing required command: $cmd"
    if [[ "$cmd" == "jq" ]]; then
      print_jq_install_instructions
    fi
    return 1
  fi
  return 0
}

print_jq_install_instructions() {
  log_error "Install jq:"
  log_error "  macOS: brew install jq"
  log_error "  Ubuntu/Debian: sudo apt-get install -y jq"
  log_error "  Fedora/CentOS: sudo dnf install -y jq  (or yum install jq)"
  log_error "  Windows (scoop): scoop install jq  or (chocolatey): choco install jq"
}

verify_dependencies() {
  local missing_deps=()
  for cmd in $REQUIRED_COMMANDS; do
    if ! check_command "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing dependencies: ${missing_deps[*]}"
    exit 2
  fi
}

# --- JSON Utilities ---
extract_json_field() {
  local file="$1" field="$2"
  local result
  result="$(jq -r "$field" "$file" 2>/dev/null)" || return 1

  # Return empty string if result is null or empty
  [[ "$result" == "null" || -z "$result" ]] && echo "" || echo "$result"
}

# --- Comment Style Configuration ---
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
  [json]="/*"
)

# --- License Formatting ---
format_block_comment() {
  local license_text="$1"
  printf '/*\n'
  printf '%s\n' "$license_text" | sed 's/^/ * /'
  printf ' */'
}

format_line_comment() {
  local license_text="$1" prefix="$2"
  printf '%s' "$license_text" | sed "s/^/$prefix/"
}

format_license_notice() {
  local license_text="$1" style="$2"

  case "$style" in
    "/*") format_block_comment "$license_text" ;;
    "//") format_line_comment "$license_text" "//" ;;
    *)    format_line_comment "$license_text" "$style" ;;
  esac
}

# --- File Modification ---
has_current_copyright() {
  local file="$1" title="$2"
  grep -qE "Copyright(\s+\(c\))?\s+$CURRENT_YEAR\s+$title" "$file"
}

create_temp_file() {
  local content="$1" original_file="$2"
  printf '%s\n' "$content" > "$TMP_FILE"
  cat "$original_file" >> "$TMP_FILE"
}

replace_file() {
  local source="$1" target="$2"
  mv "$source" "$target"
}

prepend_license_to_file() {
  local file="$1" license="$2" title="$3"

  local comment_style
  comment_style="$(get_comment_style "$file")"
  [[ -z "$comment_style" ]] && { log_debug "No comment style for $file"; return 0; }

  local license_text
  if ! license_text="$(get_license_text "$license" "$title")"; then
    log_error "Failed to get license text for $license"
    return 1
  fi

  if has_current_copyright "$file" "$title"; then
    log_info "Skipping (already has license): $file"
    return 0
  fi

  local formatted_notice
  formatted_notice="$(format_license_notice "$license_text" "$comment_style")"

  log_debug "Formatted notice: $formatted_notice"

  # Prepend the formatted notice with a blank line after it
  create_temp_file "$formatted_notice" "$file"
  replace_file "$TMP_FILE" "$file"

  log_info "Updated: $file"
  return 0
}

# --- Error Handling ---
handle_error() {
  local exit_code=$?
  # Only handle actual errors (non-zero exit codes)
  if [[ $exit_code -ne 0 && $exit_code -ne 130 ]]; then  # 130 is Ctrl+C
    # Use simple error message to avoid variable scoping issues
    echo "Error: Script failed with exit code $exit_code" >&2
    cleanup
    exit $exit_code
  fi
}

# --- License File Resolution ---
find_license_file() {
  local license="$1"
  local candidates=(
    "$LICENSES_DIR/$license.json"
    "$LICENSES_DIR/${license,,}.json"
    "$LICENSES_DIR/${license^^}.json"
    "$LICENSES_DIR/${license^}.json"
  )

  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] && echo "$candidate" && return 0
  done

  return 1
}

find_legacy_license_file() {
  local license="$1"
  local candidates=(
    "$LICENSES_DIR/$license.txt"
    "$LICENSES_DIR/${license,,}.txt"
    "$LICENSES_DIR/${license^^}.txt"
  )

  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] && echo "$candidate" && return 0
  done

  return 1
}

# --- License Text Processing ---
process_license_placeholders() {
  local text="$1" title="$2"
  printf '%s' "$text" | sed \
    "s/{{COPYRIGHT_NOTICE}}/Copyright (c) $CURRENT_YEAR $title/g; \
     s/\[yyyy\]/$CURRENT_YEAR/g; \
     s/\[name of copyright owner\]/$title/g; \
     s/\[year\]/$CURRENT_YEAR/g; \
     s/<year>/$CURRENT_YEAR/g; \
     s/<copyright holders>/$title/g"
}

get_standard_license_header() {
  local json_file="$1" title="$2"
  local header
  header="$(extract_json_field "$json_file" '.standardLicenseHeader')"
  [[ -n "$header" ]] && process_license_placeholders "$header" "$title" && return 0
  return 1
}

get_license_text_from_json() {
  local json_file="$1" title="$2"
  local license_text
  license_text="$(extract_json_field "$json_file" '.licenseText')"
  [[ -n "$license_text" ]] && process_license_placeholders "$license_text" "$title" && return 0
  return 1
}

get_license_text() {
  local license="$1" title="$2"

  # Try JSON license file first
  local json_file
  if json_file="$(find_license_file "$license")"; then
    get_standard_license_header "$json_file" "$title" && return 0
    get_license_text_from_json "$json_file" "$title" && return 0
  fi

  # Fall back to legacy .txt files
  local txt_file
  if txt_file="$(find_legacy_license_file "$license")"; then
    process_license_placeholders "$(cat "$txt_file")" "$title"
    return 0
  fi

  log_error "License file for '$license' not found in json or txt form."
  return 1
}

# --- File Processing ---
is_excluded_file() {
  local file="$1"
  local filename="$(basename "$file")"

  # Check excluded file patterns
  for pattern in $EXCLUDED_FILES; do
    [[ "$filename" == $pattern ]] && return 0
  done

  return 1
}

is_excluded_directory() {
  local file="$1"

  # Check if file is in excluded directories
  for dir in $EXCLUDED_DIRS; do
    [[ "$file" == *"/$dir/"* ]] && return 0
  done

  return 1
}

should_ignore_file() {
  local file="$1"

  # Check .gitignore first
  git check-ignore -q "$file" && return 0

  # Check excluded files and directories
  is_excluded_file "$file" && return 0
  is_excluded_directory "$file" && return 0

  return 1
}

get_file_extension() {
  local file="$1"
  local ext="${file##*.}"
  # Handle files without extensions
  [[ "$file" == "$ext" ]] && echo "" || echo "$ext"
}

get_comment_style() {
  local file="$1"
  local ext="$(get_file_extension "$file")"
  printf '%s' "${COMMENT_STYLES[$ext]:-}"
}

# --- Directory Processing ---
build_find_prune_args() {
  local args=""
  for dir in $EXCLUDED_DIRS; do
    args="$args -name $dir -o"
  done
  # Remove trailing " -o"
  printf '%s' "${args% -o}"
}

find_files_to_process() {
  local dir="$1"
  local prune_args="$(build_find_prune_args)"
  find "$dir" -type d \( $prune_args \) -prune -o -type f -print0
}

process_file() {
  local file="$1" license="$2" title="$3"

  if should_ignore_file "$file"; then
    echo "1"  # Ignored
    return 0
  fi

  if prepend_license_to_file "$file" "$license" "$title"; then
    echo "0"  # Processed
    return 0
  else
    echo "2"  # Error
    return 0
  fi
}

scan_directory() {
  local dir="$1" license="$2" title="$3"
  local processed=0 skipped=0 errors=0

  while IFS= read -r -d '' file; do
    log_debug "Processing file: $file"
    case "$(process_file "$file" "$license" "$title")" in
      0) ((processed++)) ;;
      1) ((skipped++)) ;;
      2) ((errors++)) ;;
    esac
  done < <(find_files_to_process "$dir") || true

  log_info "Summary: $processed files updated, $skipped files skipped, $errors errors."
}

# --- Root License Management ---
license_file_exists() {
  [[ -f LICENSE || -f LICENSE.md || -f LICENSE.txt ]]
}

create_root_license() {
  local license="$1" title="$2"

  if license_file_exists; then
    log_info "Root LICENSE file already present; skipping creation."
    return 0
  fi

  local json_file
  if ! json_file="$(find_license_file "$license")"; then
    log_warn "License json not found for $license; will not create root LICENSE."
    return 1
  fi

  local license_text
  license_text="$(extract_json_field "$json_file" '.licenseText')"
  if [[ -z "$license_text" ]]; then
    log_warn "No licenseText in $json_file; will not create root LICENSE."
    return 1
  fi

  log_info "Creating root LICENSE using $license"
  process_license_placeholders "$license_text" "$title" > LICENSE
  return 0
}

# --- Command Line Interface ---
print_usage() {
  cat << EOF
Usage: $SCRIPT_NAME <directory> <license-type> <copyright-title>

Arguments:
  directory      Directory to scan for source files
  license-type   SPDX license identifier (e.g., MIT, Apache-2.0)
  copyright-title Name of the copyright holder

Examples:
  $SCRIPT_NAME . MIT "John Doe"
  $SCRIPT_NAME src Apache-2.0 "My Company"
  $SCRIPT_NAME /path/to/project GPL-3.0-only "Open Source Project"

Options:
  DEBUG=1       Enable debug logging

EOF
}

validate_arguments() {
  [[ $# -eq 3 ]] || { print_usage; exit 1; }

  local dir="$1"
  [[ -d "$dir" ]] || { log_error "Directory does not exist: $dir"; exit 1; }

  return 0
}

# --- Main Application ---
main() {
  local directory="$1" license_type="$2" copyright_title="$3"

  log_info "Starting license processing..."
  log_info "Directory: $directory"
  log_info "License Type: $license_type"
  log_info "Copyright Title: $copyright_title"

  scan_directory "$directory" "$license_type" "$copyright_title"

  # Optional: Create root license file
  # create_root_license "$license_type" "$copyright_title"

  log_info "Processing complete."
}

# --- Entry Point ---
verify_dependencies
validate_arguments "$@"

# Disable ERR trap for main execution to prevent interference with successful exits
trap - ERR

main "$@"

# Re-enable cleanup trap for proper resource management
trap cleanup EXIT
