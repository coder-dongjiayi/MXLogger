#!/usr/bin/env bash
# Compile the shared Core + JNI/Flutter bridges without Gradle or publishing credentials.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
NDK_DIR=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
if [ ! -f "$NDK_DIR/build/cmake/android.toolchain.cmake" ]; then
    echo "Set ANDROID_NDK_HOME to an installed Android NDK directory." >&2
    exit 1
fi
command -v cmake >/dev/null
command -v ninja >/dev/null
NDK_NM=("$NDK_DIR"/toolchains/llvm/prebuilt/*/bin/llvm-nm)
if [ ${#NDK_NM[@]} -ne 1 ] || [ ! -x "${NDK_NM[0]}" ]; then
    echo "Could not find the NDK llvm-nm executable." >&2
    exit 1
fi

BUILD="$ROOT/build/android-validation"
mkdir -p "$BUILD"
for ABI in arm64-v8a armeabi-v7a x86_64 x86; do
    echo ">> Android $ABI (API 21, Release)"
    cmake -S "$ROOT/Android/MXLogger/mxlogger" -B "$BUILD/$ABI" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$ABI" -DANDROID_PLATFORM=android-21 \
        -DANDROID_STL=c++_static -DCMAKE_BUILD_TYPE=Release \
        > "$BUILD/$ABI-configure.log" 2>&1 || { cat "$BUILD/$ABI-configure.log"; exit 1; }
    cmake --build "$BUILD/$ABI" --parallel \
        > "$BUILD/$ABI-build.log" 2>&1 || { cat "$BUILD/$ABI-build.log"; exit 1; }
    "${NDK_NM[0]}" -u "$BUILD/$ABI/libmxlogger.so" > "$BUILD/$ABI-symbols.log"
    if grep -Eq '[[:space:]]flock(@[^[:space:]]*)?$' "$BUILD/$ABI-symbols.log"; then
        echo "Unexpected macOS process-lock dependency in Android $ABI" >&2
        exit 1
    fi
done
echo ">> Android native checks passed; logs: $BUILD"
