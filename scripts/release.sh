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
# Usage: ./release.sh [--dry-run] <vX.Y.Z>
#
# Dependencies: git
#
# Author: Robert Lindley
# License: Apache-2.0

set -euo pipefail

# --- Constants ---
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SEMVER_TAG_REGEX='^v[0-9]+\.[0-9]+\.[0-9]+$'
readonly SEMVER_TAG_GLOB='v[0-9].[0-9].[0-9]*'
readonly GIT_REMOTE='origin'

# shellcheck source=scripts/lib/logging.bash
source "$SCRIPT_DIR/lib/logging.bash"

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
    BOLD_BLUE='\033[1;34m'
    BOLD_GREEN='\033[1;32m'
    OFF='\033[0m'
  else
    BOLD_BLUE=''
    BOLD_GREEN=''
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
# ensure_remote_tag_available: Verifies remote inspection and tag availability.
# Arguments: tag
ensure_remote_tag_available() {
  local remote_status=0
  git ls-remote --exit-code --tags "$GIT_REMOTE" "refs/tags/$1" >/dev/null 2>&1 || remote_status=$?
  case "$remote_status" in
    0) log_error "Tag already exists remotely: $1"; return 1 ;;
    2) return 0 ;;
    *) log_error "Unable to inspect remote tags on $GIT_REMOTE"; return 1 ;;
  esac
}

# ensure_release_ready: Verifies the remote and requested tag are available.
# Arguments: tag
ensure_release_ready() {
  git remote get-url "$GIT_REMOTE" >/dev/null
  if git show-ref --verify --quiet "refs/tags/$1"; then
    log_error "Tag already exists locally: $1"
    return 1
  fi
  ensure_remote_tag_available "$1"
}

# run_git: Executes git or logs the exact mutation during a dry run.
# Arguments: dry_run, git_arguments...
run_git() {
  local dry_run="$1"
  shift
  [[ "$dry_run" == "true" ]] && { log_info "DRY RUN: git $*"; return 0; }
  git "$@"
}

# create_tag: Creates an annotated git tag.
# Arguments: dry_run, tag, message, [force_flag]
create_tag() {
  local dry_run="$1" tag="$2" message="$3" force="${4:-}"
  local force_args=()
  [[ -n "$force" ]] && force_args+=("$force")

  run_git "$dry_run" tag "$tag" --annotate --message "$message" "${force_args[@]}"
  log_info "Tagged: ${BOLD_GREEN}$tag${OFF}"
}

# update_major_tags: Creates or advances the floating major-version tag.
# Arguments: dry_run, is_major, new_tag, latest_tag
update_major_tags() {
  local dry_run="$1" is_major="$2" new_tag="$3" latest_tag="$4"

  if [[ "$is_major" == "true" ]]; then
    local new_major
    new_major="$(major_tag_of "$new_tag")"
    log_info "Creating new major version tag: ${BOLD_GREEN}$new_major${OFF}"
    create_tag "$dry_run" "$new_major" "$new_major Release"
    return 0
  fi

  local latest_major
  latest_major="$(major_tag_of "$latest_tag")"
  log_info "Syncing major version tag: ${BOLD_GREEN}$latest_major${OFF} with new tag: ${BOLD_GREEN}$new_tag${OFF}"
  create_tag "$dry_run" "$latest_major" "Sync $latest_major tag with $new_tag" --force
}

# push_release_refs: Atomically publishes all release references.
# Arguments: dry_run, is_major, new_tag, latest_tag
push_release_refs() {
  local dry_run="$1" is_major="$2" new_tag="$3" latest_tag="$4"
  local major refs
  major="$(major_tag_of "$new_tag")"
  [[ "$is_major" == "true" ]] || major="$(major_tag_of "$latest_tag")"
  refs=("refs/tags/$new_tag:refs/tags/$new_tag" "+refs/tags/$major:refs/tags/$major")

  if [[ "$is_major" == "true" ]]; then
    refs+=("refs/heads/releases/$major:refs/heads/releases/$major")
  fi
  run_git "$dry_run" push --atomic "$GIT_REMOTE" "${refs[@]}"
  log_info "Published release references for ${BOLD_GREEN}$new_tag${OFF} atomically"
}

# create_release_branch: Creates the local release branch for major versions.
# Arguments: dry_run, is_major, new_tag
create_release_branch() {
  local dry_run="$1" is_major="$2" new_tag="$3"

  [[ "$is_major" == "true" ]] || return 0

  local new_major
  new_major="$(major_tag_of "$new_tag")"
  log_info "Creating releases branch for major version: ${BOLD_GREEN}$new_major${OFF}"
  run_git "$dry_run" branch "releases/$new_major" "$new_major"
}

# parse_arguments: Prints the dry-run flag and validated release tag.
# Arguments: [--dry-run], tag
parse_arguments() {
  local dry_run=false
  [[ "${1:-}" == "--dry-run" ]] && { dry_run=true; shift; }
  [[ $# -eq 1 ]] || { log_error "Usage: $SCRIPT_NAME [--dry-run] <vX.Y.Z>"; return 1; }
  validate_tag "$1" || { log_error "Tag '$1' is not valid (expected vX.Y.Z)"; return 1; }
  printf '%s %s\n' "$dry_run" "$1"
}

# classify_release: Sets is_major and logs the release classification.
# Arguments: latest_tag, new_tag
classify_release() {
  if is_major_release "$1" "$2"; then
    log_info "This is a major release"
    printf '%s' "true"
    return 0
  fi
  log_info "This is not a major release"
  printf '%s' "false"
}

# --- Main ---
# main: Main function that orchestrates the release process.
main() {
  require_cmds
  init_colors

  log_info "Starting release process..."

  local parsed dry_run new_tag
  parsed="$(parse_arguments "$@")"
  read -r dry_run new_tag <<< "$parsed"
  ensure_release_ready "$new_tag"

  local latest_tag
  latest_tag="$(get_latest_tag)"
  log_info "Latest release tag: ${BOLD_BLUE}$latest_tag${OFF}"

  create_tag "$dry_run" "$new_tag" "$new_tag Release"

  local is_major
  is_major="$(classify_release "$latest_tag" "$new_tag")"
  update_major_tags "$dry_run" "$is_major" "$new_tag" "$latest_tag"
  create_release_branch "$dry_run" "$is_major" "$new_tag"
  push_release_refs "$dry_run" "$is_major" "$new_tag" "$latest_tag"

  log_info "${BOLD_GREEN}Done!${OFF}"
}

main "$@"
