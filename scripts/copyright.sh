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
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
ACTION_ROOT="${GITHUB_ACTION_PATH:-$SCRIPT_DIR/..}"
readonly ACTION_ROOT
readonly LICENSES_DIR="$ACTION_ROOT/licenses"
readonly COMMENT_STYLE_MANIFEST="$SCRIPT_DIR/config/comment-styles.tsv"
CURRENT_YEAR="$(date +"%Y")"
readonly CURRENT_YEAR
readonly RESULT_UPDATED=0
readonly RESULT_SKIPPED=1
readonly RESULT_ERROR=2
readonly -a EXCLUDED_DIRS=(.git node_modules .next dist build .cache .vscode .idea __pycache__ .github .continue licenses)
readonly -a EXCLUDED_FILES=(.eslintrc\* eslint.config.\* .DS_Store Thumbs.db)
readonly -a REQUIRED_COMMANDS=(git sed find mktemp jq grep zcat head tail chmod mv)

# shellcheck source=scripts/lib/logging.bash
source "$SCRIPT_DIR/lib/logging.bash"
# shellcheck source=scripts/lib/comment_styles.bash
source "$SCRIPT_DIR/lib/comment_styles.bash"
# shellcheck source=scripts/lib/header_operations.bash
source "$SCRIPT_DIR/lib/header_operations.bash"

USE_GIT=0
GIT_ROOT=""

# --- Error Handling ---
# on_error: Handles unexpected script errors with an actionable exit message.
on_error() {
  local exit_code=$?
  [[ $exit_code -eq 130 ]] && exit 130
  echo "Error: Script failed with exit code $exit_code" >&2
  exit $exit_code
}

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

# missing_dependencies: Prints each unavailable required command.
missing_dependencies() {
  local cmd
  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! require_cmd "$cmd"; then
      printf '%s\n' "$cmd"
    fi
  done
}

