# src/plugins/log_receiver_journald/CMakeLists.txt

add_library(log_receiver_journald SHARED log_receiver_journald.cpp)

target_include_directories(log_receiver_journald PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

set_target_properties(log_receiver_journald PROPERTIES
    PREFIX "lib"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_log_receiver_journald test_log_receiver_journald.cpp)
    target_link_libraries(test_log_receiver_journald PRIVATE
        GTest::gtest_main
        log_receiver_journald
    )
    target_include_directories(test_log_receiver_journald PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_log_receiver_journald)
endif()
