#!/usr/bin/env bash
# filepath: __tests__/test_missing_args.sh

set -euo pipefail

# shellcheck source=__tests__/helpers.sh
source "$(dirname "$0")/helpers.sh"

if "$(dirname "$0")/../scripts/copyright.sh" >/dev/null 2>&1; then
  fail "Expected failure when required args are missing"
else
  pass "Missing args returns non-zero exit"
fi