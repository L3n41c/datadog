# 03 — Configuration format and reflection

## Format decision

The configuration file needs **two levels**: a section header naming the plugin, and a body
of `key: value` parameters, with **typed values** (booleans, integers, durations, URLs — not
just strings). YAML/JSON/XML would work but are verbose for a hand-edited file. Boost.PropertyTree
(`read_ini`) gives the two-level INI shape for free but produces untyped strings, so durations
and URLs would still need a per-key parsing pass with duplicated code.

Decision: a **custom, minimal INI-like format parsed in one pass by a Boost.Spirit X3 grammar**
that produces typed values directly, with precise error messages (line and column, via the X3
`error_handler`). The value grammar is reused for the `set` IPC command and for formatting
values back to strings, so there is exactly one parser for values in the whole project.

Grammar (EBNF):

```ebnf
config    = { section } ;
section   = "[" , plugin_name , "]" , { param } ;
param     = identifier , ":" , value ;
value     = boolean | duration | integer | real | url | string | array ;
boolean   = "true" | "false" ;
integer   = [ "-" ] , digit , { digit } ;
real      = [ "-" ] , digit , { digit } , "." , { digit } ;
duration  = integer , unit ;
unit      = "ns" | "us" | "ms" | "s" | "m" | "h" ;
url       = scheme , "://" , { char - " " } ;   (* parsed/validated by boost::urls::parse_uri *)
string    = '"' , { escaped_char } , '"' | bare_token ;
array     = "[" , [ value , { "," , value } ] , "]" ;
comment   = "#" , { char - newline } ;
```

An unquoted token is interpreted as boolean, then duration (integer followed by a unit), then
integer, then real, then URL (if `boost::urls::parse_uri` accepts it and it has a scheme),
otherwise as a plain string. Quoted strings are always strings. `#` starts a comment anywhere
outside a quoted string. Whitespace around tokens is insignificant.

Example (`/etc/datadog/datadog.conf`):

```ini
# Daemon-wide settings (reserved section name "core").
[core]
log_level: info
log_target: journald        # stderr | journald | file:<path> | syslog:<host>:<port>
threads: 0                  # 0 = auto (hardware concurrency, capped)
socket: /run/datadog/datadog.sock
plugin_path: /usr/lib/datadog/plugins

[foo]
log_level: info
foo_A: true
foo_B: 42

[bar]
name: bar-prod              # optional explicit component name
log_level: warning
bar_A: https://example.org
bar_B: 20s

[bar]
name: bar-dev
log_level: debug
bar_A: http://localhost:1234
bar_B: 1s
```

Rules:

- A section header is a plugin name; the daemon loads `lib<plugin>.so` for it (doc 02).
- The reserved section `[core]` configures the daemon itself (table below) and never
  instantiates a component.
- An optional `name` parameter gives the component its explicit name; otherwise the component
  is named `<plugin>#<n>` (`n` = 0-based occurrence index of that plugin in the file).
  Component names must be unique; duplicates are a config error.
- Unknown keys, type mismatches, and duplicate keys are config errors reported with the
  section name and line/column; the whole file is validated before anything is applied.

`[core]` keys:

| Key | Values | Default |
|---|---|---|
| `log_level` | `trace` `debug` `info` `warning` `error` `critical` | `info` |
| `log_target` | `stderr`, `journald`, `file:<path>`, `syslog:<host>:<port>` | `stderr` |
| `log_queue` | `unbounded`, `drop_on_overflow` | `unbounded` |
| `threads` | integer, `0` = auto | `0` |
| `socket` | path of the control Unix socket | `/run/datadog/datadog.sock` |
| `plugin_path` | colon-separated directories | compiled-in default |
| `config` | path of the config file (alternative to `--config`) | — |

## Typed values: `config_value`

Parsed values are not strings internally (see `AGENTS.md`: never store composite data in a
`std::string` to be parsed later):

```cpp
// include/datadog/config.hpp (core)
using config_value = std::variant<
    std::monostate,                    // absent
    bool,
    std::int64_t,
    double,
    std::chrono::nanoseconds,          // all durations normalize to nanoseconds
    boost::urls::url,                  // validated at parse time
    std::string,
    std::vector<config_value>          // arrays
>;

using config_params = std::vector<std::pair<std::string, config_value>>;  // ordered, dup-checked
```

`to_string(const config_value&)` formats a value back (durations keep their largest whole unit,
URLs via `boost::urls::url::buffer()`/to-string) — used by `dump` and by error messages.

## Hot-path config: atomic fields

Each plugin defines its configuration as a plain aggregate struct publicly inheriting
`common_config`:

```cpp
// include/datadog/config.hpp (core)
struct common_config {
    config_atomic<severity> log_level;   // every component has a log level (doc 04)
};

// In the plugin:
struct foo_config : common_config {
    config_atomic<bool> foo_A;
    config_atomic<std::int64_t> foo_B;
};
```

