#!/usr/bin/env bash
# filepath: scripts/copyright.sh

# Copyright and License Script
# ============================
#
# Adds copyright headers and license texts to source files using SPDX
# license identifiers.
#
# Usage: ./copyright.sh <directory> <license-type> <copyright-title>
#
# Dependencies: git, sed, find, mktemp, jq, grep
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Configuration ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LICENSES_DIR="$SCRIPT_DIR/../licenses"
readonly TMP_FILE="$(mktemp)"
readonly CURRENT_YEAR="$(date +"%Y")"
readonly EXCLUDED_DIRS=".git node_modules .next dist build .cache .vscode .idea __pycache__ .github .continue licenses"
readonly EXCLUDED_FILES=".eslintrc* eslint.config.* .DS_Store Thumbs.db"
readonly REQUIRED_COMMANDS="git sed find mktemp jq grep zcat"

USE_GIT=0
GIT_ROOT=""

# --- Logging ---
# log: Logs a message with timestamp, script name, and log level.
log() {
  local level="$1"; shift
  printf '%s [%s] %s: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$SCRIPT_NAME" "$level" "$*" >&2
}
# log_info: Logs an informational message.
log_info() { log "INFO" "$@"; }
# log_warn: Logs a warning message.
log_warn() { log "WARN" "$@"; }
# log_error: Logs an error message.
log_error() { log "ERROR" "$@"; }
# log_debug: Logs a debug message if DEBUG is set to 1.
log_debug() { [[ "${DEBUG:-}" == "1" ]] && log "DEBUG" "$@"; }

# --- Error Handling ---
# cleanup: Removes temporary files created during script execution.
cleanup() {
  [[ -f "$TMP_FILE" ]] && rm "$TMP_FILE" 2>/dev/null || true
}

# on_error: Handles script errors by logging the exit code and cleaning up.
on_error() {
  local exit_code=$?
  [[ $exit_code -eq 130 ]] && exit 130
  echo "Error: Script failed with exit code $exit_code" >&2
  cleanup
  exit $exit_code
}

trap cleanup EXIT
trap on_error ERR

# --- Dependencies ---
# print_jq_install_instructions: Prints installation instructions for jq.
print_jq_install_instructions() {
  log_error "Install jq:"
  log_error "  macOS: brew install jq"
  log_error "  Ubuntu/Debian: sudo apt-get install -y jq"
  log_error "  Fedora/CentOS: sudo dnf install -y jq  (or yum install jq)"
  log_error "  Windows (scoop): scoop install jq  or (chocolatey): choco install jq"
}

# require_cmd: Checks if a command is available in the system PATH.
# Arguments: command name
require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# verify_dependencies: Verifies that all required commands are installed.
verify_dependencies() {
  local missing=()
  local cmd
  for cmd in $REQUIRED_COMMANDS; do
    if ! require_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  log_error "Missing dependencies: ${missing[*]}"
  if printf '%s\n' "${missing[@]}" | grep -qx "jq"; then
    print_jq_install_instructions
  fi
  exit 2
}

# --- JSON Utilities ---
# extract_json_field: Extracts a field from a JSON file using jq.
# Arguments: json_file, field_path
extract_json_field() {
  local file="$1" field="$2"
  local result
  if [[ "$file" == *.gz ]]; then
    result="$(zcat "$file" | jq -r "$field" 2>/dev/null)" || return 1
  else
    result="$(jq -r "$field" "$file" 2>/dev/null)" || return 1
  fi
  [[ "$result" == "null" || -z "$result" ]] && printf '%s' "" || printf '%s' "$result"
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
  [json]="/*"
)

# --- Text Formatting ---
# format_block_comment: Formats license text as a block comment (/* */).
# Arguments: license_text
format_block_comment() {
  local license_text="$1"
  printf '/*\n'
  printf '%s\n' "$license_text" | sed 's/^/ * /'
  printf ' */'
}

# format_line_comment: Formats license text as line comments with a prefix.
# Arguments: license_text, prefix
format_line_comment() {
  local license_text="$1" prefix="$2"
  printf '%s' "$license_text" | sed "s/^/$prefix/"
}

# format_license_notice: Formats license text according to the comment style.
# Arguments: license_text, comment_style
format_license_notice() {
  local license_text="$1" style="$2"
  case "$style" in
    "/*") format_block_comment "$license_text" ;;
    "//") format_line_comment "$license_text" "//" ;;
    *)    format_line_comment "$license_text" "$style" ;;
  esac
}

# escape_sed_replacement: Escapes special characters for sed replacement.
# Arguments: text
escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

