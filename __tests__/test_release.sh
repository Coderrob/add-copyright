#!/usr/bin/env bash
# filepath: __tests__/test_release.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TEST_DIR="test_release_repo"

remove_dir "$TEST_DIR"
mkdir "$TEST_DIR"

init_git_repo "$TEST_DIR"
(
  cd "$TEST_DIR"
  write_file "package.json" '{"name": "test", "version": "0.0.1"}'
  git add package.json
  git commit -m "init" > /dev/null
  git tag v0.0.1 -a -m "v0.0.1 Release"
  git remote add origin .

  export GIT_TERMINAL_PROMPT=0
  NEW_TAG="v0.1.0"
  (echo -e "$NEW_TAG\ny" | ../scripts/release.sh) || true

  if git tag | grep -q "$NEW_TAG"; then
    pass "Release tag $NEW_TAG created"
  else
    fail "Release tag $NEW_TAG not created"
  fi
)

remove_dir "$TEST_DIR"
