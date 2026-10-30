#!/usr/bin/env bash
# Exercise a relocated installed SDK, independent of the source-tree targets.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CORE_TESTS=ON
if [ "${1:-}" = --skip-core-tests ] && [ "$#" = 1 ]; then
    CORE_TESTS=OFF
elif [ "$#" != 0 ]; then
    echo "Usage: $0 [--skip-core-tests]" >&2
    exit 2
fi
mkdir -p "$ROOT/build/core-package"
BUILD=$(mktemp -d "$ROOT/build/core-package/run-XXXXXX")
cmake -S "$ROOT/Core" -B "$BUILD/core" -G 'Ninja Multi-Config' \
    -DMXLOGGER_INSTALL=ON -DMXLOGGER_BUILD_TESTS="$CORE_TESTS" -DCMAKE_INSTALL_LIBDIR=lib
for CONFIGURATION in Debug Release; do
    cmake --build "$BUILD/core" --config "$CONFIGURATION" --parallel 4
    if [ "$CORE_TESTS" = ON ]; then
        ctest --test-dir "$BUILD/core" -C "$CONFIGURATION" --output-on-failure --no-tests=error
    fi
    cmake --install "$BUILD/core" --config "$CONFIGURATION" --prefix "$BUILD/original-sdk"
done
mv "$BUILD/original-sdk" "$BUILD/relocated-sdk"
cmake -S "$ROOT/platform/Windows/tests/package_consumer" -B "$BUILD/consumer" \
    -G 'Ninja Multi-Config' -DCMAKE_PREFIX_PATH="$BUILD/relocated-sdk"
for CONFIGURATION in Debug Release; do
    cmake --build "$BUILD/consumer" --config "$CONFIGURATION" --parallel 4
    ctest --test-dir "$BUILD/consumer" -C "$CONFIGURATION" --output-on-failure --no-tests=error
done
echo ">> Installed and relocated C++ SDK checks passed: $BUILD"
