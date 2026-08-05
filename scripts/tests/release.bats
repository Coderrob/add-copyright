#!/usr/bin/env bats

# setup: Creates a disposable Git repository for each release test.
setup() {
  TEST_ROOT="$(mktemp -d)"
  TEST_REPOSITORY="$TEST_ROOT/repository"
  RELEASE_REMOTE="$TEST_ROOT/remote.git"
  git init --bare -q "$RELEASE_REMOTE"
  mkdir -p "$TEST_REPOSITORY"
  git -C "$TEST_REPOSITORY" init -q
  git -C "$TEST_REPOSITORY" config user.name "BATS Runner"
  git -C "$TEST_REPOSITORY" config user.email "bats@example.com"
  printf '{}\n' > "$TEST_REPOSITORY/package.json"
  git -C "$TEST_REPOSITORY" add package.json
  git -C "$TEST_REPOSITORY" commit -qm init
  git -C "$TEST_REPOSITORY" tag -a v0.0.1 -m "v0.0.1 Release"
  git -C "$TEST_REPOSITORY" remote add origin "$RELEASE_REMOTE"
}

# teardown: Removes the disposable release-test repository.
teardown() {
  rm -rf "$TEST_ROOT"
}

@test "rejects an invalid semantic version tag" {
  cd "$TEST_REPOSITORY"
  run "$BATS_TEST_DIRNAME/../release.sh" invalid
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid"* ]]
}

@test "creates an annotated release tag before publishing" {
  cd "$TEST_REPOSITORY"
  run "$BATS_TEST_DIRNAME/../release.sh" v0.1.0
  [ "$status" -eq 0 ]
  git tag --list v0.1.0 | grep -qx v0.1.0
}

@test "atomic publication leaves no remote tags when one ref is rejected" {
  printf '%s\n' '#!/usr/bin/env bash' \
    'while read -r _ _ ref; do' \
    '  [[ "$ref" == "refs/tags/v0" ]] && exit 1' \
    'done' > "$RELEASE_REMOTE/hooks/pre-receive"
  chmod +x "$RELEASE_REMOTE/hooks/pre-receive"
  cd "$TEST_REPOSITORY"
  run "$BATS_TEST_DIRNAME/../release.sh" v0.2.0
  [ "$status" -ne 0 ]
  [ -z "$(git --git-dir="$RELEASE_REMOTE" tag --list v0.2.0)" ]
  [ -z "$(git --git-dir="$RELEASE_REMOTE" tag --list v0)" ]
}

@test "preflight rejects a release tag that already exists remotely" {
  git -C "$TEST_REPOSITORY" tag -a v0.3.0 -m remote-fixture
  git -C "$TEST_REPOSITORY" push -q origin v0.3.0
  git -C "$TEST_REPOSITORY" tag -d v0.3.0 >/dev/null
  cd "$TEST_REPOSITORY"
  run "$BATS_TEST_DIRNAME/../release.sh" v0.3.0
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists remotely"* ]]
  [ -z "$(git tag --list v0.3.0)" ]
}

@test "dry run reports release mutations without changing git state" {
  cd "$TEST_REPOSITORY"
  run "$BATS_TEST_DIRNAME/../release.sh" --dry-run v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN: git tag v1.0.0"* ]]
  [ -z "$(git tag --list v1.0.0)" ]
  ! git show-ref --verify --quiet refs/heads/releases/v1
}
