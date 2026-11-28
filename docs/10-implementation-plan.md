# 10 — Implementation plan

Phased plan to implement the core architecture designed in docs 01–09. Each phase is one
branch and one pull request, squashed to a single commit on merge (see `AGENTS.md`). A phase is
done only when the whole CI is green (build + tests on every preset, sanitizers, all linters)
and every new behavior has a GTest.

Cross-cutting rules for every phase (from `AGENTS.md`): English only; C++26; no raw pointers,
no manual `new`/`delete`; `std::expected`/`std::optional` for errors; `[[nodiscard]]` on fallible
functions; Doxygen comments on public headers; run `clang-format` and `clang-tidy` locally before
committing; colocated `test_<target>.cpp` GTest files; simplification pass at the end of each
phase; if a phase changes documented behavior, update `docs/` in the same commit.

## Phase 0 — Build and dependency foundation

Goal: the core shared library exists and everything builds and tests green.

1. Extend `vcpkg.json`: add `boost-log`, `boost-program-options`, `boost-url`, `boost-json`,
   `boost-spirit`, `boost-describe`; add `libsystemd` behind a CMake option
   `DATADOG_WITH_SYSTEMD` (default ON on Linux, doc 04).
1. Create `src/core/` with target `datadog_core` (`SHARED`, `libdatadog_core.so`), exporting
   public symbols via a `DATADOG_API` macro (doc 08); add `datadog_core` (+ its test target) to
   `DATADOG_ALL_TARGETS` in the root `CMakeLists.txt`.
1. Add the `datadog_plugin(name <sources...>)` helper in `src/plugins/CMakeLists.txt`
   (SHARED lib `lib<name>.so`, hidden visibility, links `datadog_core`, installs to
   `lib/datadog/plugins`, colocated test target).
1. Rewire the existing stubs: `datadogd`/`datadogctl` link `datadog_core`; each stub plugin in
   `src/plugins/*` links `datadog_core` (still exporting only `kVERSION` for now).
1. Verify `cmake --workflow --preset dev` (and the sanitizer presets compile).

## Phase 1 — Core headers: plugin ABI and config types (doc 02, doc 03)

1. `include/datadog/plugin_api.hpp`: `kPluginAbiVersion`, `plugin_descriptor` with
   `std::function` callbacks, `create_params`, abstract `component` (`component_name()`,
   `plugin_name()`, `config()`, `run() -> awaitable<void>`).
1. `include/datadog/config.hpp`: `config_value` variant, `config_type`, `config_params`,
   `config_atomic<T>` (scalar `std::atomic<T>` relaxed vs `std::atomic<std::shared_ptr<const
   T>>` release/acquire), `common_config` (log level), `config_ref`/`field_view` with bound
   `std::function` accessors, `make_config_ref<T>`/`make_schema<T>` on top of Boost.Describe
   (base classes included), `config_builder<T>::from_params`, `to_json(config_ref)`,
   `to_string(config_value)`.
1. Tests: Describe walk over a test struct with a base class; value conversions (chrono, url,
   severity); bound get/set; schema defaults; unknown-key/missing-key errors.

## Phase 2 — Configuration file grammar (doc 03)

1. `include/datadog/config_grammar.hpp` + `src/core/config_grammar.cpp`: Boost.Spirit X3 grammar
   for the two-level file (sections, `key: value`, comments, typed values: bool / int / real /
   duration / URL / string / array) and the single-value parser reused by IPC `set`; errors with
   line/column via the X3 `error_handler`; `config_tree` result type (`[core]` + ordered
   sections).
1. Tests: the example file from doc 03 parses with exact typed values; malformed inputs report
   line/column; duplicate keys and duplicate component names are errors; optional fuzz target
   under `ENABLE_FUZZER`.

## Phase 3 — Logging (doc 04)

1. `include/datadog/logging.hpp` + `src/core/logging.cpp`: `severity` enum + `to_string` /
   `parse_severity`; `make_component_logger(name, config_atomic<severity>&)` (channel logger +
   filter reading the atomic on every record); sink setup from `[core]`: `stderr`
   (text_ostream), `journald` (custom backend calling `sd_journal_send` with `PRIORITY` /
   `MESSAGE` / `COMPONENT`, behind `DATADOG_WITH_SYSTEMD`; fallback `syslog_backend` →
   `/dev/log`, then stderr), `file:<path>`, `syslog:<host>:<port>`; every sink wrapped in
   `asynchronous_sink` with `unbounded_fifo_queue` (or bounded + drop per `[core] log_queue`);
   shutdown = `core->flush()` + `remove_all_sinks()`.
1. Tests: severity mapping, per-component level hot change visible in the filter, enqueue never
   blocks.

## Phase 4 — Plugin registry (doc 02)

