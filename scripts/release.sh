#!/usr/bin/env bash
# filepath: scripts/release.sh

set -euo pipefail

# --- Constants ---
readonly SCRIPT_NAME="$(basename "$0")"
readonly SEMVER_TAG_REGEX='v[0-9]+\.[0-9]+\.[0-9]+$'
readonly SEMVER_TAG_GLOB='v[0-9].[0-9].[0-9]*'
readonly MAJOR_SEMVER_TAG_REGEX='v\([0-9]\+\)\..*'
readonly GIT_REMOTE='origin'

# --- Logging ---
log() {
  local level="$1"; shift
  printf '%s [%s] %s: %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$SCRIPT_NAME" "$level" "$*" >&2
}
log_info()    { log "INFO" "$@"; }
log_warn()    { log "WARN" "$@"; }
log_error()   { log "ERROR" "$@"; }

# --- Error Handling ---
trap 'log_error "Error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

# --- Check Dependencies ---
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log_error "Missing required command: $1"; exit 2; }
}
for cmd in git expr; do require_cmd "$cmd"; done

# --- ANSI Colors (optional) ---
if [[ -t 1 ]]; then
  readonly BOLD='\033[1m'
  readonly BOLD_BLUE='\033[1;34m'
  readonly BOLD_GREEN='\033[1;32m'
  readonly BOLD_PURPLE='\033[1;35m'
  readonly BOLD_RED='\033[1;31m'
  readonly BOLD_UNDERLINED='\033[1;4m'
  readonly OFF='\033[0m'
else
  readonly BOLD=''
  readonly BOLD_BLUE=''
  readonly BOLD_GREEN=''
  readonly BOLD_PURPLE=''
  readonly BOLD_RED=''
  readonly BOLD_UNDERLINED=''
  readonly OFF=''
fi

# --- Functions ---
get_latest_tag() {
  git describe --abbrev=0 --match="$SEMVER_TAG_GLOB" 2>/dev/null || printf '%s' "[unknown]"
}

validate_tag() {
  [[ "$1" =~ $SEMVER_TAG_REGEX ]]
}

update_package_version() {
  local tag="$1"

  log_info "Reminding user to update package.json version"
  printf 'Make sure the version field in package.json is %s%s%s. Yes? [Y/%sn%s] ' "$BOLD_BLUE" "$tag" "$OFF" "$BOLD_UNDERLINED" "$OFF"
  read -r YN

  if [[ ! ($YN == "y" || $YN == "Y") ]]; then
    log_error "Please update the package.json version to ${BOLD_PURPLE}$tag${OFF} and commit your changes"
    exit 1
  fi
}

create_tag() {
  local tag="$1"
  local message="$2"
  local force="${3:-}"

  git tag "$tag" --annotate --message "$message" $force
  log_info "Tagged: ${BOLD_GREEN}$tag${OFF}"
}

is_major_release() {
  local latest_tag="$1"
  local new_tag="$2"

  if [[ "$latest_tag" == "[unknown]" ]]; then
    return 0 # This is the first major release
  fi

  local latest_major
  latest_major=$(expr "$latest_tag" : "$MAJOR_SEMVER_TAG_REGEX")
  local new_major
  new_major=$(expr "$new_tag" : "$MAJOR_SEMVER_TAG_REGEX")

  [[ "$latest_major" != "$new_major" ]]
}

update_major_tags() {
  local is_major="$1"
  local new_tag="$2"
  local latest_tag="$3"

  if $is_major; then
    local new_major
    new_major=$(expr "$new_tag" : "$MAJOR_SEMVER_TAG_REGEX")
    log_info "Creating new major version tag: ${BOLD_GREEN}$new_major${OFF}"
    create_tag "$new_major" "$new_major Release"
  else
    local latest_major
    latest_major=$(expr "$latest_tag" : "$MAJOR_SEMVER_TAG_REGEX")
    log_info "Syncing major version tag: ${BOLD_GREEN}$latest_major${OFF} with new tag: ${BOLD_GREEN}$new_tag${OFF}"
    create_tag "$latest_major" "Sync $latest_major tag with $new_tag" --force
  fi
}

push_tags() {
  local is_major="$1"
  local new_tag="$2"
  local latest_tag="$3"

  git push --follow-tags

  if $is_major; then
    local new_major
    new_major=$(expr "$new_tag" : "$MAJOR_SEMVER_TAG_REGEX")
    log_info "Tags: ${BOLD_GREEN}$new_major${OFF} and ${BOLD_GREEN}$new_tag${OFF} pushed to remote"
  else
    local latest_major
    latest_major=$(expr "$latest_tag" : "$MAJOR_SEMVER_TAG_REGEX")
    git push "$GIT_REMOTE" "$latest_major" --force
    log_info "Tags: ${BOLD_GREEN}$latest_major${OFF} and ${BOLD_GREEN}$new_tag${OFF} pushed to remote"
  fi
}

create_release_branch() {
  local new_tag="$1"
  local latest_tag="$2"

  if is_major_release "$latest_tag" "$new_tag"; then
    local new_major
    new_major=$(expr "$new_tag" : "$MAJOR_SEMVER_TAG_REGEX")
    log_info "Creating and pushing new releases branch for major version: ${BOLD_GREEN}$new_major${OFF}"
    git branch "releases/$new_major" "$new_major"
    git push --set-upstream "$GIT_REMOTE" "releases/$new_major"
  fi
}

# --- Main ---
log_info "Starting release process..."

# Retrieve the latest tag
latest_tag="$(get_latest_tag)"
log_info "Latest release tag: ${BOLD_BLUE}$latest_tag${OFF}"

# Prompt user for a new tag
printf 'Enter a new release tag (vX.X.X format): '
read -r new_tag

# Validate the new tag
if ! validate_tag "$new_tag"; then
  log_error "Tag: ${BOLD_BLUE}$new_tag${OFF} is ${BOLD_RED}not valid${OFF} (must be in ${BOLD}vX.X.X${OFF} format)"
  exit 1
fi

# Remind user to update package.json version
update_package_version "$new_tag"

# Tag the new release
create_tag "$new_tag" "$new_tag Release"

# Check if this is a major release
if is_major_release "$latest_tag" "$new_tag"; then
  log_info "This is a major release"
else
  log_info "This is not a major release"
fi

# Update major tags
update_major_tags "$(is_major_release "$latest_tag" "$new_tag")" "$new_tag" "$latest_tag"

# Push the new tags to remote
push_tags "$(is_major_release "$latest_tag" "$new_tag")" "$new_tag" "$latest_tag"

# Create a release branch for major releases, if needed
create_release_branch "$new_tag" "$latest_tag"

log_info "${BOLD_GREEN}Done!${OFF}"
