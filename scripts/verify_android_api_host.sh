#!/usr/bin/env bash
# Java API tests use the real JNI bridge/Core. Only Android Context/Looper are
# supplied by AGP's mockable android.jar; device tests remain separate.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build/android-api-host"
CORE_TESTS=ON
if [ "${1:-}" = --skip-core-tests ] && [ "$#" = 1 ]; then
    CORE_TESTS=OFF
elif [ "$#" != 0 ]; then
    echo "Usage: $0 [--skip-core-tests]" >&2
    exit 2
fi
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
    export JAVA_HOME=$(/usr/libexec/java_home -F -v 17)
fi
mkdir -p "$BUILD"
cmake -S "$ROOT/platform/Android/MXLogger/mxlogger/tests/host" -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Debug -DMXLOGGER_BUILD_TESTS="$CORE_TESTS" -DMXLOGGER_INSTALL=OFF \
    > "$BUILD/configure.log" 2>&1 || { tail -n 50 "$BUILD/configure.log"; exit 1; }
cmake --build "$BUILD" --parallel 4 > "$BUILD/build.log" 2>&1 || { tail -n 50 "$BUILD/build.log"; exit 1; }
if [ "$CORE_TESTS" = ON ]; then
    ctest --test-dir "$BUILD" --output-on-failure --no-tests=error > "$BUILD/core-tests.log" 2>&1 || {
        tail -n 70 "$BUILD/core-tests.log"; exit 1;
    }
fi
MXLOGGER_JNI_TEST_LIBRARY_DIR="$BUILD/jni" bash "$ROOT/platform/Android/MXLogger/gradlew" \
    -p "$ROOT/platform/Android/MXLogger" --no-daemon --console=plain \
    :mxlogger:apiCoverageReport > "$BUILD/java-tests.log" 2>&1 || { tail -n 80 "$BUILD/java-tests.log"; exit 1; }
echo ">> Java/JNI/Core API tests passed; reports: $ROOT/platform/Android/MXLogger/mxlogger/build/reports/jacoco/apiCoverageReport"
