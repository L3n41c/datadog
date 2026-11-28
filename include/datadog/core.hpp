// include/datadog/core.hpp
// Public entry point of libdatadog_core.so, the shared core library linked by
// datadogd, datadogctl and every plugin (doc 02, doc 08).

#pragma once

#include <datadog/api.hpp>

#include <string_view>

namespace datadog {

/// Version of the datadog_core shared library, derived from git describe.
DATADOG_API std::string_view core_version() noexcept;

} // namespace datadog
