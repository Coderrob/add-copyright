#!/usr/bin/env bats

# setup: Resolves the workflow directory for configuration assertions.
setup() {
  WORKFLOW_DIR="$BATS_TEST_DIRNAME/../../.github/workflows"
}

@test "workflows pin Node 24 actions to immutable commits" {
  run grep -RE 'uses: (actions/checkout|peter-evans/create-pull-request)@v' "$WORKFLOW_DIR"
  [ "$status" -eq 1 ]
  run grep -RE 'uses: (actions/checkout|peter-evans/create-pull-request)@[0-9a-f]{40} # v(6|8)' "$WORKFLOW_DIR"
  [ "$status" -eq 0 ]
}

@test "copyright automation invokes local action with supported inputs" {
  run grep -F "working-directory: ./scripts" "$WORKFLOW_DIR/update-copyright.yml"
  [ "$status" -eq 0 ]
  run grep -E 'create-branch:|directory-path:' "$WORKFLOW_DIR/update-copyright.yml"
  [ "$status" -eq 1 ]
}

@test "automation workflows create pull requests instead of direct pushes" {
  run grep -F "uses: peter-evans/create-pull-request@5f6978faf089d4d20b00c7766989d076bb2fc7f1 # v8" \
    "$WORKFLOW_DIR/update-copyright.yml" "$WORKFLOW_DIR/update-licenses.yml"
  [ "$status" -eq 0 ]
  run grep -RE 'git push' "$WORKFLOW_DIR"
  [ "$status" -eq 1 ]
}
