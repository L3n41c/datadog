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

- CMake 3.28+
- Ninja
- C++23-capable compiler (GCC 14+ or Clang 18+)
- vcpkg (for dependency management)
- Git (for version derivation)

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

API documentation is generated with Doxygen:

```bash
cmake --build build/dev --target docs
```

## License

See [LICENSE](LICENSE).
