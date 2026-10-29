# cmake/Version.cmake
# Derives the project version from git describe.
# Sets the following variables:
#   DATADOG_VERSION       - Full version string (e.g. "v1.2.3-5-gabcdef-dirty")
#   DATADOG_VERSION_MAJOR - Major version number
#   DATADOG_VERSION_MINOR - Minor version number
#   DATADOG_VERSION_PATCH - Patch version number
#
# Dual-mode:
#   Configure time (include()) — sets the variables above for project() and
#     the configure_file() call in CMakeLists.txt.
#   Script mode (cmake -P)     — additionally regenerates version.h via
#     configure_file().  Expects -DSOURCE_DIR=<src> -DBINARY_DIR=<build>.
#     configure_file() only updates the output timestamp when content changes
#     (CopyFileIfDifferent), so this is safe to run on every build.

find_package(Git REQUIRED)

# In script mode, use SOURCE_DIR (passed via -D). In configure mode, use
# CMAKE_SOURCE_DIR (the project root).
if(CMAKE_SCRIPT_MODE_FILE)
    set(_version_working_dir "${SOURCE_DIR}")
else()
    set(_version_working_dir "${CMAKE_SOURCE_DIR}")
endif()

# --tags: use all tags (not just annotated). --always: fall back to short hash
# when no tags exist. --dirty: append "-dirty" for uncommitted changes.
execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
    WORKING_DIRECTORY "${_version_working_dir}"
    OUTPUT_VARIABLE DATADOG_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE _git_describe_result
)

if(NOT _git_describe_result EQUAL 0 OR NOT DATADOG_VERSION)
    set(DATADOG_VERSION "v0.0.0-unknown")
endif()

# Parse version components if the version looks like vMAJOR.MINOR.PATCH[-...]
string(REGEX MATCH "^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)" _version_match "${DATADOG_VERSION}")
if(CMAKE_MATCH_COUNT EQUAL 3)
    set(DATADOG_VERSION_MAJOR "${CMAKE_MATCH_1}")
    set(DATADOG_VERSION_MINOR "${CMAKE_MATCH_2}")
    set(DATADOG_VERSION_PATCH "${CMAKE_MATCH_3}")
else()
    set(DATADOG_VERSION_MAJOR "0")
    set(DATADOG_VERSION_MINOR "0")
    set(DATADOG_VERSION_PATCH "0")
endif()

# In script mode, regenerate the version header.  configure_file() only
# updates the output timestamp when content changes, so dependent files are
# recompiled only when the version actually differs.
if(CMAKE_SCRIPT_MODE_FILE)
    configure_file(
        "${SOURCE_DIR}/include/datadog/version.h.in"
        "${BINARY_DIR}/include/datadog/version.h"
        @ONLY
    )
endif()

message(STATUS "Datadog version (from git): ${DATADOG_VERSION}")
