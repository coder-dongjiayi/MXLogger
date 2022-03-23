# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Sets the minimum version of CMake required to build the native library.

cmake_minimum_required(VERSION 3.10.0)



project("blinglogger")

add_subdirectory(../../../Core Core)

add_library(
        blinglogger
        SHARED
        src/main/cpp/navtive-bridge.cpp)

set_target_properties(blinglogger PROPERTIES
        CXX_STANDARD 17
        CXX_EXTENSIONS OFF
        POSITION_INDEPENDENT_CODE ON
        )
find_library(
        log-lib


        log )


target_link_libraries(
        blinglogger
        BlingLoggerCore
        ${log-lib} )