#!/usr/bin/env bash
# Build and exercise the native Storyboard demo using this checkout's pods.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build/macos-native-demo"
mkdir -p "$BUILD"
pod install --project-directory="$ROOT/platform/macOS/MXLoggerDemo" > "$BUILD/pods.log" 2>&1 || {
    cat "$BUILD/pods.log"; exit 1;
}
for CONFIGURATION in Debug Release; do
    echo ">> macOS native demo: $CONFIGURATION"
    xcodebuild -quiet -workspace "$ROOT/platform/macOS/MXLoggerDemo/MXLoggerDemo.xcworkspace" \
        -scheme MXLoggerDemo -configuration "$CONFIGURATION" -destination 'generic/platform=macOS' \
        -derivedDataPath "$BUILD" build > "$BUILD/$CONFIGURATION-build.log" 2>&1 || {
        cat "$BUILD/$CONFIGURATION-build.log"; exit 1;
    }
    BINARY="$BUILD/Build/Products/$CONFIGURATION/MXLoggerDemo.app/Contents/MacOS/MXLoggerDemo"
    "$BINARY" --smoke-test > "$BUILD/$CONFIGURATION-smoke.log" 2>&1 || {
        cat "$BUILD/$CONFIGURATION-smoke.log"; exit 1;
    }
    grep 'MXLOGGER_NATIVE_MACOS_DEMO_OK' "$BUILD/$CONFIGURATION-smoke.log"
done
"$BUILD/Build/Products/Debug/MXLoggerDemo.app/Contents/MacOS/MXLoggerDemo" \
    --ui-smoke-test "$BUILD/previews" > "$BUILD/ui-smoke.log" 2>&1 || {
    cat "$BUILD/ui-smoke.log"; exit 1;
}
grep 'MXLOGGER_NATIVE_MACOS_UI_OK' "$BUILD/ui-smoke.log"
echo ">> Native demo checks passed; logs and previews: $BUILD"
