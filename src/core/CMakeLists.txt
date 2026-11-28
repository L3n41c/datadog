# src/core/CMakeLists.txt

# libdatadog_core.so: shared core library linked by datadogd, datadogctl and every plugin (doc 08).
# Public symbols are exported with DATADOG_API; everything else is hidden.

add_library(datadog_core SHARED core.cpp)
add_library(Datadog::core ALIAS datadog_core)

target_compile_definitions(datadog_core PRIVATE DATADOG_CORE_BUILD)

target_link_libraries(datadog_core PUBLIC Boost::headers)

target_include_directories(datadog_core PUBLIC "${CMAKE_SOURCE_DIR}/include"
                                               "${CMAKE_BINARY_DIR}/include")

set_target_properties(
    datadog_core
    PROPERTIES PREFIX "lib"
               CXX_VISIBILITY_PRESET hidden
               VISIBILITY_INLINES_HIDDEN ON)

install(TARGETS datadog_core LIBRARY DESTINATION lib)

# --- Unit tests ---
if(BUILD_TESTING AND DATADOG_BUILD_GTESTS)
    add_executable(test_datadog_core test_datadog_core.cpp)
    target_link_libraries(test_datadog_core PRIVATE GTest::gtest_main Datadog::core)
    gtest_discover_tests(test_datadog_core DISCOVERY_MODE PRE_TEST)
endif()
