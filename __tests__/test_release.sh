#!/usr/bin/env bash
# filepath: __tests__/test_release.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

export GIT_TERMINAL_PROMPT=0

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

  # Test 1: Minor release creates correct tag
  NEW_TAG="v0.1.0"
  (printf "%s\ny\n" "$NEW_TAG" | ../scripts/release.sh) || true

  if git tag | grep -q "$NEW_TAG"; then
    pass "Release tag $NEW_TAG created"
  else
    fail "Release tag $NEW_TAG not created"
  fi

  # Test 2: Minor release creates/updates major version tag (v0)
  if git tag | grep -qx "v0"; then
    pass "Major version tag v0 synced with minor release"
  else
    fail "Major version tag v0 not created during minor release"
  fi

  # Test 3: Major release creates new version and major tag
  NEW_MAJOR_TAG="v1.0.0"
  (printf "%s\ny\n" "$NEW_MAJOR_TAG" | ../scripts/release.sh) || true

  if git tag | grep -q "$NEW_MAJOR_TAG"; then
    pass "Major release tag $NEW_MAJOR_TAG created"
  else
    fail "Major release tag $NEW_MAJOR_TAG not created"
  fi

  # Test 4: Major release creates v1 tag
  if git tag | grep -qx "v1"; then
    pass "New major version tag v1 created for major release"
  else
    fail "Major version tag v1 not created during major release"
  fi
)

# Test 5: Invalid tag format exits with error
invalid_test_dir="test_release_invalid"
remove_dir "$invalid_test_dir"
mkdir "$invalid_test_dir"
(
  cd "$invalid_test_dir"
  git init -q
  git config user.name "Test"
  git config user.email "test@test.com"
  write_file "package.json" '{"name":"test"}'
  git add .
  git commit -m "init" > /dev/null
  git remote add origin .

  if (printf "invalid-tag\n" | ../scripts/release.sh) 2>/dev/null; then
    fail "Expected failure for invalid tag format"
  else
    pass "Invalid tag format correctly returns error"
  fi
)
remove_dir "$invalid_test_dir"

remove_dir "$TEST_DIR"
