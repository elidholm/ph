#!/usr/bin/env bats

setup() {
  PH_BIN="${BATS_TEST_DIRNAME}/../ph"
}

@test "prints usage and exits with error when run without command" {
  run "$PH_BIN"
  ((status == 1))
  [[ $output == *'Usage:'* ]]
}

@test "fails when non-existing command is run" {
  run "$PH_BIN" non-existing-command
  ((status == 1))
  [[ $output == *'Unknown command:'* ]]
  [[ $output == *'non-existing-command'* ]]
}

@test "prints main help with --help" {
  run "$PH_BIN" --help
  ((status == 0))
  [[ $output == *'Usage:'* ]]
  [[ $output == *'Commands:'* ]]
}

@test "prints help for disable command" {
  run "$PH_BIN" disable --help
  ((status == 0))
  [[ $output == *'Usage:'* ]]
  [[ $output == *'disable'* ]]
}

@test "fails for non-existing disable argument" {
  run "$PH_BIN" disable --non-existing-argument
  ((status == 1))
  [[ $output == *'Unknown argument:'* ]]
  [[ $output == *'--non-existing-argument'* ]]
}

@test "prints help for enable command" {
  run "$PH_BIN" enable --help
  ((status == 0))
  [[ $output == *'Usage:'* ]]
  [[ $output == *'enable'* ]]
}

@test "fails for non-existing enable argument" {
  run "$PH_BIN" enable --non-existing-argument
  ((status == 1))
  [[ $output == *'Unknown argument:'* ]]
  [[ $output == *'--non-existing-argument'* ]]
}

@test "prints help for status command" {
  run "$PH_BIN" status --help
  ((status == 0))
  [[ $output == *'Usage:'* ]]
  [[ $output == *'status'* ]]
}

@test "fails for non-existing status argument" {
  run "$PH_BIN" status --non-existing-argument
  ((status == 1))
  [[ $output == *'Unknown argument:'* ]]
  [[ $output == *'--non-existing-argument'* ]]
}

@test "fails when PIHOLE_API_URL is missing" {
  run env PIHOLE_API_URL='' "$PH_BIN" status
  ((status == 1))
  [[ $output == *'Environment variable PIHOLE_API_URL is required.'* ]]
}

@test "fails when PIHOLE_API_KEY is missing" {
  run env PIHOLE_API_URL='http://localhost:8080' PIHOLE_API_KEY='' "$PH_BIN" status
  ((status == 1))
  [[ $output == *'Environment variable PIHOLE_API_KEY is required.'* ]]
}
