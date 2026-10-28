#!/usr/bin/env bash
# Build the Apple API directly from source, independently of CocoaPods/SwiftPM distribution.
# Runs shared ObjC tests, macOS manual-cleanup tests, Swift API smoke, and iOS compile checks.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
BUILD="$ROOT/build/apple-native-tests"
CORE="$ROOT/Core"
APPLE="$ROOT/platform/iOS/MXLogger/MXLogger"
TESTS="$ROOT/platform/iOS/MXLogger/tests"
SDK=$(xcrun --sdk macosx --show-sdk-path)
DEVELOPER=$(xcode-select -p)
TEST_FRAMEWORKS="$DEVELOPER/Platforms/MacOSX.platform/Developer/Library/Frameworks"
mkdir -p "$BUILD/module-cache" "$BUILD/MXLoggerAppleTests.xctest/Contents/MacOS"

echo ">> building native Apple test library..."
xcrun clang -isysroot "$SDK" -w -O1 -fPIC -c "$CORE/md5/md5.c" -o "$BUILD/md5.o"
xcrun clang -isysroot "$SDK" -w -O1 -fPIC -c "$CORE/json/cJSON.c" -o "$BUILD/cJSON.o"
xcrun clang++ -isysroot "$SDK" -std=c++17 -fobjc-arc -O1 -fPIC -dynamiclib \
    -I"$CORE/include" -I"$CORE" \
    "$APPLE/MXLogger.mm" \
    "$CORE/mxlogger.cpp" "$CORE/mxlogger_console.cpp" "$CORE/mxlogger_util.cpp" \
    "$CORE/log_msg.cpp" "$CORE/logger_os.cpp" "$CORE/debug_log.cpp" \
    "$CORE/sink/sink.cpp" "$CORE/sink/base_file_sink.cpp" "$CORE/sink/mmap_sink.cpp" \
    "$CORE/aes/aes_crypt.cpp" "$CORE/aes/openssl/openssl_aes_core.cpp" \
    "$CORE/aes/openssl/openssl_cfb128.cpp" \
    "$CORE/aes/openssl/openssl_aes-armv4.S" "$CORE/aes/openssl/openssl_aesv8-armx.S" \
    "$BUILD/md5.o" "$BUILD/cJSON.o" \
    -framework Foundation \
    -install_name @rpath/libMXLoggerAppleTests.dylib \
    -o "$BUILD/libMXLoggerAppleTests.dylib"

echo ">> building Objective-C tests..."
xcrun clang -isysroot "$SDK" -fobjc-arc -fmodules \
    -fmodules-cache-path="$BUILD/module-cache" -bundle \
    -I"$APPLE/include" -F"$TEST_FRAMEWORKS" \
    "$ROOT/platform/iOS/MXLogger/MXLoggerTests/MXLoggerTests.m" \
    -L"$BUILD" -lMXLoggerAppleTests \
    -framework Foundation -framework AppKit -framework XCTest \
    -Wl,-rpath,"$BUILD" -Wl,-rpath,"$TEST_FRAMEWORKS" \
    -o "$BUILD/MXLoggerAppleTests.xctest/Contents/MacOS/MXLoggerAppleTests"
cat > "$BUILD/MXLoggerAppleTests.xctest/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.mxlogger.apple-native-tests</string>
  <key>CFBundleExecutable</key><string>MXLoggerAppleTests</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
</dict></plist>
PLIST

echo ">> running Objective-C tests..."
xcrun xctest "$BUILD/MXLoggerAppleTests.xctest"

echo ">> building and running Swift API smoke..."
xcrun swiftc -sdk "$SDK" -module-cache-path "$BUILD/module-cache" \
    -import-objc-header "$APPLE/include/MXLogger/MXLogger.h" \
    "$TESTS/SwiftSmoke.swift" -L"$BUILD" -lMXLoggerAppleTests \
    -Xlinker -rpath -Xlinker "$BUILD" -o "$BUILD/swift-smoke"
"$BUILD/swift-smoke"

echo ">> checking iOS device and simulator compilation..."
for PLATFORM in iphoneos iphonesimulator; do
    IOS_SDK=$(xcrun --sdk "$PLATFORM" --show-sdk-path)
    if [ "$PLATFORM" = iphoneos ]; then
        TARGET=arm64-apple-ios13.0
    else
        TARGET=arm64-apple-ios13.0-simulator
    fi
    xcrun clang++ -isysroot "$IOS_SDK" -target "$TARGET" \
        -std=c++17 -fobjc-arc -c -I"$CORE/include" -I"$CORE" \
        "$APPLE/MXLogger.mm" -o "$BUILD/MXLogger-$PLATFORM.o"
    # Compile the modified Core paths too; no desktop locking may enter iOS.
    for SOURCE in sink/mmap_sink.cpp sink/base_file_sink.cpp mxlogger_util.cpp; do
        OBJECT="$BUILD/$(basename "$SOURCE" .cpp)-$PLATFORM.o"
        xcrun clang++ -isysroot "$IOS_SDK" -target "$TARGET" \
            -std=c++17 -c -I"$CORE" "$CORE/$SOURCE" -o "$OBJECT"
        if nm -u "$OBJECT" | grep -q '_flock'; then
            echo "unexpected macOS process lock in $PLATFORM: $SOURCE" >&2
            exit 1
        fi
    done
done
echo ">> native Apple tests passed"
