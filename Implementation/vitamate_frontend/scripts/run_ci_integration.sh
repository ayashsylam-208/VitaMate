#!/bin/sh
set -eu

LOG_DIR="/tmp/vitamate-integration"
SMOKE_LOG="$LOG_DIR/flutter-smoke.log"
CHRONIC_LOG="$LOG_DIR/flutter-chronic.log"

mkdir -p "$LOG_DIR"
cd "$(dirname "$0")/.."

run_drive() {
  target="$1"
  output="$2"

  if ! flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    -d emulator-5554 \
    --dart-define=API_BASE_URL="${API_BASE_URL}" \
    >"$output" 2>&1; then
    cat "$output"
    exit 1
  fi

  cat "$output"
}

run_drive "integration_test/smoke_login_home_test.dart" "$SMOKE_LOG"
run_drive "integration_test/chronic_flow_test.dart" "$CHRONIC_LOG"
