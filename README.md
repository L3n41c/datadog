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

### Dependency management

Dependencies are managed via [vcpkg](https://vcpkg.io) in manifest mode.
The `vcpkg.json` file at the project root declares all dependencies.

To use vcpkg with CMake, set the toolchain file:

```bash
cmake --preset dev -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
```

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
