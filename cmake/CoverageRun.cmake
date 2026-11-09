# cmake/CoverageRun.cmake
#
# Script mode (-P), invoked by the coverage_reset / coverage_report targets
# (cmake/Coverage.cmake) with -DMODE=reset|report. The tests themselves run
# via the 'coverage' test preset; this script only resets stale coverage data
# (reset) or writes the report from the data the tests produced (report):
# GCC -> gcovr Cobertura XML, Clang -> llvm-profdata + llvm-cov LCOV.

if(NOT DEFINED MODE)
    message(FATAL_ERROR "CoverageRun.cmake: -DMODE=reset|report is required.")
endif()

if(MODE STREQUAL "reset")
    if(COMPILER_ID MATCHES "Clang")
        file(REMOVE_RECURSE "${COVERAGE_DIR}/profraw")
        file(MAKE_DIRECTORY "${COVERAGE_DIR}/profraw")
    else()
        # GLOB_RECURSE roots at the pattern's directory part: glob from
        # BINARY_DIR itself to also catch nested target dirs.
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
    # --filter values are regexes: escape SOURCE_DIR, or a checkout path with
    # regex metacharacters would match nothing and yield an empty report.
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

    # Every binary after the first must be passed with -object; a positional
    # extra would be treated as a source filter.
    set(llvm_cov_objects)
    foreach(obj IN LISTS OBJECTS)
        list(APPEND llvm_cov_objects -object "${obj}")
    endforeach()

    # Anchored deny-list: escaped absolute build dir (also drops vcpkg_installed
    # and generated headers) plus specific external roots. Bare "/build/"-style
    # alternatives could match the checkout path itself and empty the report.
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
