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
  run "$BATS_TEST_DIRNAME/../release.sh" invalid
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid"* ]]
}

@test "creates an annotated release tag before publishing" {
  cd "$TEST_REPOSITORY"
  git remote add origin .
  run "$BATS_TEST_DIRNAME/../release.sh" v0.1.0
  [ "$status" -eq 0 ]
  git tag --list v0.1.0 | grep -qx v0.1.0
}

@test "dry run reports release mutations without changing git state" {
  cd "$TEST_REPOSITORY"
  run "$BATS_TEST_DIRNAME/../release.sh" --dry-run v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN: git tag v1.0.0"* ]]
  [ -z "$(git tag --list v1.0.0)" ]
  ! git show-ref --verify --quiet refs/heads/releases/v1
}
