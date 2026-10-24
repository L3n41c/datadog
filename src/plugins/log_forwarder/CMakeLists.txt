# src/plugins/log_forwarder/CMakeLists.txt

add_library(log_forwarder SHARED log_forwarder.cpp)

target_include_directories(log_forwarder PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

set_target_properties(log_forwarder PROPERTIES
    PREFIX "lib"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_log_forwarder test_log_forwarder.cpp)
    target_link_libraries(test_log_forwarder PRIVATE
        GTest::gtest_main
        log_forwarder
    )
    target_include_directories(test_log_forwarder PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_log_forwarder)
endif()
