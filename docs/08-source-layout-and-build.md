# 08 — Source layout and build

## Directory layout

```text
include/datadog/               public headers of the core library (Doxygen-documented)
  plugin_api.hpp               component, plugin_descriptor, create_params, kPluginAbiVersion
  config.hpp                   config_value, config_atomic, common_config, config_ref, schema helpers
  config_grammar.hpp           Boost.Spirit X3 grammar for the config file and single values
  plugin_registry.hpp          Boost.Dll wrapper (load/release, refcounting)
  component_manager.hpp        doc 06
  logging.hpp                  severity, make_component_logger, sink setup (doc 04)
  ipc.hpp                      protocol types (request/response), command interface
  version.h.in                 (existing) generated version header
src/
  core/                        target datadog_core → libdatadog_core.so (shared by all)
    CMakeLists.txt
    config.cpp  config_grammar.cpp  plugin_registry.cpp
    component_manager.cpp  logging.cpp  ipc_server.cpp  ipc_client.cpp
  datadogd/                    daemon executable (main.cpp + daemon wiring)
  datadogctl/                  CLI executable (main.cpp + command implementations)
  plugins/
    CMakeLists.txt             datadog_plugin(name ...) helper function
    host_forwarder/            one directory per plugin → libhost_forwarder.so
    host_linux/
    log_forwarder/
    log_receiver_journald/
    log_receiver_syslog/
    log_receiver_file/
tests are colocated: src/<dir>/test_<target>.cpp (existing convention), discovered with
GTest's gtest_discover_tests.
docs/                          this design (linked from AGENTS.md)
specs/                         functional specs submodule (read-only reference)
```

## Build rules

- One shared library `libdatadog_core.so` (target `datadog_core`) holds everything plugins and
  both executables share: the plugin ABI types, config machinery, registry, manager, logging
  setup, IPC. Public symbols are exported with a `DATADOG_API` macro
  (`BOOST_SYMBOL_EXPORT` / `__attribute__((visibility("default")))`); everything else in the
  core lib is hidden.
- `datadogd`, `datadogctl`, and every plugin link `datadog_core`. Plugins are `SHARED`
  libraries named `lib<name>.so` with `CXX_VISIBILITY_PRESET hidden`; only
  `kDatadogPlugin` is exported (doc 02). They install to `<prefix>/lib/datadog/plugins`.
- The `datadog_plugin(name <sources...>)` CMake function encapsulates: shared lib, prefix
  `lib`, hidden visibility, link to `datadog_core` + Boost, install rule, and the colocated
  `test_<name>` executable when `BUILD_TESTING` is on. New plugins add one line in
  `src/plugins/CMakeLists.txt`.
- `DATADOG_ALL_TARGETS` in the root `CMakeLists.txt` is extended with `datadog_core` (and its
  test target) so the `version_header` dependency and coverage keep working.

## Dependencies (vcpkg.json)

Existing: `boost-dll`, `boost-asio`, `gtest`, `benchmark`. To be added for the core:

| Package | Used for |
|---|---|
| `boost-log` (+ `boost-thread`) | logging (doc 04) |
| `boost-program-options` | CLI parsing (doc 07) |
| `boost-url` | `boost::urls::url` config values (doc 03) |
| `boost-json` | IPC protocol (doc 07) |
| `boost-spirit` | config grammar (header-only, doc 03) |
| `boost-describe` | config reflection (header-only, doc 03) |
| system `libsystemd-dev` (OS package, installed explicitly in CI workflows; detected via pkg-config then `find_library`; behind `DATADOG_WITH_SYSTEMD`) — not a vcpkg port: the vcpkg `libsystemd` port fails to build on the CI runner images (libxcrypt system requirements), and libsystemd is a host library anyway | `sd_journal_send` native journald backend (doc 04) |

`boost-property-tree` is only needed if we add the INI/JSON fallback parser; not required by the
primary design.

## Naming and style

- Namespaces: `datadog` for the core API; `datadog::plugins::<name>` inside plugins.
- Files: snake_case (`plugin_registry.cpp`, `plugin_registry.hpp`); one class per file where
  practical; headers use `#pragma once`.
- C++26, `-Wall -Wextra -Wpedantic -Wconversion -Werror ...` as already configured; tabs in
  C++ sources, 2 spaces in Markdown (see `.editorconfig`).
- Public headers carry brief Doxygen comments (the API docs are generated with Doxygen, see
  `DATADOG_BUILD_DOCS`).
- Tests: one `test_<target>.cpp` per target, GTest, colocated; every new behavior gets a test;
  build and test with `cmake --workflow --preset dev` (and the sanitizer presets in CI).
