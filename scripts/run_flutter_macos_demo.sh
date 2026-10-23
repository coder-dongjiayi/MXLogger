#!/usr/bin/env bash
# Run the actual Flutter demo against this checkout's unpublished native sources.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FLUTTER_BIN=${FLUTTER_BIN:-flutter}
ACTION=${1:-run}
if [ "$#" -gt 0 ]; then shift; fi
if [ "$(uname -s)" != Darwin ]; then
    echo "This demo requires macOS and Xcode." >&2
    exit 1
fi
if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
    echo "Flutter not found. Set FLUTTER_BIN=/path/to/flutter/bin/flutter." >&2
    exit 1
fi
case "$ACTION" in
    run|build|test) ;;
    *) echo "Usage: bash scripts/run_flutter_macos_demo.sh [run|build|test] [Flutter options]" >&2; exit 1 ;;
esac

# Scope the package-manager choice to this process; do not change Flutter's global config.
export FLUTTER_SWIFT_PACKAGE_MANAGER=false
export MXLOGGER_LOCAL_NATIVE=1
cd "$ROOT/flutter_mxlogger/example"
"$FLUTTER_BIN" pub get
case "$ACTION" in
    run) exec "$FLUTTER_BIN" run -d macos --no-pub "$@" ;;
    build) exec "$FLUTTER_BIN" build macos --no-pub "$@" ;;
    test) exec "$FLUTTER_BIN" drive -d macos --no-pub \
        --driver=test_driver/integration_test.dart \
        --target=integration_test/macos_demo_test.dart "$@" ;;
esac
