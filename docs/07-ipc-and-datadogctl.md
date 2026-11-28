# 07 — IPC control plane and datadogctl

`datadogctl` sends commands to the running `datadogd` daemon and prints the responses.

## Transport

- **Unix stream socket** (`boost::asio::local::stream_protocol`), path from `[core] socket`
  (default `/run/datadog/datadog.sock`), created with permissions `0660` (owner root, group
  `datadog`).
- **Authorization is done by the socket file permissions only** (owner root, group `datadog`):
  no application-level authentication.
- **Audit logging via `SO_PEERCRED`**: at accept time, the server calls
  `getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &len)` on the accepted socket, which on Linux
  fills a `struct ucred { pid_t pid; uid_t uid; gid_t gid; }`. The uid is resolved to a user
  name (`getpwuid_r`) and attached to the connection. Every command received is then logged on
  a dedicated `audit` channel, e.g.:
  `audit: cmd=set component=bar-prod key=log_level value=debug from user=root uid=0 pid=4242 gid=0`
  so the journal answers precisely "who sent this command" (`journalctl COMPONENT=audit` with
  the native backend, doc 04).
- The server runs on the **control io_context** (doc 05): one `acceptor`, one `co_spawn`'d
  coroutine per connection, `async_read_until('\n')` for requests, `async_write` for responses.

## Protocol

Newline-delimited JSON (Boost.JSON) — one request per line, one response per line:

```json
{"id": 1, "cmd": "set", "args": {"component": "bar-prod", "key": "log_level", "value": "debug"}}
{"id": 1, "ok": true, "result": null}
{"id": 2, "ok": false, "error": {"code": "unknown_component", "message": "no component named 'baz'"}}
```

- `value` in `set`/`load` args is a **string** parsed with the same Spirit X3 value grammar as
  the config file (doc 03), so `20s`, `https://example.org`, `true`, `42` are typed correctly.
- Responses are single-line JSON (`serialize` with default options); `dump` results are
  pretty-printed client-side by `datadogctl`.

## Commands

Implemented as a **Command pattern**: a map from command name to a `command` object with
`execute(args) -> awaitable<json::value>`, all running on the control strand and delegating to
the component manager (doc 06):

| Command | Args | Result |
|---|---|---|
| `list` | — | array of `{component, plugin, state}` |
| `status` | — | daemon info: version, uptime, plugin count, dropped log count |
| `schema` | `plugin` | the plugin's config schema (field names, types, defaults) |
| `dump` | `component` optional | config of one component, or of all, as a JSON object |
| `get` | `component`, `key` | one parameter value |
| `set` | `component`, `key`, `value` | apply one parameter at runtime (hot, atomic store) |
| `load` | `plugin`, `params` (object) | instantiate a new component now |
| `unload` | `component` | stop and destroy a component (unloads the plugin if last) |
| `reload` | — | re-read the config file and reconcile (same as `SIGUSR1`) |
| `shutdown` | — | graceful shutdown (same as `SIGTERM`) |

While the daemon is `draining` (shutdown in progress, doc 05), lifecycle-mutating commands
(`load`, `unload`, `reload`, `set`) are rejected with error code `shutting_down`; read-only
commands (`list`, `status`, `schema`, `dump`, `get`) remain available until the control
`io_context` stops. Note that stopping the acceptor alone is not enough: each accepted
connection has its own coroutine on the control strand, which could otherwise interleave
during the shutdown's asynchronous waits and mutate the lifecycle.

## datadogctl

CLI built with **Boost.Program_options** (subcommands mapped to the commands above), fully
Asio-based client (doc 05):

```text
datadogctl [--socket <path>] list
datadogctl dump [component]
datadogctl schema <plugin>
datadogctl get <component> <key>
datadogctl set <component> <key> <value>
datadogctl load <plugin> [key: value ...]
datadogctl unload <component>
datadogctl reload
datadogctl status
datadogctl shutdown
```

Exit code `0` on `ok: true`, `1` on error (message printed to stderr). `list` prints a table;
`dump` prints pretty-printed JSON.

## datadogd command line

Boost.Program_options, nothing more:

```text
datadogd --help
datadogd --version
datadogd --config=<CONFIG_FILE>     # default /etc/datadog/datadog.conf
```

All business configuration lives in the config file, never on the command line.
