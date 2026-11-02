# src/datadogd/CMakeLists.txt

add_executable(datadogd main.cpp)

target_include_directories(datadogd PRIVATE
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_BINARY_DIR}/include"
)

# --- Unit tests ---
if(BUILD_TESTING)
    add_executable(test_datadogd test_datadogd.cpp)
    target_link_libraries(test_datadogd PRIVATE GTest::gtest_main)
    target_include_directories(test_datadogd PRIVATE
        "${CMAKE_SOURCE_DIR}/include"
        "${CMAKE_BINARY_DIR}/include"
    )
    gtest_discover_tests(test_datadogd)
endif()
