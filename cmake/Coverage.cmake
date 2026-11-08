# cmake/Coverage.cmake
#
# Defines the 'coverage' custom target for builds configured with
# -DENABLE_COVERAGE=ON (the 'coverage' configure preset). The target is
# self-contained: it resets stale coverage data from previous runs, runs the
# test suite (JUnit report written to the build dir), then writes the coverage
# report that CI uploads to Datadog:
#
#   cmake --preset coverage
#   cmake --build --preset coverage
#   cmake --build --preset coverage --target coverage
#
# One report file per toolchain, both accepted by
# DataDog/coverage-upload-github-action:
#   GCC   (--coverage -> .gcno/.gcda): gcovr -> Cobertura XML (coverage.xml)
#   Clang (-fprofile-instr-generate -fcoverage-mapping -> .profraw):
#         llvm-profdata + llvm-cov -> LCOV (coverage.lcov)
#
# The actual work happens in CoverageRun.cmake (script mode) because the
# coverage data files must be discovered at build time, after the tests ran.
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

add_custom_target(coverage
    COMMAND ${CMAKE_COMMAND}
        "-DCOVERAGE_DIR=${CMAKE_BINARY_DIR}"
        "-DSOURCE_DIR=${CMAKE_SOURCE_DIR}"
        "-DBINARY_DIR=${CMAKE_BINARY_DIR}"
        "-DCMAKE_CTEST_COMMAND=${CMAKE_CTEST_COMMAND}"
        "-DCOMPILER_ID=${CMAKE_CXX_COMPILER_ID}"
        "-DGCOVR_EXECUTABLE=${GCOVR_EXECUTABLE}"
        "-DLLVM_PROFDATA_EXECUTABLE=${LLVM_PROFDATA_EXECUTABLE}"
        "-DLLVM_COV_EXECUTABLE=${LLVM_COV_EXECUTABLE}"
        "-DOBJECTS=${COVERAGE_OBJECTS}"
        -P "${CMAKE_CURRENT_LIST_DIR}/CoverageRun.cmake"
    COMMENT "Running tests and generating coverage report in ${CMAKE_BINARY_DIR}"
    VERBATIM
)

# The target runs ctest itself, so it must not run against missing or stale
# binaries: building 'coverage' alone (cmake --build --preset coverage
# --target coverage) first builds all instrumented targets.
add_dependencies(coverage ${DATADOG_ALL_TARGETS})
