#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_FILE=".github/workflows/test-action.yml"

if command -v act >/dev/null 2>&1; then
  ACT=act
else
  echo "act not found. In the devcontainer this feature is provided by the devcontainer feature 'act'. Start the devcontainer in VS Code or install act locally: https://github.com/nektos/act"
  exit 2
fi

mkdir -p src

PRE_COUNT=$(find src -type f | wc -l || true)
PRE_SUM=$(find src -type f -exec sha1sum {} + 2>/dev/null || true)

echo "Pre-run files: $PRE_COUNT"

echo "Running act for workflow: $WORKFLOW_FILE"
ACT_OUTPUT_FILE=$(mktemp)

# Capture act output for assertions
if ! "$ACT" -s GITHUB_TOKEN="" -W .github/workflows -j test 2>&1 | tee "$ACT_OUTPUT_FILE"; then
  echo "act failed" >&2
  echo "---- act output (tail) ----"
  tail -n 200 "$ACT_OUTPUT_FILE"
  rm -f "$ACT_OUTPUT_FILE"
  exit 3
fi

echo "Act finished, running assertions..."

YEAR=$(date +%Y)
EXPECTED_COPYRIGHT_LINE="Copyright (c) $YEAR Test Runner"
EXPECTED_LICENSE_TOKEN="MIT"

# Check the act output for the updated file indicator and the printed file content
if ! grep -E "Updated: .*src/example.js" "$ACT_OUTPUT_FILE" >/dev/null 2>&1; then
  echo "FAIL: action did not report updating src/example.js" >&2
  echo "---- act output (tail) ----"
  tail -n 200 "$ACT_OUTPUT_FILE"
  rm -f "$ACT_OUTPUT_FILE"
  exit 4
fi

# Now check the printed file content that the workflow step outputs
if grep -F "$EXPECTED_COPYRIGHT_LINE" "$ACT_OUTPUT_FILE" >/dev/null 2>&1 && grep -F "$EXPECTED_LICENSE_TOKEN" "$ACT_OUTPUT_FILE" >/dev/null 2>&1; then
  echo "PASS: file contains expected copyright line and SPDX token"
  rm -f "$ACT_OUTPUT_FILE"
  exit 0
else
  echo "FAIL: file content does not contain expected copyright or SPDX token" >&2
  echo "Expected copyright line: $EXPECTED_COPYRIGHT_LINE"
  echo "Expected license token: $EXPECTED_LICENSE_TOKEN"
  echo "---- act output (tail) ----"
  tail -n 200 "$ACT_OUTPUT_FILE"
  rm -f "$ACT_OUTPUT_FILE"
  exit 5
fi

