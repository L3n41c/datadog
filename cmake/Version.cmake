# cmake/Version.cmake
# Derives the project version from git describe.
# Sets the following variables:
#   DATADOG_VERSION       - Full version string (e.g. "v1.2.3-5-gabcdef-dirty")
#   DATADOG_VERSION_MAJOR - Major version number
#   DATADOG_VERSION_MINOR - Minor version number
#   DATADOG_VERSION_PATCH - Patch version number

find_package(Git REQUIRED)

# Try to get a descriptive version from git
execute_process(
    COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE _git_describe
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE _git_describe_result
)

if(_git_describe_result EQUAL 0 AND _git_describe)
    set(DATADOG_VERSION "${_git_describe}")
else()
    # Fallback: use git rev-parse for the short hash
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE _git_hash
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
        RESULT_VARIABLE _git_hash_result
    )
    if(_git_hash_result EQUAL 0 AND _git_hash)
        set(DATADOG_VERSION "0.0.0-${_git_hash}")
    else()
        set(DATADOG_VERSION "0.0.0-unknown")
    endif()
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
