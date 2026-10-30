#!/usr/bin/env bash
# JVM tests first; CI calls package only after every verification job succeeds.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$ROOT/platform/Android/MXLogger"
BUILD="$ROOT/build/android-demo"
MODE="${1:-test}"
if [ "$#" -gt 1 ] || { [ "$MODE" != test ] && [ "$MODE" != package ]; }; then
    echo "Usage: $0 [test|package]" >&2
    exit 2
fi
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ ! -d "$SDK_DIR/platforms/android-33" ]; then
    echo 'Set ANDROID_HOME to an Android SDK with platforms;android-31 and platforms;android-33.' >&2
    exit 1
fi
export ANDROID_HOME="$SDK_DIR"
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
    JAVA_HOME=$(/usr/libexec/java_home -F -v 17)
    export JAVA_HOME
fi
mkdir -p "$BUILD"
if [ "$MODE" = test ]; then
    bash "$PROJECT/gradlew" -p "$PROJECT" --no-daemon --console=plain \
        :mxlogger:testDefaultCppReleaseUnitTest \
        :mxloggerdemo:testDefaultCppReleaseUnitTest > "$BUILD/test.log" 2>&1 || {
        tail -n 100 "$BUILD/test.log"; exit 1;
    }
    echo ">> Android library and Demo JVM tests passed; log: $BUILD/test.log"
    exit 0
fi

bash "$PROJECT/gradlew" -p "$PROJECT" --no-daemon --console=plain \
    -PmxloggerDemoTestSigning=true :mxloggerdemo:assembleDefaultCppRelease \
    > "$BUILD/build.log" 2>&1 || { tail -n 100 "$BUILD/build.log"; exit 1; }
APK="$PROJECT/mxloggerdemo/build/outputs/apk/DefaultCpp/release/mxloggerdemo-DefaultCpp-release.apk"
TOOLS="$SDK_DIR/build-tools/34.0.0"
"$TOOLS/apksigner" verify --verbose "$APK" > "$BUILD/signing.log" 2>&1 || {
    cat "$BUILD/signing.log"; exit 1;
}
"$TOOLS/aapt" dump badging "$APK" > "$BUILD/apk-info.log"
if grep -q '^application-debuggable' "$BUILD/apk-info.log"; then
    echo 'Expected a non-debuggable Release APK.' >&2
    exit 1
fi
python3 - "$APK" <<'PY'
import sys
import zipfile
with zipfile.ZipFile(sys.argv[1]) as apk:
    for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'):
        if f'lib/{abi}/libmxlogger.so' not in apk.namelist():
            raise SystemExit(f'Missing native logger library for {abi}')
print('PASS: all four native ABIs are included')
PY
OUTPUT="$BUILD/MXLoggerDemo-android-Release.apk"
python3 - "$ROOT" "$BUILD/local-core.json" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
sys.path.insert(0, str(root / 'scripts'))
from check_local_core import check_cmake, write_report
caches = list((root / 'platform/Android/MXLogger/mxlogger/.cxx').rglob('CMakeCache.txt'))
if not caches:
    raise SystemExit('Missing native Core build configuration for the Android APK')
write_report(sys.argv[2], [check_cmake(p) for p in caches])
PY
cp "$APK" "$OUTPUT"
echo ">> Installable Release Demo (test signing): $OUTPUT"
