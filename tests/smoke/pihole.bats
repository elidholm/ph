#!/usr/bin/env bats
#
# Smoke tests that exercise `ph` against a real Pi-hole instance (e.g. the
# `pihole/pihole` Docker container started by the CI "smoke-test" job).
#
# Requires PIHOLE_API_URL and PIHOLE_API_KEY to point at a live Pi-hole
# instance; tests are skipped when they are not set so this file is safe to
# leave out of the regular `bats tests` unit-test run.

setup() {
  PH_BIN="${BATS_TEST_DIRNAME}/../../ph"

  if [[ -z ${PIHOLE_API_URL-} || -z ${PIHOLE_API_KEY-} ]]; then
    skip 'PIHOLE_API_URL and PIHOLE_API_KEY must be set to run smoke tests against a real Pi-hole instance.'
  fi
}

@test "status reports blocking enabled initially" {
  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Blocking'* ]]
  [[ $output == *'Enabled'* ]]
}

@test "disable turns blocking off immediately" {
  run "$PH_BIN" disable -3
  ((status == 0))
  [[ $output == *'[SUCCESS]'* ]]
  [[ $output == *'disabled'* ]]

  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Disabled'* ]]
}

@test "blocking automatically resumes after the timer elapses" {
  run "$PH_BIN" disable -2
  ((status == 0))

  sleep 4

  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Enabled'* ]]
}

@test "enable turns blocking on explicitly" {
  run "$PH_BIN" enable -2
  ((status == 0))
  [[ $output == *'[SUCCESS]'* ]]
  [[ $output == *'enabled'* ]]

  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Enabled'* ]]
}

@test "permanent disable keeps blocking off past the default timer window" {
  run "$PH_BIN" disable --permanent
  ((status == 0))
  [[ $output == *'[SUCCESS]'* ]]
  [[ $output == *'permanently'* ]]

  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Disabled'* ]]
  [[ $output == *'Permanent (no timer)'* ]]

  sleep 4

  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Disabled'* ]]

  # Restore blocking so subsequent tests start from a known state.
  run "$PH_BIN" enable --permanent
  ((status == 0))
}

@test "permanent enable clears any running timer" {
  run "$PH_BIN" disable -60
  ((status == 0))

  run "$PH_BIN" enable -p
  ((status == 0))
  [[ $output == *'[SUCCESS]'* ]]
  [[ $output == *'permanently'* ]]

  run "$PH_BIN" status
  ((status == 0))
  [[ $output == *'Enabled'* ]]
  [[ $output == *'Permanent (no timer)'* ]]
}
