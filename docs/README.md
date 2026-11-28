# Core architecture design

This directory contains the design of the **core architecture** of the `datadog` agent
re-implementation: the plugin system, the configuration model, logging, the asynchronous
execution model, the component manager, and the control plane (`datadogctl`).

It is the reference for all implementation sessions. When a change alters this design,
update these documents in the same commit. The functional (external) contract is defined
by `specs/specs`; these documents define only the internal architecture.

## Reading order

1. [01 — Overview and principles](01-overview-and-principles.md) — goals, glossary, architecture at a glance.
1. [02 — Plugin system and ABI](02-plugin-system-and-abi.md) — dynamic libraries, plugin descriptor, load/unload lifecycle.
1. [03 — Configuration format and reflection](03-configuration-format-and-reflection.md) — config file grammar, typed values, hot-path config access, programmatic iteration.
1. [04 — Logging](04-logging.md) — Boost.Log setup, non-blocking sinks, per-component log level.
1. [05 — Execution model and lifecycle](05-execution-model-and-lifecycle.md) — Boost.Asio thread pool, strands, signals, startup/shutdown.
1. [06 — Component manager and hot reload](06-component-manager-and-hot-reload.md) — generic create/update/destroy engine.
1. [07 — IPC control plane and datadogctl](07-ipc-and-datadogctl.md) — socket protocol and commands.
1. [08 — Source layout and build](08-source-layout-and-build.md) — directories, targets, dependencies.
1. [09 — Design patterns and clean code](09-design-patterns-and-clean-code.md) — patterns used and coding rules.
1. [10 — Implementation plan](10-implementation-plan.md) — phased plan (one branch/PR per phase) to implement this design.

## Decisions at a glance

| Topic | Decision |
|---|---|
| Plugin mechanism | `*.so` loaded on demand with Boost.Dll, unloaded when the last component of the plugin is destroyed |
| Plugin ABI | one `extern "C"` exported `plugin_descriptor` struct per plugin, checked against an ABI version |
| Config file format | custom INI-like two-level format, parsed by a Boost.Spirit X3 grammar into typed values |
| Config hot path | each parameter is a `std::atomic<T>` (or `std::atomic<std::shared_ptr<const T>>`) field of the component's config struct |
| Config iteration | Boost.Describe (`BOOST_DESCRIBE_STRUCT` with base classes) behind a type-erased `config_ref` interface |
| Logging | Boost.Log, asynchronous (non-blocking) sinks; stderr in dev, journald via `sd_journal_send` (native, structured) in production, syslog socket as fallback; per-component log level, hot-changeable |
| Async model | Boost.Asio: one pool of worker `io_context`s plus one dedicated control `io_context`; strands per component |
| Control plane | newline-delimited JSON over a Unix stream socket, Boost.JSON; `datadogctl` as the client; authorization by socket permissions, `SO_PEERCRED` for audit logging |
| CLI parsing | Boost.Program_options (`--help`, `--version`, `--config` for `datadogd`) |
