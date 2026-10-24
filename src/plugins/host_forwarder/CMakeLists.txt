# src/plugins/host_forwarder/CMakeLists.txt

add_library(host_forwarder SHARED host_forwarder.cpp)

target_include_directories(host_forwarder PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

set_target_properties(host_forwarder PROPERTIES
    PREFIX "lib"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_host_forwarder test_host_forwarder.cpp)
    target_link_libraries(test_host_forwarder PRIVATE
        GTest::gtest_main
        host_forwarder
    )
    target_include_directories(test_host_forwarder PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_host_forwarder)
endif()
