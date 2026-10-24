# src/datadogctl/CMakeLists.txt

add_executable(datadogctl main.cpp)

target_include_directories(datadogctl PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_datadogctl test_datadogctl.cpp)
    target_link_libraries(test_datadogctl PRIVATE GTest::gtest_main)
    target_include_directories(test_datadogctl PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_datadogctl)
endif()
