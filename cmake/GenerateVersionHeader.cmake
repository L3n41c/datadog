# cmake/GenerateVersionHeader.cmake
# Build-time version header generator.
#
# Invoked as:
#   cmake -DSOURCE_DIR=<src> -DBINARY_DIR=<build> -P cmake/GenerateVersionHeader.cmake
#
# Runs `git describe` at build time and regenerates version.h via
# configure_file().  configure_file() only updates the output timestamp when
# the content actually changes (CopyFileIfDifferent), so dependent files are
# recompiled only when the version string differs.

find_package(Git REQUIRED)

execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
    WORKING_DIRECTORY "${SOURCE_DIR}"
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

# configure_file() only updates the output file's timestamp when the content
# changes, so this is safe to call on every build without triggering
# unnecessary recompilations.
configure_file(
    "${SOURCE_DIR}/include/datadog/version.h.in"
    "${BINARY_DIR}/include/datadog/version.h"
    @ONLY
)
