# src/plugins/log_receiver_file/CMakeLists.txt

add_library(log_receiver_file SHARED log_receiver_file.cpp)

target_include_directories(log_receiver_file PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

set_target_properties(log_receiver_file PROPERTIES
    PREFIX "lib"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_log_receiver_file test_log_receiver_file.cpp)
    target_link_libraries(test_log_receiver_file PRIVATE
        GTest::gtest_main
        log_receiver_file
    )
    target_include_directories(test_log_receiver_file PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_log_receiver_file)
endif()
