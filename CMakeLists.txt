cmake_minimum_required(VERSION 3.28)

# Derive version from git before project() so it is available everywhere.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Version)

project(datadog
    VERSION ${DATADOG_VERSION_MAJOR}.${DATADOG_VERSION_MINOR}.${DATADOG_VERSION_PATCH}
    DESCRIPTION "Datadog agent with dynamic plugin architecture"
    LANGUAGES CXX
)

# --- C++ standard ---
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# --- Export compile commands for clangd / clang-tidy ---
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# --- Position Independent Code (required for shared libraries / plugins) ---
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- Generate version header ---
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/include/datadog/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/datadog/version.h"
    @ONLY
)

# --- Global include directories ---
include_directories(
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${CMAKE_CURRENT_BINARY_DIR}/include"
)

# --- Options ---
option(BUILD_TESTING "Build unit tests" ON)
option(ENABLE_COVERAGE "Enable code coverage instrumentation" OFF)
option(ENABLE_FUZZER "Enable libFuzzer targets" OFF)
option(DATADOG_BUILD_DOCS "Build Doxygen documentation" OFF)

# --- Testing ---
if(BUILD_TESTING)
    enable_testing()
    find_package(GTest REQUIRED)
    include(GoogleTest)
endif()

# --- Coverage instrumentation ---
if(ENABLE_COVERAGE)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        add_compile_options(-fprofile-instr-generate -fcoverage-mapping)
        add_link_options(-fprofile-instr-generate -fcoverage-mapping)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        add_compile_options(--coverage -O0 -g)
        add_link_options(--coverage)
    endif()
endif()

# --- Subdirectories ---
add_subdirectory(src)

# --- Doxygen documentation ---
if(DATADOG_BUILD_DOCS)
    find_package(Doxygen REQUIRED)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile"
        "${CMAKE_CURRENT_BINARY_DIR}/Doxyfile"
        @ONLY
    )
    doxygen_add_docs(docs
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        COMMENT "Generating Doxygen documentation"
    )
endif()
