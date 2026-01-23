#!/usr/bin/env bash
# filepath: __tests__/test_placeholders.sh

set -euo pipefail

TEST_DIR="__tests__/test_workspace_placeholders"
SRC_FILE="$TEST_DIR/sample.js"
LICENSE_TYPE="MIT"
COPYRIGHT_HOLDER="ACME/Corp & Co"
EXPECTED_LINE="Copyright (c) $(date +"%Y") $COPYRIGHT_HOLDER"

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

create_workspace "$TEST_DIR"
write_file "$SRC_FILE" "console.log('hi');"

run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
assert_contains "$SRC_FILE" "$EXPECTED_LINE"
pass "Placeholder substitution supports special characters"

remove_dir "$TEST_DIR"