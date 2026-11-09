# cmake/Coverage.cmake
#
# 'coverage_reset' and 'coverage_report' targets for ENABLE_COVERAGE=ON builds
# (the 'coverage' workflow preset runs them around the test step:
# cmake --workflow --preset coverage). Report format per toolchain, both
# accepted by DataDog/coverage-upload-github-action:
#   GCC   -> gcovr Cobertura XML (coverage.xml)
#   Clang -> llvm-profdata + llvm-cov LCOV (coverage.lcov)
# The work happens in CoverageRun.cmake (-DMODE=reset|report), which must run
# at build time, after the tests wrote the coverage data. Included from the
# top-level CMakeLists.txt after all targets (expects DATADOG_ALL_TARGETS).

if(NOT ENABLE_COVERAGE)
    return()
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    find_program(GCOVR_EXECUTABLE NAMES gcovr)
    if(NOT GCOVR_EXECUTABLE)
        message(FATAL_ERROR
            "ENABLE_COVERAGE with GCC requires gcovr "
            "(e.g. 'python -m pip install -r .github/requirements-coverage.txt').")
    endif()
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # Version-matched tool names first: LLVM profiles are not cross-version
    # compatible, so an unversioned tool newer than the compiler could fail.
    string(REGEX MATCH "^[0-9]+" LLVM_TOOLS_VERSION_MAJOR "${CMAKE_CXX_COMPILER_VERSION}")
    find_program(LLVM_PROFDATA_EXECUTABLE
        NAMES llvm-profdata-${LLVM_TOOLS_VERSION_MAJOR} llvm-profdata)
    find_program(LLVM_COV_EXECUTABLE
        NAMES llvm-cov-${LLVM_TOOLS_VERSION_MAJOR} llvm-cov)
    if(NOT LLVM_PROFDATA_EXECUTABLE OR NOT LLVM_COV_EXECUTABLE)
        message(FATAL_ERROR
            "ENABLE_COVERAGE with Clang requires llvm-profdata and llvm-cov "
            "(shipped with LLVM/Clang).")
    endif()
else()
    message(FATAL_ERROR
        "ENABLE_COVERAGE is only supported with GCC and Clang "
        "(CMAKE_CXX_COMPILER_ID is '${CMAKE_CXX_COMPILER_ID}').")
endif()

# llvm-cov takes a single positional BIN, so all instrumented binaries are
# passed via -object (this also includes the plugin libraries).
set(COVERAGE_OBJECTS)
foreach(target IN LISTS DATADOG_ALL_TARGETS)
    if(TARGET ${target})
        list(APPEND COVERAGE_OBJECTS "$<TARGET_FILE:${target}>")
    endif()
endforeach()

# Shared -D arguments for both script modes. OBJECTS is deliberately not part
# of this list: expanding a list variable unquoted in COMMAND re-splits its
# semicolons, so -DOBJECTS would receive only the first entry. It is passed as
# a quoted argument at each COMMAND site instead.
set(COVERAGE_RUN_ARGS
    "-DCOVERAGE_DIR=${CMAKE_BINARY_DIR}"
    "-DSOURCE_DIR=${CMAKE_SOURCE_DIR}"
    "-DBINARY_DIR=${CMAKE_BINARY_DIR}"
    "-DCOMPILER_ID=${CMAKE_CXX_COMPILER_ID}"
    "-DGCOVR_EXECUTABLE=${GCOVR_EXECUTABLE}"
    "-DLLVM_PROFDATA_EXECUTABLE=${LLVM_PROFDATA_EXECUTABLE}"
    "-DLLVM_COV_EXECUTABLE=${LLVM_COV_EXECUTABLE}"
)

# Delete stale coverage data from previous runs in the same build tree.
add_custom_target(coverage_reset
    COMMAND ${CMAKE_COMMAND} ${COVERAGE_RUN_ARGS}
        -DMODE=reset
        -P "${CMAKE_CURRENT_LIST_DIR}/CoverageRun.cmake"
    COMMENT "Resetting stale coverage data in ${CMAKE_BINARY_DIR}"
    VERBATIM
)

# Generate the coverage report from the data written by the test run.
add_custom_target(coverage_report
    COMMAND ${CMAKE_COMMAND} ${COVERAGE_RUN_ARGS}
        "-DOBJECTS=${COVERAGE_OBJECTS}"
        -DMODE=report
        -P "${CMAKE_CURRENT_LIST_DIR}/CoverageRun.cmake"
    COMMENT "Generating coverage report in ${CMAKE_BINARY_DIR}"
    VERBATIM
)

# llvm-cov reads the instrumented binaries: build all targets first.
add_dependencies(coverage_report ${DATADOG_ALL_TARGETS})
