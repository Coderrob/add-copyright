#!/usr/bin/env bash
# filepath: __tests__/test_gitignore.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TEST_DIR="__tests__/test_gitignore"
SRC_FILE="$TEST_DIR/ignored.js"
LICENSE_TYPE="MIT"
COPYRIGHT_HOLDER="Ignored User"

create_workspace "$TEST_DIR"
write_file "$TEST_DIR/.gitignore" "ignored.js"
write_file "$SRC_FILE" "console.log('ignored');"

init_git_repo "$TEST_DIR"

run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
assert_not_contains "$SRC_FILE" "Copyright (c) $(current_year) $COPYRIGHT_HOLDER"
pass ".gitignore respected for ignored files"

remove_dir "$TEST_DIR"