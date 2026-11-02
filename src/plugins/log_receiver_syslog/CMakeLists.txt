# src/plugins/log_receiver_syslog/CMakeLists.txt

add_library(log_receiver_syslog SHARED log_receiver_syslog.cpp)
target_link_libraries(log_receiver_syslog PRIVATE Boost::headers)

target_include_directories(log_receiver_syslog PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

set_target_properties(log_receiver_syslog PROPERTIES
    PREFIX "lib"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_log_receiver_syslog test_log_receiver_syslog.cpp)
    target_link_libraries(test_log_receiver_syslog PRIVATE
        GTest::gtest_main
        log_receiver_syslog
    )
    target_include_directories(test_log_receiver_syslog PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_log_receiver_syslog)
endif()
