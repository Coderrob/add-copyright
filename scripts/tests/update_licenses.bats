#!/usr/bin/env bats

# setup: Creates a local SPDX repository and isolated update workspace.
setup() {
  TEST_ROOT="$(mktemp -d)"
  SPDX_FIXTURE="$TEST_ROOT/spdx"
  UPDATE_WORKSPACE="$TEST_ROOT/workspace"
  mkdir -p "$SPDX_FIXTURE/json/details" "$UPDATE_WORKSPACE/licenses"
  printf '{"licenseId":"MIT","licenseText":"MIT fixture"}\n' \
    > "$SPDX_FIXTURE/json/details/MIT.json"
  git -C "$SPDX_FIXTURE" init -q
  git -C "$SPDX_FIXTURE" config user.name "BATS Runner"
  git -C "$SPDX_FIXTURE" config user.email "bats@example.com"
  git -C "$SPDX_FIXTURE" add .
  git -C "$SPDX_FIXTURE" commit -qm fixture
  printf 'existing license\n' > "$UPDATE_WORKSPACE/LICENSE"
}

# teardown: Removes local SPDX and update fixtures.
teardown() {
  rm -rf "$TEST_ROOT"
}

@test "license updater emits compressed runtime records" {
  cd "$UPDATE_WORKSPACE"
  run env SPDX_REPO="$SPDX_FIXTURE" bash \
    "$BATS_TEST_DIRNAME/../update_licenses.sh"
  [ "$status" -eq 0 ]
  [ -f "$UPDATE_WORKSPACE/licenses/MIT.json.gz" ]
  [ ! -f "$UPDATE_WORKSPACE/licenses/MIT.json" ]
  run bash -c "zcat '$UPDATE_WORKSPACE/licenses/MIT.json.gz' | jq -r .licenseId"
  [ "$status" -eq 0 ]
  [ "$output" = "MIT" ]
}