# process_license_placeholders: Replaces placeholders in license text with actual values.
# Arguments: text, title
process_license_placeholders() {
  local text="$1" title="$2"
  local escaped_title escaped_year escaped_notice
  escaped_title="$(escape_sed_replacement "$title")"
  escaped_year="$(escape_sed_replacement "$CURRENT_YEAR")"
  escaped_notice="$(escape_sed_replacement "Copyright (c) $CURRENT_YEAR $title")"

  printf '%s' "$text" | sed \
    "s|{{COPYRIGHT_NOTICE}}|$escaped_notice|g; \
     s|\\[yyyy\\]|$escaped_year|g; \
     s|\\[name of copyright owner\\]|$escaped_title|g; \
     s|\\[year\\]|$escaped_year|g; \
     s|<year>|$escaped_year|g; \
     s|<copyright holders>|$escaped_title|g"
}

# --- License Resolution ---
# first_existing_file: Returns the first existing file from a list of paths.
# Arguments: file_paths...
first_existing_file() {
  local path
  for path in "$@"; do
    [[ -f "$path" ]] && { printf '%s' "$path"; return 0; }
  done
  return 1
}

# find_license_json: Finds the JSON license file for a given license type.
# Arguments: license_type
find_license_json() {
  local license="$1"
  first_existing_file \
    "$LICENSES_DIR/$license.json" \
    "$LICENSES_DIR/${license,,}.json" \
    "$LICENSES_DIR/${license^^}.json" \
    "$LICENSES_DIR/${license^}.json" \
    "$LICENSES_DIR/$license.json.gz" \
    "$LICENSES_DIR/${license,,}.json.gz" \
    "$LICENSES_DIR/${license^^}.json.gz" \
    "$LICENSES_DIR/${license^}.json.gz"
}

# find_license_txt: Finds the TXT license file for a given license type.
# Arguments: license_type
find_license_txt() {
  local license="$1"
  first_existing_file \
    "$LICENSES_DIR/$license.txt" \
    "$LICENSES_DIR/${license,,}.txt" \
    "$LICENSES_DIR/${license^^}.txt"
}

# license_text_from_json: Extracts license text from a JSON license file.
# Arguments: json_file, title
license_text_from_json() {
  local json_file="$1" title="$2"
  local header
  header="$(extract_json_field "$json_file" '.standardLicenseHeader')"
  [[ -n "$header" ]] && { process_license_placeholders "$header" "$title"; return 0; }

  local license_text
  license_text="$(extract_json_field "$json_file" '.licenseText')"
  [[ -n "$license_text" ]] && { process_license_placeholders "$license_text" "$title"; return 0; }
  return 1
}

# get_license_text: Retrieves the license text for a given license type and title.
# Arguments: license_type, title
get_license_text() {
  local license="$1" title="$2"

  local json_file
  if json_file="$(find_license_json "$license")"; then
    license_text_from_json "$json_file" "$title" && return 0
  fi

  local txt_file
  if txt_file="$(find_license_txt "$license")"; then
    process_license_placeholders "$(cat "$txt_file")" "$title"
    return 0
  fi

  log_error "License file for '$license' not found in json or txt form."
  return 1
}

# --- File Selection ---
# get_file_extension: Extracts the file extension from a file path.
# Arguments: file_path
get_file_extension() {
  local file="$1"
  local ext="${file##*.}"
  [[ "$file" == "$ext" ]] && printf '%s' "" || printf '%s' "$ext"
}

# get_comment_style: Determines the comment style for a file based on its extension.
# Arguments: file_path
get_comment_style() {
  local ext
  ext="$(get_file_extension "$1")"
  printf '%s' "${COMMENT_STYLES[$ext]:-}"
}

# is_excluded_file: Checks if a file should be excluded based on its name.
# Arguments: file_path
is_excluded_file() {
  local filename
  filename="$(basename "$1")"
  local pattern
  for pattern in $EXCLUDED_FILES; do
    [[ "$filename" == $pattern ]] && return 0
  done
  return 1
}

# is_excluded_directory: Checks if a file is in an excluded directory.
# Arguments: file_path
is_excluded_directory() {
  local file="$1"
  local dir
  for dir in $EXCLUDED_DIRS; do
    [[ "$file" == *"/$dir/"* ]] && return 0
  done
  return 1
}

# is_git_ignored: Checks if a file is ignored by git.
# Arguments: file_path
is_git_ignored() {
  [[ "$USE_GIT" -eq 1 ]] || return 1
  git -C "$GIT_ROOT" check-ignore -q "$1" 2>/dev/null
}

# should_ignore_file: Determines if a file should be ignored for processing.
# Arguments: file_path
should_ignore_file() {
  is_git_ignored "$1" && return 0
  is_excluded_file "$1" && return 0
  is_excluded_directory "$1" && return 0
  return 1
}

