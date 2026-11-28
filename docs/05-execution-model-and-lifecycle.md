# 05 — Execution model and lifecycle

Everything in the project is asynchronous and runs on **Boost.Asio**. Components never create
threads, never call blocking I/O, and never lock mutexes in their hot path.

## Executors

The daemon creates all executors and hands them to the components:

```text
worker pool                control plane
├── io_context × N          ├── io_context (1)
│   └── 1 thread each       │   └── 1 thread
│   └── work_guard          │   └── strand (serializes everything)
│   └── components assigned │       ├── signal_set (SIGUSR1/SIGTERM/SIGINT)
│       round-robin, each │       ├── IPC server (doc 07)
│       on its own strand │       └── component manager (doc 06)
└── (component hot paths)   └── (config reload, load/unload)
```

- `N` = `[core] threads`, or `min(hardware_concurrency, 16)` when `0` (auto).
- The pool follows the classic Asio `io_context_pool` pattern: one `io_context` per worker
  thread, each with a `make_work_guard` so `run()` does not exit prematurely.
- Each component is pinned to **one strand** (`boost::asio::make_strand(io)`) obtained
  round-robin from the pool. All handlers of a component — timers, sockets, posted callbacks,
  its `run()` coroutine — execute on that strand, so component code needs no internal locking
  (strand = serialized executor). The strand is passed to the plugin in
  `create_params::executor` as a type-erased `any_io_executor` (doc 02).
- The **control plane** is a separate `io_context` with a single thread. Everything that
  mutates global state — the plugin registry, the component manager, the IPC server, signal
  handling — is posted to its strand. A strand serializes individual handler invocations, so
  handler bodies run single-threaded without any explicit mutex — but a coroutine interleaves
  with other coroutines at every `co_await`. Lifecycle operations that suspend (e.g. waiting
  for a component to stop) must therefore serialize explicitly across the wait; see the state
  machine and shared completion wait in doc 06.

## Component execution

`component::run()` is a coroutine returning `boost::asio::awaitable<void>`. The manager
starts it with:

```cpp
asio::co_spawn(strand, component->run(),
    asio::bind_cancellation_slot(stop_signal->slot(),   // stop_signal is a shared_ptr (doc 06)
        [stop](std::exception_ptr e) {                  // completion handler: every exit path
            asio::post(control_strand, [stop, e] {      // completion processed on control strand
                if (e) { /* log the coroutine failure */ }
                stop->state = component_state::stopped;
                for (auto& w : std::exchange(stop->waiters, {})) w();  // broadcast (doc 06)
            });
        }));
```

Stopping a component = **posting the emission of the cancellation signal onto the component's
own strand**, then waiting for the coroutine to finish on the control strand. The emission
must be posted, not called directly from the control strand: Asio requires a cancellation
request to never run concurrently with the target operation's intermediate completion
handlers. The posted lambda captures the `shared_ptr<asio::cancellation_signal>` **by value**
(`asio::post(strand, [sig = entry.stop_signal] { sig->emit(); })`), so the signal stays alive
until the emission has actually run, even if the entry is erased first (e.g. `run()`
completed spontaneously before the emission executed). Completion is observed through the
completion handler above (not `asio::detached`, which provides no handler), which posts the
completion to the control strand and sets `stop->state = stopped` on every exit path —
including an exception escaping `run()`, which is logged — then broadcasts to all registered
waiters (doc 06). The component
must handle cancellation at every suspension point (Asio cancels timers/sockets
automatically; `co_await` points receive the cancellation). Destruction happens only after the
coroutine has completed, and the plugin library is unloaded only after destruction (doc 02).

## Signals

An `asio::signal_set` on the control `io_context`:

| Signal | Action |
|---|---|
| `SIGUSR1` | re-read the config file and reconcile (hot reload, doc 06) |
| `SIGTERM`, `SIGINT` | graceful shutdown |

Signal handling is `async_wait` on the control strand — no async-signal-unsafe code.

## Startup sequence

1. Parse CLI (`--help`/`--version`/`--config`, Boost.Program_options — doc 07).
1. Read and parse the config file (doc 03) into a typed tree; validate `[core]`.
1. Initialize logging from `[core] log_target` / `log_queue` (doc 04).
1. Create the worker pool (N `io_context`s + threads) and the control `io_context` + thread.
1. Start the IPC server on the control strand (doc 07).
1. Register the `signal_set`.
1. Reconcile the config: for each section, load the plugin (Boost.Dll), validate parameters
   against the plugin schema, create the component, `co_spawn` its `run()` on its strand
   (doc 06).
1. Run the control `io_context` on the main thread; join worker threads at exit.

## Shutdown sequence

The daemon has a state `running → draining` (control strand only). `SIGTERM`/`SIGINT` or the
IPC `shutdown` command sets it **synchronously** before anything else:

1. Set `draining`: lifecycle-mutating IPC commands (`load`, `unload`, `reload`) are rejected
   from now on; read-only commands (`list`, `status`, `dump`, `get`, `schema`) are still
   answered (doc 07). This matters because already-accepted connections keep their own
   coroutine on the control strand and could otherwise interleave at a suspension point and
   start a component after the cancellation sweep.
1. Stop the IPC acceptor (no new connections).
1. Drain in-flight manager operations (await in-flight operation count == 0).
1. Post the cancellation emission onto every component's strand; wait for all `run()`
   coroutines to finish (completion observed via the `stop_state` broadcast — doc 06).
1. Destroy components in reverse creation order; release plugins (unload `.so` at last
   component — doc 02).
1. `core->flush()` then `remove_all_sinks()` (doc 04).
1. Stop and join all `io_context`s and threads.

## Concurrency invariants

These invariants encode the lessons of the design reviews; apply them everywhere (daemon and
plugins). They are not optional style rules — violating one reintroduces a race.

1. **Actor model on the control strand.** All manager/registry/IPC state is mutated only on
   the control strand, and every state transition happens **synchronously, before any
   `co_await`**. A strand serializes handler invocations, not coroutine continuations: any
   operation that suspends (stop wait, reconcile, drain) goes through the FIFO operation queue
   (doc 06), never interleaves with another one.
1. **Shared RAII ownership at every boundary.** No raw pointers (`AGENTS.md`). Anything that
   crosses an asynchronous boundary or the `.so` boundary is kept alive by `shared_ptr`
   captured **by value** (e.g. the posted cancellation-emission lambda captures
   `shared_ptr<cancellation_signal>`), and plugin-descriptor callbacks are `std::function`.
1. **Memory ordering per field kind.** Scalar `std::atomic<T>` config fields: `relaxed`
   load/store. Shared-pointer-backed fields (`std::atomic<std::shared_ptr<const T>>`):
   `release` on store, `acquire` on load, so the published pointee is visible to readers.
1. **Broadcast, never channels, for multi-waiter completion.** Asio channels consume one
   message per receiver; completion is published as persistent state (`stop_state`) plus a
   waiter list that is invoked all at once on the control strand (doc 06).

## Rules

- No `std::thread` anywhere except the pool/control runners created by the daemon. No
  `std::mutex` in component hot paths (strands serialize); the control plane needs none either.
- No blocking calls in handlers (`run()`, socket callbacks, timers). Long CPU work is chunked
  and re-posted.
- `datadogctl` is also fully Asio-based: it creates its own `io_context`, connects to the
  control socket with `local::stream_protocol`, `co_spawn`s one coroutine, and `run()`s until
  the response arrives.
