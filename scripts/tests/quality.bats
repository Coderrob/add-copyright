#!/usr/bin/env bats

@test "all shell functions satisfy project quality limits" {
  run "$BATS_TEST_DIRNAME/../check_shell_quality.sh"
  [ "$status" -eq 0 ]
}
