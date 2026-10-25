# cmake/Version.cmake
# Derives the project version from git describe.
# Sets the following variables:
#   DATADOG_VERSION       - Full version string (e.g. "v1.2.3-5-gabcdef-dirty")
#   DATADOG_VERSION_MAJOR - Major version number
#   DATADOG_VERSION_MINOR - Minor version number
#   DATADOG_VERSION_PATCH - Patch version number

find_package(Git REQUIRED)

# --tags: use all tags (not just annotated). --always: fall back to short hash
# when no tags exist. --dirty: append "-dirty" for uncommitted changes.
execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
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

message(STATUS "Datadog version (from git): ${DATADOG_VERSION}")
