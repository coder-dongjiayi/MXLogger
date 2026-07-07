#!/bin/bash
#
# 构建宿主机测试用动态库 libmxlogger_test.dylib
#
# 用途: flutter test 在宿主机(macOS)上运行, 插件的FFI绑定通过
# DynamicLibrary.process() 查找 flutter_mxlogger_* 符号。
# 本脚本把 Android桥接(纯C++) + Core 编译成宿主dylib,
# 测试中 DynamicLibrary.open 加载后(dlopen默认RTLD_GLOBAL)
# process() 即可解析到全部符号, 让所有FFI接口真实执行。
#
# 由 flutter_mxlogger_test.dart 的 setUpAll 自动调用, 也可手动执行。
set -e
cd "$(dirname "$0")"

REPO=../../..
CORE=$REPO/Core
BRIDGE=$REPO/Android/MXLogger/mxlogger/src/main/cpp/flutter-bridge.cpp
OUT=libmxlogger_test.dylib

CC="${CC:-$(command -v clang)}"
CXX="${CXX:-$(command -v clang++)}"

BUILD=build_tmp
mkdir -p "$BUILD"

"$CC" -w -O1 -fPIC -c "$CORE/md5/md5.c"    -o "$BUILD/md5.o"
"$CC" -w -O1 -fPIC -c "$CORE/json/cJSON.c" -o "$BUILD/cJSON.o"

"$CXX" -std=c++17 -DFORCE_POSIX -pthread -O1 -fPIC -dynamiclib \
    -I"$CORE" \
    "$BRIDGE" \
    "$CORE/mxlogger.cpp" \
    "$CORE/mxlogger_console.cpp" \
    "$CORE/mxlogger_util.cpp" \
    "$CORE/log_msg.cpp" \
    "$CORE/logger_os.cpp" \
    "$CORE/debug_log.cpp" \
    "$CORE/sink/sink.cpp" \
    "$CORE/sink/base_file_sink.cpp" \
    "$CORE/sink/mmap_sink.cpp" \
    "$CORE/aes/aes_crypt.cpp" \
    "$CORE/aes/openssl/openssl_aes_core.cpp" \
    "$CORE/aes/openssl/openssl_cfb128.cpp" \
    "$BUILD/md5.o" "$BUILD/cJSON.o" \
    -o "$OUT"

rm -rf "$BUILD"
echo "built: $(pwd)/$OUT"
