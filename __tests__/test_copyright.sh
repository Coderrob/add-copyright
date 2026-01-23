#!/usr/bin/env bash
# filepath: __tests__/test_copyright.sh

set -euo pipefail

TEST_DIR="__tests__/test_copyright_workspace"
SRC_FILE="$TEST_DIR/hello.ts"
LICENSE_TYPE="apache-2.0"
COPYRIGHT_HOLDER="Test User"
EXPECTED_HEADER="Copyright $(date +"%Y") $COPYRIGHT_HOLDER"

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

create_workspace "$TEST_DIR"
write_file "$SRC_FILE" "export const hello = () => 'Hello, world!';"

run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
assert_contains "$SRC_FILE" "$EXPECTED_HEADER"
pass "Copyright header present in $SRC_FILE"

run_copyright "$TEST_DIR" "$LICENSE_TYPE" "$COPYRIGHT_HOLDER"
if [[ $(grep -c "$EXPECTED_HEADER" "$SRC_FILE") -eq 1 ]]; then
  pass "Header not duplicated on second run"
else
  fail "Header duplicated on second run"
fi

remove_dir "$TEST_DIR"
