#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/tmp/vitamate-integration"
SMOKE_LOG="$LOG_DIR/flutter-smoke.log"
CHRONIC_LOG="$LOG_DIR/flutter-chronic.log"
SMOKE_TIMEOUT_SECONDS="${SMOKE_TIMEOUT_SECONDS:-900}"
CHRONIC_TIMEOUT_SECONDS="${CHRONIC_TIMEOUT_SECONDS:-1200}"

mkdir -p "$LOG_DIR"
cd "$(dirname "$0")/.."

run_drive() {
  target="$1"
  output="$2"
  timeout_seconds="$3"

  : >"$output"
  echo "===== Running $target (timeout: ${timeout_seconds}s) ====="

  if ! timeout --signal=TERM --kill-after=30s "$timeout_seconds" \
    flutter drive \
      --driver=test_driver/integration_test.dart \
      --target="$target" \
      -d emulator-5554 \
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

run_drive \
  "integration_test/smoke_login_home_test.dart" \
  "$SMOKE_LOG" \
  "$SMOKE_TIMEOUT_SECONDS"
run_drive \
  "integration_test/chronic_flow_test.dart" \
  "$CHRONIC_LOG" \
  "$CHRONIC_TIMEOUT_SECONDS"
