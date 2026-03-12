#!/usr/bin/env bash
# filepath: __tests__/test_invalid_license.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TEST_DIR="__tests__/test_invalid_license"
SRC_FILE="$TEST_DIR/hello.js"
LICENSE_TYPE="NOT-A-LICENSE"
COPYRIGHT_HOLDER="Test User"

create_workspace "$TEST_DIR"
write_file "$SRC_FILE" "console.log('hello');"

if run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"; then
  fail "Expected failure for invalid license"
else
  pass "Invalid license returns non-zero exit"
fi

remove_dir "$TEST_DIR"