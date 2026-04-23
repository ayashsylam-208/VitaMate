#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/tmp/vitamate-integration"
SMOKE_LOG="$LOG_DIR/flutter-smoke.log"
CHRONIC_LOG="$LOG_DIR/flutter-chronic.log"
# The timeout wraps Gradle build + APK install + test execution. Cold GitHub
# runners can spend 10+ minutes installing Android toolchain pieces alone.
SMOKE_TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-2400}"
CHRONIC_TIMEOUT_SECONDS="${CHRONIC_TIMEOUT_SECONDS:-2400}"

mkdir -p "$LOG_DIR"
cd "$(dirname "$0")/.."

run_integration_test() {
  target="$1"
  output="$2"
  timeout_seconds="$3"

  : >"$output"
  echo "===== Running $target (timeout: ${timeout_seconds}s) ====="

  if ! timeout --signal=TERM --kill-after=30s "$timeout_seconds" \
    flutter test \
      "$target" \
      -d emulator-5554 \
      --reporter expanded \
      --dart-define=API_BASE_URL="${API_BASE_URL}" \
      2>&1 | tee "$output"; then
    status="${PIPESTATUS[0]}"
    if [ "$status" -eq 124 ]; then
      echo "Integration test timed out after ${timeout_seconds}s: $target" >&2
    fi
    exit 1
  fi

  echo "===== Completed $target ====="
}

run_integration_test \
  "integration_test/smoke_login_home_test.dart" \
  "$SMOKE_LOG" \
  "$SMOKE_TIMEOUT_SECONDS"
run_integration_test \
  "integration_test/chronic_flow_test.dart" \
  "$CHRONIC_LOG" \
  "$CHRONIC_TIMEOUT_SECONDS"
