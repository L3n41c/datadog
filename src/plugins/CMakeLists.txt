# src/plugins/CMakeLists.txt

# Builds one plugin shared library: lib<name>.so with hidden visibility (only BOOST_SYMBOL_EXPORT
# symbols are visible), linked against the core library, installed to lib/datadog/plugins, with its
# colocated test_<name> target (doc 02, doc 08).
function(datadog_plugin name)
    add_library(${name} SHARED ${ARGN})
    target_link_libraries(${name} PRIVATE Datadog::core)

    set_target_properties(
        ${name}
        PROPERTIES PREFIX "lib"
                   CXX_VISIBILITY_PRESET hidden
                   VISIBILITY_INLINES_HIDDEN ON)

    install(TARGETS ${name} LIBRARY DESTINATION lib/datadog/plugins)

    # --- Unit tests ---
    if(BUILD_TESTING AND DATADOG_BUILD_GTESTS)
        add_executable(test_${name} test_${name}.cpp)
        target_link_libraries(test_${name} PRIVATE GTest::gtest_main ${name})
        gtest_discover_tests(test_${name} DISCOVERY_MODE PRE_TEST)
    endif()
endfunction()

add_subdirectory(host_forwarder)
add_subdirectory(host_linux)
add_subdirectory(log_forwarder)
add_subdirectory(log_receiver_journald)
add_subdirectory(log_receiver_syslog)
add_subdirectory(log_receiver_file)
