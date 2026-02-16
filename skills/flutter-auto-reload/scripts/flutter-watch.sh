#!/bin/bash
# Flutter Auto Hot Reload Script
# Usage: flutter-watch.sh -d <device> [flutter run options]
#
# Starts Flutter with auto hot reload on file changes.
# Requires: fswatch (brew install fswatch)

set -e

DEVICE=""
EXTRA_ARGS=""
PID_FILE="/tmp/flutter-$$.pid"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--device)
      DEVICE="$2"
      shift 2
      ;;
    *)
      EXTRA_ARGS="$EXTRA_ARGS $1"
      shift
      ;;
  esac
done

if [ -z "$DEVICE" ]; then
  echo "Usage: flutter-watch.sh -d <device> [options]"
  echo ""
  echo "Examples:"
  echo "  flutter-watch.sh -d chrome"
  echo "  flutter-watch.sh -d iPhone"
  echo "  flutter-watch.sh -d emulator-5554"
  exit 1
fi

# Check for fswatch
if ! command -v fswatch &> /dev/null; then
  echo "Error: fswatch not found. Install with: brew install fswatch"
  exit 1
fi

# Cleanup on exit
cleanup() {
  echo ""
  echo "Stopping file watcher..."
  [ -n "$WATCHER_PID" ] && kill $WATCHER_PID 2>/dev/null
  echo "Stopping Flutter..."
  [ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null
  rm -f "$PID_FILE"
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "Starting Flutter with auto hot reload..."
echo "Device: $DEVICE"
echo "PID file: $PID_FILE"
echo ""

# Start Flutter in background
flutter run -d "$DEVICE" --pid-file="$PID_FILE" $EXTRA_ARGS &
FLUTTER_PID=$!

# Wait for PID file to be created
echo "Waiting for Flutter to start..."
while [ ! -f "$PID_FILE" ]; do
  sleep 0.5
  # Check if Flutter is still running
  if ! kill -0 $FLUTTER_PID 2>/dev/null; then
    echo "Flutter failed to start"
    exit 1
  fi
done

echo ""
echo "Flutter started (PID: $(cat $PID_FILE))"
echo "Starting file watcher on lib/..."
echo "Press Ctrl+C to stop"
echo ""

# Start file watcher
fswatch -o lib/ | while read; do
  if [ -f "$PID_FILE" ]; then
    echo "[$(date +%H:%M:%S)] Change detected - hot reloading..."
    kill -USR1 $(cat "$PID_FILE") 2>/dev/null || true
  fi
done &
WATCHER_PID=$!

# Wait for Flutter to exit
wait $FLUTTER_PID
cleanup
