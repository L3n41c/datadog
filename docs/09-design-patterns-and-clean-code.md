# 09 — Design patterns and clean code

## Patterns used, and where

| Pattern | Where | Why |
|---|---|---|
| Microkernel (POSA) + Plugin Registry | the whole architecture (docs 01–07) | `datadogd` is the microkernel, plugins are the external servers, `plugin_registry` is the registry; terminology follows the pattern literature (a plugin artifact is a "bundle" in OSGi terms) |
| Abstract Factory / Factory Method | `plugin_descriptor::create` (doc 02) | the daemon instantiates components without knowing their concrete type |
| Registry / Information Expert (GRASP) | `plugin_registry` (doc 02) | the single place that knows which `.so` provides which plugin and when to load/unload |
| Facade | `plugin_registry` over Boost.Dll; `logging.hpp` over Boost.Log | `dlopen`/`dlclose` and Boost.Log setup appear exactly once in the codebase |
| RAII + reference counting | `shared_library` handles, component entries, log sinks, `work_guard` | load on first use, unload on last release; no manual resource management anywhere |
| Command | IPC command map (doc 07) | each `datadogctl` command is an object executed on the control strand; adding a command = adding one class + one registration |
| Strategy | log backend selection (`[core] log_target`, doc 04); value grammar (doc 03) | the daemon picks a sink backend / parser without knowing the details |
| Observer | config changes: manager pushes via `field_view::set` (doc 03/06) | components see new parameter values through their atomics; no polling |
| State | component lifecycle: `running → stopping → stopped` (doc 06) | transitions are made synchronously on the control strand before any suspension, with a single removal owner per entry, so overlapping operations cannot double-transition or double-destroy (a strand serializes handlers, not coroutine continuations — doc 05) |
| Dependency Inversion (SOLID-D) | components depend only on core abstractions (`component`, `config_ref`, executors), never on the daemon internals | plugins are independently buildable and testable |
| Polymorphism (SOLID-O/L) | `component` interface; plugins closed for modification, open for extension | new checks/collectors are new `.so` files, no daemon change |

Deliberately **not** used: singletons for our own state (everything is passed explicitly;
Boost.Log's core is a singleton by nature and hidden behind `logging.hpp`), global mutable
state, manual `new`/`delete`, stringly-typed configuration internally.

## Clean-code rules applied to this design

From `AGENTS.md` (KISS, DRY, YAGNI, SOLID, GRASP, CUPID, Law of Demeter, Command-Query
Separation), concretely:

- **Minimal code, small functions**: each class in docs 02–07 has one responsibility and a
  handful of methods; manager operations are one-liners delegating to the registry.
- **No speculative generality**: no plugin "capabilities" system, no generic event bus, no
  remote-config machinery — YAGNI until a spec requires it.
- **Strong typing**: config values are a `std::variant`, never strings to be re-parsed; temporal
  values are `std::chrono` durations end to end; URLs are `boost::urls::url`.
- **Errors as values**: `std::expected` / `std::optional`, `[[nodiscard]]` on fallible functions;
  no exceptions across the plugin boundary.
- **No raw pointers / no manual memory**: smart pointers, references, `std::span`; RAII for the
  `.so` handles, sinks, executors.
- **English only** in every committed file; Doxygen comments on public headers only, kept short.
- **Tests colocated** (`test_<target>.cpp`) for every behavior; CI runs all presets +
  sanitizers + linters (clang-format, clang-tidy, markdownlint, editorconfig-checker, …) and must
  stay green; docs in `docs/` are linted like any other tracked file.
- **Simplification pass** after each implementation task: remove dead code and comments about
  removed code so no trace of intermediate iterations remains.

## Resolved decisions

1. **IPC security**: authorization is done by the socket file permissions only; `SO_PEERCRED`
   (`struct ucred` pid/uid/gid) is read at accept time and used solely for audit logging of
   every received command on a dedicated `audit` channel — specified in doc 07.
1. **journald backend**: production default is the native protocol via `sd_journal_send`
   (custom Boost.Log sink backend, structured fields such as `COMPONENT=`), with the
   `/run/systemd/journal/syslog` syslog socket as fallback — specified in doc 04.

## Open points for implementation sessions

1. Exact `config_type` ↔ C++ type mapping table (including `std::chrono` specializations and
   arrays of scalars) — to be pinned down when `config.hpp` is written.
1. `datadogctl load` argument syntax on the command line (`key: value ...`) vs JSON in `args` —
   both parse through the same value grammar; pick one surface syntax.
