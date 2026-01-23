#!/usr/bin/env bash
# filepath: __tests__/test_invalid_directory.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

BAD_DIR="__tests__/does_not_exist"

if run_copyright "$BAD_DIR" "MIT" "Nobody" >/dev/null 2>&1; then
  fail "Expected failure for non-existent directory"
else
  pass "Non-existent directory returns non-zero exit"
fi