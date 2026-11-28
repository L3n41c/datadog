# 02 — Plugin system and ABI

## Concepts

A **plugin** is a shared library `lib<name>.so` living in the plugin directory. A plugin
provides exactly one kind of **component**. The daemon loads a plugin on demand, the first
time a component of that plugin is instantiated, and unloads it when the last component
provided by that plugin is destroyed.

The loading/unloading uses **Boost.Dll** (`boost::dll::shared_library`), which wraps
`dlopen`/`dlsym`/`dlclose` on POSIX and `LoadLibrary`/`GetProcAddress`/`FreeLibrary` on
Windows. `dlopen`/`dlclose` are never called directly anywhere in the project.

## Plugin ABI

The boundary between the daemon and a plugin is defined by the public header
`include/datadog/plugin_api.hpp`, compiled into the shared core library
`libdatadog_core.so` (see [08 — Source layout](08-source-layout-and-build.md)). Both the
daemon and every plugin link against this library, so C++ types and vtables cross the
boundary safely (single toolchain, single standard library — a project-wide constraint).

Each plugin exports exactly one symbol:

```cpp
// Inside the plugin .so:
extern "C" BOOST_SYMBOL_EXPORT const datadog::plugin_descriptor kDatadogPlugin = {
    .name = "foo",
    .abi_version = datadog::kPluginAbiVersion,
    .describe_config = &foo_describe_config,
    .create = &foo_create,
};
```

```cpp
// In include/datadog/plugin_api.hpp (core):
namespace datadog {

inline constexpr std::uint32_t kPluginAbiVersion = 1;

struct plugin_descriptor {
    std::string_view name;                        // plugin name, e.g. "foo" -> libfoo.so
    std::uint32_t abi_version;                    // must equal kPluginAbiVersion
    // Callable wrappers, not raw function pointers (AGENTS.md forbids raw pointers). Safe
    // across the .so boundary because both sides share the toolchain and libdatadog_core.
    std::function<config_schema()> describe_config;                      // config schema (doc 03)
    std::function<std::unique_ptr<component>(const create_params&)> create;  // factory
};

struct create_params {
    std::string component_name;                   // unique component name (doc 06)
    config_params params;                         // typed values from the config file / IPC
    boost::asio::any_io_executor executor;        // strand dedicated to this component (doc 05)
};

class component {
public:
    virtual ~component() = default;
    virtual std::string_view component_name() const noexcept = 0;
    virtual std::string_view plugin_name() const noexcept = 0;
    virtual config_ref config() noexcept = 0;     // type-erased access to live config (doc 03)
    virtual auto run() -> boost::asio::awaitable<void> = 0;  // main coroutine, co_spawn'd by the manager
};

} // namespace datadog
```

Why an `extern "C"` descriptor struct and not an exported C++ class: name mangling and layout
of exported C++ symbols are compiler-specific; a single `extern "C"` variable holding plain
function pointers is stable, trivially inspectable with `dlsym`, and keeps the ABI explicit.
The C++ types behind the pointers (`component`, `config_ref`) are safe because both sides are
built with the same toolchain against the same core library.

## Loading and unloading (Boost.Dll)

The `plugin_registry` (part of the core library) maps plugin names to loaded libraries:

```cpp
class plugin_registry {
public:
    // Loads lib<name>.so if needed; returns the exported descriptor.
    // Boost.Dll refcounts loads of the same path across shared_library objects,
    // so concurrent users of one plugin share a single dlopen handle.
    [[nodiscard]] std::expected<std::shared_ptr<const plugin_descriptor>, plugin_error>
    load(std::string_view name);

    // Called when the last component of the plugin is destroyed.
    void release(std::string_view name);  // drops the handle; dlclose happens at refcount 0
};
```

Loading a plugin:

```cpp
namespace dll = boost::dll;
dll::shared_library lib(path, dll::load_mode::append_decorations);  // "foo" -> libfoo.so
auto descriptor = dll::import_symbol<const plugin_descriptor>(lib, "kDatadogPlugin");
// import_symbol returns a refcounted handle that keeps the library loaded
// until the handle is destroyed.
if (descriptor->abi_version != kPluginAbiVersion) → reject with a clear error.
```

Unloading: `shared_library::unload()` does not call `dlclose` immediately if other
`shared_library` objects still reference the same library — Boost.Dll keeps an internal
reference count and only unloads at zero. On top of that, the registry only releases its
handle when **no live component** of that plugin remains (tracked by the component manager,
doc 06). `dlclose` therefore happens exactly when the last component is destroyed, and never
while component code could still be running.

Safety rules for plugin authors (enforced by review, not by the loader):

- A plugin must not start threads that outlive its components. All asynchronous work runs on
  the executor handed over in `create_params` and is cancelled before destruction.
- A plugin must not keep references to core-library objects beyond the lifetime of its
  components.
- Static/global objects in a plugin must not be touched after `dlclose`; the manager
  guarantees that destruction completes before the release.

## Plugin discovery

The plugin directory is resolved in this order:

1. `plugin_path` key of the reserved `[core]` section of the config file (colon-separated list);
1. `DATADOG_PLUGIN_PATH` environment variable (colon-separated list);
1. compiled-in default: `<install-prefix>/lib/datadog/plugins`.

A plugin named `foo` is loaded from the first directory containing `libfoo.so`.

## CMake

Each plugin is a directory under `src/plugins/<name>/` built by a helper function defined in
`src/plugins/CMakeLists.txt`:

```cmake
datadog_plugin(foo foo.cpp)   # produces libfoo.so, hidden visibility except kDatadogPlugin,
                             # links datadog_core, installs to lib/datadog/plugins
```

The existing per-plugin `set_target_properties(... PREFIX "lib" CXX_VISIBILITY_PRESET hidden)`
pattern is kept: only `BOOST_SYMBOL_EXPORT` symbols are visible from a plugin.

## Alternatives considered

- **Exporting a C++ factory function directly** (`extern "C" std::unique_ptr<component> create()`):
  works, but a single descriptor struct is easier to version and to extend (adding
  `describe_config` later did not change the ABI shape).
- **Header-only core (no `libdatadog_core.so`)**: would avoid one shared library, but then
  every plugin statically embeds the core code; type-erased interfaces (`config_ref`) and
  RTTI across the boundary become fragile. A shared core library with an explicit visibility
  macro (`DATADOG_API`) is the standard solution.
- **`boost::dll::experimental::smart_library`**: considered; its automatic unload-on-scope-exit
  semantics fight with the explicit "unload at last component" rule. Plain `shared_library`
  plus our own component count gives exact control.
