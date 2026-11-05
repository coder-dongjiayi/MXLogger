cmake_minimum_required(VERSION 3.14)
project(MXLoggerOHOSPoc LANGUAGES C CXX)

get_filename_component(MXLOGGER_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_subdirectory("${MXLOGGER_ROOT}/Core" "${CMAKE_CURRENT_BINARY_DIR}/core")
# This probe returns errors in its report; keep its test output deterministic.
target_compile_definitions(MXLoggerCore PRIVATE
    MXLOGGER_CONSOLE_ENABLED=0 MXLOGGER_DEBUG_LOG_ENABLED=0)
set_target_properties(MXLoggerCore PROPERTIES CXX_VISIBILITY_PRESET hidden
    C_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN YES)

add_library(mxlogger SHARED
    "${MXLOGGER_ROOT}/Core/ffi/mxlogger_ffi.cpp"
    smoke.cpp)
target_include_directories(mxlogger PRIVATE "${MXLOGGER_ROOT}/Core/ffi")
target_compile_definitions(mxlogger PRIVATE MXLOGGER_FFI_BUILD=1)
target_compile_features(mxlogger PRIVATE cxx_std_17)
target_link_libraries(mxlogger PRIVATE MXLoggerCore)
set_target_properties(mxlogger PROPERTIES
    CXX_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN YES)

if(OHOS)
    target_sources(mxlogger PRIVATE napi_bridge.cpp)
    target_link_libraries(mxlogger PRIVATE libace_napi.z.so)
endif()

# Node-API needs an application runtime on OHOS. The CLI is a host-only check;
# device validation runs the actual ArkTS application instead.
if(OHOS)
    set(MXLOGGER_POC_RUNNER_DEFAULT OFF)
else()
    set(MXLOGGER_POC_RUNNER_DEFAULT ON)
endif()
option(MXLOGGER_POC_BUILD_RUNNER "Build the host process-persistence probe" ${MXLOGGER_POC_RUNNER_DEFAULT})
if(MXLOGGER_POC_BUILD_RUNNER)
    add_executable(mxlogger_poc_runner runner.cpp)
    target_compile_features(mxlogger_poc_runner PRIVATE cxx_std_17)
    target_link_libraries(mxlogger_poc_runner PRIVATE mxlogger)
    set_target_properties(mxlogger_poc_runner PROPERTIES BUILD_RPATH "$ORIGIN")
endif()

file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/poc-library.txt"
    CONTENT "$<TARGET_FILE:mxlogger>\n")
