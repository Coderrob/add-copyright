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
  run env SPDX_REPO="$SPDX_FIXTURE" MIN_LICENSE_COUNT=1 bash \
    "$BATS_TEST_DIRNAME/../update_licenses.sh"
  [ "$status" -eq 0 ]
  [ -f "$UPDATE_WORKSPACE/licenses/MIT.json.gz" ]
  [ ! -f "$UPDATE_WORKSPACE/licenses/MIT.json" ]
  run bash -c "zcat '$UPDATE_WORKSPACE/licenses/MIT.json.gz' | jq -r .licenseId"
  [ "$status" -eq 0 ]
  [ "$output" = "MIT" ]
}

@test "license updater preserves the live database when validation fails" {
  printf 'keep me\n' > "$UPDATE_WORKSPACE/licenses/sentinel.json.gz"
  cd "$UPDATE_WORKSPACE"
  run env SPDX_REPO="$SPDX_FIXTURE" MIN_LICENSE_COUNT=2 bash \
    "$BATS_TEST_DIRNAME/../update_licenses.sh"
  [ "$status" -ne 0 ]
  [ "$(<licenses/sentinel.json.gz)" = "keep me" ]
}

@test "license updater restores the live database when installation is interrupted" {
  printf 'keep me\n' > "$UPDATE_WORKSPACE/licenses/sentinel.json.gz"
  mkdir -p "$TEST_ROOT/bin"
  printf '%s\n' '#!/usr/bin/env bash' \
    'if [[ "$1" == "licenses" && "$2" == *"licenses.backup" ]]; then' \
    '  /usr/bin/mv "$@"' \
    '  kill -TERM "$PPID"' \
    '  sleep 1' \
    'else' \
    '  /usr/bin/mv "$@"' \
    'fi' > "$TEST_ROOT/bin/mv"
  chmod +x "$TEST_ROOT/bin/mv"
  cd "$UPDATE_WORKSPACE"
  run env PATH="$TEST_ROOT/bin:$PATH" SPDX_REPO="$SPDX_FIXTURE" \
    MIN_LICENSE_COUNT=1 bash "$BATS_TEST_DIRNAME/../update_licenses.sh"
  [ "$status" -eq 130 ]
  [ "$(<licenses/sentinel.json.gz)" = "keep me" ]
}