1. `include/datadog/plugin_registry.hpp` + `src/core/plugin_registry.cpp`: Boost.Dll
   `shared_library` per plugin (`load_mode::append_decorations`),
   `import_symbol<const plugin_descriptor>(lib, "kDatadogPlugin")`, ABI version check,
   refcounted descriptor handle; `release()` drops the handle so `dlclose` happens at refcount
   zero; plugin path resolution (`[core] plugin_path`, `DATADOG_PLUGIN_PATH`, compiled default).
1. Tests with a test plugin `.so`: load → descriptor → create → release → unload; ABI mismatch
   rejected with a clear error; loading the same plugin twice shares one `dlopen`.

## Phase 5 — Execution model (doc 05)

1. `src/core/executors.{hpp,cpp}`: worker pool (N `io_context`s, one thread each, `work_guard`,
   round-robin strand assignment, N from `[core] threads` or `min(hardware_concurrency, 16)`);
   control `io_context` + strand; `signal_set` (SIGUSR1 reload, SIGTERM/SIGINT shutdown).
1. Component launch: `co_spawn` on the component strand with `bind_cancellation_slot` and a
   real completion handler (`void(std::exception_ptr)`) that posts completion to the control
   strand; stop = `post(strand, [sig = shared_ptr signal]{ sig->emit(); })`.
1. Tests: strand serialization of a component's handlers; cancellation observed; completion
   broadcast to several waiters; no thread explosion (fixed thread count).

## Phase 6 — Component manager (doc 06)

1. `include/datadog/component_manager.hpp` + `src/core/component_manager.cpp`: entries keyed by
   component name (`name` or `<plugin>#<n>`); FIFO operation queue on the control strand;
   `reconcile` diff (new / changed params via `field_view::set` / removed) with `stop_state`
   (`state`, `has_removal_owner`, `result`, `waiters`) and the three-branch removal protocol;
   parse/validation errors are atomic (old config keeps running).
1. Tests: reconcile create/update/remove; overlapping reloads serialize through the queue;
   unload of a spontaneously stopped component; double-unload safety; reload keeps running
   config on parse error.

## Phase 7 — IPC control plane, datadogd, datadogctl (docs 05, 07)

1. `include/datadog/ipc.hpp`: JSON-lines request/response types (Boost.JSON), `command`
   interface, command registry.
1. `src/core/ipc_server.cpp`: Unix stream socket (`[core] socket`, perms `0660`), acceptor on
   the control strand, one coroutine per connection, `async_read_until('\n')`, SO_PEERCRED
   audit line per command; `draining` state rejects `load`/`unload`/`reload`/`set` with
   `shutting_down`.
1. Commands: `list`, `status`, `schema`, `dump`, `get`, `set` (value parsed by the doc-03
   grammar), `load`, `unload`, `reload`, `shutdown` — all delegating to the manager.
1. `src/datadogd/main.cpp`: Boost.Program_options (`--help`/`--version`/`--config`), config
   parse, logging init, pool + control start, IPC server, initial reconcile, startup/shutdown
   sequences of doc 05.
1. `src/datadogctl/main.cpp`: subcommands mirroring the commands, Asio client, pretty-printed
   output, exit code 0/1.
1. Tests: end-to-end over a temporary Unix socket (list/dump/get/set/load/unload/reload/
   shutdown), audit line contains uid/pid, `shutting_down` rejection during shutdown.

## Phase 8 — Migrate the plugins one by one (specs/specs)

Each plugin gets its own branch/PR: real config struct (`BOOST_DESCRIBE_STRUCT` with
`common_config` base), exported `kDatadogPlugin` descriptor, `component` implementation whose
business logic conforms to `specs/specs`. Suggested order (increasing complexity):
`log_receiver_file` → `log_receiver_syslog` → `log_receiver_journald` → `log_forwarder` →
`host_linux` → `host_forwarder`. The stubs keep building until each is replaced.

## Phase 9 — Packaging and service

1. Install rules: `datadogd`, `datadogctl`, plugins → `<prefix>/lib/datadog/plugins`, default
   config `/etc/datadog/datadog.conf`.
1. `datadogd.service` systemd unit (Type=simple; logs reach journald via the doc-04 backend).
1. Smoke test: `datadogd --config <file>` starts, `datadogctl list` answers, SIGUSR1 reloads,
   SIGTERM shuts down cleanly.

## Suggested branch/PR cadence

`phase/0-build-core` → `phase/1-abi-config` → `phase/2-config-grammar` → `phase/3-logging` →
`phase/4-plugin-registry` → `phase/5-execution-model` → `phase/6-component-manager` →
`phase/7-ipc-daemon-cli` → `phase/8-plugin-<name>` (×6) → `phase/9-packaging`. Each PR: one
squashed commit, CI green, docs updated in the same commit when behavior changes.
