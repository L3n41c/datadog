# datadog

Lightweight Datadog agent with a dynamic plugin architecture.

## Architecture

The project consists of two executables and six dynamically-loadable plugins:

### Executables

| Binary       | Description |
|-------------|-------------|
| `datadogd`   | Main daemon process |
| `datadogctl` | Command-line control tool |

### Plugins (shared libraries)

| Library                   | Description |
|---------------------------|-------------|
| `libhost_forwarder.so`    | Host metrics forwarder plugin |
| `libhost_linux.so`        | Linux-specific host metrics plugin |
| `liblog_forwarder.so`     | Log forwarder plugin |
| `liblog_receiver_journald.so` | Journald log receiver plugin |
| `liblog_receiver_syslog.so`   | Syslog log receiver plugin |
| `liblog_receiver_file.so`     | File log receiver plugin |

## Build

### Prerequisites

- CMake 4.0+
- Ninja
- C++26-capable compiler (GCC 15+ or Clang 19+)
- vcpkg (for dependency management)
- Git (for version derivation)
- Doxygen (for documentation generation)
- Graphviz / dot (required by Doxygen for diagrams)

### Quick start

```bash
# Configure (development build with ASan + UBSan)
cmake --preset dev

# Build
cmake --build --preset dev

# Run tests
ctest --preset dev

# Or use the workflow preset (configure + build + test)
cmake --workflow --preset dev
```

### Available presets

| Preset       | Description |
|-------------|-------------|
| `dev`        | Debug build with AddressSanitizer + UndefinedBehaviorSanitizer |
| `dev-tsan`   | Debug build with ThreadSanitizer (data race detection) |
| `release`    | Optimized release build with LTO |
| `coverage`   | Debug build with code coverage instrumentation (llvm-cov / gcov) |
| `fuzzer`     | Build with libFuzzer for fuzz testing |

Every preset also has a matching `workflow` preset, so
`cmake --workflow --preset <name>` runs configure + build + test in one
command (`release` has no test step since it builds with `BUILD_TESTING=OFF`;
`coverage` stops after the build because its tests must run inside the
`coverage` target, see below). Test presets write a JUnit report to
`build/<preset>/junit.xml`.

### Dependency management

Dependencies are managed via [vcpkg](https://vcpkg.io) in manifest mode.
The `vcpkg.json` file at the project root declares all dependencies.

To use vcpkg with CMake, set the toolchain file:

```bash
cmake --preset dev -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
```

### Code coverage

The `coverage` preset instruments the build (`--coverage` with GCC,
`-fprofile-instr-generate -fcoverage-mapping` with Clang). The `coverage` CMake
target (`cmake/Coverage.cmake`) is self-contained: it resets stale coverage data
from previous runs, runs the test suite (JUnit report written to the build
directory), then writes the coverage report — identically locally and in CI:

```bash
cmake --preset coverage
cmake --build --preset coverage
cmake --build --preset coverage --target coverage  # runs the tests + writes the report
```

The tool is chosen per compiler: **gcovr** (Cobertura XML) for GCC,
**llvm-profdata + llvm-cov** (LCOV) for Clang. The report is written to the
build directory (`build/coverage/coverage.xml` or `build/coverage/coverage.lcov`)
and covers project sources and headers, excluding test files. Both formats are
accepted by the Datadog coverage upload. On the GCC leg, gcovr must be
installed (`python -m pip install -r .github/requirements-coverage.txt`); on the
Clang leg, `llvm-profdata`/`llvm-cov` ship with LLVM. Clang profiles are written
with a `%p` (pid) pattern so concurrent test processes do not overwrite each
other.

### Datadog Code Coverage

The `coverage` jobs in GitHub Actions (GCC and Clang) generate the report via
the same `coverage` CMake target and upload it to Datadog (Cobertura XML for GCC,
LCOV for Clang). Configure the repository's Actions secret `DD_API_KEY` and
Actions variable `DD_SITE` (for example, `datadoghq.eu`). Also configure `DD_API_KEY`
as a Dependabot secret to enable uploads from Dependabot pull requests. Uploads
are skipped for fork pull requests, which do not receive the API key.

After a successful CI run, view the results under **Software Delivery > Code Coverage**
in Datadog. The repository must be connected through Datadog's source code integration.

### Datadog test reporting

The Build and Test GitHub Actions workflow generates a JUnit report for each test-running
compiler/preset combination and uploads it to Datadog using the `datadog-ci` CLI, including
when tests fail. Reports use service `datadog`, environment `ci`, and a `test.configuration`
tag identifying the compiler and preset. The release preset does not run tests or upload reports.

Configure the repository's GitHub Actions secret `DD_API_KEY` with a Datadog API key and
the Actions variable `DD_SITE` with your Datadog site (for this project, `datadoghq.eu`).
Both must be available to the build job. If using environment-scoped secrets or variables,
the job must reference that GitHub environment. Uploads are explicitly skipped when the API
key is unavailable, such as on pull requests from forks; tests still run normally.

[JUnit XML reporting](https://docs.datadoghq.com/tests/setup/junit_xml/)
provides test results without native Test Impact Analysis or automatic retries.
Confirm ingestion after a CI run in the
[Test Optimization Explorer](https://app.datadoghq.eu/ci/test/runs?query=@git.repository.name:l3n41c/datadog).

## Code style

- Formatting: `clang-format` (see `.clang-format`)
- Linting: `clang-tidy` (see `.clang-tidy`)
- Editor configuration: `.editorconfig`, `.dir-locals.el` (Emacs), `.vimrc` (Vim)

## Documentation

API documentation is generated with Doxygen (requires the `DATADOG_BUILD_DOCS` option):

```bash
cmake --preset dev -DDATADOG_BUILD_DOCS=ON
cmake --build --preset dev --target docs
```

## License

See [LICENSE](LICENSE).
