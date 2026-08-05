#!/usr/bin/env bats

# setup: Resolves the workflow directory for configuration assertions.
setup() {
  WORKFLOW_DIR="$BATS_TEST_DIRNAME/../../.github/workflows"
}

@test "workflows use Node 24 action generations" {
  run grep -RE 'actions/checkout@v[1-5]|create-pull-request@v[1-7]' "$WORKFLOW_DIR"
  [ "$status" -eq 1 ]
}

@test "copyright automation invokes local action with supported inputs" {
  run grep -F "working-directory: ./scripts" "$WORKFLOW_DIR/update-copyright.yml"
  [ "$status" -eq 0 ]
  run grep -E 'create-branch:|directory-path:' "$WORKFLOW_DIR/update-copyright.yml"
  [ "$status" -eq 1 ]
}

@test "automation workflows create pull requests instead of direct pushes" {
  run grep -F "uses: peter-evans/create-pull-request@v8" \
    "$WORKFLOW_DIR/update-copyright.yml" "$WORKFLOW_DIR/update-licenses.yml"
  [ "$status" -eq 0 ]
  run grep -RE 'git push' "$WORKFLOW_DIR"
  [ "$status" -eq 1 ]
}
