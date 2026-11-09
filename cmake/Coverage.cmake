# cmake/Coverage.cmake
#
# Defines the 'coverage_reset' and 'coverage_report' custom targets for builds
# configured with -DENABLE_COVERAGE=ON (the 'coverage' configure preset).
# Test execution and report generation are separate steps so that the
# 'coverage' workflow preset can run them in order around the test step:
#
#   cmake --workflow --preset coverage
#   # = configure + build + coverage_reset + test + coverage_report
#
# One report file per toolchain, both accepted by
# DataDog/coverage-upload-github-action:
#   GCC   (--coverage -> .gcno/.gcda): gcovr -> Cobertura XML (coverage.xml)
#   Clang (-fprofile-instr-generate -fcoverage-mapping -> .profraw):
#         llvm-profdata + llvm-cov -> LCOV (coverage.lcov)
#
# The actual work happens in CoverageRun.cmake (script mode, -DMODE=reset or
# -DMODE=report) because the coverage data files must be discovered at build
# time, after the tests ran.
#
# Included from the top-level CMakeLists.txt after all targets are defined
# (expects DATADOG_ALL_TARGETS to be set there).

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
    # Version-matched names first (e.g. llvm-cov-21 for clang 21.x): LLVM raw
    # profiles/coverage mappings have no cross-version compatibility guarantee,
    # so an unversioned tool newer than the compiler could fail to read them.
    # Fall back to the unversioned names for toolchains without versioned ones.
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

# Instrumented binaries passed to llvm-cov via -object, so plugin code is
# included (llvm-cov accepts only one positional binary).
set(COVERAGE_OBJECTS)
foreach(target IN LISTS DATADOG_ALL_TARGETS)
    if(TARGET ${target})
        list(APPEND COVERAGE_OBJECTS "$<TARGET_FILE:${target}>")
    endif()
endforeach()

# Shared -D arguments for both script modes. OBJECTS is deliberately NOT part
# of this list: it is a semicolon-separated list, and embedding it in a list
# variable would re-split it into separate arguments when the list is expanded
# unquoted in COMMAND, leaving -DOBJECTS with only the first binary. It is
# passed as a quoted argument at each COMMAND site instead, so it stays a
# single argument and -D receives the full list.
set(COVERAGE_RUN_ARGS
    "-DCOVERAGE_DIR=${CMAKE_BINARY_DIR}"
    "-DSOURCE_DIR=${CMAKE_SOURCE_DIR}"
    "-DBINARY_DIR=${CMAKE_BINARY_DIR}"
    "-DCOMPILER_ID=${CMAKE_CXX_COMPILER_ID}"
    "-DGCOVR_EXECUTABLE=${GCOVR_EXECUTABLE}"
    "-DLLVM_PROFDATA_EXECUTABLE=${LLVM_PROFDATA_EXECUTABLE}"
    "-DLLVM_COV_EXECUTABLE=${LLVM_COV_EXECUTABLE}"
)

# Reset stale coverage data from previous runs in the same build tree
# (profiles/counters accumulate across runs and would skew the report).
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

# Building 'coverage_report' alone (cmake --build --preset coverage --target
# coverage_report) must not run against missing binaries (llvm-cov reads the
# instrumented executables): build all targets first.
add_dependencies(coverage_report ${DATADOG_ALL_TARGETS})
