// log_receiver_file — shared library plugin (stub).

#include <datadog/version.h>
#include <string_view>

/// Global version variable exported from this shared library.
extern "C" __attribute__((visibility("default"))) const std::string_view version = datadog::version;
