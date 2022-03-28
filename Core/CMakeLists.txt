#
# Tencent is pleased to support the open source community by making
# MMKV available.
#
# Copyright (C) 2019 THL A29 Limited, a Tencent company.
# All rights reserved.
#
# Licensed under the BSD 3-Clause License (the "License"); you may not use
# this file except in compliance with the License. You may obtain a copy of
# the License at
#
#       https://opensource.org/licenses/BSD-3-Clause
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Sets the minimum version of CMake required to build the native library.

cmake_minimum_required(VERSION 3.10.0)

IF(APPLE)
    # tell ranlib to ignore empty compilation units
    SET(CMAKE_C_ARCHIVE_FINISH   "<CMAKE_RANLIB> -no_warning_for_no_symbols -c <TARGET>")
    SET(CMAKE_CXX_ARCHIVE_FINISH "<CMAKE_RANLIB> -no_warning_for_no_symbols -c <TARGET>")
    # prevents ar from invoking ranlib, let CMake do it
    SET(CMAKE_C_ARCHIVE_CREATE   "<CMAKE_AR> qc -S <TARGET> <LINK_FLAGS> <OBJECTS>")
    SET(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> qc -S <TARGET> <LINK_FLAGS> <OBJECTS>")

    add_compile_definitions(FORCE_POSIX)
ENDIF()

set(can_use_assembler TRUE)
enable_language(ASM)
IF("${ANDROID_ABI}" STREQUAL "arm64-v8a")
    SET(ASM_OPTIONS "-x assembler-with-cpp")
    SET(CMAKE_ASM_FLAGS "${CFLAGS} ${ASM_OPTIONS} -march=armv8+crypto -D__ANDROID__")
ELSEIF("${ANDROID_ABI}" STREQUAL "armeabi-v7a")
    SET(ASM_OPTIONS "-x assembler-with-cpp")
    SET(CMAKE_ASM_FLAGS "${CFLAGS} ${ASM_OPTIONS} -march=armv7a -D__ANDROID__")
ELSEIF("${ANDROID_ABI}" STREQUAL "armeabi")
    SET(ASM_OPTIONS "-x assembler-with-cpp")
    SET(CMAKE_ASM_FLAGS "${CFLAGS} ${ASM_OPTIONS} -march=armv5 -D__ANDROID__")
ENDIF()

#include(CMakePrintHelpers)
#cmake_print_variables(CMAKE_SYSTEM_PROCESSOR)
IF(UNIX AND (NOT APPLE))
    IF("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "aarch64")
        SET(ASM_OPTIONS "-x assembler-with-cpp")
        SET(CMAKE_ASM_FLAGS "${CFLAGS} ${ASM_OPTIONS} -march=armv8-a+crypto")
    ENDIF()
ENDIF()


project(MXLoggerCore)

# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds them for you.
# Gradle automatically packages shared libraries with your APK.

add_library(MXLoggerCore

        # Sets the library as a shared library.
        STATIC

        # Provides a relative path to your source file(s).
        async_logger.cpp
        async_logger.hpp
        async_msg.cpp
        async_msg.hpp
       
        console_sink.cc
        console_sink.h
        file_appender.cpp
        file_appender.hpp
        file_helper.cpp
        file_helper.hpp
        file_sink.cpp
        file_sink.hpp
        flag_formatter.cpp
        flag_formatter.hpp
        fmt_helper.h
        formatter.cpp
        formatter.hpp
        log_msg_buffer.cpp
         log_msg_buffer.hpp
         log_msg.cc
        log_msg.h
        logger_common.h
        logger_enum.h
        mxlogger_manager.cpp
        mxlogger_manager.hpp
        logger_os.cpp
        logger_os.hpp
        logger.cpp
        logger.hpp
        mpmc_blocking_queue.cpp
        mpmc_blocking_queue.hpp
        pattern_formatter.cpp
        pattern_formatter.hpp
        sinks.cc
        sinks.h
        thread_pool.cpp
        thread_pool.hpp
        fmt/xchar.h
        fmt/args.h
        fmt/chrono.h
        fmt/color.h
        fmt/compile.h
        fmt/core.h
        fmt/format-inl.h
        fmt/format.cc
        fmt/format.h
        fmt/locale.h
        fmt/os.cc
        fmt/os.h
        fmt/ostream.h
        fmt/printf.h
        fmt/ranges.h
       
        )

target_include_directories(MXLoggerCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

set_target_properties(MXLoggerCore PROPERTIES
        CXX_STANDARD 17
        CXX_EXTENSIONS OFF
        POSITION_INDEPENDENT_CODE ON
        )


target_link_libraries(MXLoggerCore)

