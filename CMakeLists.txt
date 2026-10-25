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

# --- Fuzzer guard: -fsanitize=fuzzer-no-link is Clang-only ---
if(ENABLE_FUZZER AND NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR
        "ENABLE_FUZZER requires Clang (uses -fsanitize=fuzzer-no-link, "
        "which GCC does not support). Use the 'fuzzer' CMake preset "
        "(which selects clang++) or configure with -DCMAKE_CXX_COMPILER=clang++.")
endif()

# --- Subdirectories ---
add_subdirectory(src)

# --- Doxygen documentation ---
# Uses doxygen_add_docs with DOXYGEN_* variables (CMake FindDoxygen module).
# doxygen_add_docs generates its own Doxyfile from these variables.
# Theme: doxygen-awesome-css, fetched via FetchContent at configure time.
if(DATADOG_BUILD_DOCS)
    find_package(Doxygen REQUIRED)

    # Fetch doxygen-awesome-css theme assets at configure time.
    include(FetchContent)
    FetchContent_Declare(
        doxygen-awesome-css
        GIT_REPOSITORY https://github.com/jothepro/doxygen-awesome-css.git
        # Pinned to immutable commit SHA for tag v2.4.1 (tags can be force-moved).
        GIT_TAG 1f3620084ff75734ed192101acf40e9dff01d848
        SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/doxygen-awesome-css"
    )
    FetchContent_MakeAvailable(doxygen-awesome-css)

    # DOXYGEN_* variables consumed by doxygen_add_docs to customize the generated Doxyfile.
    set(DOXYGEN_PROJECT_NAME "datadog")
    set(DOXYGEN_PROJECT_NUMBER "${DATADOG_VERSION}")
    set(DOXYGEN_PROJECT_BRIEF "Datadog agent with dynamic plugin architecture")
    set(DOXYGEN_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/docs/api")
    set(DOXYGEN_GENERATE_LATEX "NO")
    set(DOXYGEN_GENERATE_XML "NO")
    set(DOXYGEN_GENERATE_RTF "NO")
    set(DOXYGEN_GENERATE_MAN "NO")
    set(DOXYGEN_SOURCE_BROWSER "YES")
    set(DOXYGEN_INLINE_SOURCES "NO")
    set(DOXYGEN_STRIP_CODE_COMMENTS "YES")
    set(DOXYGEN_VERBATIM_HEADERS "YES")
    set(DOXYGEN_WARN_IF_UNDOCUMENTED "YES")
    set(DOXYGEN_WARN_IF_DOC_ERROR "YES")
    set(DOXYGEN_WARN_NO_MATCHED_DOC "YES")
    set(DOXYGEN_WARN_LOGFILE "${CMAKE_CURRENT_BINARY_DIR}/docs/doxygen-warnings.log")
    set(DOXYGEN_RECURSIVE "YES")
    set(DOXYGEN_FILE_PATTERNS "*.h;*.hpp;*.hxx;*.cpp;*.cxx")
    set(DOXYGEN_EXCLUDE_PATTERNS "*/build/*;*/.git/*")
    set(DOXYGEN_ENABLE_PREPROCESSING "YES")
    set(DOXYGEN_MACRO_EXPANSION "NO")
    set(DOXYGEN_SEARCH_INCLUDES "YES")
    set(DOXYGEN_INCLUDE_PATH
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_BINARY_DIR}/include"
    )
    set(DOXYGEN_PREDEFINED "")
    set(DOXYGEN_EXPAND_AS_DEFINED "")
    set(DOXYGEN_SKIP_FUNCTION_MACROS "YES")
    set(DOXYGEN_HAVE_DOT "NO")
    set(DOXYGEN_CLASS_DIAGRAMS "YES")
    set(DOXYGEN_HTML_DYNAMIC_MENUS "YES")
    set(DOXYGEN_HTML_DYNAMIC_SECTIONS "YES")
    set(DOXYGEN_HTML_INDEX_NUM_ENTRIES 100)
    set(DOXYGEN_GENERATE_TREEVIEW "YES")
    set(DOXYGEN_DISABLE_INDEX "NO")
    set(DOXYGEN_FULL_SIDEBAR "YES")
    set(DOXYGEN_HTML_COLORSTYLE_HUE 220)
    set(DOXYGEN_HTML_COLORSTYLE_SAT 100)
    set(DOXYGEN_HTML_COLORSTYLE_GAMMA 80)
    set(DOXYGEN_HTML_COLORSTYLE "LIGHT")
    # doxygen-awesome-css theme integration
    set(DOXYGEN_HTML_EXTRA_STYLESHEET
        "${CMAKE_CURRENT_BINARY_DIR}/doxygen-awesome-css/doxygen-awesome.css"
    )
    set(DOXYGEN_HTML_EXTRA_FILES
        "${CMAKE_CURRENT_BINARY_DIR}/doxygen-awesome-css/doxygen-awesome-darkmode-toggle.js"
    )

    doxygen_add_docs(docs
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        COMMENT "Generating Doxygen documentation with doxygen-awesome-css theme"
    )
endif()
