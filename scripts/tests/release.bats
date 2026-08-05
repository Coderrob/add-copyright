#!/usr/bin/env bats

# setup: Creates a disposable Git repository for each release test.
setup() {
  TEST_REPOSITORY="$(mktemp -d)"
  git -C "$TEST_REPOSITORY" init -q
  git -C "$TEST_REPOSITORY" config user.name "BATS Runner"
  git -C "$TEST_REPOSITORY" config user.email "bats@example.com"
  printf '{}\n' > "$TEST_REPOSITORY/package.json"
  git -C "$TEST_REPOSITORY" add package.json
  git -C "$TEST_REPOSITORY" commit -qm init
  git -C "$TEST_REPOSITORY" tag -a v0.0.1 -m "v0.0.1 Release"
}

# teardown: Removes the disposable release-test repository.
teardown() {
  rm -rf "$TEST_REPOSITORY"
}

@test "rejects an invalid semantic version tag" {
  cd "$TEST_REPOSITORY"
  run bash -c "printf 'invalid\n' | '$BATS_TEST_DIRNAME/../release.sh'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid"* ]]
}

@test "creates an annotated release tag before publishing" {
  cd "$TEST_REPOSITORY"
  git remote add origin .
  run bash -c "printf 'v0.1.0\ny\n' | '$BATS_TEST_DIRNAME/../release.sh'"
  git tag --list v0.1.0 | grep -qx v0.1.0
}
