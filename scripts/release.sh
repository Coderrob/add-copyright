#!/usr/bin/env bash
# filepath: scripts/release.sh

# Release Management Script
# =========================
#
# Automates the release process:
# - Creates semantic version tags
# - Maintains major version tags
# - Pushes tags to the remote repository
# - Creates release branches for major versions
#
# Usage: ./release.sh
#
# Dependencies: git
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Constants ---
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SEMVER_TAG_REGEX='^v[0-9]+\.[0-9]+\.[0-9]+$'
readonly SEMVER_TAG_GLOB='v[0-9].[0-9].[0-9]*'
readonly GIT_REMOTE='origin'

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
trap 'log_error "Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

# --- Dependencies ---
# require_cmds: Checks if required commands are available.
require_cmds() {
  command -v git >/dev/null 2>&1 || { log_error "Missing required command: git"; exit 2; }
}

# --- ANSI Colors (optional) ---
# init_colors: Initializes ANSI color codes if output is a terminal.
init_colors() {
  if [[ -t 1 ]]; then
    BOLD='\033[1m'
    BOLD_BLUE='\033[1;34m'
    BOLD_GREEN='\033[1;32m'
    BOLD_PURPLE='\033[1;35m'
    BOLD_RED='\033[1;31m'
    BOLD_UNDERLINED='\033[1;4m'
    OFF='\033[0m'
  else
    BOLD=''
    BOLD_BLUE=''
    BOLD_GREEN=''
    BOLD_PURPLE=''
    BOLD_RED=''
    BOLD_UNDERLINED=''
    OFF=''
  fi
}

# --- Tag Utilities ---
# get_latest_tag: Retrieves the latest semantic version tag from git.
get_latest_tag() {
  git describe --abbrev=0 --match="$SEMVER_TAG_GLOB" 2>/dev/null || printf '%s' "[unknown]"
}

# validate_tag: Validates if a tag matches the semantic version format.
# Arguments: tag
validate_tag() {
  [[ "$1" =~ $SEMVER_TAG_REGEX ]]
}

# major_of_tag: Extracts the major version number from a tag.
# Arguments: tag
major_of_tag() {
  local tag="$1"
  tag="${tag#v}"
  printf '%s' "${tag%%.*}"
}

# major_tag_of: Returns the major version tag with 'v' prefix.
# Arguments: tag
major_tag_of() {
  printf 'v%s' "$(major_of_tag "$1")"
}

# is_major_release: Determines if a new tag represents a major version release.
# Arguments: latest_tag, new_tag
is_major_release() {
  local latest_tag="$1"
  local new_tag="$2"

  [[ "$latest_tag" == "[unknown]" ]] && return 0

  local latest_major
  latest_major="$(major_of_tag "$latest_tag")"
  local new_major
  new_major="$(major_of_tag "$new_tag")"

  [[ "$latest_major" != "$new_major" ]]
}

# --- Release Steps ---
# confirm_package_version: Prompts user to confirm package.json version matches the tag.
# Arguments: tag
confirm_package_version() {
  local tag="$1"

  log_info "Reminding user to update package.json version"
  printf 'Make sure the version field in package.json is %s%s%s. Yes? [Y/%sn%s] ' "$BOLD_BLUE" "$tag" "$OFF" "$BOLD_UNDERLINED" "$OFF"
  read -r answer

  if [[ ! ("$answer" == "y" || "$answer" == "Y") ]]; then
    log_error "Please update the package.json version to ${BOLD_PURPLE}$tag${OFF} and commit your changes"
    exit 1
  fi
}

# create_tag: Creates an annotated git tag.
# Arguments: tag, message, [force_flag]
create_tag() {
  local tag="$1"
  local message="$2"
  local force="${3:-}"

  if [[ -n "$force" ]]; then
    git tag "$tag" --annotate --message "$message" "$force"
  else
    git tag "$tag" --annotate --message "$message"
  fi
  log_info "Tagged: ${BOLD_GREEN}$tag${OFF}"
}

update_major_tags() {
  local is_major="$1"
  local new_tag="$2"
  local latest_tag="$3"

  if [[ "$is_major" == "true" ]]; then
    local new_major
    new_major="$(major_tag_of "$new_tag")"
    log_info "Creating new major version tag: ${BOLD_GREEN}$new_major${OFF}"
    create_tag "$new_major" "$new_major Release"
    return 0
  fi

  local latest_major
  latest_major="$(major_tag_of "$latest_tag")"
  log_info "Syncing major version tag: ${BOLD_GREEN}$latest_major${OFF} with new tag: ${BOLD_GREEN}$new_tag${OFF}"
  create_tag "$latest_major" "Sync $latest_major tag with $new_tag" --force
}

# push_tags: Pushes tags to the remote repository.
# Arguments: is_major, new_tag, latest_tag
push_tags() {
  local is_major="$1"
  local new_tag="$2"
  local latest_tag="$3"

  git push --follow-tags

  if [[ "$is_major" == "true" ]]; then
    local new_major
    new_major="$(major_tag_of "$new_tag")"
    log_info "Tags: ${BOLD_GREEN}$new_major${OFF} and ${BOLD_GREEN}$new_tag${OFF} pushed to remote"
    return 0
  fi

  local latest_major
  latest_major="$(major_tag_of "$latest_tag")"
  git push "$GIT_REMOTE" "$latest_major" --force
  log_info "Tags: ${BOLD_GREEN}$latest_major${OFF} and ${BOLD_GREEN}$new_tag${OFF} pushed to remote"
}

# create_release_branch: Creates a release branch for major versions.
# Arguments: is_major, new_tag
create_release_branch() {
  local is_major="$1"
  local new_tag="$2"

  [[ "$is_major" == "true" ]] || return 0

  local new_major
  new_major="$(major_tag_of "$new_tag")"
  log_info "Creating and pushing new releases branch for major version: ${BOLD_GREEN}$new_major${OFF}"
  git branch "releases/$new_major" "$new_major"
  git push --set-upstream "$GIT_REMOTE" "releases/$new_major"
}

# --- Main ---
# main: Main function that orchestrates the release process.
main() {
  require_cmds
  init_colors

  log_info "Starting release process..."

  local latest_tag
  latest_tag="$(get_latest_tag)"
  log_info "Latest release tag: ${BOLD_BLUE}$latest_tag${OFF}"

  printf 'Enter a new release tag (vX.X.X format): '
  read -r new_tag

  if ! validate_tag "$new_tag"; then
    log_error "Tag: ${BOLD_BLUE}$new_tag${OFF} is ${BOLD_RED}not valid${OFF} (must be in ${BOLD}vX.X.X${OFF} format)"
    exit 1
  fi

  confirm_package_version "$new_tag"
  create_tag "$new_tag" "$new_tag Release"

  local is_major="false"
  if is_major_release "$latest_tag" "$new_tag"; then
    is_major="true"
    log_info "This is a major release"
  else
    log_info "This is not a major release"
  fi

  update_major_tags "$is_major" "$new_tag" "$latest_tag"
  push_tags "$is_major" "$new_tag" "$latest_tag"
  create_release_branch "$is_major" "$new_tag"

  log_info "${BOLD_GREEN}Done!${OFF}"
}

main "$@"
