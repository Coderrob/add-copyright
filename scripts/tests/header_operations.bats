#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures/headers"
  TEST_ROOT="$(mktemp -d)"
  source "$PROJECT_ROOT/scripts/lib/header_operations.bash"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

# render_fixture: Replaces an owned header using static fixture notice text.
# Arguments: input_fixture, output_path, formatted_notice
render_fixture() {
  local input="$FIXTURES/$1" output="$2" notice="$3" preamble
  preamble="$(preamble_line_count "$input")"
  write_licensed_content "$notice" "$input" "$preamble" > "$output"
}

@test "golden line fixture preserves the preamble and replaces owned content" {
  local notice=$'# add-copyright: begin\n# SPDX-License-Identifier: Apache-2.0\n# Copyright 2026 New Holder\n# add-copyright: end'
  render_fixture line-input.py "$TEST_ROOT/actual.py" "$notice"
  cmp "$FIXTURES/line-expected.py" "$TEST_ROOT/actual.py"
}

@test "golden block fixture replaces exactly one owned header" {
  local notice=$'/*\n * add-copyright: begin\n * SPDX-License-Identifier: Apache-2.0\n * Copyright 2026 New Holder\n * add-copyright: end\n */'
  render_fixture block-input.js "$TEST_ROOT/actual.js" "$notice"
  cmp "$FIXTURES/block-expected.js" "$TEST_ROOT/actual.js"
}

@test "golden slash-comment fixture replaces exactly one owned header" {
  local notice=$'// add-copyright: begin\n// SPDX-License-Identifier: Apache-2.0\n// Copyright 2026 New Holder\n// add-copyright: end'
  render_fixture slash-input.go "$TEST_ROOT/actual.go" "$notice"
  cmp "$FIXTURES/slash-expected.go" "$TEST_ROOT/actual.go"
}

@test "golden user-owned fixture remains untouched" {
  local notice=$'# add-copyright: begin\n# SPDX-License-Identifier: Apache-2.0\n# Copyright 2026 New Holder\n# add-copyright: end'
  render_fixture user-owned-input.py "$TEST_ROOT/actual.py" "$notice"
  cmp "$FIXTURES/user-owned-expected.py" "$TEST_ROOT/actual.py"
}
