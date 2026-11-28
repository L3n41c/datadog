# 04 — Logging

All logging in the project — daemon and plugins — goes through **Boost.Log**. Plugins never
write to `std::cout`/`std::cerr` directly.

## Severity

The core defines its own severity enum (so config files and IPC use stable names) in
`include/datadog/logging.hpp`:

```cpp
enum class severity { trace, debug, info, warning, error, critical };
std::string_view to_string(severity) noexcept;
std::optional<severity> parse_severity(std::string_view) noexcept;
std::ostream& operator<<(std::ostream&, severity);   // for Boost.Log formatters
```

## Non-blocking sinks

Requirement: in a fully asynchronous program, emitting a log record must never block the hot
path. Boost.Log is configured with **one `asynchronous_sink` per backend**, using an
`unbounded_fifo_queue` by default (enqueue never blocks; a dedicated feeding thread, created
with `start_thread = true`, drains the queue to the backend):

```cpp
using async_sink_t = boost::log::sinks::asynchronous_sink<
    boost::log::sinks::text_ostream_backend,           // or syslog_backend, text_file_backend
    boost::log::sinks::unbounded_fifo_queue>;

auto sink = boost::make_shared<async_sink_t>(boost::make_shared<backend_t>(...));
boost::log::core::get()->add_sink(sink);
```

`[core] log_queue: drop_on_overflow` switches to a `bounded_fifo_queue` +
`drop_on_overflow` policy and counts dropped records (reported in `status`), for environments
where unbounded memory growth is worse than losing logs. Either way the logging call itself
stays non-blocking.

On shutdown, after all components have stopped: `core->flush()` (waits until the queue is
drained), then `core->remove_all_sinks()`.

## Backends (selected at startup from `[core] log_target`)

| Target | Backend | Notes |
|---|---|---|
| `stderr` (development) | `text_ostream_backend` on `std::cerr`, `auto_flush(true)` | default when running in a terminal / under a debugger |
| `journald` (production, systemd service) | custom sink backend calling `sd_journal_send` (native protocol, see below); fallback: `syslog_backend` with `use_impl = syslog::unix_socket_based`, target `/dev/log` | native protocol by default — structured fields, no text parsing; syslog input only when built without libsystemd or when the native socket is absent (containers) |
| `file:<path>` | `text_file_backend` with size-based rotation | for exotic setups |
| `syslog:<host>:<port>` | `syslog_backend` with `udp_socket_based` (or `tcp_socket_based`) and `set_target_address(host, port)` | remote syslog server |

Severity → syslog level mapping uses `custom_severity_mapping<severity>("Severity")` mapping
our six levels onto the eight syslog levels (used by the syslog backends).

### journald: native protocol (`sd_journal_send`) vs syslog socket

`sd_journal_send` talks the **native journal protocol** on `/run/systemd/journal/socket` and
is strictly richer than the syslog **input** socket `/dev/log` (the socket journald listens
on, normally a symlink to `/run/systemd/journal/dev-log`; note that
`/run/systemd/journal/syslog` is only journald's *forwarding output* to an external syslog
daemon, not an input):

| Capability | native (`sd_journal_send`) | syslog input (`/dev/log`) |
|---|---|---|
| Arbitrary structured fields (`COMPONENT=bar-prod`, `PLUGIN=bar`, `CODE_LINE=…`) | yes — stored as first-class indexed journal fields | no — only `PRIORITY`, `SYSLOG_IDENTIFIER`, `SYSLOG_PID`, `MESSAGE` (free text) |
| Queryable with `journalctl COMPONENT=bar-prod`, `journalctl -o json` | yes | only via `SYSLOG_IDENTIFIER`; everything else is buried in the message text |
| Message payload | binary-safe (newlines, NULs allowed in `MESSAGE=`) | line-based text |
| Trusted metadata (`_PID`, `_UID`, `_GID`, `_COMM`, `_SYSTEMD_UNIT` added by journald from the socket credentials, non-forgeable) | yes | yes |
| Dependency | libsystemd (vcpkg port `libsystemd`, Linux only) | none |

Decision: the production `journald` target is a **custom Boost.Log sink backend** (about a
hundred lines, implementing the sink-backend `consume(record)` concept) that extracts the
record's attributes and calls `sd_journal_send` / `sd_journal_sendv` with `PRIORITY=<mapped
severity>`, `MESSAGE=<formatted message>`, `COMPONENT=<channel = component name>`, optionally
`CODE_FILE`/`CODE_LINE`. The `syslog_backend` → `/dev/log` remains as the automatic fallback
when built without libsystemd (build option `DATADOG_WITH_SYSTEMD=OFF`) or when the native
socket does not exist; if `/dev/log` does not exist either (e.g. containers without any local
logging daemon), the daemon falls back to `stderr` and logs a warning.

Format (all backends): `[TimeStamp] [Severity] [Channel] Message`, where `Channel` is the
component name. `add_common_attributes()` registers `TimeStamp` and `LineID`.

## Per-component log level

Every config struct inherits `common_config::log_level` (a `config_atomic<severity>`, doc 03).
Each component creates its logger through the core helper:

```cpp
// core helper — each component calls this once at creation
auto logger = datadog::make_component_logger(component_name, cfg_.log_level);
// internally: sources::channel_logger_mt<severity> with Channel = component_name, and a filter
//   [](const attribute_value_set& s) { return s[severity] >= level.load(relaxed); }
// the filter reads the atomic on every record, so changing log_level at runtime is hot.
```

Usage in plugin code: `BOOST_LOG_CHANNEL_SEV(logger, severity::info) << "...";` — never block,
never lock (the `_mt` logger is thread-safe, and the sink is asynchronous anyway).

The daemon-wide default level comes from `[core] log_level`; a component's own `log_level`
parameter overrides it. Changing it at runtime (`datadogctl set <component> log_level debug`)
goes through the generic `field_view::set` path (doc 03) and takes effect on the next record —
no restart, no re-creation of the component.

## Rules for plugin authors

- Get the logger from `make_component_logger` in the constructor; store it in the component.
- Log at the appropriate severity; never log in a tight loop without rate limiting (YAGNI: add
  rate limiting only where a real risk exists).
- Errors that must reach the operator go to `error`/`critical`; per-event details to `debug`/`trace`.