# build_find_prune_args: Builds arguments for find command to prune excluded directories.
build_find_prune_args() {
  local args=""
  local dir
  for dir in $EXCLUDED_DIRS; do
    args="$args -name $dir -o"
  done
  printf '%s' "${args% -o}"
}

# find_files_to_process: Finds all files in a directory that should be processed.
# Arguments: directory
find_files_to_process() {
  local dir="$1"
  local prune_args
  prune_args="$(build_find_prune_args)"
  find "$dir" -type d \( $prune_args \) -prune -o -type f -print0
}

# --- File Updates ---
# has_current_copyright: Checks if a file already has the current year's copyright notice.
# Arguments: file_path, title
has_current_copyright() {
  local file="$1" title="$2"
  grep -Fiq "Copyright $CURRENT_YEAR $title" "$file" || grep -Fiq "Copyright (c) $CURRENT_YEAR $title" "$file"
}

# create_temp_file: Creates a temporary file with license notice prepended to file content.
# Arguments: license_notice, file_path
create_temp_file() {
  printf '%s\n' "$1" > "$TMP_FILE"
  printf '\n' >> "$TMP_FILE"
  cat "$2" >> "$TMP_FILE"
}

# prepend_license_to_file: Prepends license notice to a file if it doesn't already have it.
# Arguments: file_path, license_type, title
prepend_license_to_file() {
  local file="$1" license="$2" title="$3"

  local comment_style
  comment_style="$(get_comment_style "$file")"
  [[ -n "$comment_style" ]] || { log_debug "No comment style for $file"; return 0; }

  local license_text
  license_text="$(get_license_text "$license" "$title")" || { log_error "Failed to get license text for $license"; return 1; }

  has_current_copyright "$file" "$title" && { log_info "Skipping (already has license): $file"; return 0; }

  local formatted_notice
  formatted_notice="$(format_license_notice "$license_text" "$comment_style")"
  log_debug "Formatted notice: $formatted_notice"

  create_temp_file "$formatted_notice" "$file"
  mv "$TMP_FILE" "$file"

  log_info "Updated: $file"
}

# process_file: Processes a single file for license addition.
# Arguments: file_path, license_type, title
# Returns: 0 (processed), 1 (skipped), 2 (error)
process_file() {
  local file="$1" license="$2" title="$3"

  should_ignore_file "$file" && { echo "1"; return 0; }
  prepend_license_to_file "$file" "$license" "$title" && { echo "0"; return 0; }
  echo "2"
}

# scan_directory: Scans a directory and processes all files for license addition.
# Arguments: directory, license_type, title
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

  [[ $errors -gt 0 ]] && return 1 || return 0
}

# --- Root LICENSE ---
# license_file_exists: Checks if a root LICENSE file already exists.
license_file_exists() {
  [[ -f LICENSE || -f LICENSE.md || -f LICENSE.txt ]]
}

# create_root_license: Creates a root LICENSE file if it doesn't exist.
# Arguments: license_type, title
create_root_license() {
  local license="$1" title="$2"

  license_file_exists && { log_info "Root LICENSE file already present; skipping creation."; return 0; }

  local json_file
  json_file="$(find_license_json "$license")" || { log_warn "License json not found for $license; will not create root LICENSE."; return 1; }

  local license_text
  license_text="$(extract_json_field "$json_file" '.licenseText')"
  [[ -n "$license_text" ]] || { log_warn "No licenseText in $json_file; will not create root LICENSE."; return 1; }

  log_info "Creating root LICENSE using $license"
  process_license_placeholders "$license_text" "$title" > LICENSE
}

# --- CLI ---
# print_usage: Prints the usage information for the script.
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

# validate_arguments: Validates the command-line arguments.
# Arguments: script_args...
validate_arguments() {
  [[ $# -eq 3 ]] || { print_usage; exit 1; }
  [[ -d "$1" ]] || { log_error "Directory does not exist: $1"; exit 1; }
}

# init_git_context: Initializes git context if the directory is a git repository.
# Arguments: directory
init_git_context() {
  if GIT_ROOT="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)"; then
    USE_GIT=1
  else
    USE_GIT=0
    GIT_ROOT=""
  fi
}

# --- Main ---
# main: Main function that orchestrates the license processing.
# Arguments: directory, license_type, copyright_title
main() {
  local directory="$1" license_type="$2" copyright_title="$3"

  log_info "Starting license processing..."
  log_info "Directory: $directory"
  log_info "License Type: $license_type"
  log_info "Copyright Title: $copyright_title"

  init_git_context "$directory"
  scan_directory "$directory" "$license_type" "$copyright_title" || exit 1

  # Optional: Create root license file
  # create_root_license "$license_type" "$copyright_title"

  log_info "Processing complete."
}

verify_dependencies
validate_arguments "$@"
main "$@"
