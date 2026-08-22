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

# Linux等无clang的环境自动回退gcc；也可通过 CC/CXX 环境变量指定
CC="${CC:-$(command -v clang || command -v gcc)}"
CXX="${CXX:-$(command -v clang++ || command -v g++)}"
echo ">> compiler: $CXX"

SAN_FLAG=""
if [ -n "$SAN" ]; then
    SAN_FLAG="-fsanitize=$SAN -g"
    echo ">> sanitizer: $SAN"
fi

# 控制台输出和 debug_log 默认在发布构建下被编译期裁掉(见 Core/mxlogger_build_config.h)，
# 这里手搓编译不带任何配置宏，Apple 平台会判定为发布构建，必须显式打开，
# 否则 console_output_no_crash 用例会变成空跑、VERBOSE=1 也没有输出可看
CXXFLAGS="-std=c++17 -DFORCE_POSIX -DMXLOGGER_CONSOLE_ENABLED=1 -DMXLOGGER_DEBUG_LOG_ENABLED=1 -pthread $SAN_FLAG -I$CORE -I."
CFLAGS="$SAN_FLAG"

echo ">> compiling C dependencies..."
"$CC" $CFLAGS -w -c "$CORE/md5/md5.c"    -o "$BUILD/md5.o"
"$CC" $CFLAGS -w -c "$CORE/json/cJSON.c" -o "$BUILD/cJSON.o"

echo ">> compiling core + tests..."
"$CXX" $CXXFLAGS \
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
