// src/core/core.cpp
// Translation unit of libdatadog_core.so; proves the DATADOG_API export machinery.

#include <datadog/core.hpp>
#include <datadog/version.h>

#include <string_view>

namespace datadog {

std::string_view core_version() noexcept { return kVERSION; }

} // namespace datadog
