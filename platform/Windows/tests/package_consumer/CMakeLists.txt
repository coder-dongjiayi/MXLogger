cmake_minimum_required(VERSION 3.20)
project(MXLoggerPackageConsumer LANGUAGES CXX)
find_package(MXLoggerCore 2.3 CONFIG REQUIRED)
add_executable(mxlogger_package_consumer main.cpp)
target_link_libraries(mxlogger_package_consumer PRIVATE MXLogger::Core)
enable_testing()
add_test(NAME installed-sdk COMMAND mxlogger_package_consumer
    "${CMAKE_CURRENT_BINARY_DIR}/logs-$<CONFIG>")
