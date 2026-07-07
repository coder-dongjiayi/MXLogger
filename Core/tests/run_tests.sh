#!/bin/bash
#
# MXLoggerCore 单元测试构建与运行
#
# 用法:
#   ./run_tests.sh                 普通构建并运行
#   SAN=address ./run_tests.sh    开启 AddressSanitizer
#   SAN=thread  ./run_tests.sh    开启 ThreadSanitizer
#   VERBOSE=1   ./run_tests.sh    保留库内部的 mxlogger_info 输出
#
set -e
set -o pipefail
cd "$(dirname "$0")"

CORE=..
BUILD=build
mkdir -p "$BUILD"

SAN_FLAG=""
if [ -n "$SAN" ]; then
    SAN_FLAG="-fsanitize=$SAN -g"
    echo ">> sanitizer: $SAN"
fi

CXXFLAGS="-std=c++17 -DFORCE_POSIX $SAN_FLAG -I$CORE -I."
CFLAGS="$SAN_FLAG"

echo ">> compiling C dependencies..."
clang $CFLAGS -w -c "$CORE/md5/md5.c"    -o "$BUILD/md5.o"
clang $CFLAGS -w -c "$CORE/json/cJSON.c" -o "$BUILD/cJSON.o"

echo ">> compiling core + tests..."
clang++ $CXXFLAGS \
    test_main.cpp \
    test_helper.cpp \
    test_aes_crypt.cpp \
    test_sink_crypt.cpp \
    test_mmap_file.cpp \
    test_mxlogger_api.cpp \
    test_file_util.cpp \
    test_concurrency.cpp \
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
    -o "$BUILD/mxlogger_tests"

echo ">> running..."
if [ -n "$VERBOSE" ]; then
    "$BUILD/mxlogger_tests"
else
    # 过滤库自身的调试输出，只保留测试结果
    "$BUILD/mxlogger_tests" | grep -vE "^\[mxlogger_(info|error)\]"
fi