# verify_dependencies: Verifies that all required commands are installed.
verify_dependencies() {
  local missing=()
  mapfile -t missing < <(missing_dependencies)

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
# shellcheck disable=SC2034 # Read indirectly through a nameref helper.
declare -A COMMENT_STYLES=()
load_comment_styles "$COMMENT_STYLE_MANIFEST" COMMENT_STYLES

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
  printf '%s' "$license_text" | sed "s|^|$prefix |"
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

# default_license_header: Prints the fallback header for licenses without one.
# Arguments: copyright_title
default_license_header() {
  printf 'Copyright (c) %s %s' "$CURRENT_YEAR" "$1"
}

# license_header_from_json: Resolves the definition's file-header template.
# Arguments: json_file, title
license_header_from_json() {
  local json_file="$1" title="$2"
  local header
  header="$(extract_json_field "$json_file" '.standardLicenseHeader')"
  [[ -n "$header" ]] && { process_license_placeholders "$header" "$title"; return 0; }
  default_license_header "$title"
}

# get_license_header: Retrieves the license-specific file-header content.
# Arguments: license_type, title
get_license_header() {
  local license="$1" title="$2"

  local json_file
  if json_file="$(find_license_json "$license")"; then
    license_header_from_json "$json_file" "$title"
    return 0
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
  comment_style_for "$ext" COMMENT_STYLES
}

# is_excluded_file: Checks if a file should be excluded based on its name.
# Arguments: file_path
is_excluded_file() {
  local filename
  filename="$(basename "$1")"
  local pattern
  for pattern in "${EXCLUDED_FILES[@]}"; do
    # shellcheck disable=SC2053 # Patterns intentionally use shell globs.
    [[ "$filename" == $pattern ]] && return 0
  done
  return 1
}

# is_excluded_directory: Checks if a file is in an excluded directory.
# Arguments: file_path
is_excluded_directory() {
  local file="$1"
  local dir
  for dir in "${EXCLUDED_DIRS[@]}"; do
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

# find_files_to_process: Finds all files in a directory that should be processed.
# Arguments: directory
find_files_to_process() {
  local dir="$1"
  local excluded_dir
  local find_args=("$dir" -type d "(")
  for excluded_dir in "${EXCLUDED_DIRS[@]}"; do
    find_args+=(-name "$excluded_dir" -o)
  done
  unset 'find_args[${#find_args[@]}-1]'
  find_args+=(")" -prune -o -type f -print0)
  find "${find_args[@]}"
}

# --- File Updates ---
# write_updated_file: Atomically replaces one file with its licensed content.
# Arguments: license_notice, file_path
write_updated_file() {
  local notice="$1" file="$2" temp_file preamble_lines
  temp_file="$(mktemp "${file}.add-copyright.XXXXXX")"
  preamble_lines="$(preamble_line_count "$file")"

  if write_licensed_content "$notice" "$file" "$preamble_lines" > "$temp_file"; then
    chmod --reference="$file" "$temp_file"
    mv "$temp_file" "$file"
    return 0
  fi

  rm -f "$temp_file"
  return 1
}

# prepend_license_to_file: Prepends license notice to a file if it doesn't already have it.
# Arguments: file_path, license_type, title
prepend_license_to_file() {
  local file="$1" license="$2" title="$3"

  local comment_style
  comment_style="$(get_comment_style "$file")"
  [[ -n "$comment_style" ]] || { log_debug "Skipping unsupported file: $file"; return "$RESULT_SKIPPED"; }

  local license_text
  license_text="$(get_license_header "$license" "$title")" || { log_error "Failed to get license header for $license"; return "$RESULT_ERROR"; }

  managed_header_matches "$file" "$license" "$CURRENT_YEAR" "$title" && { log_info "Skipping (already has license): $file"; return "$RESULT_SKIPPED"; }

  local formatted_notice
  license_text="$MANAGED_HEADER_BEGIN"$'\n'"SPDX-License-Identifier: $license"$'\n'"$license_text"$'\n'"$MANAGED_HEADER_END"
  formatted_notice="$(format_license_notice "$license_text" "$comment_style")"
  log_debug "Formatted notice: $formatted_notice"

  write_updated_file "$formatted_notice" "$file"

  log_info "Updated: $file"
  return "$RESULT_UPDATED"
}

# process_file: Processes a single file for license addition.
# Arguments: file_path, license_type, title
# Returns: 0 (processed), 1 (skipped), 2 (error)
process_file() {
  local file="$1" license="$2" title="$3"
  local result

  should_ignore_file "$file" && { echo "$RESULT_SKIPPED"; return 0; }
  if prepend_license_to_file "$file" "$license" "$title"; then
    echo "$RESULT_UPDATED"
    return 0
  else
    result=$?
  fi
  [[ $result -eq $RESULT_SKIPPED ]] && { echo "$RESULT_SKIPPED"; return 0; }
  echo "$RESULT_ERROR"
}

# scan_directory: Scans a directory and processes all files for license addition.
# Arguments: directory, license_type, title
scan_directory() {
  local dir="$1" license="$2" title="$3"
  local result file_list
  local counts=(0 0 0)

  file_list="$(mktemp)"
  if find_files_to_process "$dir" > "$file_list"; then
    while IFS= read -r -d '' file; do
      log_debug "Processing file: $file"
      result="$(process_file "$file" "$license" "$title")"
      counts[result]=$((counts[result] + 1))
    done < "$file_list"
  else
    log_error "Failed to discover files below: $dir"
    counts[RESULT_ERROR]=1
  fi
  rm -f "$file_list"

  local processed="${counts[$RESULT_UPDATED]}" skipped="${counts[$RESULT_SKIPPED]}" errors="${counts[$RESULT_ERROR]}"
  log_info "Summary: $processed files updated, $skipped files skipped, $errors errors."
  printf '%s %s %s\n' "$processed" "$skipped" "$errors"

  [[ $errors -eq 0 ]]
}

# write_action_outputs: Publishes structured GitHub Action result counts.
# Arguments: updated_count, skipped_count, error_count
write_action_outputs() {
  local updated="$1" skipped="$2" errors="$3"
  [[ -n "${GITHUB_OUTPUT:-}" ]] || return 0
  {
    printf 'updated-count=%s\n' "$updated"
    printf 'skipped-count=%s\n' "$skipped"
    printf 'error-count=%s\n' "$errors"
    [[ "$updated" -gt 0 ]] && printf 'changed=true\n' || printf 'changed=false\n'
  } >> "$GITHUB_OUTPUT"
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
  local summary updated skipped errors scan_status=0

  log_info "Starting license processing..."
  log_info "Directory: $directory"
  log_info "License Type: $license_type"
  log_info "Copyright Title: $copyright_title"

  init_git_context "$directory"
  summary="$(scan_directory "$directory" "$license_type" "$copyright_title")" || scan_status=$?
  read -r updated skipped errors <<< "$summary"
  write_action_outputs "$updated" "$skipped" "$errors"
  [[ $scan_status -eq 0 ]] || return "$scan_status"

  # Optional: Create root license file
  # create_root_license "$license_type" "$copyright_title"

  log_info "Processing complete."
}

verify_dependencies
validate_arguments "$@"
main "$@"
