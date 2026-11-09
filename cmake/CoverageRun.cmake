# cmake/CoverageRun.cmake
#
# Script mode (-P), invoked by the 'coverage_reset' and 'coverage_report'
# custom targets (Coverage.cmake) with -DMODE=reset or -DMODE=report:
#   reset:  delete stale coverage data from previous runs in the same build
#           tree (profiles/counters accumulate across runs);
#   report: generate the coverage report uploaded to Datadog from the data
#           written by the test run:
#           GCC -> gcovr Cobertura XML; Clang -> llvm-profdata + llvm-cov LCOV.
#
# The tests themselves run via the 'coverage' test preset (the workflow
# preset runs: configure + build + coverage_reset + test + coverage_report),
# which writes the JUnit report and sets LLVM_PROFILE_FILE for Clang.
#
# -D variables set by the custom targets: MODE, COVERAGE_DIR, SOURCE_DIR,
# BINARY_DIR, COMPILER_ID, GCOVR_EXECUTABLE, LLVM_PROFDATA_EXECUTABLE,
# LLVM_COV_EXECUTABLE, OBJECTS (list of instrumented binaries).

if(NOT DEFINED MODE)
    message(FATAL_ERROR "CoverageRun.cmake: -DMODE=reset|report is required.")
endif()

if(MODE STREQUAL "reset")
    # Reset stale coverage data (profiles/counters accumulate across runs).
    if(COMPILER_ID MATCHES "Clang")
        file(REMOVE_RECURSE "${COVERAGE_DIR}/profraw")
        file(MAKE_DIRECTORY "${COVERAGE_DIR}/profraw")
    else()
        # GLOB_RECURSE roots the traversal at the directory part of the
        # pattern, so glob from BINARY_DIR itself to also catch nested target
        # dirs like build/coverage/src/datadogd/CMakeFiles/.../*.gcda.
        file(GLOB_RECURSE stale_gcda "${BINARY_DIR}/*.gcda")
        file(REMOVE ${stale_gcda})
    endif()
    return()
endif()

if(NOT MODE STREQUAL "report")
    message(FATAL_ERROR "CoverageRun.cmake: unknown MODE '${MODE}' (expected reset|report).")
endif()

# --- generate the report from the data written by the test run ---
if(COMPILER_ID MATCHES "GNU")
    # gcovr --filter values are regexes matched against file paths: escape the
    # checkout path, or a checkout containing regex metacharacters (e.g.
    # /tmp/datadog+checkout) would match nothing and yield an empty report.
    string(REGEX REPLACE "([][\\^$.|?*+()\\\\])" "\\\\\\1" escaped_source_dir "${SOURCE_DIR}")
    execute_process(
        COMMAND ${GCOVR_EXECUTABLE}
            --root "${SOURCE_DIR}"
            --filter "${escaped_source_dir}/src/"
            --filter "${escaped_source_dir}/include/"
            --exclude "(^|.*/)test_[^/]*[.]cpp$"
            --cobertura "${COVERAGE_DIR}/coverage.xml"
            "${BINARY_DIR}"
        WORKING_DIRECTORY "${SOURCE_DIR}"
        COMMAND_ERROR_IS_FATAL ANY)
elseif(COMPILER_ID MATCHES "Clang")
    file(GLOB profraw_files "${COVERAGE_DIR}/profraw/*.profraw")
    if(NOT profraw_files)
        message(FATAL_ERROR "No .profraw files found in ${COVERAGE_DIR}/profraw.")
    endif()

    execute_process(
        COMMAND ${LLVM_PROFDATA_EXECUTABLE} merge -sparse
            ${profraw_files}
            -o "${COVERAGE_DIR}/coverage.profdata"
        COMMAND_ERROR_IS_FATAL ANY)

    # llvm-cov takes a single binary as positional BIN; every additional binary
    # must be passed with -object, otherwise it is treated as a source filter.
    set(llvm_cov_objects)
    foreach(obj IN LISTS OBJECTS)
        list(APPEND llvm_cov_objects -object "${obj}")
    endforeach()

    # Deny-list anchored so it can never match the checkout path itself: the
    # build dir via its escaped absolute path (also drops vcpkg_installed and
    # generated headers), specific external roots (/usr/include, /usr/lib,
    # ...), and test files. Bare "/build/" or "/usr/" alternatives would
    # silently empty the report for checkouts under such a path component.
    string(REGEX REPLACE "([][\\^$.|?*+()\\\\])" "\\\\\\1" escaped_binary_dir "${BINARY_DIR}")
    set(ignore_alternatives
        "${escaped_binary_dir}/"
        "/usr/include/"
        "/usr/lib/"
        "/usr/lib64/"
        "/usr/local/include/"
        "vcpkg_installed"
        "_deps"
        "(^|/)test_[^/]*[.]cpp$")
    if(NOT SOURCE_DIR MATCHES "^/opt(/|$)")
        list(APPEND ignore_alternatives "/opt/")
    endif()
    string(JOIN "|" joined ${ignore_alternatives})
    set(ignore_regex "(${joined})")
    execute_process(
        COMMAND ${LLVM_COV_EXECUTABLE} export
            -instr-profile "${COVERAGE_DIR}/coverage.profdata"
            -format=lcov
            -ignore-filename-regex "${ignore_regex}"
            ${llvm_cov_objects}
        OUTPUT_FILE "${COVERAGE_DIR}/coverage.lcov"
        COMMAND_ERROR_IS_FATAL ANY)
endif()
