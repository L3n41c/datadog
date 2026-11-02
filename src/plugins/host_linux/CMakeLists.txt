# src/plugins/host_linux/CMakeLists.txt

add_library(host_linux SHARED host_linux.cpp)
target_link_libraries(host_linux PRIVATE Boost::headers)

target_include_directories(host_linux PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

set_target_properties(host_linux PROPERTIES
    PREFIX "lib"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_host_linux test_host_linux.cpp)
    target_link_libraries(test_host_linux PRIVATE
        GTest::gtest_main
        host_linux
    )
    target_include_directories(test_host_linux PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_host_linux)
endif()
