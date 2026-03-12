#!/usr/bin/env bash
# filepath: __tests__/test_unsupported_extension.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TEST_DIR="__tests__/test_unsupported_extension"
SRC_FILE="$TEST_DIR/notes.txt"
LICENSE_TYPE="MIT"
COPYRIGHT_HOLDER="Test User"

create_workspace "$TEST_DIR"
write_file "$SRC_FILE" "some text"

run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
assert_not_contains "$SRC_FILE" "Copyright (c) $(current_year) $COPYRIGHT_HOLDER"
pass "Unsupported extension not modified"

remove_dir "$TEST_DIR"