`config_atomic<T>` is `std::atomic<T>` when `T` is trivially copyable, and
`std::atomic<std::shared_ptr<const T>>` otherwise (URLs, strings, arrays), with uniform
`load_value()` / `store_value()` helpers. Memory ordering depends on the kind of field:

- scalar fields (`std::atomic<U>`, trivially copyable): `load`/`store` with
  `std::memory_order_relaxed` — the atomic value itself is the whole payload;
- shared-pointer-backed fields (`std::atomic<std::shared_ptr<const T>>`): `store_value()` uses
  `std::memory_order_release` and `load_value()` uses `std::memory_order_acquire`, so that
  publishing the new pointee establishes a happens-before with any reader that dereferences
  it (a relaxed store would publish the pointer without ordering the pointee's construction).

Therefore **reading a parameter in the hot path is literally one atomic load**:

```cpp
if (cfg_.foo_A.load(std::memory_order_relaxed)) { ... }        // atomic<bool>, scalar
auto url = cfg_.endpoint.load_value();  // atomic<shared_ptr<const url>>, acquire inside
```

This is exactly the required "as fast as reading a `std::atomic<T>` field" property, and it
makes per-parameter hot updates safe: a `set` from `datadogctl` or a reload does a single
`store` per changed field, with no lock and no whole-struct swap.

## Programmatic iteration: Boost.Describe

The C++ hot path never iterates the config; only the control plane does (dump, get, set,
validation, schema). For that we need field **names** and **typed access**. Boost.PFR can
iterate aggregate fields but treats structs with base classes as non-portable
("SimpleAggregate" excludes bases), and our config structs all inherit `common_config`.
**Boost.Describe** handles base classes explicitly and deterministically:

```cpp
BOOST_DESCRIBE_STRUCT(foo_config, (common_config), (foo_A, foo_B))
```

On top of Describe, the core provides a small type-erased reflection layer:

```cpp
struct field_view {
    std::string_view name;
    config_type type;                                        // boolean|integer|real|duration|url|string|array
    std::function<config_value()> get;                       // bound to the config instance
    std::function<std::expected<void, std::string>(const config_value&)> set;  // atomic store
};

// Self-contained: the get/set closures are bound to the configuration instance at
// make_config_ref() time, so no raw pointer crosses the plugin boundary (AGENTS.md).
// Valid only while the component (and its configuration) is alive.
struct config_ref {                    // what component::config() returns
    std::string_view struct_name;
    std::vector<field_view> fields;    // base-class fields first (common_config::log_level included)
};

template <typename T>
config_ref make_config_ref(T& cfg);    // builds field_views from BOOST_DESCRIBE_STRUCT(T, ...),
                                       // binding &cfg into the get/set closures

template <typename T>
config_schema make_schema(const T& defaults);  // {name, type, default_value, description}
```

`set` converts the `config_value` to the member type (`std::atomic<U>` → `U`, with
`duration_cast` for `std::chrono` types, `parse_severity` for the log level, etc.) and stores
it with the field's memory order: `release` for shared-pointer-backed (non-scalar) fields so
the new pointee is safely published, `relaxed` for independent scalar fields (see
`config_atomic` above). A type mismatch is an error string, never an exception across the
plugin boundary.

Building a config from file/IPC parameters (`config_builder<T>::from_params(params, schema)`)
uses the same Describe walk: unknown key → error; missing key → schema default; present key →
`set`. So validation, instantiation, hot reload, and IPC `set` all share one code path (DRY).

Dumping is generic too: `to_json(const config_ref&)` produces a `boost::json::value` object of
`{field: value}` for `datadogctl dump`.

## Alternatives considered

- **Boost.PropertyTree INI/JSON/XML**: zero custom parser, but values arrive as strings and each
  plugin would re-parse durations/URLs/bools with its own code, and error positions are poor.
  Kept as a fallback only if a machine-generated config must be accepted (Boost.JSON can be
  layered on the same `config_value` tree).
- **Boost.PFR** (`pfr::for_each_field`, `pfr::get_name`): excellent for flat aggregates, but the
  documented "SimpleAggregate" excludes base classes, and our structs inherit `common_config`.
  Boost.Describe supports bases explicitly (`BOOST_DESCRIBE_STRUCT(T, (Base), (...))`).
- **Code generation** (a small CMake-time generator emitting field lists): no runtime reflection
  library needed, but adds a build step and a second source of truth for field names. Describe
  keeps names next to the struct, at compile time, with zero codegen.
- **Whole-config swap** (`std::atomic<std::shared_ptr<const Config>>`): simpler struct (plain
  fields), but a read costs an atomic pointer load plus a refcount, and per-field hot update is
  impossible. Rejected in favor of per-field atomics, which match the requirement literally.
