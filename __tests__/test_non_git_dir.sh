#!/usr/bin/env bash
# filepath: __tests__/test_non_git_dir.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

TMP_DIR="$(mktemp -d)"
SRC_FILE="$TMP_DIR/sample.py"
LICENSE_TYPE="MIT"
COPYRIGHT_HOLDER="Non Git User"
EXPECTED_LINE="Copyright (c) $(date +"%Y") $COPYRIGHT_HOLDER"

write_file "$SRC_FILE" "print('hi')"

run_copyright "$TMP_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
assert_contains "$SRC_FILE" "$EXPECTED_LINE"
pass "Script runs outside a git repository"

remove_dir "$TMP_DIR"