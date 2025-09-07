#!/usr/bin/env bash
# filepath: scripts/copyright.sh

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
trap 'log_error "Error on line $LINENO: $BASH_COMMAND"; rm -f "$TMP_FILE"; exit 1' ERR
trap 'rm -f "$TMP_FILE"' EXIT

# --- Check Dependencies ---
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log_error "Missing required command: $1"; exit 2; }
}
for cmd in git sed awk find mktemp; do require_cmd "$cmd"; done

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
)

# --- Functions ---
should_ignore_file() {
  local file="$1"
  git check-ignore -q "$file" && return 0
  [[ "$file" == *".eslintrc"* || "$file" == "eslint.config."* ]] && return 0
  return 1
}

get_comment_style() {
  local ext="${1##*.}"
  printf '%s' "${COMMENT_STYLES[$ext]:-}"
}

get_license_text() {
  local license="$1" title="$2"
  local license_file="$LICENSES_DIR/$license.txt"
  if [[ ! -f "$license_file" ]]; then
    # Try lowercase
    license_file="$LICENSES_DIR/${license,,}.txt"
  fi
  if [[ ! -f "$license_file" ]]; then
    # Try uppercase
    license_file="$LICENSES_DIR/${license^^}.txt"
  fi
  [[ -f "$license_file" ]] || { log_error "License file '$license_file' not found."; exit 3; }
  sed "s/{{COPYRIGHT_NOTICE}}/Copyright (c) $CURRENT_YEAR $title/g" "$license_file"
}

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

prepend_license() {
  local file="$1" license="$2" title="$3"
  local comment_style license_text formatted_notice

  comment_style="$(get_comment_style "$file")"
  [[ -z "$comment_style" ]] && { log_debug "No comment style for $file"; return; }

  license_text="$(get_license_text "$license" "$title")"
  grep -q "Copyright (c) $CURRENT_YEAR $title" "$file" && {
    log_info "Skipping (already has license): $file"
    return
  }

  formatted_notice="$(format_license_notice "$license_text" "$comment_style")"
  { printf '%s\n' "$formatted_notice"; cat "$file"; } > "$TMP_FILE"
  mv "$TMP_FILE" "$file"
  log_info "Updated: $file"
}

scan_directory() {
  local dir="$1" license="$2" title="$3"
  local processed=0 skipped=0 errors=0
  while IFS= read -r -d '' file; do
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
  done < <(find "$dir" -type f -print0)
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

log_info "Processing complete."
