# 01 — Overview and principles

## Goal

`datadog` is a drop-in replacement for the official Datadog agent. The external behavior
(payloads, endpoints, formats) is fully specified by `specs/specs`. This project delegates
all business logic to **plugins**; the two executables contain only the machinery to load,
configure, run, supervise, and unload those plugins:

- `datadogd` — the daemon. Reads a configuration file, instantiates components from plugins,
  runs them asynchronously, reloads configuration on signal, and exposes a control socket.
- `datadogctl` — the command-line client that sends commands to `datadogd` over the control
  socket and prints the responses.

## Glossary

| Term | Definition |
|---|---|
| Plugin | A shared library `lib<name>.so` (plus its exported descriptor) providing one kind of component. Loaded on demand, unloaded when its last component is destroyed. In pattern literature this artifact is also called a "bundle" (OSGi) or "module"; "plugin" is used here because it is loaded dynamically. |
| Shared library | The OS-level artifact (`.so`) behind a plugin, loaded and unloaded through Boost.Dll's `shared_library`. This is the mechanism, not the architectural concept. |
| Component | A running object instantiated from a plugin (one plugin can be instantiated several times), running asynchronously on an Asio executor. Same term as the reference Datadog agent's `comp/` framework. |
| Component name | Unique name of a component, used to address it from `datadogctl` (explicit `name` parameter, or `<plugin>#<n>`). |
| Config file | Two-level text file: each section header names a plugin, the section body holds the component's parameters. |
| Hot path | Code executed per event (per metric, per log line) inside a component. Must never block and must read config as fast as an atomic field. |
| Control plane | The single-threaded part of the daemon (dedicated `io_context`) that handles signals, config reloads, and IPC commands. |

## Architecture at a glance

```text
datadogd
├── CLI (Boost.Program_options): --help, --version, --config=<file>
├── Config parser (Boost.Spirit X3) → typed config_value tree
├── Plugin registry (Boost.Dll) ── lib<plugin>.so ──► plugin_descriptor
│                                              └──► create() ──► component
├── Component manager (control plane, single-threaded)
│     ├── instantiate / update / destroy components (hot reload, IPC)
│     └── components, each on its own Asio strand
├── Execution model (Boost.Asio)
│     ├── worker io_context pool (N threads) — component hot paths
│     └── control io_context (1 thread) — signals, IPC server, manager
├── Logging (Boost.Log, asynchronous sinks)
│     └── stderr | journald (syslog socket) | file | remote syslog
└── IPC server (Unix socket, newline-delimited JSON / Boost.JSON) ◄── datadogctl
```

This is the **Microkernel pattern** (POSA) with a **plugin registry**: `datadogd` is the
microkernel, the plugins are the external servers, and the plugin registry tracks which
plugins are loaded.

## Hard requirements

1. Plugins are dynamic libraries loaded on demand with Boost.Dll (`dlopen`/`dlclose` hidden
   behind the API) and unloaded automatically when the last component they provide is destroyed.
1. Reading a configuration parameter in a component's hot path must be as fast as reading a
   `std::atomic<T>` field.
1. It must be possible to iterate over a component's configuration parameters programmatically
   (to dump or modify the configuration of all components generically). This is not in the hot
   path; reflection-level performance is acceptable.
1. Every plugin has its own configuration; all configuration structs publicly inherit a common
   configuration struct that contains at least the log level.
1. All logging goes through Boost.Log, non-blocking in the hot path. Development logs go to
   stderr; production (systemd service) logs go to journald; file and remote syslog targets
   must also be supported. The log level is configurable per component, at runtime.
1. Everything is asynchronous on Boost.Asio. The daemon creates the `io_context`s and the
   threads and passes the executor to the components.
1. `datadogd` reads a multi-section configuration file; the section header names the plugin,
   the body holds the parameters. The same create/destroy machinery must be reusable for
   initial load, config reload on `SIGUSR1`, and commands from `datadogctl` (list, dump
   config, change a parameter at runtime, load new components).
1. `datadogctl` talks to `datadogd` over a control channel and can list components, dump their
   configuration, change parameters at runtime, and load new components.

## Non-goals

- Business logic (collectors, forwarders, parsers) — that lives in plugins and is specified by
  `specs/specs`.
- Backward compatibility with earlier versions of this codebase (the project has no users yet).
- Windows support in the first iteration (Boost.Dll is cross-platform, but paths, signals, and
  journald are POSIX; keep the code portable where free).

## Guiding principles

- **Spec conformance**: the external interface must conform to `specs/specs`; when a spec is
  ambiguous, the reference implementation in `specs/src/datadog-agent` decides. Internal design
  is free and documented here and with Doxygen comments.
- **Clean code** (see `AGENTS.md`): KISS, DRY, YAGNI, SOLID, GRASP, CUPID. Minimal code, small
  functions with meaningful names, no speculative generality. English only in committed files.
- **Modern C++26**: smart pointers only (no raw pointers, no manual `new`/`delete`), `const` and
  `constexpr` wherever possible, `std::expected`/`std::optional` for errors, `[[nodiscard]]` on
  fallible functions, no C-style casts, no pointer arithmetic.
- **Boost first**: prefer the C++ standard library, then Boost, then other vcpkg-managed
  libraries. All Boost usage is documented in the relevant design document.
- **Fail loudly, recover locally**: a malformed config file or a failing plugin must never take
  the whole daemon down silently; errors are logged and returned to the caller (IPC), and the
  previous configuration keeps running.
