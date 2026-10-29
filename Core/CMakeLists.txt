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

# The runtime API and distribution metadata share one version source.
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/mxlogger_version.hpp" MXLOGGER_VERSION_LINE
    REGEX "^#define MXLOGGER_CORE_VERSION ")
string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" MXLOGGER_CORE_VERSION "${MXLOGGER_VERSION_LINE}")
# Identify the compiler before checking MSVC or enabling GNU-style assembly.
project(MXLoggerCore VERSION ${MXLOGGER_CORE_VERSION} LANGUAGES C CXX)
include(GNUInstallDirs)

IF(APPLE)
    # tell ranlib to ignore empty compilation units
    SET(CMAKE_C_ARCHIVE_FINISH   "<CMAKE_RANLIB> -no_warning_for_no_symbols -c <TARGET>")
    SET(CMAKE_CXX_ARCHIVE_FINISH "<CMAKE_RANLIB> -no_warning_for_no_symbols -c <TARGET>")
    # prevents ar from invoking ranlib, let CMake do it
    SET(CMAKE_C_ARCHIVE_CREATE   "<CMAKE_AR> qc -S <TARGET> <LINK_FLAGS> <OBJECTS>")
    SET(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> qc -S <TARGET> <LINK_FLAGS> <OBJECTS>")

ENDIF()

# MSVC没有GNU汇编器，ARM加速汇编仅在非MSVC下启用(内部有架构守卫，x86上编译为空)
IF(NOT MSVC)
    set(can_use_assembler TRUE)
    enable_language(ASM)
ENDIF()

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


# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds them for you.
# Gradle automatically packages shared libraries with your APK.

add_library(MXLoggerCore

        # Sets the library as a shared library.
        STATIC

        # Provides a relative path to your source file(s).
        debug_log.cpp
        debug_log.hpp
        mxlogger_build_config.h
        log_enum.h
        log_msg.cpp
        log_msg.hpp
        log_serialize.h
        logger_os.cpp
        logger_os.hpp
        mxlogger_file_util.hpp
        mxlogger_file.hpp
        mxlogger_platform.hpp
        mxlogger_interprocess.hpp
        mxlogger_windows_cache.hpp
        mxlogger_windows_write_time.hpp
        mxlogger_helper.hpp
        mxlogger_util.cpp
        mxlogger_util.hpp
        mxlogger_console.cpp
        mxlogger_console.hpp
        mxlogger.cpp
        mxlogger.hpp
        mxlogger_version.hpp
        aes/aes_crypt.hpp
        aes/aes_crypt.cpp
        aes/openssl/openssl_aes_core.cpp
        aes/openssl/openssl_aes_locl.h
        aes/openssl/openssl_aes.h
        aes/openssl/openssl_arm_arch.h
        aes/openssl/openssl_cfb128.cpp

        flatbuffers/base.h
        flatbuffers/flatbuffers.h
        flatbuffers/stl_emulation.h
        md5/md5.h
        md5/md5.c
        json/cJSON.h
        json/cJSON.c
        sink/sink.hpp
        sink/sink.cpp
        sink/base_file_sink.cpp
        sink/base_file_sink.hpp
        sink/mmap_sink.cpp
        sink/mmap_sink.hpp
        )

find_package(Threads REQUIRED)
# ARM加速汇编：MSVC不支持GNU汇编语法，其余平台照常参与编译(源内有架构守卫)
IF(NOT MSVC)
    target_sources(MXLoggerCore PRIVATE
            aes/openssl/openssl_aes-armv4.S
            aes/openssl/openssl_aesv8-armx.S
            )
ENDIF()

add_library(MXLogger::Core ALIAS MXLoggerCore)
target_include_directories(MXLoggerCore PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_features(MXLoggerCore PUBLIC cxx_std_17)

set_target_properties(MXLoggerCore PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        POSITION_INDEPENDENT_CODE ON
        EXPORT_NAME Core
        )


target_link_libraries(MXLoggerCore PUBLIC Threads::Threads)

if(MSVC)
    target_compile_options(MXLoggerCore PUBLIC /utf-8)
endif()
if(WIN32)
    target_compile_definitions(MXLoggerCore PUBLIC
        _CRT_SECURE_NO_WARNINGS NOMINMAX WIN32_LEAN_AND_MEAN)
endif()
if(APPLE)
    target_compile_definitions(MXLoggerCore PUBLIC FORCE_POSIX $<$<CONFIG:Debug>:DEBUG=1>)
endif()

# Opt in explicitly so Android/Flutter consumers only build the library.
option(MXLOGGER_BUILD_TESTS "Build the native Core tests" OFF)
if(MXLOGGER_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# Explicit opt-in: embedded Android/Apple/Flutter builds do not install an SDK.
option(MXLOGGER_INSTALL "Install the public C++ SDK and CMake package" OFF)
if(MXLOGGER_INSTALL)
    set_property(TARGET MXLoggerCore PROPERTY DEBUG_POSTFIX d)
    include(CMakePackageConfigHelpers)
    set(MXLOGGER_CONFIG_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/MXLoggerCore")
    install(TARGETS MXLoggerCore EXPORT MXLoggerCoreTargets
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    install(FILES mxlogger.hpp mxlogger_util.hpp DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
    install(FILES ../LICENSE.TXT DESTINATION "${CMAKE_INSTALL_DATADIR}/MXLoggerCore")
    configure_package_config_file(cmake/MXLoggerCoreConfig.cmake.in
        "${CMAKE_CURRENT_BINARY_DIR}/MXLoggerCoreConfig.cmake"
        INSTALL_DESTINATION "${MXLOGGER_CONFIG_DIR}")
    write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/MXLoggerCoreConfigVersion.cmake"
        VERSION "${PROJECT_VERSION}" COMPATIBILITY SameMajorVersion)
    install(EXPORT MXLoggerCoreTargets NAMESPACE MXLogger::
        DESTINATION "${MXLOGGER_CONFIG_DIR}")
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/MXLoggerCoreConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/MXLoggerCoreConfigVersion.cmake"
        DESTINATION "${MXLOGGER_CONFIG_DIR}")
endif()

