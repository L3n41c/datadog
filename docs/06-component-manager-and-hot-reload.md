# 06 — Component manager and hot reload

The **component manager** is the single generic engine that creates, updates, and destroys
components. It is used by all three entry points — initial config load, `SIGUSR1` reload, and
IPC commands from `datadogctl` — so behavior is identical in every context (doc 05).

## State

```cpp
enum class component_state { running, stopping, stopped };  // control strand only

// Persistent completion state, shared by all lifecycle waiters. Asio channels do NOT
// broadcast (each message is consumed by a single receiver), so completion is broadcast
// explicitly: the co_spawn completion handler (doc 05) stores the result, sets
// state = stopped, and invokes every registered waiter. Waiters hold a shared_ptr to this
// struct, so its lifetime extends through the last waiter.
struct stop_state {
    component_state state = component_state::running;  // execution state, control strand only
    // Removal ownership, tracked INDEPENDENTLY of the execution state: set synchronously on
    // the control strand by the operation that claims the removal; the completion handler
    // never touches it. This survives the stopping -> stopped transition.
    bool has_removal_owner = false;                    // control strand only
    boost::system::error_code result;                  // set once, at completion
    std::vector<std::function<void()>> waiters;        // control strand only
};

struct component_entry {
    std::string component_name;                       // unique, from "name" or <plugin>#<n>
    std::string plugin_name;
    std::shared_ptr<const plugin_descriptor> descriptor;  // keeps the .so refcounted (doc 02)
    std::unique_ptr<component> object;
    boost::asio::any_io_executor strand;
    // Shared ownership: the posted emission lambda (below) captures it by value, so the signal
    // stays alive until the posted emission has actually run, even if this entry is erased
    // first (e.g. run() completed spontaneously before the emission executed).
    std::shared_ptr<asio::cancellation_signal> stop_signal =
        std::make_shared<asio::cancellation_signal>();
    std::shared_ptr<stop_state> stop = std::make_shared<stop_state>();
};

class component_manager {
    plugin_registry registry_;
    std::map<std::string, component_entry> components_;  // keyed by component name
    // all methods are invoked on the control strand only
};
```

A strand serializes handler invocations, not coroutine continuations across `co_await`
(doc 05). Two IPC connections unloading the same component, or a reload overlapping an
unload, would therefore interleave while the first operation waits for `run()` to finish, and
both could destroy and erase the same entry. To prevent this, lifecycle operations follow an
ownership rule (one of the concurrency invariants of doc 05): the operation that transitions
the entry `running → stopping` — done
**synchronously, before any suspension** — sets `has_removal_owner` and is the sole removal
owner; any other operation that finds the entry `stopping`, or `stopped` with an owner, only
registers a waiter on the same `stop` state and resumes when completion is broadcast. Only the
owner destroys the component, erases the entry, and calls `registry_.release(plugin)`.

## Operations (all posted to the control strand)

A strand serializes handler invocations, not coroutine continuations across `co_await`: two
overlapping `reconcile`s could interleave during their stop waits and end in a state matching
neither requested config (per-entry removal ownership prevents double destruction, but not
this). Complete manager operations are therefore **serialized through a FIFO operation queue
on the control strand**: an operation holds the queue until it has fully finished — including
all its asynchronous stop waits — and the next operation starts only then. Per-entry removal
ownership (above) remains as a second guard.

- `load_config_file(path) -> expected<void, config_error>` — parse (doc 03), validate every
  section against the plugin schema, then `reconcile`.
- `reconcile(config_tree)` — diff against current components by component name:
  - **new component** → `registry_.load(plugin)` (Boost.Dll `dlopen` if not already loaded),
    build config from params + schema defaults, `descriptor->create(...)`, store entry,
    `co_spawn` `run()` on the component strand;
  - **existing component, changed params** → apply each changed field through
    `component->config()` `field_view::set` (atomic store — hot, doc 03); if the section's
    plugin name changed (same component name, different plugin), destroy and recreate;
  - **removed component** → branch on `stop->state` **and** `stop->has_removal_owner`:
    - `running` (no owner yet) → transition synchronously to `stopping`, set
      `has_removal_owner = true`, become the removal owner: post the cancellation emission onto
      the component's strand, capturing the signal by value so it outlives the entry —
      `asio::post(strand, [sig = entry.stop_signal] { sig->emit(); })` — then wait for the
      broadcast completion; on completion, destroy
      the component, erase the entry, `registry_.release(plugin)` (unloads the `.so` when it was
      the last component of that plugin);
    - `stopping`, or `stopped` **with** an owner (a removal is already in progress) → only
      register a waiter on `stop` — never destroy or erase twice;
    - `stopped` **without** an owner (the coroutine finished spontaneously, normally or by
      exception, and the completion handler already broadcast) → claim removal ownership
      immediately and synchronously (`has_removal_owner = true`, no wait needed), then destroy,
      erase, `registry_.release(plugin)`.

    Waiter registration rule: if `stop->state` is already `stopped` when a waiter registers, the
    waiter is invoked immediately; otherwise it is appended to `stop->waiters` and invoked at
    broadcast. Removal ownership is independent of the execution state (`has_removal_owner`,
    set synchronously on the control strand; the completion handler never touches it), so only
    the removal owner ever destroys/erases/releases and overlapping operations cannot
    double-remove an entry.
- `load_component(plugin, params)` / `unload_component(component_name)` /
  `set_param(component_name, key, value)` / `get_param` / `dump(component_name?)` / `list()` —
  the primitives behind the IPC commands (doc 07). `set_param` parses the value string with the
  same Spirit X3 value grammar as the config file (doc 03).

Reconcile is **atomic with respect to parse errors**: if the new file fails to parse or to
validate, nothing changes, the error (with line/column) is logged and returned to the caller
(`SIGUSR1` → logged; IPC `reload` → error response). If a plugin fails to load or a component
fails to start, only that component is skipped; the rest of the config still applies, and the
failure is reported.

## Component naming

- If the section has a `name` parameter, that is the component name.
- Otherwise the component name is `<plugin>#<n>`, `n` = 0-based occurrence of that plugin in
  the file. Example: the two `[bar]` sections without `name` become `bar#0` and `bar#1`.
- Component names are unique across the whole config; a collision is a config error.

## Hot reload example

`kill -USR1 <pid>` (or `datadogctl reload`) re-reads the file:

```ini
[bar]
name: bar-prod
log_level: debug        # changed: info -> debug, applied live via atomic store
bar_A: https://example.org
bar_B: 20s
```

`bar-prod` keeps running with the new level; a removed section is stopped and destroyed; a new
section is created, loading its plugin on demand. Plugins that are no longer referenced are
unloaded (`dlclose` via Boost.Dll refcount, doc 02).
