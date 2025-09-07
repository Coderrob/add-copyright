#!/usr/bin/env bash
# filepath: __tests__/test_release.sh

# Release Script Test Suite
# =========================
#
# This test suite validates the functionality of the release.sh script.
# It tests the release process including tag creation and validation.
#
# Tests:
# - Semantic version tag creation
# - Git tag management
# - Release workflow simulation
#
# Usage: ./test_release.sh
#
# Dependencies: git, bash
#
# Author: Robert Lindley
# License: MIT

set -euo pipefail

# --- Test Setup ---
TEST_DIR="test_release_repo"
cd "$(dirname "$0")/.."
rm -rf "$TEST_DIR"
mkdir "$TEST_DIR"
cd "$TEST_DIR"
git init -q
echo '{"name": "test", "version": "0.0.1"}' > package.json
git add package.json
git commit -m "init" > /dev/null

git tag v0.0.1 -a -m "v0.0.1 Release"

# --- Simulate user input for new tag ---
export GIT_TERMINAL_PROMPT=0
NEW_TAG="v0.1.0"
echo "y" | ../../scripts/release.sh <<< "$NEW_TAG"

# --- Test Assertion ---
if git tag | grep -q "$NEW_TAG"; then
  echo "[PASS] Release tag $NEW_TAG created"
else
  echo "[FAIL] Release tag $NEW_TAG not created" >&2
  exit 1
fi

# Clean up
git tag -d "$NEW_TAG" > /dev/null
cd ..
rm -rf "$TEST_DIR"
