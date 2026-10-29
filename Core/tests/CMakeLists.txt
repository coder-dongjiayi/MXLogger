add_executable(mxlogger_tests
    test_main.cpp
    test_helper.cpp
    test_aes_crypt.cpp
    test_sink_crypt.cpp
    test_mmap_file.cpp
    test_mxlogger_api.cpp
    test_file_util.cpp
    test_concurrency.cpp
    test_multiprocess.cpp
    test_write_time.cpp
)
target_link_libraries(mxlogger_tests PRIVATE MXLoggerCore)
set_target_properties(mxlogger_tests PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
)

# The runner prints each case and its failing assertions. Process workers use
# posix_spawn on macOS and CreateProcessW on Windows, with pipe barriers.
add_test(NAME MXLoggerCore COMMAND mxlogger_tests)
set_tests_properties(MXLoggerCore PROPERTIES
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    TIMEOUT 180
)
