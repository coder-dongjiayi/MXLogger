cmake_minimum_required(VERSION 3.14)
project(MXLoggerPOCEntry LANGUAGES C CXX)
if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../../../../native"
    "${CMAKE_CURRENT_BINARY_DIR}/mxlogger-native")
